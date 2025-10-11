class DataExportCleanupJob < ApplicationJob
  queue_as :low_priority
  
  def perform
    Rails.logger.info "Starting data export cleanup..."
    
    # Clean up expired exports
    expired_count = 0
    
    DataExport.expired.find_each do |export|
      # Delete file if it exists
      if export.file_path && File.exist?(export.file_path)
        File.delete(export.file_path)
        Rails.logger.info "Deleted export file: #{export.file_path}"
      end
      
      # Delete export record
      export.destroy
      expired_count += 1
    end
    
    Rails.logger.info "Data export cleanup complete. Removed #{expired_count} expired exports."
  end
end

