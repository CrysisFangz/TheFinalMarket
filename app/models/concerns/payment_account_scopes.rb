# frozen_string_literal: true

# Payment Account Scopes
# High-performance query optimization with database-level filtering
module PaymentAccountScopes
  extend ActiveSupport::Concern

  included do
    # Status-based scopes
    scope :active, -> { where(status: :active) }
    scope :pending, -> { where(status: :pending) }
    scope :suspended, -> { where(status: :suspended) }
    scope :restricted, -> { where(status: :restricted) }
    scope :terminated, -> { where(status: :terminated) }
    scope :operational, -> { active.where(risk_level: %w[low medium]) }

    # Risk level scopes
    scope :low_risk, -> { where(risk_level: :low) }
    scope :medium_risk, -> { where(risk_level: :medium) }
    scope :high_risk, -> { where(risk_level: %w[high critical extreme]) }
    scope :critical_risk, -> { where(risk_level: %w[critical extreme]) }
    scope :extreme_risk, -> { where(risk_level: :extreme) }

    # Compliance status scopes
    scope :compliant, -> { where(compliance_status: :verified) }
    scope :unverified, -> { where(compliance_status: :unverified) }
    scope :compliance_pending, -> { where(compliance_status: :pending) }
    scope :compliance_failed, -> { where(compliance_status: :failed) }

    # Account type scopes
    scope :standard_accounts, -> { where(account_type: :standard) }
    scope :premium_accounts, -> { where(account_type: :premium) }
    scope :enterprise_accounts, -> { where(account_type: :enterprise) }
    scope :business_accounts, -> { where(account_type: %w[premium enterprise]) }

    # Balance-based scopes
    scope :with_balance, -> { where('available_balance_cents > 0') }
    scope :zero_balance, -> { where(available_balance_cents: 0) }
    scope :high_balance, -> { where('available_balance_cents > ?', 10000000) } # $100,000+
    scope :low_balance, -> { where('available_balance_cents < ?', 100000) }    # $1,000-

    # Activity-based scopes
    scope :recently_active, ->(days = 7) {
      joins(:payment_transactions)
      .where('payment_transactions.created_at > ?', days.days.ago)
      .distinct
    }
    scope :inactive, ->(days = 30) {
      where.not(id: recently_active(days).pluck(:id))
    }

    # Verification level scopes
    scope :basic_verified, -> { where(verification_level: :basic) }
    scope :premium_verified, -> { where(verification_level: :premium) }
    scope :enterprise_verified, -> { where(verification_level: :enterprise) }
    scope :enhanced_verified, -> { where(verification_level: %w[premium enterprise]) }

    # Fraud and security scopes
    scope :high_fraud_risk, -> { where('fraud_detection_score > 0.8') }
    scope :suspicious_activity, -> { where('payment_velocity_score > 0.9') }
    scope :flagged_for_review, -> {
      where(status: :restricted)
      .or(where(risk_level: %w[critical extreme]))
      .or(where('fraud_detection_score > 0.7'))
    }

    # Geographic scopes (if country field exists)
    scope :domestic, -> { where(country: 'US') }
    scope :international, -> { where.not(country: 'US') }

    # Time-based scopes
    scope :created_today, -> { where(created_at: Date.current.all_day) }
    scope :created_this_week, -> { where(created_at: 1.week.ago..Time.current) }
    scope :created_this_month, -> { where(created_at: 1.month.ago..Time.current) }

    # Performance-optimized complex scopes

    # Accounts requiring immediate attention
    scope :requiring_attention, -> {
      where(status: %w[suspended restricted])
      .or(where(risk_level: %w[extreme]))
      .or(where(compliance_status: :failed))
      .or(where('fraud_detection_score > 0.9'))
    }

    # Accounts eligible for premium features
    scope :premium_eligible, -> {
      where(account_type: %w[standard])
      .where(risk_level: %w[low medium])
      .where(compliance_status: :verified)
      .where('available_balance_cents > ?', 100000) # $1,000+
    }

    # Accounts with high transaction volume
    scope :high_volume, -> {
      joins(:payment_transactions)
      .where('payment_transactions.created_at > ?', 30.days.ago)
      .group('payment_accounts.id')
      .having('COUNT(payment_transactions.id) > 100')
    }

    # Accounts with suspicious patterns
    scope :suspicious_patterns, -> {
      # Multiple high-risk indicators
      where('fraud_detection_score > 0.7')
      .where('payment_velocity_score > 0.8')
      .where(risk_level: %w[high critical])
    }

    # Search and filtering scopes

    # Search by account identifier
    scope :search_by_identifier, ->(query) {
      where('distributed_payment_id LIKE ? OR square_account_id LIKE ?',
            "%#{query}%", "%#{query}%")
    }

    # Filter by balance range
    scope :balance_between, ->(min_cents, max_cents) {
      where(available_balance_cents: min_cents..max_cents)
    }

    # Filter by risk score range
    scope :risk_score_between, ->(min_score, max_score) {
      where(fraud_detection_score: min_score..max_score)
    }

    # Filter by creation date range
    scope :created_between, ->(start_date, end_date) {
      where(created_at: start_date..end_date)
    }

    # Advanced filtering scope with multiple criteria
    scope :advanced_filter, ->(filters = {}) {
      scope = all

      if filters[:status].present?
        scope = scope.where(status: filters[:status])
      end

      if filters[:risk_level].present?
        scope = scope.where(risk_level: filters[:risk_level])
      end

      if filters[:account_type].present?
        scope = scope.where(account_type: filters[:account_type])
      end

      if filters[:compliance_status].present?
        scope = scope.where(compliance_status: filters[:compliance_status])
      end

      if filters[:min_balance].present?
        scope = scope.where('available_balance_cents >= ?', filters[:min_balance])
      end

      if filters[:max_balance].present?
        scope = scope.where('available_balance_cents <= ?', filters[:max_balance])
      end

      if filters[:min_fraud_score].present?
        scope = scope.where('fraud_detection_score >= ?', filters[:min_fraud_score])
      end

      if filters[:max_fraud_score].present?
        scope = scope.where('fraud_detection_score <= ?', filters[:max_fraud_score])
      end

      if filters[:country].present?
        scope = scope.where(country: filters[:country])
      end

      if filters[:verification_level].present?
        scope = scope.where(verification_level: filters[:verification_level])
      end

      scope
    }

    # Pagination-optimized scopes

    # For admin dashboard with preloading
    scope :for_admin_dashboard, -> {
      includes(:user, :payment_transactions)
      .order(created_at: :desc)
    }

    # For API responses with selective fields
    scope :for_api_response, -> {
      select(:id, :user_id, :status, :account_type, :risk_level,
             :available_balance_cents, :created_at, :updated_at)
    }

    # For monitoring systems
    scope :for_monitoring, -> {
      select(:id, :status, :risk_level, :fraud_detection_score,
             :compliance_score, :last_balance_calculation_at)
    }

    # Database performance optimized scopes

    # Use database indexes for common queries
    scope :recent_with_balance, -> {
      with_balance
      .where('created_at > ?', 30.days.ago)
      .order(created_at: :desc)
    }

    # Optimized for reporting queries
    scope :for_reporting, ->(date_range = 30.days.ago..Time.current) {
      joins(:payment_transactions)
      .where('payment_transactions.created_at' => date_range)
      .group('payment_accounts.id')
      .select('payment_accounts.*',
              'COUNT(payment_transactions.id) as transaction_count',
              'SUM(payment_transactions.amount_cents) as total_volume_cents')
    }

    # For batch processing
    scope :processable_batch, ->(batch_size = 100) {
      active
      .low_risk
      .compliant
      .order(:last_balance_calculation_at)
      .limit(batch_size)
    }
  end

  # Class methods for complex queries

  def self.find_by_distributed_id(distributed_id)
    find_by(distributed_payment_id: distributed_id)
  end

  def self.find_by_blockchain_hash(blockchain_hash)
    find_by(blockchain_verification_hash: blockchain_hash)
  end

  def self.with_pending_risk_assessment
    where('last_risk_assessment_at < ? OR last_risk_assessment_at IS NULL', 24.hours.ago)
  end

  def self.with_pending_compliance_check
    where('last_compliance_check_at < ? OR last_compliance_check_at IS NULL', 7.days.ago)
  end

  def self.high_value_accounts(min_balance_cents = 100000000) # $1,000,000
    with_balance.where('available_balance_cents >= ?', min_balance_cents)
  end

  def self.recently_suspended(hours = 24)
    suspended.where('suspended_at > ?', hours.hours.ago)
  end

  def self.requiring_manual_review
    restricted.or(high_risk).or(compliance_failed)
  end

  # Statistical query methods

  def self.average_balance
    with_balance.average(:available_balance_cents) || 0
  end

  def self.total_balance
    with_balance.sum(:available_balance_cents) || 0
  end

  def self.risk_distribution
    group(:risk_level).count
  end

  def self.status_distribution
    group(:status).count
  end

  def self.account_type_distribution
    group(:account_type).count
  end

  # Performance monitoring queries

  def self.slow_balance_calculations(threshold_seconds = 1.0)
    where('last_balance_calculation_at > ?', 1.hour.ago)
    .where('available_balance_cents > ?', 10000000) # High balance accounts
  end

  # Compliance monitoring queries

  def self.non_compliant_accounts
    where(compliance_status: %w[failed expired])
    .or(where('compliance_score < 70'))
  end

  def self.accounts_due_for_review(days_since_creation = 90)
    where('created_at < ?', days_since_creation.days.ago)
    .where(compliance_status: %w[unverified pending])
  end
end