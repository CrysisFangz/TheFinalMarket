class ExchangeRateUpdateJob < ApplicationJob
  queue_as :default
  
  # Update exchange rates for all currencies
  def perform
    ExchangeRateService.update_all_rates
    
    # Clean up old exchange rates (keep last 30 days)
    ExchangeRate.where('created_at < ?', 30.days.ago).delete_all
    
    Rails.logger.info "Exchange rates updated successfully"
  rescue => e
    Rails.logger.error "Failed to update exchange rates: #{e.message}"
    Sentry.capture_exception(e) if defined?(Sentry)
  end
end

