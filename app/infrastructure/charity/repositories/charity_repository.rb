# frozen_string_literal: true

module Infrastructure
  module Charity
    module Repositories
      # Repository for charity aggregate persistence and retrieval
      # Implements sophisticated caching and query optimization
      class CharityRepository
        include Interfaces::CharityRepository

        def initialize(event_store = nil, cache_store = nil)
          @event_store = event_store || Infrastructure::EventStore::InMemoryEventStore.new
          @cache_store = cache_store || Infrastructure::Cache::RedisCacheStore.new
          @loaded_aggregates = {}
        end

        # Find charity by ID with sophisticated caching
        # @param charity_id [String] charity identifier
        # @return [Domain::Entities::Charity, nil] charity aggregate or nil
        def find_by_id(charity_id)
          # Try cache first for performance
          cached_charity = fetch_from_cache(charity_id)
          return cached_charity if cached_charity.present?

          # Load from event store
          events = @event_store.get_events_for_aggregate(charity_id)

          if events.any?
            charity = reconstruct_from_events(charity_id, events)
            cache_charity(charity)
            charity
          else
            cache_miss(charity_id) # Cache negative result
            nil
          end
        end

        # Find charity by EIN for duplicate checking
        # @param ein [String] employer identification number
        # @return [Domain::Entities::Charity, nil] charity aggregate or nil
        def find_by_ein(ein)
          # Use read model projection for efficient EIN lookup
          read_model = find_charity_read_model_by_ein(ein)

          if read_model.present?
            events = @event_store.get_events_for_aggregate(read_model.id)
            charity = reconstruct_from_events(read_model.id, events)
            cache_charity(charity)
            charity
          end
        end

        # Save charity aggregate (update read models)
        # @param charity_aggregate [Domain::Entities::Charity] charity aggregate
        def save(charity_aggregate)
          # Update read models for query optimization
          update_read_models(charity_aggregate)

          # Update cache
          cache_charity(charity_aggregate)

          # Trigger any background processing
          trigger_background_processing(charity_aggregate)
        end

        # Find charities by category with sophisticated filtering
        # @param category [Symbol] charity category
        # @param filters [Hash] additional filters
        # @return [Array<Domain::Entities::Charity>] filtered charities
        def find_by_category(category, filters = {})
          # Use read model for efficient category queries
          read_models = find_charity_read_models_by_category(category, filters)

          read_models.map do |read_model|
            events = @event_store.get_events_for_aggregate(read_model.id)
            reconstruct_from_events(read_model.id, events)
          end
        end

        # Find verified charities with pagination
        # @param page [Integer] page number
        # @param per_page [Integer] items per page
        # @return [Hash] paginated results with metadata
        def find_verified_charities(page = 1, per_page = 20)
          # Use read model projection for verified charities
          read_models = find_verified_charity_read_models(page, per_page)

          charities = read_models.map do |read_model|
            events = @event_store.get_events_for_aggregate(read_model.id)
            reconstruct_from_events(read_model.id, events)
          end

          {
            charities: charities,
            pagination: {
              page: page,
              per_page: per_page,
              total: total_verified_charities_count,
              total_pages: (total_verified_charities_count.to_f / per_page).ceil
            }
          }
        end

        # Search charities with sophisticated text search
        # @param query [String] search query
        # @param options [Hash] search options
        # @return [Array<Domain::Entities::Charity>] matching charities
        def search(query, options = {})
          # Use full-text search capabilities
          read_models = search_charity_read_models(query, options)

          read_models.map do |read_model|
            events = @event_store.get_events_for_aggregate(read_model.id)
            reconstruct_from_events(read_model.id, events)
          end
        end

        # Get charity impact leaderboard
        # @param limit [Integer] number of results
        # @param timeframe [Symbol] time period (:daily, :weekly, :monthly, :all_time)
        # @return [Array<Hash>] leaderboard data
        def get_impact_leaderboard(limit = 10, timeframe = :monthly)
          # Use pre-computed impact projections
          leaderboard_data = fetch_impact_leaderboard_data(limit, timeframe)

          leaderboard_data.map do |entry|
            charity_id = entry['charity_id']
            events = @event_store.get_events_for_aggregate(charity_id)
            charity = reconstruct_from_events(charity_id, events)

            entry.merge(
              'charity' => charity,
              'formatted_impact' => format_impact_score(entry['impact_score'])
            )
          end
        end

        private

        # Fetch charity from cache
        # @param charity_id [String] charity identifier
        # @return [Domain::Entities::Charity, nil] cached charity or nil
        def fetch_from_cache(charity_id)
          cache_key = "charity:#{charity_id}"

          # Try in-memory cache first
          return @loaded_aggregates[charity_id] if @loaded_aggregates.key?(charity_id)

          # Try Redis cache
          cached_data = @cache_store.get(cache_key)
          return nil if cached_data == 'MISS' # Explicit cache miss

          if cached_data.present?
            reconstruct_from_cache_data(cached_data)
          end
        end

        # Cache charity aggregate
        # @param charity [Domain::Entities::Charity] charity aggregate
        def cache_charity(charity)
          cache_key = "charity:#{charity.id}"

          # Update in-memory cache
          @loaded_aggregates[charity.id] = charity

          # Update Redis cache with TTL
          cache_data = serialize_for_cache(charity)
          @cache_store.set(cache_key, cache_data, expires_in: 1.hour)
        end

        # Mark cache miss for negative caching
        # @param charity_id [String] charity identifier
        def cache_miss(charity_id)
          cache_key = "charity:#{charity_id}"
          @cache_store.set(cache_key, 'MISS', expires_in: 15.minutes)
        end

        # Reconstruct charity from events
        # @param charity_id [String] charity identifier
        # @param events [Array<Domain::Events::DomainEvent>] domain events
        # @return [Domain::Entities::Charity] reconstructed charity
        def reconstruct_from_events(charity_id, events)
          charity = Domain::Entities::Charity.new(charity_id)
          events.each { |event| charity.apply(event) }
          charity.mark_events_committed
          charity
        end

        # Reconstruct charity from cache data
        # @param cache_data [Hash] cached charity data
        # @return [Domain::Entities::Charity] reconstructed charity
        def reconstruct_from_cache_data(cache_data)
          charity = Domain::Entities::Charity.new(cache_data['id'])

          # Reconstruct state from cache snapshot
          charity.instance_variable_set(:@name, cache_data['name'])
          charity.instance_variable_set(:@version, cache_data['version'])
          charity.instance_variable_set(:@created_at, Time.parse(cache_data['created_at']))
          charity.instance_variable_set(:@updated_at, Time.parse(cache_data['updated_at']))

          # Mark as loaded from cache (no uncommitted events)
          charity.mark_events_committed

          charity
        end

        # Serialize charity for caching
        # @param charity [Domain::Entities::Charity] charity aggregate
        # @return [Hash] serializable cache data
        def serialize_for_cache(charity)
          {
            id: charity.id,
            name: charity.name,
            version: charity.version,
            created_at: charity.created_at.iso8601,
            updated_at: charity.updated_at.iso8601
          }
        end

        # Update read models for query optimization
        # @param charity_aggregate [Domain::Entities::Charity] charity aggregate
        def update_read_models(charity_aggregate)
          # This would update materialized views for fast querying
          # For now, implemented as placeholder
          Rails.logger.info("Updating read models for charity: #{charity_aggregate.id}")
        end

        # Trigger background processing
        # @param charity_aggregate [Domain::Entities::Charity] charity aggregate
        def trigger_background_processing(charity_aggregate)
          # Trigger impact recalculation if needed
          if charity_aggregate.donor_count % 10 == 0 # Every 10 donations
            recalculate_impact_projections(charity_aggregate.id)
          end
        end

        # Placeholder methods for read model operations
        # These would integrate with actual database views/projections

        def find_charity_read_model_by_ein(ein)
          # Placeholder - would query charity_read_models table
          nil
        end

        def find_charity_read_models_by_category(category, filters)
          # Placeholder - would query with sophisticated filtering
          []
        end

        def find_verified_charity_read_models(page, per_page)
          # Placeholder - would query verified charities with pagination
          []
        end

        def search_charity_read_models(query, options)
          # Placeholder - would use full-text search
          []
        end

        def fetch_impact_leaderboard_data(limit, timeframe)
          # Placeholder - would query pre-computed impact scores
          []
        end

        def total_verified_charities_count
          # Placeholder - would query count of verified charities
          0
        end

        def format_impact_score(score)
          # Format impact score for display
          "$#{score.round(0)}"
        end

        def recalculate_impact_projections(charity_id)
          # Trigger background job for impact recalculation
          ImpactRecalculationJob.perform_async(charity_id)
        end
      end
    end
  end
end