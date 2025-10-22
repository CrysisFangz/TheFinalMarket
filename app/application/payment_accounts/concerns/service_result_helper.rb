# frozen_string_literal: true

# Service Result Helper
# Standardized result handling for service operations
module ServiceResultHelper
  # Success result structure
  def success_result(data = nil, message = 'Operation completed successfully')
    ServiceResult.new(success: true, data: data, message: message)
  end

  # Failure result structure
  def failure_result(message, data = nil, error_code = nil)
    ServiceResult.new(success: false, data: data, message: message, error_code: error_code)
  end

  # Service Result class
  class ServiceResult
    attr_reader :success, :data, :message, :error_code, :errors

    def initialize(success:, data: nil, message: nil, error_code: nil, errors: nil)
      @success = success
      @data = data
      @message = message
      @error_code = error_code
      @errors = errors || []
    end

    def failure?
      !success
    end

    def success?
      success
    end

    def on_success
      yield(data, message) if success?
      self
    end

    def on_failure
      yield(message, error_code, errors) if failure?
      self
    end

    def to_h
      {
        success: success,
        data: data,
        message: message,
        error_code: error_code,
        errors: errors
      }
    end

    def to_json(options = {})
      to_h.to_json(options)
    end
  end
end