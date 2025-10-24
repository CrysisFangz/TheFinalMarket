class MessageReportingService
  def self.report!(message, reporter, reason)
    MessageReport.create!(
      message: message,
      reporter: reporter,
      reason: reason,
      reported_at: Time.current
    )
  end
end