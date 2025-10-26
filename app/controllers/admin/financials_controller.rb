class Admin::FinancialsController < Admin::BaseController
  def index
    @financials = CircuitBreaker.execute_with_fallback(:financials_decorator) do
      FinancialsDecorator.new
    end
  rescue => e
    Rails.logger.error("Financials index failed: #{e.message}")
    @financials = nil
    flash[:error] = 'Unable to load financials data.'
  end
end
