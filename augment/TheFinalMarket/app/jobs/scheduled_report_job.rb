class ScheduledReportJob < ApplicationJob
  queue_as :default
  
  def perform(report_id, params = {})
    report = AnalyticsReport.find(report_id)
    
    Rails.logger.info "Executing scheduled report: #{report.name}"
    
    begin
      result = report.execute(params)
      
      # Send email notification if configured
      if report.configuration['email_recipients'].present?
        ReportMailer.scheduled_report(report, result).deliver_later
      end
      
      # Export to file if configured
      if report.configuration['auto_export']
        export_report(report, result)
      end
      
      Rails.logger.info "Successfully executed report: #{report.name}"
    rescue => e
      Rails.logger.error "Failed to execute report #{report.name}: #{e.message}"
      
      # Send error notification
      if report.configuration['email_recipients'].present?
        ReportMailer.report_error(report, e.message).deliver_later
      end
      
      raise e
    end
  end
  
  private
  
  def export_report(report, result)
    # Create data export
    export = DataExport.create!(
      user: report.user,
      export_type: 'scheduled_report',
      parameters: { report_id: report.id },
      status: :processing
    )
    
    # Generate file
    file_name = "#{report.name.parameterize}_#{Time.current.strftime('%Y%m%d_%H%M%S')}.json"
    file_path = Rails.root.join('tmp', 'exports', file_name)
    
    FileUtils.mkdir_p(File.dirname(file_path))
    File.write(file_path, JSON.pretty_generate(result))
    
    export.update!(
      file_name: file_name,
      file_path: file_path.to_s,
      file_size_bytes: File.size(file_path),
      status: :completed,
      completed_at: Time.current,
      expires_at: 7.days.from_now
    )
  end
end

