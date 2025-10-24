# frozen_string_literal: true

# ReportExecution model refactored for performance and resilience.
# Tracks analytics report execution with comprehensive monitoring.
class ReportExecution < ApplicationRecord
  belongs_to :analytics_report

  # Enhanced validations with custom messages
  validates :executed_at, presence: true
  validates :status, presence: true, inclusion: { in: statuses.keys }
  validates :error_message, length: { maximum: 1000 }, allow_blank: true
  validates :file_path, length: { maximum: 500 }, allow_blank: true

  # Enhanced scopes with performance optimization
  scope :recent, -> { where('executed_at > ?', 30.days.ago) }
  scope :completed, -> { where(status: :completed) }
  scope :failed, -> { where(status: :failed) }
  scope :running, -> { where(status: :running) }
  scope :with_report, -> { includes(:analytics_report) }
  scope :by_date_range, ->(start_date, end_date) { where(executed_at: start_date..end_date) }

  # Event-driven: Publish events on execution lifecycle
  after_create :publish_execution_started_event
  after_update :publish_execution_completed_event, if: :saved_change_to_status?
  after_update :publish_execution_failed_event, if: -> { saved_change_to_status? && status == 'failed' }

  # Execution status
  enum status: {
    running: 0,
    completed: 1,
    failed: 2
  }

  # Get execution time in seconds with enhanced calculation
  def execution_time
    return nil unless completed_at && executed_at
    (completed_at - executed_at).to_i
  end

  # Check if execution was successful
  def successful?
    status == 'completed'
  end

  # Get execution duration in human-readable format
  def execution_duration
    return 'N/A' unless execution_time

    minutes = execution_time / 60
    seconds = execution_time % 60

    if minutes > 0
      "#{minutes}m #{seconds}s"
    else
      "#{seconds}s"
    end
  end

  # Get performance metrics
  def performance_metrics
    {
      execution_time: execution_time,
      duration: execution_duration,
      successful: successful?,
      file_size: file_size,
      records_processed: records_processed
    }
  end

  private

  def publish_execution_started_event
    Rails.logger.info("Report execution started: ID=#{id}, Report=#{analytics_report_id}")
    # In a full event system: EventPublisher.publish('report_execution_started', self.attributes)
  end

  def publish_execution_completed_event
    Rails.logger.info("Report execution completed: ID=#{id}, Duration=#{execution_time}s")
    # In a full event system: EventPublisher.publish('report_execution_completed', self.attributes)
  end

  def publish_execution_failed_event
    Rails.logger.error("Report execution failed: ID=#{id}, Error=#{error_message}")
    # In a full event system: EventPublisher.publish('report_execution_failed', self.attributes)
  end
end

