require 'admin/authentication_service'

class Admin::BaseController < ApplicationController
  before_action :require_admin
  layout 'admin'

  private

  def require_admin
    CircuitBreaker.execute_with_fallback(:admin_authentication) do
      Admin::AuthenticationService.authenticate(current_user)
    end
  rescue AuthenticationError => e
    handle_admin_authentication_error(e)
  end

  def handle_admin_authentication_error(error)
    error_classification = AdminErrorClassificationService.new(error).classify
    recovery_strategy = AdaptiveAdminRecoveryService.new(error_classification).determine_strategy
    circuit_breaker.record_failure(error)

    @error_response = AdminErrorResponseService.new(
      error,
      error_classification,
      recovery_strategy
    ).generate_response

    flash[:danger] = @error_response.user_message
    redirect_to root_path
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
        redirect_to root_path
      }
      format.json { render json: @error_response, status: error_classification.http_status }
    end
  end
end