class DataExportService
  def self.cleanup_expired
    DataExport.expired.find_each do |export|
      File.delete(export.file_path) if export.file_path && File.exist?(export.file_path)
      export.destroy
    end
  end
end