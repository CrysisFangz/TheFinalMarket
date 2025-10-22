# frozen_string_literal: true

# Payment Account Serialization
# Secure serialization with encryption and filtering for different contexts
module PaymentAccountSerialization
  extend ActiveSupport::Concern

  included do
    # JSON serialization with context-aware filtering
    def as_json(options = {})
      context = options.delete(:context) || :default
      super(options.merge(context_options(context)))
    end

    # API serialization for different endpoints
    def to_api_json(api_version = 'v1')
      case api_version
      when 'v1'
        to_api_v1_json
      when 'v2'
        to_api_v2_json
      else
        to_public_json
      end
    end

    # Public-safe serialization
    def to_public_json
      as_json(context: :public)
    end

    # Admin dashboard serialization
    def to_admin_json
      as_json(context: :admin)
    end

    # Mobile app serialization
    def to_mobile_json
      as_json(context: :mobile)
    end

    # Compliance report serialization
    def to_compliance_json
      as_json(context: :compliance)
    end

    # Audit trail serialization
    def to_audit_json
      as_json(context: :audit)
    end

    # Export serialization for data portability
    def to_export_json
      as_json(context: :export)
    end

    # Blockchain serialization for distributed ledger
    def to_blockchain_json
      {
        distributed_payment_id: distributed_payment_id,
        blockchain_verification_hash: blockchain_verification_hash,
        account_data_hash: calculate_account_data_hash,
        verification_proof: generate_verification_proof,
        timestamp: Time.current.iso8601
      }
    end

    # Event sourcing serialization
    def to_event_json
      {
        payment_account_id: id,
        user_id: user_id,
        status: status,
        account_type: account_type,
        risk_level: risk_level,
        compliance_status: compliance_status,
        verification_level: verification_level,
        available_balance_cents: available_balance_cents,
        metadata: {
          distributed_payment_id: distributed_payment_id,
          blockchain_verification_hash: blockchain_verification_hash,
          last_updated: updated_at
        }
      }
    end

    # Search index serialization
    def to_search_index_json
      {
        id: id,
        user_id: user_id,
        status: status,
        account_type: account_type,
        risk_level: risk_level,
        available_balance_cents: available_balance_cents,
        created_at: created_at,
        updated_at: updated_at,
        # Search-optimized fields
        searchable_text: generate_searchable_text,
        tags: generate_search_tags
      }
    end

    # Monitoring serialization
    def to_monitoring_json
      {
        id: id,
        status: status,
        risk_level: risk_level,
        fraud_detection_score: fraud_detection_score,
        compliance_score: compliance_score,
        payment_velocity_score: payment_velocity_score,
        available_balance_cents: available_balance_cents,
        last_activity_at: last_activity_at,
        health_indicators: generate_health_indicators
      }
    end

    # Encrypted serialization for secure transmission
    def to_encrypted_json(encryption_key = nil)
      data = to_event_json
      encryption_key ||= SecureRandom.hex(32)

      {
        encrypted_data: EncryptionService.encrypt(data.to_json, encryption_key),
        encryption_key_hash: Digest::SHA256.hexdigest(encryption_key),
        account_id: id,
        timestamp: Time.current.iso8601
      }
    end

    # Decrypt serialized data
    def self.from_encrypted_json(encrypted_data, encryption_key)
      decrypted = EncryptionService.decrypt(encrypted_data, encryption_key)
      JSON.parse(decrypted).deep_symbolize_keys
    end
  end

  private

  # Context-specific serialization options

  def context_options(context)
    case context.to_sym
    when :public
      public_serialization_options
    when :admin
      admin_serialization_options
    when :mobile
      mobile_serialization_options
    when :compliance
      compliance_serialization_options
    when :audit
      audit_serialization_options
    when :export
      export_serialization_options
    when :api_v1
      api_v1_serialization_options
    when :api_v2
      api_v2_serialization_options
    else
      default_serialization_options
    end
  end

  def public_serialization_options
    {
      only: %i[id status account_type created_at],
      methods: %i[available_balance_formatted]
    }
  end

  def admin_serialization_options
    {
      except: %i[activation_metadata suspension_metadata payment_method_metadata],
      methods: %i[
        available_balance_formatted
        risk_level_formatted
        compliance_status_formatted
        last_activity_at
        health_score
      ]
    }
  end

  def mobile_serialization_options
    {
      only: %i[
        id status account_type risk_level available_balance_cents
        created_at updated_at
      ],
      methods: %i[
        available_balance_formatted
        can_make_payments
        requires_verification
      ]
    }
  end

  def compliance_serialization_options
    {
      only: %i[
        id user_id status compliance_status kyc_status verification_level
        compliance_score fraud_detection_score created_at updated_at
      ],
      include: {
        compliance_records: {
          only: %i[id requirement_type status created_at],
          methods: %i[compliance_result_formatted]
        }
      }
    }
  end

  def audit_serialization_options
    {
      except: %i[payment_methods activation_metadata suspension_metadata],
      include: {
        audit_events: {
          only: %i[id action description performed_at],
          methods: %i[audit_result_formatted]
        }
      }
    }
  end

  def export_serialization_options
    {
      except: %i[
        activation_metadata suspension_metadata payment_method_metadata
        distributed_processing_metadata enterprise_audit_data
      ],
      methods: %i[
        available_balance_formatted
        total_transaction_volume
        account_age_days
        export_metadata
      ]
    }
  end

  def api_v1_serialization_options
    {
      only: %i[
        id status account_type available_balance_cents
        created_at updated_at
      ],
      methods: %i[available_balance_formatted]
    }
  end

  def api_v2_serialization_options
    {
      only: %i[
        id user_id status account_type risk_level compliance_status
        available_balance_cents created_at updated_at
      ],
      methods: %i[
        available_balance_formatted
        risk_level_formatted
        compliance_status_formatted
      ]
    }
  end

  def default_serialization_options
    {
      only: %i[id user_id status account_type created_at updated_at],
      methods: %i[available_balance_formatted]
    }
  end

  # API-specific serialization methods

  def to_api_v1_json
    as_json(context: :api_v1).merge(
      _links: {
        self: "/api/v1/payment_accounts/#{id}",
        user: "/api/v1/users/#{user_id}",
        transactions: "/api/v1/payment_accounts/#{id}/transactions"
      }
    )
  end

  def to_api_v2_json
    as_json(context: :api_v2).merge(
      _links: {
        self: "/api/v2/payment_accounts/#{id}",
        user: "/api/v2/users/#{user_id}",
        transactions: "/api/v2/payment_accounts/#{id}/transactions",
        compliance: "/api/v2/payment_accounts/#{id}/compliance"
      },
      _metadata: {
        api_version: 'v2',
        exported_at: Time.current.iso8601,
        data_freshness: calculate_data_freshness
      }
    )
  end

  # Helper methods for serialization

  def available_balance_formatted
    Money.new(available_balance_cents || 0).format
  end

  def risk_level_formatted
    case risk_level
    when 'low' then '🟢 Low'
    when 'medium' then '🟡 Medium'
    when 'high' then '🟠 High'
    when 'critical' then '🔴 Critical'
    when 'extreme' then '⚫ Extreme'
    else '⚪ Unknown'
    end
  end

  def compliance_status_formatted
    case compliance_status
    when 'verified' then '✅ Verified'
    when 'pending' then '⏳ Pending'
    when 'failed' then '❌ Failed'
    when 'expired' then '⏰ Expired'
    else '❓ Unverified'
    end
  end

  def last_activity_at
    payment_transactions.maximum(:updated_at) || updated_at
  end

  def can_make_payments
    active? && compliant? && available_balance_cents > 0
  end

  def requires_verification
    compliance_status != 'verified' || kyc_status != 'verified'
  end

  def health_score
    # Calculate overall account health score
    scores = []
    scores << (status == 'active' ? 100 : 0)
    scores << (risk_level == 'low' ? 100 : (risk_level == 'medium' ? 75 : 25))
    scores << (compliance_status == 'verified' ? 100 : 0)
    scores << (fraud_detection_score < 0.3 ? 100 : (fraud_detection_score < 0.7 ? 50 : 0))

    scores.sum / scores.size
  end

  def total_transaction_volume
    payment_transactions.where(status: :completed).sum(:amount_cents)
  end

  def account_age_days
    ((Time.current - created_at) / 1.day).to_i
  end

  def export_metadata
    {
      exported_at: Time.current.iso8601,
      data_version: '1.0',
      includes_sensitive_data: false,
      anonymized: false
    }
  end

  def generate_searchable_text
    [
      user&.email,
      user&.full_name,
      distributed_payment_id,
      square_account_id,
      business_email,
      merchant_name
    ].compact.join(' ').downcase
  end

  def generate_search_tags
    tags = []
    tags << "status:#{status}"
    tags << "type:#{account_type}"
    tags << "risk:#{risk_level}"
    tags << "compliance:#{compliance_status}"
    tags << "verification:#{verification_level}"

    if available_balance_cents > 10000000 # $100,000+
      tags << 'high_balance'
    elsif available_balance_cents > 0
      tags << 'has_balance'
    else
      tags << 'zero_balance'
    end

    tags << 'business' if business_account?
    tags << 'enterprise' if account_type == 'enterprise'
    tags << 'premium' if account_type == 'premium'

    tags
  end

  def generate_health_indicators
    {
      operational: active?,
      compliant: compliant?,
      low_risk: %w[low medium].include?(risk_level),
      active_recently: last_activity_at > 7.days.ago,
      balance_healthy: available_balance_cents >= 0,
      verification_complete: verification_level != 'basic'
    }
  end

  def calculate_account_data_hash
    # Generate hash of account data for blockchain verification
    data_string = [
      id,
      user_id,
      status,
      available_balance_cents,
      created_at.to_i,
      updated_at.to_i
    ].join(':')

    Digest::SHA256.hexdigest(data_string)
  end

  def generate_verification_proof
    # Generate cryptographic proof for blockchain verification
    proof_data = {
      account_id: id,
      distributed_payment_id: distributed_payment_id,
      blockchain_verification_hash: blockchain_verification_hash,
      timestamp: Time.current.to_i
    }

    signature = EncryptionService.sign(proof_data.to_json)
    Base64.encode64(signature)
  end

  def calculate_data_freshness
    # Calculate how fresh the data is
    seconds_since_update = Time.current - updated_at

    case seconds_since_update
    when 0..60 then 'real_time'
    when 61..300 then 'very_fresh'    # 5 minutes
    when 301..3600 then 'fresh'       # 1 hour
    when 3601..86400 then 'stale'     # 1 day
    else 'very_stale'
    end
  end
end