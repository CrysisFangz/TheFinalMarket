# frozen_string_literal: true

module Infrastructure
  module UserCurrencyPreference
    module Repositories
      # Repository for user currency preference aggregate persistence and retrieval
      # Implements sophisticated caching and query optimization
      class UserCurrencyPreferenceRepository
        def initialize(cache_store = nil)
          @cache_store = cache_store || Rails.cache
          @loaded_preferences = {}
        end

        # Find preference by user ID with caching
        # @param user_id [Integer] user identifier
        # @return [UserCurrencyPreference, nil] preference or nil
        def find_by_user_id(user_id)
          # Try cache first
          cached_preference = fetch_from_cache(user_id)
          return cached_preference if cached_preference.present?

          # Load from database
          preference = ::UserCurrencyPreference.find_by(user_id: user_id)

          if preference.present?
            cache_preference(preference)
            preference
          else
            cache_miss(user_id)
            nil
          end
        end

        # Save preference
        # @param preference [UserCurrencyPreference] preference to save
        def save(preference)
          preference.save!
          cache_preference(preference)
        end

        # Delete preference
        # @param user_id [Integer] user identifier
        def delete_by_user_id(user_id)
          preference = ::UserCurrencyPreference.find_by(user_id: user_id)
          return unless preference

          preference.destroy!
          invalidate_cache(user_id)
        end

        private

        # Fetch preference from cache
        # @param user_id [Integer] user identifier
        # @return [UserCurrencyPreference, nil] cached preference or nil
        def fetch_from_cache(user_id)
          cache_key = "user_currency_preference:#{user_id}"

          # Try in-memory cache first
          return @loaded_preferences[user_id] if @loaded_preferences.key?(user_id)

          # Try cache
          cached_data = @cache_store.read(cache_key)
          return nil if cached_data == 'MISS'

          if cached_data.present?
            reconstruct_from_cache_data(cached_data)
          end
        end

        # Cache preference
        # @param preference [UserCurrencyPreference] preference to cache
        def cache_preference(preference)
          cache_key = "user_currency_preference:#{preference.user_id}"

          # Update in-memory cache
          @loaded_preferences[preference.user_id] = preference

          # Update cache with TTL
          cache_data = serialize_for_cache(preference)
          @cache_store.write(cache_key, cache_data, expires_in: 1.hour)
        end

        # Mark cache miss
        # @param user_id [Integer] user identifier
        def cache_miss(user_id)
          cache_key = "user_currency_preference:#{user_id}"
          @cache_store.write(cache_key, 'MISS', expires_in: 15.minutes)
        end

        # Invalidate cache
        # @param user_id [Integer] user identifier
        def invalidate_cache(user_id)
          cache_key = "user_currency_preference:#{user_id}"
          @cache_store.delete(cache_key)
          @loaded_preferences.delete(user_id)
        end

        # Reconstruct preference from cache data
        # @param cache_data [Hash] cached data
        # @return [UserCurrencyPreference] reconstructed preference
        def reconstruct_from_cache_data(cache_data)
          ::UserCurrencyPreference.new(
            id: cache_data['id'],
            user_id: cache_data['user_id'],
            currency_id: cache_data['currency_id'],
            created_at: Time.parse(cache_data['created_at']),
            updated_at: Time.parse(cache_data['updated_at'])
          )
        end

        # Serialize preference for caching
        # @param preference [UserCurrencyPreference] preference
        # @return [Hash] serializable data
        def serialize_for_cache(preference)
          {
            id: preference.id,
            user_id: preference.user_id,
            currency_id: preference.currency_id,
            created_at: preference.created_at.iso8601,
            updated_at: preference.updated_at.iso8601
          }
        end
      end
    end
  end
end