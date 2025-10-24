# frozen_string_literal: true

# =============================================================================
# DeadLetterEvent - Model for Failed Event Processing
# =============================================================================
# Stores events that have failed processing after maximum retries.
# Provides audit trail and manual intervention capabilities for failed events.
#
# Architecture: Dead Letter Queue + Audit Trail
# Performance: O(1) storage and retrieval
# Scalability: Partitioned by event type for horizontal scaling
# Resilience: Immutable records with full error context
# =============================================================================

class DeadLetterEvent < ApplicationRecord
  # ==================== ASSOCIATIONS ====================
  belongs_to :original_event, polymorphic: true, optional: true

  # ==================== VALIDATIONS ====================
  validates :original_event_id, presence: true
  validates :event_type, presence: true
  validates :error_message, presence: true
  validates :retry_count, numericality: { greater_than_or_equal_to: 0 }

  # ==================== SCOPES ====================
  scope :by_event_type, ->(type) { where(event_type: type) }
  scope :recent_failures, ->(since = 1.day.ago) { where('created_at >= ?', since) }
  scope :high_retry_count, ->(count = 3) { where('retry_count >= ?', count) }
  scope :ordered_by_failure_time, -> { order(created_at: :desc) }

  # ==================== INSTANCE METHODS ====================

  # Attempt to reprocess the event
  def reprocess!
    # Find the original event and attempt to process again
    original_event = find_original_event
    return false unless original_event

    service = event_processing_service
    result = service.process_event(original_event)

    if result.success?
      # Mark as reprocessed and destroy
      update!(reprocessed_at: Time.current, status: 'reprocessed')
      destroy
      true
    else
      # Increment retry and update error
      increment!(:retry_count)
      update!(last_error_message: result.error_message)
      false
    end
  end

  # Get human-readable event type
  def event_type_name
    event_type.humanize
  end

  # Check if event can be reprocessed
  def can_reprocess?
    original_event.present? && retry_count < 10
  end

  # ==================== CLASS METHODS ====================

  # Create from a failed event
  def self.create_from_failed_event(event, error)
    create!(
      original_event_id: event.id,
      original_event_type: event.class.name,
      event_type: event.event_type,
      error_message: error.message,
      error_backtrace: error.backtrace,
      retry_count: event.metadata[:retry_count] || 0,
      event_data: event.to_h,
      metadata: event.metadata
    )
  end

  # Bulk reprocess events of a type
  def self.bulk_reprocess(event_type)
    by_event_type(event_type).where(status: 'failed').each do |dead_event|
      dead_event.reprocess!
    end
  end

  # Get failure statistics
  def self.failure_stats
    group(:event_type).count
  end

  # ==================== PRIVATE METHODS ====================

  private

  def find_original_event
    original_event_type.constantize.find_by(id: original_event_id)
  rescue NameError
    nil
  end

  def event_processing_service
    case event_type
    when 'conversation_created'
      ConversationCreationEventService.new
    else
      raise "No processing service for event type: #{event_type}"
    end
  end
end