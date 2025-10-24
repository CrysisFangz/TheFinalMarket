class ReviewModerationService
  include CircuitBreaker
  include Retryable

  CACHE_KEY_PREFIX = 'review_moderation'
  CACHE_TTL = 20.minutes

  def self.validate_review_ownership(review)
    cache_key = "#{CACHE_KEY_PREFIX}:ownership:#{review.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('review_moderation') do
        with_retry do
          if review.item_review? && review.reviewable.user_id == review.reviewer_id
            review.errors.add(:base, "You cannot review your own item")
            return false
          end
          true
        end
      end
    end
  end

  def self.validate_purchase_requirement(review)
    cache_key = "#{CACHE_KEY_PREFIX}:purchase:#{review.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('review_moderation') do
        with_retry do
          unless OrderItem.exists?(item: review.reviewable, order: { user_id: review.reviewer_id })
            review.errors.add(:base, "You must purchase this item before reviewing it")
            return false
          end
          true
        end
      end
    end
  end

  def self.validate_seller_transaction(review)
    cache_key = "#{CACHE_KEY_PREFIX}:seller_transaction:#{review.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('review_moderation') do
        with_retry do
          if review.reviewable_type == 'User' && !Order.joins(:items)
              .where(user_id: review.reviewer_id, items: { user_id: review.reviewable_id })
              .exists?
            review.errors.add(:base, "You must have completed a transaction with this seller to review them")
            return false
          end
          true
        end
      end
    end
  end

  def self.validate_dispute_status(review)
    cache_key = "#{CACHE_KEY_PREFIX}:dispute:#{review.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('review_moderation') do
        with_retry do
          if review.dispute&.active?
            review.errors.add(:base, "cannot review while dispute is active")
            return false
          end
          true
        end
      end
    end
  end

  def self.validate_content_quality(review)
    cache_key = "#{CACHE_KEY_PREFIX}:content_quality:#{review.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('review_moderation') do
        with_retry do
          issues = []

          # Check for minimum content length
          if review.content.length < 10
            issues << "Review must be at least 10 characters long"
          end

          # Check for spam patterns
          spam_patterns = ['buy now', 'click here', 'limited time', 'act now']
          if spam_patterns.any? { |pattern| review.content.downcase.include?(pattern) }
            issues << "Review contains promotional content"
          end

          # Check for excessive punctuation
          if review.content.count('!') > 3 || review.content.count('?') > 3
            issues << "Review contains excessive punctuation"
          end

          if issues.any?
            review.errors.add(:content, issues.join(', '))
            return false
          end

          true
        end
      end
    end
  end

  def self.moderate_review(review)
    cache_key = "#{CACHE_KEY_PREFIX}:moderate:#{review.id}"

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      with_circuit_breaker('review_moderation') do
        with_retry do
          validations = [
            -> { validate_review_ownership(review) },
            -> { validate_content_quality(review) }
          ]

          # Add purchase validation for item reviews
          validations << -> { validate_purchase_requirement(review) } if review.item_review?

          # Add seller transaction validation for seller reviews
          validations << -> { validate_seller_transaction(review) } if review.seller_review?

          # Add dispute validation if review invitation exists
          validations << -> { validate_dispute_status(review) } if review.review_invitation

          all_valid = validations.all? { |validation| validation.call }

          EventPublisher.publish('review.moderation_completed', {
            review_id: review.id,
            reviewer_id: review.reviewer_id,
            reviewable_type: review.reviewable_type,
            reviewable_id: review.reviewable_id,
            moderation_passed: all_valid,
            validation_count: validations.size
          })

          all_valid
        end
      end
    end
  end

  def self.clear_moderation_cache(review_id)
    cache_keys = [
      "#{CACHE_KEY_PREFIX}:ownership:#{review_id}",
      "#{CACHE_KEY_PREFIX}:purchase:#{review_id}",
      "#{CACHE_KEY_PREFIX}:seller_transaction:#{review_id}",
      "#{CACHE_KEY_PREFIX}:dispute:#{review_id}",
      "#{CACHE_KEY_PREFIX}:content_quality:#{review_id}",
      "#{CACHE_KEY_PREFIX}:moderate:#{review_id}"
    ]

    Rails.cache.delete_multi(cache_keys)
  end
end