# frozen_string_literal: true

module Application
  module UserCurrencyPreference
    module Commands
      # Command to update user currency preference
      class UpdateUserCurrencyPreferenceCommand
        attr_reader :user_id, :currency_id, :correlation_id

        # Initialize update currency preference command
        # @param user_id [Integer] user identifier
        # @param currency_id [Integer] currency identifier
        # @param correlation_id [String] correlation identifier
        def initialize(user_id, currency_id, correlation_id = nil)
          @user_id = user_id
          @currency_id = currency_id
          @correlation_id = correlation_id || generate_correlation_id

          validate_command
        end

        # Execute the command
        # @param repository [Infrastructure::UserCurrencyPreference::Repositories::UserCurrencyPreferenceRepository] repository
        # @return [Result] command execution result
        def execute(repository)
          validate_dependencies(repository)

          # Find or create preference
          preference = repository.find_by_user_id(@user_id) || ::UserCurrencyPreference.new(user_id: @user_id)

          # Update currency
          preference.currency_id = @currency_id

          # Save via repository
          repository.save(preference)

          # Publish event
          publish_event(preference)

          Result.success(preference)
        rescue ActiveRecord::RecordInvalid => e
          Result.failure("Validation failed: #{e.message}", :validation_error)
        rescue StandardError => e
          Result.failure("Command execution failed: #{e.message}", :system_error)
        end

        private

        # Validate command input parameters
        def validate_command
          raise ArgumentError, 'User ID is required' unless @user_id.present?
          raise ArgumentError, 'Currency ID is required' unless @currency_id.present?
        end

        # Validate dependencies
        # @param repository [Infrastructure::UserCurrencyPreference::Repositories::UserCurrencyPreferenceRepository] repository
        def validate_dependencies(repository)
          raise ArgumentError, 'Repository is required' unless repository.present?
        end

        # Publish event
        def publish_event(preference)
          event = UserCurrencyPreferenceEvents::EventFactory.preference_updated(
            preference.id,
            preference.user_id,
            preference.currency_id,
            preference.currency_id_was
          )
          # Assuming there's an event publisher, e.g., EventStore.append
          # For simplicity, log the event
          Rails.logger.info("Published event: #{event.event_type} for user #{preference.user_id}")
        end

        # Generate correlation ID
        # @return [String] correlation identifier
        def generate_correlation_id
          "update_currency_preference_#{Time.current.to_i}_#{SecureRandom.hex(4)}"
        end

        # Command execution result
        class Result
          attr_reader :success, :value, :error, :error_code

          def initialize(success, value = nil, error = nil, error_code = nil)
            @success = success
            @value = value
            @error = error
            @error_code = error_code
          end

          def self.success(value = nil)
            new(true, value)
          end

          def self.failure(error, error_code = nil)
            new(false, nil, error, error_code)
          end

          def successful?
            @success
          end

          def failed?
            !@success
          end
        end
      end
    end
  end
end