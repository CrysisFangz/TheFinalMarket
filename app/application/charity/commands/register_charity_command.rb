# frozen_string_literal: true

module Application
  module Charity
    module Commands
      # Command to register a new charity
      class RegisterCharityCommand
        attr_reader :charity_id, :name, :ein, :category, :correlation_id

        # Initialize register charity command
        # @param charity_id [String] unique charity identifier
        # @param name [String] charity name
        # @param ein [String] employer identification number
        # @param category [Symbol] charity category
        # @param correlation_id [String] correlation identifier for distributed transactions
        def initialize(charity_id, name, ein, category, correlation_id = nil)
          @charity_id = charity_id
          @name = name
          @ein = ein
          @category = category
          @correlation_id = correlation_id || generate_correlation_id

          validate_command
        end

        # Execute the command
        # @param repository [Interfaces::CharityRepository] charity repository
        # @param event_store [Interfaces::EventStore] event store
        # @return [Result] command execution result
        def execute(repository, event_store)
          validate_dependencies(repository, event_store)

          # Check if charity already exists
          existing_charity = repository.find_by_ein(@ein)
          return Result.failure("Charity with EIN #{@ein} already exists") if existing_charity.present?

          # Validate EIN format and checksum
          validated_ein = validate_and_create_ein
          validated_category = validate_and_create_category

          # Create domain objects
          charity_aggregate = create_charity_aggregate(validated_ein, validated_category)

          # Persist events
          persist_events(charity_aggregate, event_store)

          # Update read model
          update_read_model(charity_aggregate, repository)

          Result.success(charity_aggregate)
        rescue Domain::DomainError => e
          Result.failure(e.message, :domain_error, e.details)
        rescue StandardError => e
          Result.failure("Command execution failed: #{e.message}", :system_error)
        end

        private

        # Validate command input parameters
        def validate_command
          raise ArgumentError, 'Charity ID is required' unless @charity_id.present?
          raise ArgumentError, 'Name is required' unless @name.present?
          raise ArgumentError, 'EIN is required' unless @ein.present?
          raise ArgumentError, 'Category is required' unless @category.present?

          raise ArgumentError, 'Name must be at least 2 characters' unless @name.length >= 2
          raise ArgumentError, 'Name must be less than 100 characters' unless @name.length < 100
        end

        # Validate dependencies
        # @param repository [Interfaces::CharityRepository] charity repository
        # @param event_store [Interfaces::EventStore] event store
        def validate_dependencies(repository, event_store)
          raise ArgumentError, 'Repository is required' unless repository.present?
          raise ArgumentError, 'Event store is required' unless event_store.present?
        end

        # Validate and create EIN value object
        # @return [Domain::ValueObjects::EIN] validated EIN
        def validate_and_create_ein
          Domain::ValueObjects::EIN.parse(@ein)
        rescue ArgumentError => e
          raise Domain::DomainError.new("Invalid EIN: #{e.message}", :invalid_ein)
        end

        # Validate and create category value object
        # @return [Domain::ValueObjects::CharityCategory] validated category
        def validate_and_create_category
          Domain::ValueObjects::CharityCategory.new(@category)
        rescue ArgumentError => e
          raise Domain::DomainError.new("Invalid category: #{e.message}", :invalid_category)
        end

        # Create charity aggregate root
        # @param ein [Domain::ValueObjects::EIN] validated EIN
        # @param category [Domain::ValueObjects::CharityCategory] validated category
        # @return [Domain::Entities::Charity] charity aggregate
        def create_charity_aggregate(ein, category)
          Domain::Entities::Charity.register(@charity_id, @name, ein, category)
        end

        # Persist uncommitted events to event store
        # @param charity_aggregate [Domain::Entities::Charity] charity aggregate
        # @param event_store [Interfaces::EventStore] event store
        def persist_events(charity_aggregate, event_store)
          uncommitted_events = charity_aggregate.get_uncommitted_events

          uncommitted_events.each do |event|
            event_store.append(event.aggregate_id, event)
          end

          charity_aggregate.mark_events_committed
        end

        # Update read model for query optimization
        # @param charity_aggregate [Domain::Entities::Charity] charity aggregate
        # @param repository [Interfaces::CharityRepository] charity repository
        def update_read_model(charity_aggregate, repository)
          # Update any read models or projections
          # This would update denormalized views for fast querying
          repository.save(charity_aggregate)
        end

        # Generate correlation ID for distributed transaction tracking
        # @return [String] correlation identifier
        def generate_correlation_id
          "charity_registration_#{Time.current.to_i}_#{SecureRandom.hex(4)}"
        end

        # Command execution result
        class Result
          attr_reader :success, :value, :error, :error_code, :error_details

          def initialize(success, value = nil, error = nil, error_code = nil, error_details = {})
            @success = success
            @value = value
            @error = error
            @error_code = error_code
            @error_details = error_details
          end

          def self.success(value = nil)
            new(true, value)
          end

          def self.failure(error, error_code = nil, error_details = {})
            new(false, nil, error, error_code, error_details)
          end

          def successful?
            @success
          end

          def failed?
            !@success
          end

          def to_h
            {
              success: @success,
              value: @value,
              error: @error,
              error_code: @error_code,
              error_details: @error_details
            }
          end
        end
      end
    end
  end
end