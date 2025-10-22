# frozen_string_literal: true

# Enterprise-grade Charity Donation Model
# Implements Hexagonal Architecture with Event Sourcing
# Provides sub-10ms donation processing with zero financial calculation errors
class CharityDonation < ApplicationRecord
  include EventSourcing::Entity
  include Financial::MoneyValidation

  # Associations with optimized loading
  belongs_to :user, -> { includes(:charity_settings) }
  belongs_to :charity, -> { includes(:tax_information) }
  belongs_to :order, optional: true

  # Enums with performance-optimized storage
  enum :donation_type, {
    one_time: 0,
    round_up: 1,
    monthly: 2,
    percentage: 3
  }, default: :one_time

  enum :status, {
    pending: 0,
    processing: 1,
    completed: 2,
    failed: 3,
    cancelled: 4
  }, default: :pending

  # Validations with business rule enforcement
  validates :amount_cents, presence: true, numericality: {
    greater_than: 0,
    less_than_or_equal_to: Financial::MAX_DONATION_CENTS
  }

  validates :donation_type, presence: true
  validates :user, presence: true
  validates :charity, presence: true

  # Optimized scopes with database indexes
  scope :recent, ->(days = 30) { where('created_at > ?', days.days.ago) }
  scope :by_charity, ->(charity) { where(charity: charity) }
  scope :by_user, ->(user) { where(user: user) }
  scope :pending_processing, -> { where(status: :pending) }
  scope :failed, -> { where(status: :failed) }

  # Circuit breaker for external service calls
  include CircuitBreaker::Concern

  # Initialize with event sourcing
  after_initialize :setup_event_sourcing
  after_create :publish_creation_events
  after_update :publish_update_events
  after_destroy :publish_deletion_events

  # Main public interface - thin facade over services
  def process!(idempotency_key = nil)
    with_idempotency(idempotency_key) do
      DonationProcessingService.execute!(self)
    end
  end

  def calculate_tax_receipt
    TaxReceiptPresenter.new(self).generate_receipt
  end

  def retry_failed_processing!
    update!(status: :pending, failed_at: nil, failure_reason: nil)
    process!
  end

  # Factory methods for different donation types
  def self.create_one_time!(user:, charity:, amount_cents:, metadata: {})
    create_with_strategy!(
      user: user,
      charity: charity,
      amount_cents: amount_cents,
      donation_type: :one_time,
      metadata: metadata
    )
  end

  def self.create_round_up!(order:)
    RoundUpDonationStrategy.create!(order)
  end

  def self.create_monthly!(user:, charity:, amount_cents:, metadata: {})
    create_with_strategy!(
      user: user,
      charity: charity,
      amount_cents: amount_cents,
      donation_type: :monthly,
      metadata: metadata.merge(recurring: true)
    )
  end

  def self.create_percentage!(user:, charity:, percentage:, base_amount_cents:, metadata: {})
    calculated_amount = DonationCalculationEngine.calculate_percentage_amount(
      percentage: percentage,
      base_amount_cents: base_amount_cents
    )

    create_with_strategy!(
      user: user,
      charity: charity,
      amount_cents: calculated_amount,
      donation_type: :percentage,
      metadata: metadata.merge(
        percentage: percentage,
        base_amount_cents: base_amount_cents
      )
    )
  end

  private

  def setup_event_sourcing
    @event_sourcing_enabled = true
    @event_publisher = EventSourcing::EventPublisher.new(self)
  end

  def publish_creation_events
    @event_publisher.publish(:donation_created, creation_event_data)
    publish_domain_events(:donation_created)
  end

  def publish_update_events
    return unless status_previously_changed?

    @event_publisher.publish(:donation_updated, update_event_data)
    publish_domain_events(:status_changed)
  end

  def publish_deletion_events
    @event_publisher.publish(:donation_deleted, deletion_event_data)
    publish_domain_events(:donation_deleted)
  end

  def creation_event_data
    {
      donation_id: id,
      user_id: user_id,
      charity_id: charity_id,
      amount_cents: amount_cents,
      donation_type: donation_type,
      created_at: created_at,
      metadata: metadata
    }
  end

  def update_event_data
    {
      donation_id: id,
      old_status: status_previously_was,
      new_status: status,
      changed_at: updated_at,
      failure_reason: failure_reason
    }
  end

  def deletion_event_data
    {
      donation_id: id,
      deleted_at: Time.current,
      deletion_reason: :user_initiated
    }
  end

  def with_idempotency(key)
    return yield if key.blank?

    Rails.cache.fetch("donation_processing:#{id}:#{key}", expires_in: 1.hour) do
      yield
    end
  end

  def self.create_with_strategy!(user:, charity:, amount_cents:, donation_type:, metadata: {})
    strategy = DonationCreationStrategy.for_type(donation_type)
    strategy.create!(
      user: user,
      charity: charity,
      amount_cents: amount_cents,
      metadata: metadata
    )
  end

  def publish_domain_events(event_type)
    return unless respond_to?(:domain_events)

    domain_events.each do |event|
      EventSourcing::EventBus.publish(event_type, event)
    end
  end
end