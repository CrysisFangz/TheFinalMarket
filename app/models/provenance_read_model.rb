# frozen_string_literal: true

# CQRS Read Model for optimized provenance queries
# Provides denormalized, read-optimized view of provenance data
class ProvenanceReadModel
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Define attributes for the read model
  attribute :id, :integer
  attribute :product_id, :integer
  attribute :product_name, :string
  attribute :blockchain_id, :string
  attribute :blockchain, :string
  attribute :verified, :boolean
  attribute :verified_at, :datetime
  attribute :verification_hash, :string
  attribute :created_at, :datetime
  attribute :origin_data, :json

  # Event statistics
  attribute :total_events, :integer, default: 0
  attribute :last_event_at, :datetime
  attribute :event_types, :json, default: []

  # Performance metrics
  attribute :verification_count, :integer, default: 0
  attribute :last_verification_at, :datetime
  attribute :blockchain_status, :string

  # Cached computed fields
  attribute :days_since_creation, :integer
  attribute :verification_rate, :float
  attribute :event_frequency, :float

  # Initialize from provenance record
  # @param provenance [BlockchainProvenance] source provenance record
  def self.from_provenance(provenance)
    new(
      id: provenance.id,
      product_id: provenance.product_id,
      product_name: provenance.product&.name,
      blockchain_id: provenance.blockchain_id,
      blockchain: provenance.blockchain,
      verified: provenance.verified?,
      verified_at: provenance.verified_at,
      verification_hash: provenance.verification_hash,
      created_at: provenance.created_at,
      origin_data: provenance.origin_data,
      total_events: calculate_total_events(provenance),
      last_event_at: calculate_last_event_at(provenance),
      event_types: calculate_event_types(provenance),
      verification_count: provenance.provenance_events.where(event_type: :verified).count,
      last_verification_at: provenance.verified_at,
      blockchain_status: calculate_blockchain_status(provenance)
    ).tap do |read_model|
      read_model.calculate_computed_fields
    end
  end

    # Find by blockchain ID (read-optimized)
  # @param blockchain_id [String] blockchain ID to search for
  # @return [ProvenanceReadModel, nil] found read model or nil
  def self.find_by_blockchain_id(blockchain_id)
    # Use read-through caching for performance
    cache_key = "provenance_read_model_#{blockchain_id}"

    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      provenance = BlockchainProvenance.includes(
        :product,
        provenance_events: [:blockchain_provenance]
      ).find_by(blockchain_id: blockchain_id)

      from_provenance(provenance) if provenance
    end
  rescue StandardError => e
    Rails.logger.error("Failed to find provenance by blockchain ID #{blockchain_id}: #{e.message}")
    nil
  end</search>
</search_and_replace>

    # Search provenances with filters
  # @param filters [Hash] search filters
  # @return [Array<ProvenanceReadModel>] matching read models
  def self.search(filters = {})
    cache_key = "provenance_search_#{Digest::MD5.hexdigest(filters.to_s)}"

    Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
      provenances = BlockchainProvenance.includes(
        :product,
        provenance_events: [:blockchain_provenance]
      )

      # Apply filters with validation
      provenances = provenances.where(blockchain: filters[:blockchain]) if filters[:blockchain].present?
      provenances = provenances.where(verified: filters[:verified]) if filters.key?(:verified)
      provenances = provenances.where('created_at >= ?', filters[:created_after]) if filters[:created_after]
      provenances = provenances.where('created_at <= ?', filters[:created_before]) if filters[:created_before]
      provenances = provenances.joins(:product).where('products.name ILIKE ?', "%#{filters[:product_name]}%") if filters[:product_name].present?

      # Optimize query with pagination
      limit = [filters[:limit] || 100, 1000].min # Cap at 1000 for performance
      provenances = provenances.order(created_at: :desc).limit(limit)

      provenances.map { |provenance| from_provenance(provenance) }
    end
  rescue StandardError => e
    Rails.logger.error("Provenance search failed with filters #{filters}: #{e.message}")
    []
  end</search>
