# frozen_string_literal: true

# Enterprise-grade search integration module providing comprehensive
# search indexing, optimization, and multi-provider search capabilities
# for ActiveRecord models
#
# @author Kilo Code Autonomous Agent
# @version 2.0.0
# @since 2025-10-19
#
# @example
#   class Product < ApplicationRecord
#     enterprise_modules do
#       search :elasticsearch, providers: [:elasticsearch, :algolia]
#     end
#   end
#
module EnterpriseModules
  module SearchModule
    extend ActiveSupport::Concern

    # === CONSTANTS ===

    # Search provider configurations
    SEARCH_PROVIDERS = {
      elasticsearch: {
        adapter: :elasticsearch,
        index_name_prefix: 'enterprise',
        settings: {
          number_of_shards: 2,
          number_of_replicas: 1,
          refresh_interval: '30s'
        }
      },
      algolia: {
        adapter: :algolia,
        application_id: ENV['ALGOLIA_APPLICATION_ID'],
        api_key: ENV['ALGOLIA_API_KEY'],
        index_settings: {
          searchableAttributes: ['name', 'description'],
          attributesForFaceting: ['category', 'status']
        }
      },
      solr: {
        adapter: :solr,
        url: ENV['SOLR_URL'],
        collection: 'enterprise_collection'
      },
      database: {
        adapter: :database,
        full_text_search: true,
        trigram_search: true
      }
    }.freeze

    # Search optimization thresholds
    SEARCH_THRESHOLDS = {
      slow_search: { threshold_ms: 500, action: :optimize },
      search_timeout: { threshold_ms: 5000, action: :fallback },
      high_frequency: { threshold_per_minute: 1000, action: :cache_results },
      large_result_set: { threshold_count: 10000, action: :paginate }
    }.freeze

    # Search index configurations
    INDEX_CONFIGURATIONS = {
      real_time: { refresh_interval: '1s', batch_size: 100 },
      near_real_time: { refresh_interval: '30s', batch_size: 1000 },
      batch: { refresh_interval: '5m', batch_size: 10000 },
      scheduled: { refresh_interval: '1h', batch_size: 50000 }
    }.freeze

    # === ASSOCIATIONS ===

    included do
      # Search tracking associations
      has_many :search_queries, class_name: 'ModelSearchQuery', dependent: :destroy if defined?(ModelSearchQuery)
      has_many :search_analytics, class_name: 'ModelSearchAnalytic', dependent: :destroy if defined?(ModelSearchAnalytic)
      has_many :search_suggestions, class_name: 'ModelSearchSuggestion', dependent: :destroy if defined?(ModelSearchSuggestion)

      # Search performance monitoring
      has_many :search_metrics, class_name: 'ModelSearchMetric', dependent: :destroy if defined?(ModelSearchMetric)

      # Search configuration
      class_attribute :search_config, default: {}
      class_attribute :search_providers, default: [:database]
      class_attribute :search_mappings, default: {}
      class_attribute :search_settings, default: {}
    end

    # === CLASS METHODS ===

    # Configure search settings for the model
    def self.search_config=(config)
      self.search_config = config
    end

    # Define search providers for the model
    def self.search_providers=(providers)
      self.search_providers = Array(providers)
    end

    # Define search field mappings
    def self.search_mappings=(mappings)
      self.search_mappings = mappings
    end

    # Define search settings
    def self.search_settings=(settings)
      self.search_settings = settings
    end

    # Advanced enterprise search with security and performance
    def self.enterprise_search(query, **options)
      search_service = EnterpriseSearchService.new(self)

      # Apply security filters
      secured_query = search_service.apply_security_filters(query, options)

      # Apply performance optimizations
      optimized_query = search_service.apply_performance_optimizations(secured_query, options)

      # Execute search with monitoring
      search_service.execute_search_with_monitoring(optimized_query, options)
    end

    # Generate comprehensive search analytics
    def self.generate_search_analytics(**options)
      analytics_service = SearchAnalyticsService.new(self)

      {
        search_volume: analytics_service.search_volume(options[:timeframe]),
        popular_queries: analytics_service.popular_queries(options[:limit]),
        search_performance: analytics_service.search_performance_metrics,
        user_engagement: analytics_service.user_engagement_metrics,
        search_trends: analytics_service.search_trends(options[:timeframe]),
        conversion_rates: analytics_service.conversion_rates
      }
    end

    # Optimize search indexes for better performance
    def self.optimize_search_indexes(**options)
      optimization_service = SearchOptimizationService.new(self)

      {
        index_health: optimization_service.assess_index_health,
        optimization_suggestions: optimization_service.generate_optimization_suggestions,
        performance_improvements: optimization_service.implement_performance_improvements,
        applied_optimizations: optimization_service.applied_optimizations
      }
    end

    # === INSTANCE METHODS ===

    # Update search indexes for all configured providers
    def update_search_indexes(**options)
      return unless search_enabled?

      search_service = SearchIndexService.new(self)

      # Update primary search indexes
      search_service.update_primary_indexes(options)

      # Update secondary search indexes if configured
      search_service.update_secondary_indexes(options)

      # Update external search services
      search_service.update_external_services(options)

      # Log index update
      log_search_index_update(options)
    end

    # Remove from all search indexes
    def remove_from_search_indexes(**options)
      return unless search_enabled?

      search_service = SearchIndexService.new(self)

      # Remove from primary indexes
      search_service.remove_from_primary_indexes(options)

      # Remove from secondary indexes
      search_service.remove_from_secondary_indexes(options)

      # Remove from external services
      search_service.remove_from_external_services(options)

      # Log index removal
      log_search_index_removal(options)
    end

    # Perform search query with enterprise features
    def perform_enterprise_search(query, **options)
      search_service = EnterpriseSearchService.new(self.class)

      # Build search context
      search_context = build_search_context(options)

      # Execute search with context
      search_service.execute_contextual_search(query, search_context)
    end

    # Generate search suggestions for autocomplete
    def generate_search_suggestions(partial_query, **options)
      suggestion_service = SearchSuggestionService.new(self.class)

      suggestion_service.generate_suggestions(
        partial_query,
        limit: options[:limit] || 10,
        context: options[:context],
        user: options[:user]
      )
    end

    # === PRIVATE METHODS ===

    private

    # Check if search is enabled for this model
    def search_enabled?
      # Check if Searchkick is available and model is configured for search
      return false unless defined?(Searchkick)

      # Check model-specific search configuration
      search_config[:enabled] != false
    end

    # Build search context for the operation
    def build_search_context(options)
      {
        user: options[:user] || Current.user,
        organization: options[:organization] || Current.organization,
        permissions: options[:permissions] || current_user_permissions,
        filters: options[:filters] || {},
        preferences: options[:preferences] || current_user_search_preferences,
        timestamp: Time.current
      }
    end

    # Get current user permissions for search
    def current_user_permissions
      return {} unless Current.user

      {
        can_access_all_records: Current.user.admin?,
        can_access_organization_data: Current.user.organization.present?,
        can_access_sensitive_data: Current.user.has_sensitive_data_access?,
        restricted_categories: Current.user.restricted_categories || []
      }
    end

    # Get current user search preferences
    def current_user_search_preferences
      return {} unless Current.user

      Current.user.search_preferences || {}
    end

    # Log search index update
    def log_search_index_update(options)
      return unless respond_to?(:search_metrics)

      search_metrics.create!(
        operation: :index_update,
        provider: options[:provider] || :primary,
        record_count: 1,
        execution_time: options[:execution_time],
        success: options[:success] != false,
        error_message: options[:error_message],
        metadata: options[:metadata] || {},
        created_at: Time.current
      )
    end

    # Log search index removal
    def log_search_index_removal(options)
      return unless respond_to?(:search_metrics)

      search_metrics.create!(
        operation: :index_removal,
        provider: options[:provider] || :primary,
        record_count: 1,
        execution_time: options[:execution_time],
        success: options[:success] != false,
        error_message: options[:error_message],
        metadata: options[:metadata] || {},
        created_at: Time.current
      )
    end

    # === SEARCH SERVICES ===

    # Main enterprise search service
    class EnterpriseSearchService
      def initialize(model_class)
        @model_class = model_class
      end

      def apply_security_filters(query, options)
        # Apply security filters based on user context
        security_service = SearchSecurityService.new(@model_class)

        # Add organization filters
        if options[:user]&.organization
          query = security_service.apply_organization_filter(query, options[:user].organization)
        end

        # Add permission-based filters
        if options[:user]
          query = security_service.apply_permission_filters(query, options[:user])
        end

        # Add data classification filters
        if options[:data_classification]
          query = security_service.apply_classification_filter(query, options[:data_classification])
        end

        query
      end

      def apply_performance_optimizations(query, options)
        # Apply performance optimizations
        optimization_service = SearchOptimizationService.new(@model_class)

        # Add query result limiting
        if options[:limit]
          query = optimization_service.apply_result_limiting(query, options[:limit])
        end

        # Add field selection for performance
        if options[:select]
          query = optimization_service.apply_field_selection(query, options[:select])
        end

        # Add query caching if appropriate
        if options[:use_cache] != false
          query = optimization_service.apply_query_caching(query, options)
        end

        query
      end

      def execute_search_with_monitoring(query, options)
        # Execute search with comprehensive monitoring
        start_time = Time.current

        begin
          # Execute the search
          results = execute_search(query, options)

          # Record performance metrics
          execution_time = Time.current - start_time
          record_search_metrics(execution_time, results, options)

          # Trigger performance alerts if needed
          trigger_search_alerts(execution_time, results, options)

          results
        rescue => e
          # Handle search errors
          handle_search_error(e, query, options)
          raise e
        end
      end

      private

      def execute_search(query, options)
        # Execute search based on configured providers
        provider_service = SearchProviderService.new(@model_class)

        case options[:provider] || @model_class.search_providers.first
        when :elasticsearch
          provider_service.execute_elasticsearch_search(query, options)
        when :algolia
          provider_service.execute_algolia_search(query, options)
        when :solr
          provider_service.execute_solr_search(query, options)
        else
          provider_service.execute_database_search(query, options)
        end
      end

      def record_search_metrics(execution_time, results, options)
        return unless @model_class.respond_to?(:search_metrics)

        @model_class.search_metrics.create!(
          operation: :search,
          query: options[:query],
          provider: options[:provider] || :database,
          execution_time: execution_time,
          result_count: results&.count || 0,
          success: true,
          metadata: {
            filters_applied: options[:filters]&.keys,
            sorting: options[:order],
            pagination: options[:page]
          },
          created_at: Time.current
        )
      end

      def trigger_search_alerts(execution_time, results, options)
        alert_service = SearchAlertService.new(@model_class)

        # Check execution time thresholds
        if execution_time > SEARCH_THRESHOLDS[:slow_search][:threshold_ms].milliseconds
          alert_service.trigger_performance_alert(execution_time, options)
        end

        # Check result count thresholds
        if results&.count.to_i > SEARCH_THRESHOLDS[:large_result_set][:threshold_count]
          alert_service.trigger_large_result_alert(results.count, options)
        end
      end

      def handle_search_error(error, query, options)
        # Log search error
        return unless @model_class.respond_to?(:search_metrics)

        @model_class.search_metrics.create!(
          operation: :search,
          query: options[:query],
          provider: options[:provider] || :database,
          execution_time: 0,
          result_count: 0,
          success: false,
          error_message: error.message,
          metadata: {
            error_class: error.class.name,
            backtrace: error.backtrace&.first
          },
          created_at: Time.current
        )
      end
    end

    # Search index management service
    class SearchIndexService
      def initialize(record)
        @record = record
      end

      def update_primary_indexes(options)
        # Update primary search indexes (Elasticsearch, etc.)
        @record.class.search_providers.each do |provider|
          case provider
          when :elasticsearch
            update_elasticsearch_index(options)
          when :algolia
            update_algolia_index(options)
          when :solr
            update_solr_index(options)
          when :database
            update_database_index(options)
          end
        end
      end

      def update_secondary_indexes(options)
        # Update secondary search indexes if configured
        secondary_providers = @record.class.search_config[:secondary_providers] || []

        secondary_providers.each do |provider|
          update_secondary_provider_index(provider, options)
        end
      end

      def update_external_services(options)
        # Update external search services
        external_services = @record.class.search_config[:external_services] || []

        external_services.each do |service|
          update_external_service_index(service, options)
        end
      end

      def remove_from_primary_indexes(options)
        # Remove from primary search indexes
        @record.class.search_providers.each do |provider|
          case provider
          when :elasticsearch
            remove_from_elasticsearch_index(options)
          when :algolia
            remove_from_algolia_index(options)
          when :solr
            remove_from_solr_index(options)
          when :database
            remove_from_database_index(options)
          end
        end
      end

      def remove_from_secondary_indexes(options)
        # Remove from secondary search indexes
        secondary_providers = @record.class.search_config[:secondary_providers] || []

        secondary_providers.each do |provider|
          remove_from_secondary_provider_index(provider, options)
        end
      end

      def remove_from_external_services(options)
        # Remove from external search services
        external_services = @record.class.search_config[:external_services] || []

        external_services.each do |service|
          remove_from_external_service_index(service, options)
        end
      end

      private

      def update_elasticsearch_index(options)
        return unless defined?(Searchkick) && @record.class.respond_to?(:searchkick)

        # Update Elasticsearch index
        @record.reindex

        # Update related indexes if needed
        update_related_elasticsearch_indexes(options)
      end

      def update_algolia_index(options)
        # Update Algolia index
        return unless defined?(Algolia) && @record.class.respond_to?(:algolia_index)

        algolia_index = @record.class.algolia_index
        algolia_index.save_object(@record.algolia_index_data, { auto_generate_object_id_if_not_exist: true })
      end

      def update_solr_index(options)
        # Update Solr index
        return unless defined?(Sunspot) && @record.class.respond_to?(:sunspot)

        @record.solr_index
        Sunspot.commit
      end

      def update_database_index(options)
        # Update database search indexes (trigrams, full-text search)
        update_database_search_indexes(options)
      end

      def remove_from_elasticsearch_index(options)
        return unless defined?(Searchkick) && @record.class.respond_to?(:searchkick)

        @record.remove_from_index
      end

      def remove_from_algolia_index(options)
        return unless defined?(Algolia) && @record.class.respond_to?(:algolia_index)

        algolia_index = @record.class.algolia_index
        algolia_index.delete_object(@record.id)
      end

      def remove_from_solr_index(options)
        return unless defined?(Sunspot) && @record.class.respond_to?(:sunspot)

        @record.remove_from_solr
        Sunspot.commit
      end

      def remove_from_database_index(options)
        # Remove from database search indexes
        # Implementation depends on database search setup
      end

      def update_related_elasticsearch_indexes(options)
        # Update related indexes for associations
        update_association_indexes(options)
      end

      def update_association_indexes(options)
        # Update search indexes for associated records
        @record.class.reflect_on_all_associations.each do |association|
          next unless association.macro == :has_many

          associated_records = @record.send(association.name)
          associated_records.find_each do |associated_record|
            associated_record.update_search_indexes(options.merge(association_update: true))
          end
        end
      end

      def update_secondary_provider_index(provider, options)
        # Update secondary provider index
        case provider
        when :redis
          update_redis_search_index(options)
        when :memory
          update_memory_search_index(options)
        else
          # Generic secondary provider update
        end
      end

      def update_external_service_index(service, options)
        # Update external service index
        case service
        when :google_cloud_search
          update_google_cloud_search_index(options)
        when :azure_search
          update_azure_search_index(options)
        when :aws_cloudsearch
          update_aws_cloudsearch_index(options)
        else
          # Generic external service update
        end
      end

      def remove_from_secondary_provider_index(provider, options)
        # Remove from secondary provider index
        case provider
        when :redis
          remove_from_redis_search_index(options)
        when :memory
          remove_from_memory_search_index(options)
        end
      end

      def remove_from_external_service_index(service, options)
        # Remove from external service index
        case service
        when :google_cloud_search
          remove_from_google_cloud_search_index(options)
        when :azure_search
          remove_from_azure_search_index(options)
        when :aws_cloudsearch
          remove_from_aws_cloudsearch_index(options)
        end
      end

      def update_redis_search_index(options)
        # Update Redis search index
        # Implementation depends on Redis search setup
      end

      def update_memory_search_index(options)
        # Update in-memory search index
        # Implementation for memory-based search
      end

      def update_google_cloud_search_index(options)
        # Update Google Cloud Search index
        # Implementation for Google Cloud Search integration
      end

      def update_azure_search_index(options)
        # Update Azure Search index
        # Implementation for Azure Search integration
      end

      def update_aws_cloudsearch_index(options)
        # Update AWS CloudSearch index
        # Implementation for AWS CloudSearch integration
      end

      def remove_from_redis_search_index(options)
        # Remove from Redis search index
      end

      def remove_from_memory_search_index(options)
        # Remove from in-memory search index
      end

      def remove_from_google_cloud_search_index(options)
        # Remove from Google Cloud Search index
      end

      def remove_from_azure_search_index(options)
        # Remove from Azure Search index
      end

      def remove_from_aws_cloudsearch_index(options)
        # Remove from AWS CloudSearch index
      end

      def update_database_search_indexes(options)
        # Update database-specific search indexes
        # Implementation for database full-text search
      end
    end

    # Search security service
    class SearchSecurityService
      def initialize(model_class)
        @model_class = model_class
      end

      def apply_organization_filter(query, organization)
        # Apply organization-based filtering
        if @model_class.column_names.include?('organization_id')
          query = query.where(organization_id: organization.id)
        end

        query
      end

      def apply_permission_filters(query, user)
        # Apply user permission-based filters
        unless user.admin?
          # Apply role-based access control
          query = apply_role_based_filters(query, user)

          # Apply record-level permissions
          query = apply_record_level_permissions(query, user)
        end

        query
      end

      def apply_classification_filter(query, classification)
        # Apply data classification filters
        if @model_class.column_names.include?('data_classification')
          query = query.where(data_classification: classification)
        end

        query
      end

      private

      def apply_role_based_filters(query, user)
        # Apply filters based on user role
        case user.role&.to_sym
        when :manager
          # Managers can see their organization's data
          apply_organization_scope(query, user)
        when :user
          # Regular users can only see their own data
          apply_user_scope(query, user)
        else
          # Default restrictive scope
          query.none
        end
      end

      def apply_record_level_permissions(query, user)
        # Apply record-level permission filters
        if @model_class.column_names.include?('user_id')
          query = query.where(user_id: user.id)
        end

        query
      end

      def apply_organization_scope(query, user)
        if @model_class.column_names.include?('organization_id')
          query.where(organization_id: user.organization_id)
        else
          query
        end
      end

      def apply_user_scope(query, user)
        if @model_class.column_names.include?('user_id')
          query.where(user_id: user.id)
        else
          query.none
        end
      end
    end

    # Search optimization service
    class SearchOptimizationService
      def initialize(model_class)
        @model_class = model_class
      end

      def apply_result_limiting(query, limit)
        # Apply result limiting for performance
        query.limit(limit)
      end

      def apply_field_selection(query, fields)
        # Apply field selection to reduce data transfer
        query.select(fields)
      end

      def apply_query_caching(query, options)
        # Apply query caching for frequently executed searches
        cache_key = generate_cache_key(query, options)

        # Check cache first
        cached_result = Rails.cache.read(cache_key)
        return cached_result if cached_result.present?

        # Execute query and cache result
        result = query.execute
        Rails.cache.write(cache_key, result, expires_in: cache_expiry_time(options))
        result
      end

      def assess_index_health
        # Assess health of search indexes
        health_metrics = {}

        @model_class.search_providers.each do |provider|
          health_metrics[provider] = assess_provider_health(provider)
        end

        health_metrics
      end

      def generate_optimization_suggestions
        # Generate optimization suggestions
        suggestions = []

        # Analyze search performance
        performance_analysis = analyze_search_performance
        suggestions.concat(performance_analysis[:suggestions])

        # Analyze index usage
        usage_analysis = analyze_index_usage
        suggestions.concat(usage_analysis[:suggestions])

        suggestions.uniq
      end

      def implement_performance_improvements
        # Implement automatic performance improvements
        improvements = []

        # Optimize slow queries
        improvements.concat(optimize_slow_queries)

        # Optimize index structures
        improvements.concat(optimize_index_structures)

        # Update caching strategies
        improvements.concat(update_caching_strategies)

        improvements
      end

      private

      def generate_cache_key(query, options)
        # Generate cache key for search query
        key_components = [
          @model_class.name,
          query.to_sql,
          options[:user]&.id,
          options[:organization]&.id
        ]

        Digest::MD5.hexdigest(key_components.join(':'))
      end

      def cache_expiry_time(options)
        # Determine cache expiry time based on options
        options[:cache_expiry] || 5.minutes
      end

      def assess_provider_health(provider)
        # Assess health of specific search provider
        case provider
        when :elasticsearch
          assess_elasticsearch_health
        when :algolia
          assess_algolia_health
        when :solr
          assess_solr_health
        else
          { status: :unknown }
        end
      end

      def assess_elasticsearch_health
        # Assess Elasticsearch cluster health
        return { status: :unavailable } unless defined?(Searchkick)

        begin
          # Check cluster health
          health = Searchkick.client.cluster.health
          {
            status: health['status'].to_sym,
            active_shards: health['active_shards'],
            relocating_shards: health['relocating_shards'],
            unassigned_shards: health['unassigned_shards']
          }
        rescue
          { status: :error, error: 'Unable to connect to Elasticsearch' }
        end
      end

      def assess_algolia_health
        # Assess Algolia service health
        return { status: :unavailable } unless defined?(Algolia)

        begin
          # Check Algolia status
          index = Algolia::Index.new(@model_class.algolia_index_name)
          # Simple operation to test connectivity
          index.get_settings
          { status: :healthy }
        rescue
          { status: :error, error: 'Unable to connect to Algolia' }
        end
      end

      def assess_solr_health
        # Assess Solr health
        return { status: :unavailable } unless defined?(Sunspot)

        begin
          # Check Solr status
          Sunspot.session.commit
          { status: :healthy }
        rescue
          { status: :error, error: 'Unable to connect to Solr' }
        end
      end

      def analyze_search_performance
        # Analyze search performance metrics
        recent_metrics = @model_class.search_metrics.where('created_at >= ?', 24.hours.ago)

        {
          average_execution_time: recent_metrics.average(:execution_time) || 0,
          slow_queries_count: recent_metrics.where('execution_time > ?', 1000).count,
          suggestions: generate_performance_suggestions(recent_metrics)
        }
      end

      def analyze_index_usage
        # Analyze search index usage patterns
        {
          suggestions: generate_usage_suggestions
        }
      end

      def optimize_slow_queries
        # Optimize slow search queries
        []
      end

      def optimize_index_structures
        # Optimize search index structures
        []
      end

      def update_caching_strategies
        # Update caching strategies for better performance
        []
      end

      def generate_performance_suggestions(metrics)
        # Generate performance improvement suggestions
        suggestions = []

        avg_time = metrics.average(:execution_time) || 0
        if avg_time > 500
          suggestions << 'Consider adding database indexes for frequently searched fields'
          suggestions << 'Implement query result caching for expensive searches'
        end

        suggestions
      end

      def generate_usage_suggestions
        # Generate index usage suggestions
        [
          'Review search field mappings for optimal performance',
          'Consider implementing search result pagination for large datasets'
        ]
      end
    end

    # Search provider service
    class SearchProviderService
      def initialize(model_class)
        @model_class = model_class
      end

      def execute_elasticsearch_search(query, options)
        # Execute Elasticsearch search
        return [] unless defined?(Searchkick)

        search_options = build_elasticsearch_options(options)
        @model_class.search(query, search_options)
      end

      def execute_algolia_search(query, options)
        # Execute Algolia search
        return [] unless defined?(Algolia)

        index = @model_class.algolia_index
        search_options = build_algolia_options(options)
        index.search(query, search_options)
      end

      def execute_solr_search(query, options)
        # Execute Solr search
        return [] unless defined?(Sunspot)

        search_options = build_solr_options(options)
        Sunspot.search(@model_class, query, search_options)
      end

      def execute_database_search(query, options)
        # Execute database search
        search_options = build_database_options(options)
        @model_class.where(query).limit(search_options[:limit] || 100)
      end

      private

      def build_elasticsearch_options(options)
        # Build Elasticsearch-specific search options
        {
          limit: options[:limit] || 100,
          offset: options[:offset] || 0,
          order: options[:order] || { created_at: :desc },
          where: options[:filters] || {},
          includes: options[:includes] || []
        }
      end

      def build_algolia_options(options)
        # Build Algolia-specific search options
        {
          hitsPerPage: options[:limit] || 100,
          page: options[:page] || 0,
          filters: build_algolia_filters(options[:filters]),
          attributesToRetrieve: options[:select] || ['*']
        }
      end

      def build_solr_options(options)
        # Build Solr-specific search options
        {
          limit: options[:limit] || 100,
          offset: options[:offset] || 0,
          order: options[:order] || :created_at,
          where: options[:filters] || {}
        }
      end

      def build_database_options(options)
        # Build database-specific search options
        {
          limit: options[:limit] || 100,
          offset: options[:offset] || 0,
          order: options[:order] || { created_at: :desc }
        }
      end

      def build_algolia_filters(filters)
        # Build Algolia filter string
        return '' unless filters.present?

        filter_parts = filters.map do |field, value|
          "#{field}:#{value}"
        end

        filter_parts.join(' AND ')
      end
    end

    # Search analytics service
    class SearchAnalyticsService
      def initialize(model_class)
        @model_class = model_class
      end

      def search_volume(timeframe = 30.days)
        # Calculate search volume over timeframe
        @model_class.search_queries
          .where('created_at >= ?', timeframe.ago)
          .group("DATE(created_at)")
          .count
      end

      def popular_queries(limit = 10)
        # Get most popular search queries
        @model_class.search_queries
          .where('created_at >= ?', 30.days.ago)
          .group(:query)
          .order('COUNT(*) DESC')
          .limit(limit)
          .count
      end

      def search_performance_metrics
        # Get search performance metrics
        recent_metrics = @model_class.search_metrics.where('created_at >= ?', 24.hours.ago)

        {
          average_execution_time: recent_metrics.average(:execution_time) || 0,
          median_execution_time: recent_metrics.median(:execution_time) || 0,
          success_rate: calculate_success_rate(recent_metrics),
          total_searches: recent_metrics.count
        }
      end

      def user_engagement_metrics
        # Get user engagement metrics for search
        {
          unique_users: @model_class.search_queries.distinct.count(:user_id),
          average_queries_per_user: calculate_queries_per_user,
          top_searching_users: top_searching_users
        }
      end

      def search_trends(timeframe = 30.days)
        # Analyze search trends over time
        @model_class.search_queries
          .where('created_at >= ?', timeframe.ago)
          .group("DATE(created_at)")
          .pluck("DATE(created_at)", "COUNT(*)", "AVG(execution_time)")
      end

      def conversion_rates
        # Calculate search-to-conversion rates
        # Implementation depends on conversion tracking setup
        {}
      end

      private

      def calculate_success_rate(metrics)
        return 0.0 if metrics.empty?

        successful_searches = metrics.where(success: true).count
        (successful_searches.to_f / metrics.count * 100).round(2)
      end

      def calculate_queries_per_user
        return 0.0 if @model_class.search_queries.empty?

        total_queries = @model_class.search_queries.count
        unique_users = @model_class.search_queries.distinct.count(:user_id)
        unique_users > 0 ? total_queries.to_f / unique_users : 0.0
      end

      def top_searching_users
        @model_class.search_queries
          .where('created_at >= ?', 30.days.ago)
          .group(:user_id)
          .order('COUNT(*) DESC')
          .limit(10)
          .count
      end
    end

    # Search suggestion service
    class SearchSuggestionService
      def initialize(model_class)
        @model_class = model_class
      end

      def generate_suggestions(partial_query, **options)
        suggestions = []

        # Get suggestions from search queries
        suggestions.concat(generate_query_suggestions(partial_query, options))

        # Get suggestions from popular searches
        suggestions.concat(generate_popular_suggestions(partial_query, options))

        # Get suggestions from field values
        suggestions.concat(generate_field_suggestions(partial_query, options))

        # Limit and rank suggestions
        suggestions.first(options[:limit] || 10)
      end

      private

      def generate_query_suggestions(partial_query, options)
        # Generate suggestions based on previous search queries
        @model_class.search_queries
          .where('query ILIKE ?', "%#{partial_query}%")
          .where('created_at >= ?', 30.days.ago)
          .group(:query)
          .order('COUNT(*) DESC')
          .limit(5)
          .pluck(:query)
      end

      def generate_popular_suggestions(partial_query, options)
        # Generate suggestions based on popular searches
        popular_queries = @model_class.search_queries
          .where('created_at >= ?', 30.days.ago)
          .group(:query)
          .having('COUNT(*) >= 5')
          .order('COUNT(*) DESC')
          .limit(10)
          .pluck(:query)

        popular_queries.select { |query| query.downcase.include?(partial_query.downcase) }
      end

      def generate_field_suggestions(partial_query, options)
        # Generate suggestions based on field values
        suggestions = []

        # Get searchable fields from model configuration
        searchable_fields = @model_class.search_config[:searchable_fields] || []

        searchable_fields.each do |field|
          field_suggestions = @model_class
            .where("#{field} ILIKE ?", "%#{partial_query}%")
            .distinct
            .limit(3)
            .pluck(field)

          suggestions.concat(field_suggestions)
        end

        suggestions
      end
    end

    # Search alert service
    class SearchAlertService
      def initialize(model_class)
        @model_class = model_class
      end

      def trigger_performance_alert(execution_time, options)
        # Trigger alert for slow search performance
        return unless @model_class.respond_to?(:search_metrics)

        @model_class.search_metrics.create!(
          operation: :performance_alert,
          execution_time: execution_time,
          alert_type: :slow_search,
          metadata: {
            threshold: SEARCH_THRESHOLDS[:slow_search][:threshold_ms],
            query: options[:query],
            filters: options[:filters]
          },
          created_at: Time.current
        )
      end

      def trigger_large_result_alert(result_count, options)
        # Trigger alert for large result sets
        return unless @model_class.respond_to?(:search_metrics)

        @model_class.search_metrics.create!(
          operation: :result_alert,
          result_count: result_count,
          alert_type: :large_result_set,
          metadata: {
            threshold: SEARCH_THRESHOLDS[:large_result_set][:threshold_count],
            query: options[:query]
          },
          created_at: Time.current
        )
      end
    end
  end
end