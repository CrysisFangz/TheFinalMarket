class DataExport < ApplicationRecord
  include CircuitBreaker
  include Retryable

  belongs_to :user

  validates :export_type, presence: true

  scope :recent, -> { where('created_at > ?', 30.days.ago) }
  scope :active, -> { where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }

  # Export status
  enum status: {
    pending: 0,
    processing: 1,
    completed: 2,
    failed: 3
  }

  # Export types
  EXPORT_TYPES = %w[
    orders
    customers
    products
    revenue
    analytics
    scheduled_report
    custom
  ].freeze

  validates :export_type, inclusion: { in: EXPORT_TYPES }

  # Lifecycle callbacks
  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_destroyed_event

  # Check if export is ready
  def ready?
    Rails.cache.fetch("data_export:#{id}:ready", expires_in: 5.minutes) do
      completed? && file_path.present? && with_retry { File.exist?(file_path) }
    end
  end

  # Check if export is expired
  def expired?
    Rails.cache.fetch("data_export:#{id}:expired", expires_in: 1.minute) do
      expires_at && expires_at < Time.current
    end
  end

  # Get download URL
  def download_url
    return nil unless ready?

    # This would generate a signed URL in production
    "/downloads/exports/#{id}/#{file_name}"
  end

  # Clean up expired exports
  def self.cleanup_expired
    with_retry do
      DataExportService.cleanup_expired
    end
  end

  private

  def publish_created_event
    EventPublisher.publish('data_export.created', {
      export_id: id,
      export_type: export_type,
      user_id: user_id,
      created_at: created_at
    })
  end

  def publish_updated_event
    EventPublisher.publish('data_export.updated', {
      export_id: id,
      export_type: export_type,
      user_id: user_id,
      status: status,
      updated_at: updated_at
    })
  end

  def publish_destroyed_event
    EventPublisher.publish('data_export.destroyed', {
      export_id: id,
      export_type: export_type,
      user_id: user_id
    })
  end
end