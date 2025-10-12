class ReportExecution < ApplicationRecord
  belongs_to :analytics_report
  
  validates :executed_at, presence: true
  
  scope :recent, -> { where('executed_at > ?', 30.days.ago) }
  scope :completed, -> { where(status: :completed) }
  scope :failed, -> { where(status: :failed) }
  
  # Execution status
  enum status: {
    running: 0,
    completed: 1,
    failed: 2
  }
  
  # Get execution time in seconds
  def execution_time
    return nil unless completed_at && executed_at
    (completed_at - executed_at).to_i
  end
  
  # Check if execution was successful
  def successful?
    status == 'completed'
  end
end

