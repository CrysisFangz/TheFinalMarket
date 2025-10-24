# frozen_string_literal: true

# ProductAbTest model refactored for architectural purity and performance.
# Business logic decoupled into dedicated services for clarity and scalability.
class ProductAbTest < ApplicationRecord
  belongs_to :product
  belongs_to :seller, class_name: 'User'

  has_many :ab_test_variants, dependent: :destroy
  has_many :ab_test_impressions, dependent: :destroy

  # Enhanced validations with custom messages
  validates :test_name, presence: true, uniqueness: { scope: :product_id, message: "must be unique per product" }
  validates :test_type, presence: true, inclusion: { in: test_types.keys }
  validates :status, presence: true, inclusion: { in: statuses.keys }

  # Scopes for optimized queries
  scope :active, -> { where(status: :active) }
  scope :completed, -> { where(status: :completed) }
  scope :with_associations, -> { includes(:product, :seller, :ab_test_variants, :ab_test_impressions) }

  # Event-driven: Publish events on status changes
  after_save :publish_status_change_event, if: :saved_change_to_status?

  # Test types
  enum test_type: {
    title: 0,
    description: 1,
    price: 2,
    images: 3,
    call_to_action: 4,
    product_features: 5
  }

  # Test status
  enum status: {
    draft: 0,
    active: 1,
    paused: 2,
    completed: 3
  }

  # Start test using service
  def start!
    AbTestManagementService.start_test(self)
  end

  # Stop test using service
  def stop!
    AbTestManagementService.stop_test(self)
  end

  # Record impression using service
  def record_impression(variant, user)
    ImpressionRecordingService.record_impression(self, variant, user)
  end

  # Record conversion using service
  def record_conversion(variant, user, order)
    ImpressionRecordingService.record_conversion(self, variant, user, order)
  end

  # Get results using service
  def results
    AbTestAnalyticsService.generate_results(self)
  end

  # Determine winner using service
  def determine_winner
    AbTestManagementService.send(:determine_winner, self)
  end

  # Apply winner using service
  def apply_winner!
    AbTestApplicationService.apply_winner(self)
  end

  # Check if statistically significant using service
  def statistically_significant?
    AbTestAnalyticsService.statistically_significant?(self)
  end
  
  private

  # Publishes status change event for auditability
  def publish_status_change_event
    Rails.logger.info("A/B test status changed: ID=#{id}, Status=#{status}, Product=#{product_id}")
    # In a full event system: EventPublisher.publish('ab_test_status_changed', self.attributes)
  end
end

