# frozen_string_literal: true

# QuestObjective model refactored for performance and resilience.
# Progress calculation logic extracted into dedicated service for optimization.
class QuestObjective < ApplicationRecord
  belongs_to :shopping_quest
  belongs_to :product, optional: true
  belongs_to :category, optional: true

  # Enhanced validations with custom messages
  validates :shopping_quest, presence: true
  validates :objective_type, presence: true, inclusion: { in: objective_types.keys }
  validates :description, presence: true, length: { maximum: 500 }
  validates :target_value, numericality: { greater_than: 0, less_than_or_equal_to: 1000000 }

  # Enhanced scopes with performance optimization
  scope :by_type, ->(type) { where(objective_type: type) }
  scope :with_product, -> { includes(:product) }
  scope :with_category, -> { includes(:category) }
  scope :with_quest, -> { includes(:shopping_quest) }

  # Event-driven: Publish events on objective completion
  after_save :publish_objective_updated_event

  enum objective_type: {
    purchase_product: 0,
    purchase_from_category: 1,
    spend_amount: 2,
    purchase_count: 3,
    review_product: 4,
    share_product: 5,
    refer_friend: 6,
    visit_store: 7,
    add_to_wishlist: 8,
    complete_profile: 9
  }

  # Check if objective is completed by user using service
  def completed_by?(user)
    QuestProgressService.calculate_progress(self, user) >= target_value
  end

  # Get current progress for user using service
  def current_progress(user)
    QuestProgressService.calculate_progress(self, user)
  end

  # Get progress percentage using service
  def progress_percentage(user)
    QuestProgressService.calculate_progress_percentage(self, user)
  end

  # Get display text with enhanced formatting
  def display_text
    case objective_type.to_sym
    when :purchase_product
      "Purchase #{product&.name || 'specified product'}"
    when :purchase_from_category
      "Purchase from #{category&.name || 'specified category'}"
    when :spend_amount
      "Spend $#{target_value}"
    when :purchase_count
      "Make #{target_value} purchases"
    when :review_product
      "Review #{product&.name || 'specified product'}"
    when :share_product
      "Share #{product&.name || 'specified product'}"
    when :refer_friend
      "Refer #{target_value} friends"
    when :visit_store
      "Visit the store #{target_value} times"
    when :add_to_wishlist
      "Add #{product&.name || 'specified product'} to wishlist"
    when :complete_profile
      "Complete your profile to #{target_value}%"
    else
      description
    end
  end

  private

  def publish_objective_updated_event
    Rails.logger.info("Quest objective updated: ID=#{id}, Type=#{objective_type}, Quest=#{shopping_quest_id}")
    # In a full event system: EventPublisher.publish('quest_objective_updated', self.attributes)
  end
end

