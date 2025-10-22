# frozen_string_literal: true

# Event store model for admin transaction domain events
# Provides immutable storage for all domain events with versioning
#
# @author Kilo Code Autonomous Agent
# @version 2.0.0
class AdminTransactionEventStore < ApplicationRecord
  # Table name
  self.table_name = :admin_transaction_event_store

  # Validations
  validates :aggregate_id, presence: true, length: { maximum: 255 }
  validates :event_id, presence: true, uniqueness: true, length: { maximum: 255 }
  validates :event_type, presence: true, length: { maximum: 255 }
  validates :event_data, presence: true
  validates :version, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :occurred_at, presence: true
  validates :metadata, presence: true

  # Scopes for efficient querying
  scope :for_aggregate, ->(aggregate_id) { where(aggregate_id: aggregate_id) }
  scope :in_order, -> { order(:version) }
  scope :since_version, ->(version) { where('version > ?', version) }
  scope :event_type, ->(type) { where(event_type: type) }
  scope :since_date, ->(date) { where('occurred_at >= ?', date) }

  # Indexes for performance
  # Composite indexes for common query patterns
  index :aggregate_id
  index [:aggregate_id, :version]
  index [:event_type, :occurred_at]
  index :occurred_at

  # Ensure events are immutable once stored
  before_update :prevent_updates
  before_destroy :prevent_deletion

  # @return [Hash] deserialized event data
  def parsed_event_data
    @parsed_event_data ||= JSON.parse(event_data)
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse event data for event #{event_id}: #{e.message}")
    {}
  end

  # @return [Hash] deserialized metadata
  def parsed_metadata
    @parsed_metadata ||= JSON.parse(metadata)
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse metadata for event #{event_id}: #{e.message}")
    {}
  end

  private

  # Prevent updates to stored events (immutability)
  def prevent_updates
    raise ActiveRecord::ReadOnlyRecord, 'Event store records are immutable'
  end

  # Prevent deletion of stored events (audit trail integrity)
  def prevent_deletion
    raise ActiveRecord::ReadOnlyRecord, 'Event store records cannot be deleted'
  end
end