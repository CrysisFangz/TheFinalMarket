# frozen_string_literal: true

module Application
  module UserCurrencyPreference
    module Queries
      # Query for retrieving user currency preference with details
      class UserCurrencyPreferenceQuery
        attr_reader :user_id, :include_currency_details, :correlation_id

        # Initialize currency preference query
        # @param user_id [Integer] user identifier
        # @param include_currency_details [Boolean] include full currency info
        # @param correlation_id [String] correlation identifier
        def initialize(user_id, include_currency_details = false, correlation_id = nil)
          @user_id = user_id
          @include_currency_details = include_currency_details
          @correlation_id = correlation_id || generate_correlation_id

          validate_query
        end

        # Execute the query
        # @param repository [Infrastructure::UserCurrencyPreference::Repositories::UserCurrencyPreferenceRepository] repository
        # @return [Result] query execution result
        def execute(repository)
          validate_dependencies(repository)

          # Retrieve preference
          preference = repository.find_by_user_id(@user_id)
          return Result.failure("Currency preference not found for user: #{@user_id}") unless preference.present?

          # Build response
          response = build_response(preference)

          Result.success(response)
        rescue StandardError => e
          Result.failure("Query execution failed: #{e.message}", :system_error)
        end

        private

        # Validate query parameters
        def validate_query
          raise ArgumentError, 'User ID is required' unless @user_id.present?
        end

        # Validate dependencies
        # @param repository [Infrastructure::UserCurrencyPreference::Repositories::UserCurrencyPreferenceRepository] repository
        def validate_dependencies(repository)
          raise ArgumentError, 'Repository is required' unless repository.present?
        end

        # Build response
        # @param preference [UserCurrencyPreference] preference
        # @return [Hash] response data
        def build_response(preference)
          base_data = {
            user_id: preference.user_id,
            currency_id: preference.currency_id,
            currency_code: preference.currency_code,
            currency_name: preference.currency_name,
            currency_symbol: preference.currency_symbol,
            created_at: preference.created_at,
            updated_at: preference.updated_at,
            query_correlation_id: @correlation_id
          }

          if @include_currency_details
            base_data.merge!(
              currency_details: {
                code: preference.currency.code,
                name: preference.currency.name,
                symbol: preference.currency.symbol,
                symbol_position: preference.currency.symbol_position,
                decimal_places: preference.currency.decimal_places,
                active: preference.currency.active,
                supported: preference.currency.supported
              }
            )
          end

          base_data
        end

        # Generate correlation ID
        # @return [String] correlation identifier
        def generate_correlation_id
          "currency_preference_query_#{Time.current.to_i}_#{SecureRandom.hex(4)}"
        end

        # Query execution result
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