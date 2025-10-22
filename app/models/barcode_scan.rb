# ============================================================================
# ENTERPRISE-GRADE BARCODE SCANNING SYSTEM
# ============================================================================
#
# Enhanced barcode scanning model with performance optimizations,
# comprehensive error handling, and real-time analytics capabilities.
#
# PERFORMANCE TARGETS:
# - P99 scan processing latency: < 10ms
# - Throughput: 1000+ scans/second
# - Real-time analytics with < 1s lag
# ============================================================================

class BarcodeScan < ApplicationRecord
  # ============================================================================
  # ASSOCIATIONS & CORE ATTRIBUTES
  # ============================================================================

  belongs_to :user
  belongs_to :product, optional: true

  # Enhanced attribute storage for metadata and context
  store_accessor :scan_metadata, :device_info, :location_data, :scan_context, :performance_metrics
  store_accessor :error_info, :error_type, :error_message, :retry_count

  # ============================================================================
  # ENHANCED VALIDATIONS
  # ============================================================================

  validates :barcode, presence: true, length: { minimum: 8, maximum: 128 }
  validates :scanned_at, presence: true, timeliness: { type: :datetime }
  validates :user_id, presence: true
  validates :processing_time_ms, numericality: { greater_than: 0, less_than: 1000 }, allow_nil: true

  validate :barcode_format_valid
  validate :scan_frequency_within_limits
  validate :device_reputation_check

  # ============================================================================
  # ENUMERATIONS
  # ============================================================================

  enum status: {
    initiated: 0,
    processing: 1,
    completed: 2,
    failed: 3,
    rate_limited: 4
  }

  enum priority: {
    low: 0,
    normal: 1,
    high: 2,
    urgent: 3
  }

  # ============================================================================
  # ENHANCED SCOPES
  # ============================================================================

  scope :recent, ->(limit = 100) { order(scanned_at: :desc).limit(limit) }
  scope :for_user, ->(user) { where(user: user) }
  scope :for_barcode, ->(barcode) { where(barcode: barcode) }
  scope :successful_scans, -> { where(status: :completed) }
  scope :failed_scans, -> { where(status: :failed) }
  scope :high_performance, -> { where('processing_time_ms < ?', 10) }
  scope :within_time_window, ->(hours) { where('scanned_at >= ?', hours.hours.ago) }
  scope :by_priority, ->(priority) { where(priority: priority) }

  # ============================================================================
  # CALLBACKS
  # ============================================================================

  before_validation :initialize_scan_metadata
  before_create :validate_scan_prerequisites
  after_create :trigger_async_processing
  after_update :update_scan_analytics

  # ============================================================================
  # ENHANCED QUERY METHODS
  # ============================================================================

  # Get scan history for user with caching and analytics
  def self.history_for_user(user, limit: 50)
    Rails.cache.fetch("barcode_scan_history:#{user.id}:#{limit}", expires_in: 5.minutes) do
      scans = for_user(user).recent(limit).includes(:product)

      {
        scans: scans,
        summary: calculate_user_scan_summary(scans, user),
        performance_metrics: calculate_performance_metrics(scans)
      }
    end
  end

  # Get popular scanned products with real-time trends
  def self.popular_scans(limit: 10, time_window: 24.hours)
    Rails.cache.fetch("popular_scans:#{limit}:#{time_window}", expires_in: 1.minute) do
      cutoff_time = time_window.ago

      product_counts = within_time_window(24)
                      .where.not(product_id: nil)
                      .group(:product_id)
                      .order(Arel.sql('COUNT(*) DESC'))
                      .limit(limit)
                      .count

      enrich_with_trend_data(product_counts, cutoff_time)
    end
  end

  # High-performance scan processing
  def self.process_scan(user_id, barcode, metadata = {})
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond)

    scan = create_scan_record(user_id, barcode, metadata)
    trigger_product_resolution(scan, metadata)
    record_scan_metrics(scan, start_time)

    scan
  rescue ActiveRecord::RecordInvalid => e
    handle_scan_error(e, user_id, barcode, metadata)
  end

  # Real-time scan analytics
  def self.real_time_analytics(time_window: 1.hour)
    Rails.cache.fetch('real_time_scan_metrics', expires_in: 30.seconds) do
      scans = within_time_window(1)

      {
        total_scans: scans.count,
        scans_per_minute: calculate_scans_per_minute(scans),
        success_rate: calculate_success_rate(scans),
        avg_processing_time: scans.average(:processing_time_ms)&.round(2),
        error_rate: calculate_error_rate(scans),
        top_products: get_top_products(scans)
      }
    end
  end

  private

  # ============================================================================
  # PRIVATE HELPER METHODS
  # ============================================================================

  def initialize_scan_metadata
    self.status ||= :initiated
    self.scan_metadata ||= {}
    self.scan_context ||= generate_scan_context
    self.priority ||= :normal
  end

  def validate_scan_prerequisites
    # Rate limiting check
    if rate_limited?
      self.status = :rate_limited
      errors.add(:base, 'Scan rate limit exceeded')
      throw(:abort)
    end

    # Device reputation check
    if device_blocked?
      errors.add(:base, 'Device blocked from scanning')
      throw(:abort)
    end
  end

  def trigger_async_processing
    ScanProcessingJob.perform_later(id, barcode, scan_metadata)
  end

  def update_scan_analytics
    return unless saved_change_to_status? || saved_change_to_product_id?

    Rails.cache.delete("barcode_scan_history:#{user_id}")
    Rails.cache.delete('popular_scans')
    Rails.cache.delete('real_time_scan_metrics')
  end

  def barcode_format_valid
    return if BarcodeValidator.valid?(barcode)

    errors.add(:barcode, 'Invalid barcode format or checksum')
  end

  def scan_frequency_within_limits
    recent_scans = self.class.where(user_id: user_id)
                           .where(scanned_at: 1.minute.ago..Time.current)
                           .count

    if recent_scans >= 60 # Max 60 scans per minute per user
      errors.add(:base, 'Scan rate limit exceeded')
    end
  end

  def device_reputation_check
    # Placeholder for device reputation system
    # Would integrate with fraud detection service
    true
  end

  def rate_limited?
    self.class.where(user_id: user_id)
             .where(scanned_at: 1.minute.ago..Time.current)
             .count >= 60
  end

  def device_blocked?
    # Placeholder for device blocking logic
    false
  end

  def generate_scan_context
    {
      session_id: SecureRandom.uuid,
      timestamp: Time.current,
      api_version: 'v2.0',
      request_id: scan_metadata&.dig('request_id')
    }
  end

  # ============================================================================
  # ANALYTICS HELPER METHODS
  # ============================================================================

  def self.calculate_user_scan_summary(scans, user)
    {
      total_scans: scans.count,
      successful_scans: scans.successful_scans.count,
      unique_products: scans.distinct.count(:product_id),
      scan_tier: user.scan_tier,
      favorite_categories: calculate_favorite_categories(scans)
    }
  end

  def self.calculate_performance_metrics(scans)
    processing_times = scans.where.not(processing_time_ms: nil).pluck(:processing_time_ms)

    {
      avg_processing_time: processing_times.any? ? (processing_times.sum.to_f / processing_times.count).round(2) : 0,
      min_processing_time: processing_times.min,
      max_processing_time: processing_times.max,
      p95_processing_time: calculate_percentile(processing_times, 0.95)&.round(2)
    }
  end

  def self.enrich_with_trend_data(product_counts, cutoff_time)
    product_counts.map do |product_id, scan_count|
      recent_trend = calculate_product_trend(product_id, cutoff_time)

      {
        product_id: product_id,
        scan_count: scan_count,
        trend: recent_trend,
        popularity_score: calculate_popularity_score(scan_count, recent_trend)
      }
    end
  end

  def self.calculate_favorite_categories(scans)
    category_counts = scans.joins(:product)
                          .group('products.category')
                          .count
                          .sort_by { |_, count| -count }
                          .first(3)

    category_counts.map { |category, count| { category: category, scan_count: count } }
  end

  def self.calculate_product_trend(product_id, cutoff_time)
    recent_count = where(product_id: product_id)
                  .where('scanned_at >= ?', cutoff_time)
                  .count

    older_count = where(product_id: product_id)
                 .where('scanned_at >= ? AND scanned_at < ?', 48.hours.ago, cutoff_time)
                 .count

    return :stable if older_count.zero?

    ratio = recent_count.to_f / older_count
    if ratio > 1.2
      :rising
    elsif ratio < 0.8
      :declining
    else
      :stable
    end
  end

  def self.calculate_popularity_score(scan_count, trend)
    base_score = Math.log(scan_count + 1) * 10

    trend_multiplier = case trend
                     when :rising then 1.3
                     when :declining then 0.7
                     else 1.0
                     end

    (base_score * trend_multiplier).round(1)
  end

  def self.calculate_scans_per_minute(scans)
    return 0 if scans.empty?

    time_span_minutes = [(Time.current - scans.last.scanned_at) / 60, 1].max
    scans.count / time_span_minutes
  end

  def self.calculate_success_rate(scans)
    successful = scans.successful_scans.count
    total = scans.count
    total > 0 ? (successful.to_f / total * 100).round(2) : 0
  end

  def self.calculate_error_rate(scans)
    failed = scans.failed_scans.count
    total = scans.count
    total > 0 ? (failed.to_f / total * 100).round(2) : 0
  end

  def self.get_top_products(scans, limit: 5)
    scans.where.not(product_id: nil)
         .group(:product_id)
         .order(Arel.sql('COUNT(*) DESC'))
         .limit(limit)
         .count
         .map { |product_id, count| { product_id: product_id, scan_count: count } }
  end

  def self.calculate_percentile(values, percentile)
    return nil if values.empty?

    sorted = values.sort
    index = (sorted.length * percentile).ceil - 1
    index = [index, sorted.length - 1].min
    sorted[index]
  end

  def self.create_scan_record(user_id, barcode, metadata)
    create!(
      user_id: user_id,
      barcode: barcode,
      scanned_at: Time.current,
      scan_metadata: metadata,
      status: :initiated,
      priority: determine_priority(metadata)
    )
  end

  def self.trigger_product_resolution(scan, metadata)
    ProductResolutionService.perform_async(scan.id, scan.barcode, metadata)
  end

  def self.record_scan_metrics(scan, start_time)
    processing_time_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC, :microsecond) - start_time) / 1000).round(2)

    scan.update_column(:processing_time_ms, processing_time_ms)

    # Record metrics for monitoring
    StatsD.increment('barcode_scan.processed')
    StatsD.histogram('barcode_scan.processing_time_ms', processing_time_ms)

    # Alert if performance threshold exceeded
    if processing_time_ms > 50
      alert_performance_issue(scan, processing_time_ms)
    end
  end

  def self.determine_priority(metadata)
    # Determine scan priority based on metadata
    if metadata[:urgent] || metadata[:vip_user]
      :urgent
    elsif metadata[:high_priority]
      :high
    else
      :normal
    end
  end

  def self.alert_performance_issue(scan, processing_time_ms)
    Rails.logger.warn("Barcode scan performance issue", {
      scan_id: scan.id,
      processing_time_ms: processing_time_ms,
      threshold: 50,
      user_id: scan.user_id,
      barcode: scan.barcode
    })
  end

  def self.handle_scan_error(error, user_id, barcode, metadata)
    Rails.logger.error("Barcode scan error: #{error.message}", {
      user_id: user_id,
      barcode: barcode,
      metadata: metadata,
      error_details: error.details,
      backtrace: error.backtrace&.first(5)
    })

    raise ScanProcessingError.new(error.message, original_error: error)
  end

  # ============================================================================
  # SUPPORTING SERVICE CLASSES
  # ============================================================================

  # Barcode validation service
  class BarcodeValidator
    class << self
      def valid?(barcode)
        return false if barcode.blank?
        return false if barcode.length < 8 || barcode.length > 128

        # Basic format validation (can be extended for specific barcode types)
        barcode.match?(/^[A-Za-z0-9\-_\.]+$/) && checksum_valid?(barcode)
      end

      def checksum_valid?(barcode)
        # Placeholder for barcode-specific checksum validation
        true
      end
    end
  end

  # Product resolution service
  class ProductResolutionService
    class << self
      def perform_async(scan_id, barcode, metadata)
        ProductResolutionJob.perform_later(scan_id, barcode, metadata)
      end
    end
  end

  # ============================================================================
  # BACKGROUND JOBS
  # ============================================================================

  # Main scan processing job
  class ScanProcessingJob < ApplicationJob
    queue_as :barcode_scanning

    def perform(scan_id, barcode, metadata)
      scan = BarcodeScan.find(scan_id)

      # Resolve product
      product_id = resolve_product(barcode, metadata)
      return unless product_id

      # Update scan with resolution
      scan.update!(
        product_id: product_id,
        status: :completed,
        processing_time_ms: (Time.current - scan.created_at) * 1000
      )
    end

    private

    def resolve_product(barcode, metadata)
      # Placeholder for product resolution logic
      "product_#{Digest::SHA256.hexdigest(barcode)[0..15]}"
    end
  end

  # ============================================================================
  # CUSTOM EXCEPTIONS
  # ============================================================================

  class ScanProcessingError < StandardError
    attr_reader :original_error

    def initialize(message, original_error: nil)
      super(message)
      @original_error = original_error
    end
  end

  class ScanRateLimitError < StandardError; end
  class DeviceBlockedError < StandardError; end
  class InvalidBarcodeFormatError < StandardError; end
end