# frozen_string_literal: true

# Service class for normalizing tag names.
# Encapsulates the normalization logic to adhere to Single Responsibility Principle
# and improve testability and reusability.
# Incorporates caching for performance optimization in uniqueness checks.
class TagNameNormalizer
  CACHE_KEY_PREFIX = 'tag_name_uniqueness'
  CACHE_EXPIRY = 5.minutes

  # Normalizes a given name by downcasing and stripping whitespace.
  #
  # @param name [String] the name to normalize
  # @return [String] the normalized name
  def self.normalize(name)
    return '' if name.blank?

    name.downcase.strip
  end

  # Validates if the normalized name is unique within the context of existing tags.
  # Uses caching to optimize repeated checks and reduce database queries.
  # Includes error handling for resilience against database failures.
  #
  # @param normalized_name [String] the normalized name to check
  # @param exclude_tag [Tag, nil] optional tag to exclude from uniqueness check (for updates)
  # @return [Boolean] true if unique, false otherwise
  def self.unique?(normalized_name, exclude_tag: nil)
    cache_key = "#{CACHE_KEY_PREFIX}:#{normalized_name}"
    cache_key += ":exclude_#{exclude_tag.id}" if exclude_tag

    Rails.cache.fetch(cache_key, expires_in: CACHE_EXPIRY) do
      begin
        query = Tag.where('LOWER(name) = ?', normalized_name)
        query = query.where.not(id: exclude_tag.id) if exclude_tag
        query.none?
      rescue ActiveRecord::StatementInvalid => e
        # Log error and return false to prevent saving invalid data
        Rails.logger.error("Error checking tag name uniqueness: #{e.message}")
        false
      end
    end
  end
end