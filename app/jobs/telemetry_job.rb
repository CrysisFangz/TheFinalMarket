# frozen_string_literal: true

# TelemetryJob - Asynchronous Telemetry Recording for Performance
# Records telemetry events in the background to avoid blocking real-time operations

class TelemetryJob < ApplicationJob
  queue_as :low_priority

  def perform(event:, tags:)
    telemetry_service.record_event(event, tags: tags)
  rescue => e
    Rails.logger.error("TelemetryJob failed: #{e.message}")
  end

  private

  def telemetry_service
    @telemetry_service ||= TelemetryService::Comprehensive.instance
  end
end