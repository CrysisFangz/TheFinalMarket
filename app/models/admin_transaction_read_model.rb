# frozen_string_literal: true

# Read model for admin transactions - optimized for querying and reporting
# This is a projection of the event-sourced data for efficient read operations
#
# @author Kilo Code Autonomous Agent
# @version 2.0.0
class AdminTransactionReadModel < ApplicationRecord
  # Table name
  self.table_name = :admin_transaction_read_models

  # Attributes
  attribute :transaction_id, :string
  attribute :admin_id, :integer
  attribute :requested_by_id, :integer
  attribute :approvable_type, :string
  attribute :approvable_id, :integer
  attribute :action, :string
  attribute :reason, :text
  attribute :justification, :text
  attribute :amount, :decimal
  attribute :currency, :string
  attribute :urgency, :string
  attribute :status, :string
  attribute :compliance_flags, :json
  attribute :created_at, :datetime
  attribute :updated_at, :datetime
  attribute :approved_by_id, :integer
  attribute :approved_at, :datetime
  attribute :final_comments, :text
  attribute :version, :integer

  # Validations
  validates :transaction_id, presence: true, uniqueness: true, length: { maximum: 255 }
  validates :admin_id, presence: true, numericality: { only_integer: true }
  validates :requested_by_id, presence: true, numericality: { only_integer: true }
  validates :action, presence: true, length: { maximum: 100 }
  validates :reason, presence: true, length: { maximum: 1000 }
  validates :urgency, presence: true, inclusion: { in: %w[low medium high critical] }
  validates :status, presence: true, inclusion: {
    in: %w[draft pending_approval under_review approved rejected cancelled escalated auto_approved]
  }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :currency, inclusion: { in: Money::Currency.all.map(&:iso_code) }, allow_nil: true
  validates :version, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # Scopes for common queries
  scope :recent, ->(limit = 100) { order(created_at: :desc).limit(limit) }
  scope :by_admin, ->(admin_id) { where(admin_id: admin_id) }
  scope :by_action, ->(action) { where(action: action) }
  scope :pending_approval, -> { where(status: 'pending_approval') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }
  scope :auto_approved, -> { where(status: 'auto_approved') }
  scope :escalated, -> { where(status: 'escalated') }
  scope :urgent, -> { where(urgency: %w[high critical]) }
  scope :overdue, -> { where('updated_at < ?', 24.hours.ago) }
  scope :high_risk, -> { where('amount > ?', 10000) }
  scope :financial, -> { where(action: %w[escrow_release escrow_refund payment_override]) }
  scope :security_related, -> { where(action: %w[account_suspension account_termination emergency_access_grant]) }
  scope :compliance_required, -> { where.not(compliance_flags: []) }

  # Advanced filtering scope
  scope :with_advanced_filters, ->(filters = {}) do
    query = all

    # Status filtering
    query = query.where(status: filters[:status]) if filters[:status].present?

    # Admin filtering
    query = query.where(admin_id: filters[:admin_id]) if filters[:admin_id].present?

    # Action type filtering
    query = query.where(action: filters[:action_types]) if filters[:action_types].present?

    # Amount range filtering
    if filters[:amount_range].present?
      min_amount, max_amount = filters[:amount_range]
      query = query.where(amount: min_amount..max_amount)
    end

    # Urgency filtering
    query = query.where(urgency: filters[:urgency_levels]) if filters[:urgency_levels].present?

    # Date range filtering
    if filters[:date_range].present?
      query = query.where(created_at: filters[:date_range])
    end

    # Compliance filtering
    if filters[:compliance_only].present?
      query = query.where.not(compliance_flags: [])
    end

    # Overdue filtering
    if filters[:overdue_only].present?
      query = query.where('updated_at < ?', 24.hours.ago)
    end

    query.order(created_at: :desc)
  end

  # Search scope using full-text search
  scope :search, ->(query) do
    return all if query.blank?

    where('reason ILIKE ? OR justification ILIKE ? OR action ILIKE ?',
          "%#{query}%", "%#{query}%", "%#{query}%")
  end

  # Statistical scopes
  scope :by_status_count, -> { group(:status).count }
  scope :by_urgency_count, -> { group(:urgency).count }
  scope :by_action_count, -> { group(:action).count }
  scope :average_amount, -> { average(:amount) }
  scope :total_amount, -> { sum(:amount) }

  # Performance indexes for optimal query performance
  # Composite indexes for common query patterns
  index :created_at
  index [:admin_id, :created_at]
  index [:status, :created_at]
  index [:urgency, :created_at]
  index [:action, :status]
  index [:amount, :created_at]
  index :updated_at

  # Partial indexes for specific use cases
  index :amount, where: "amount IS NOT NULL"
  index :approved_by_id, where: "status = 'approved'"
  index :compliance_flags, where: "jsonb_array_length(compliance_flags) > 0"

  # @return [Boolean] true if transaction is in a final state
  def completed?
    %w[approved rejected cancelled auto_approved].include?(status)
  end

  # @return [Boolean] true if transaction is approved
  def approved?
    status == 'approved' || status == 'auto_approved'
  end

  # @return [Boolean] true if transaction is rejected or cancelled
  def rejected?
    status == 'rejected' || status == 'cancelled'
  end

  # @return [Boolean] true if transaction requires approval
  def requires_approval?
    %w[pending_approval under_review escalated].include?(status)
  end

  # @return [Boolean] true if transaction is overdue for escalation
  def overdue?
    updated_at < 24.hours.ago
  end

  # @return [String] formatted amount with currency
  def formatted_amount
    return nil unless amount && currency

    "#{amount} #{currency.upcase}"
  end

  # @return [Hash] JSON representation for API responses
  def as_json(options = {})
    super(options.merge(
      only: [:transaction_id, :admin_id, :requested_by_id, :approvable_type, :approvable_id,
             :action, :reason, :justification, :amount, :currency, :urgency, :status,
             :compliance_flags, :created_at, :updated_at, :approved_by_id, :approved_at,
             :final_comments, :version],
      methods: [:formatted_amount, :completed?, :approved?, :rejected?, :requires_approval?, :overdue?]
    ))
  end

  # @return [String] human-readable description
  def description
    "#{action.titleize} - #{formatted_amount || 'No amount'}"
  end

  # @return [String] inspection string for debugging
  def inspect
    "AdminTransactionReadModel(#{transaction_id} - #{status})"
  end
end