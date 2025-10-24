# frozen_string_literal: true

# Command Pattern Mixin
# Provides common command functionality with validation and error handling
module CommandPattern
  extend ActiveSupport::Concern

  included do
    include ServiceResultHelper
  end

  # Standard command errors
  class ValidationError < StandardError; end
  class CommandExecutionError < StandardError; end

  # Execute command with standard error handling
  def execute_with_handling
    execute
  rescue ValidationError => e
    failure_result("Validation failed: #{e.message}")
  rescue CommandExecutionError => e
    failure_result("Command execution failed: #{e.message}")
  rescue ActiveRecord::RecordInvalid => e
    failure_result("Data validation failed: #{e.message}")
  rescue ActiveRecord::RecordNotFound => e
    failure_result("Required record not found: #{e.message}")
  rescue StandardError => e
    Rails.logger.error("#{self.class.name} failed: #{e.message}")
    failure_result("Unexpected error: #{e.message}")
  end

  # Validate command before execution
  def validate!
    raise ValidationError, 'Validation not implemented'
  end

  # Validate command state before execution
  def validate_execution!
    true
  end

  # Default success result
  def success_result(data, message = 'Command executed successfully')
    ServiceResultHelper.success_result(data, message)
  end

  # Default failure result
  def failure_result(message, data = nil)
    ServiceResultHelper.failure_result(message, data)
  end
end