</search_and_replace>

  # Get provenance statistics
  # @return [Hash] statistical data
  def self.statistics
    Rails.cache.fetch('provenance_statistics', expires_in: 15.minutes) do
      total = BlockchainProvenance.count
      verified = BlockchainProvenance.verified.count
      by_blockchain = BlockchainProvenance.group(:blockchain).count
      avg_events = BlockchainProvenance.joins(:provenance_events)
                                     .group('blockchain_provenances.id')
                                     .average('CAST(COUNT(provenance_events.id) AS FLOAT)')
                                     .values.compact.average || 0

      {
        total_provenances: total,
        verified_provenances: verified,
        verification_rate: total > 0 ? (verified.to_f / total * 100).round(2) : 0,
        average_events_per_provenance: avg_events.round(1),
        distribution_by_blockchain: by_blockchain,
        last_updated: Time.current
      }
    end
  end

  # Check if provenance needs re-verification
  # @return [Boolean] true if needs verification
  def needs_verification?
    return true if verified_at.nil?

    # Verify daily for first 30 days, then weekly
    verification_interval = created_at > 30.days.ago ? 1.day : 7.days
    Time.current - verified_at > verification_interval
  end

  # Get verification status with human-readable format
  # @return [String] status description
  def verification_status
    case
    when !verified?
      'Not Verified'
    when needs_verification?
      'Verification Expired'
    when verified_at > 1.hour.ago
      'Recently Verified'
    else
      'Verified'
    end
  end

  # Get health score based on various metrics
  # @return [Integer] score from 0-100
  def health_score
    score = 100

    # Deduct for unverified status
    score -= 50 unless verified?

    # Deduct for old verification
    if verified_at
      days_since_verification = (Time.current - verified_at).to_i / 86400
      score -= [days_since_verification * 2, 30].min
    end

    # Deduct for missing events
    score -= 10 if total_events.zero?

    # Deduct for high event frequency (potential issues)
    if event_frequency > 10 # More than 10 events per day
      score -= 20
    end

    [score, 0].max
  end

  # Get risk level based on health score
  # @return [Symbol] risk level
  def risk_level
    case health_score
    when 80..100 then :low
    when 60..79 then :medium
    when 40..59 then :high
    else :critical
    end
  end

  # Enhanced performance and resilience methods
  def refresh_cache
    cache_key = "provenance_read_model_#{blockchain_id}"
    Rails.cache.delete(cache_key)
    self.class.find_by_blockchain_id(blockchain_id)
  end

  def to_json_with_metadata
    {
      provenance_data: as_json,
      metadata: {
        cached_at: Time.current,
        cache_expires_in: 1.hour,
        health_score: health_score,
        risk_level: risk_level,
        verification_status: verification_status
      }
    }
  end

  # Event publishing for provenance changes
  def publish_verification_event
    Rails.logger.info("Provenance verification status changed: ID=#{id}, Verified=#{verified}")
    # In a full event system: EventPublisher.publish('provenance_verified', self.attributes)
  end

  private

  # Calculate total events count
  # @param provenance [BlockchainProvenance] provenance record
  # @return [Integer] total events
  def self.calculate_total_events(provenance)
    provenance.provenance_events.count
  end

  # Calculate last event timestamp
  # @param provenance [BlockchainProvenance] provenance record
  # @return [Time, nil] last event time or nil
  def self.calculate_last_event_at(provenance)
    provenance.provenance_events.maximum(:occurred_at)
  end

  # Calculate unique event types
  # @param provenance [BlockchainProvenance] provenance record
  # @return [Array<String>] array of event types
  def self.calculate_event_types(provenance)
    provenance.provenance_events.distinct.pluck(:event_type).sort
  end

  # Calculate blockchain status
  # @param provenance [BlockchainProvenance] provenance record
  # @return [String] status description
  def self.calculate_blockchain_status(provenance)
    return 'not_synced' unless provenance.verification_hash

    if provenance.verified?
      'verified'
    elsif provenance.verification_hash.present?
      'pending_verification'
    else
      'sync_pending'
    end
  end

  # Calculate computed fields
  def calculate_computed_fields
    self.days_since_creation = ((Time.current - created_at) / 86400).to_i if created_at
    self.verification_rate = calculate_verification_rate
    self.event_frequency = calculate_event_frequency
  end

  # Calculate verification rate (verifications per day)
  # @return [Float] verification rate
  def calculate_verification_rate
    return 0.0 if verification_count.zero? || created_at.nil?

    days_active = (Time.current - created_at).to_f / 86400
    verification_count / days_active
  end

  # Calculate event frequency (events per day)
  # @return [Float] event frequency
  def calculate_event_frequency
    return 0.0 if total_events.zero? || created_at.nil?

    days_active = (Time.current - created_at).to_f / 86400
    total_events / days_active
  end
end