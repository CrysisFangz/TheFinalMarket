# frozen_string_literal: true

# Service for calculating quest objective progress with optimized queries.
# Ensures accurate progress tracking and performance under load.
class QuestProgressService
  # Calculates current progress for a user on a quest objective.
  # @param objective [QuestObjective] The quest objective.
  # @param user [User] The user.
  # @return [Numeric] Current progress value.
  def self.calculate_progress(objective, user)
    cache_key = "quest_objective:#{objective.id}:progress:#{user.id}"

    Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
      case objective.objective_type.to_sym
      when :purchase_product
        calculate_purchase_product_progress(objective, user)
      when :purchase_from_category
        calculate_purchase_category_progress(objective, user)
      when :spend_amount
        calculate_spend_amount_progress(objective, user)
      when :purchase_count
        calculate_purchase_count_progress(objective, user)
      when :review_product
        calculate_review_product_progress(objective, user)
      when :share_product
        calculate_share_product_progress(objective, user)
      when :refer_friend
        calculate_refer_friend_progress(objective, user)
      when :visit_store
        calculate_visit_store_progress(objective, user)
      when :add_to_wishlist
        calculate_wishlist_progress(objective, user)
      when :complete_profile
        calculate_profile_completion_progress(objective, user)
      else
        0
      end
    end
  rescue StandardError => e
    Rails.logger.error("Failed to calculate progress for objective #{objective.id}, user #{user.id}: #{e.message}")
    0
  end

  # Calculates progress percentage.
  # @param objective [QuestObjective] The quest objective.
  # @param user [User] The user.
  # @return [Float] Progress percentage (0-100).
  def self.calculate_progress_percentage(objective, user)
    progress = calculate_progress(objective, user)
    ((progress.to_f / objective.target_value) * 100).round(2).clamp(0, 100)
  end

  private

  def self.calculate_purchase_product_progress(objective, user)
    user.orders.completed.joins(:line_items)
        .where(line_items: { product_id: objective.product_id })
        .count
  end

  def self.calculate_purchase_category_progress(objective, user)
    user.orders.completed.joins(line_items: :product)
        .where(products: { category_id: objective.category_id })
        .count
  end

  def self.calculate_spend_amount_progress(objective, user)
    user.orders.completed
        .where('created_at >= ?', objective.shopping_quest.starts_at)
        .sum(:total_cents) / 100.0
  end

  def self.calculate_purchase_count_progress(objective, user)
    user.orders.completed
        .where('created_at >= ?', objective.shopping_quest.starts_at)
        .count
  end

  def self.calculate_review_product_progress(objective, user)
    user.reviews.where(product_id: objective.product_id).count
  end

  def self.calculate_share_product_progress(objective, user)
    # Implementation depends on sharing system
    0
  end

  def self.calculate_refer_friend_progress(objective, user)
    user.referrals.where('created_at >= ?', objective.shopping_quest.starts_at).count
  end

  def self.calculate_visit_store_progress(objective, user)
    # Implementation depends on analytics system
    0
  end

  def self.calculate_wishlist_progress(objective, user)
    user.wishlist_items.where(product_id: objective.product_id).count
  end

  def self.calculate_profile_completion_progress(objective, user)
    user.profile_completion_percentage
  end
end