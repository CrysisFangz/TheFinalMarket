# frozen_string_literal: true

##
# Helper module for creating consistent service operation results
# across the application with standardized success/failure handling.
#
# @version 1.0.0
# @author Kilo Code AI
module ServiceResultHelper
  ##
  # Represents the result of a service operation
  ServiceResult = Struct.new(:success, :data, :error_message, :metadata) do
    ##
    # Create a successful result
    #
    # @param data [Object] The result data
    # @param metadata [Hash] Additional metadata
    # @return [ServiceResult] Success result
    def self.success(data = nil, metadata = {})
      new(true, data, nil, metadata)
    end

    ##
    # Create a failure result
    #
    # @param error_message [String] The error message
    # @param metadata [Hash] Additional metadata
    # @return [ServiceResult] Failure result
    def self.failure(error_message, metadata = {})
      new(false, nil, error_message, metadata)
    end

    ##
    # Check if the result represents success
    #
    # @return [Boolean] True if successful
    def success?
      success == true
    end

    ##
    # Check if the result represents failure
    #
    # @return [Boolean] True if failed
    def failure?
      !success?
    end
  end

  private

  ##
  # Create a successful service result
  #
  # @param message [String] Success message
  # @param data [Object] Optional result data
  # @return [ServiceResult] Success result
  def success_result(message, data = nil)
    ServiceResult.success(data, { message: message })
  end

  ##
  # Create a failure service result
  #
  # @param message [String] Error message
  # @return [ServiceResult] Failure result
  def failure_result(message)
    ServiceResult.failure(message)
  end
end