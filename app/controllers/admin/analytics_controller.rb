require 'analytics_report_presenter'

class Admin::AnalyticsController < Admin::BaseController
  def index
    analytics_result = CircuitBreaker.execute_with_fallback(:admin_analytics_fetch) do
      AdminAnalyticsQuery.call(
        start_date: params.fetch(:start_date, 30.days.ago),
        end_date: params.fetch(:end_date, Time.current)
      )
    end

    @presenter = CircuitBreaker.execute_with_fallback(:admin_analytics_presenter) do
      AdminAnalyticsPresenter.new(analytics_result)
    end

    respond_to do |format|
      format.html
      format.json { render json: @presenter.to_json }
      format.csv { send_data @presenter.to_csv, filename: "analytics-#{Date.current}.csv" }
    end
  rescue StandardError => e
    handle_analytics_error(e)
  end

  def real_time
    @current_visitors = Ahoy::Visit.where('started_at > ?', 15.minutes.ago).count
    @active_carts = Cart.where('updated_at > ?', 1.hour.ago).count
    @recent_orders = Order.where('created_at > ?', 1.hour.ago)
    @recent_events = Ahoy::Event.where('time > ?', 15.minutes.ago)
                               .order(time: :desc)
                               .limit(50)

    respond_to do |format|
      format.turbo_stream
      format.json { render json: @presenter.to_json }
    end
  rescue StandardError => e
    handle_analytics_error(e)
  end

  def cohorts
    cohort_result = CircuitBreaker.execute_with_fallback(:admin_cohort_analysis) do
      AdminCohortAnalysisQuery.call(
        start_date: params.fetch(:start_date, 12.months.ago),
        end_date: params.fetch(:end_date, Time.current)
      )
    end

    @presenter = CircuitBreaker.execute_with_fallback(:admin_cohort_presenter) do
      AdminCohortAnalysisPresenter.new(cohort_result)
    end

    respond_to do |format|
      format.html
      format.json { render json: @presenter.to_json }
    end
  rescue StandardError => e
    handle_analytics_error(e)
  end

  def export
    export_result = CircuitBreaker.execute_with_fallback(:admin_analytics_export) do
      AdminAnalyticsExportService.call(
        report_type: params[:type],
        start_date: params.fetch(:start_date, 30.days.ago),
        end_date: params.fetch(:end_date, Time.current),
        user_id: current_user.id
      )
    end

    redirect_to admin_analytics_path, notice: 'Your report is being generated and will be emailed to you shortly.'
  rescue StandardError => e
    handle_analytics_error(e)
  end

  private

  def handle_analytics_error(error)
    error_classification = AdminErrorClassificationService.new(error).classify
    recovery_strategy = AdaptiveAdminRecoveryService.new(error_classification).determine_strategy
    circuit_breaker.record_failure(error)

    @error_response = AdminErrorResponseService.new(
      error,
      error_classification,
      recovery_strategy
    ).generate_response

    respond_to do |format|
      format.html {
        flash[:error] = @error_response.user_message
        redirect_to admin_analytics_path
      }
      format.json { render json: @error_response, status: error_classification.http_status }
    end
  end

  # Enhanced Error Handling with Antifragile Recovery
  rescue_from StandardError do |exception|
    error_classification = AdminErrorClassificationService.new(exception).classify
    recovery_strategy = AdaptiveAdminRecoveryService.new(error_classification).determine_strategy
    circuit_breaker.record_failure(exception)

    @error_response = AdminErrorResponseService.new(
      exception,
      error_classification,
      recovery_strategy
    ).generate_response

    respond_to do |format|
      format.html {
        flash[:error] = @error_response.user_message
        redirect_to admin_analytics_path
      }
      format.json { render json: @error_response, status: error_classification.http_status }
    end
  end
end