class DataExport < ApplicationRecord
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
  
  # Check if export is ready
  def ready?
    completed? && file_path.present? && File.exist?(file_path)
  end
  
  # Check if export is expired
  def expired?
    expires_at && expires_at < Time.current
  end
  
  # Get download URL
  def download_url
    return nil unless ready?
    
    # This would generate a signed URL in production
    "/downloads/exports/#{id}/#{file_name}"
  end
  
  # Clean up expired exports
  def self.cleanup_expired
    expired.find_each do |export|
      File.delete(export.file_path) if export.file_path && File.exist?(export.file_path)
      export.destroy
    end
  end
end

