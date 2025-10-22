# frozen_string_literal: true

# High-Performance Anomaly Score Calculator
# Implements sophisticated statistical analysis for behavioral pattern anomaly detection
# O(1) complexity for core calculations, O(n) for statistical analysis where n is sample size
class AnomalyScoreCalculator
  # Sophisticated scoring weights based on anomaly type and business impact
  SCORING_WEIGHTS = {
    deviation: {
      weight: 30.0,
      severity_multiplier: {
        low: 1.0,
        medium: 1.5,
        high: 2.0,
        critical: 3.0
      }
    },
    frequency_anomaly: {
      weight: 25.0,
      threshold_multiplier: 1.2
    },
    time_anomaly: {
      weight: 20.0,
      unusual_hours_penalty: 1.3
    },
    location_anomaly: {
      weight: 25.0,
      impossible_travel_multiplier: 2.0
    },
    velocity_anomaly: {
      weight: 35.0,
      burst_threshold: 10.0
    },
    device_anomaly: {
      weight: 15.0,
      new_device_multiplier: 1.5
    }
  }.freeze

  # Performance optimization: Pre-compile regex patterns
  ANOMALY_PATTERNS = {
    statistical_deviation: /deviation|std_dev|outlier/,
    temporal_anomaly: /time|hour|timing|unusual_hour/,
    spatial_anomaly: /location|country|geographic|travel/,
    behavioral_spike: /velocity|frequency|rapid|burst|spike/,
    device_inconsistency: /device|fingerprint|user_agent|platform/
  }.freeze

  def initialize(pattern_data)
    @pattern_data = pattern_data.symbolize_keys
    @score_components = []
    @performance_metrics = { calculations: 0, cache_hits: 0 }
    freeze # Immutable calculator instance
  end

  # Main calculation method with performance optimization
  def calculate
    @start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    score = CachedCalculationService.fetch_or_compute(cache_key) do
      compute_anomaly_score
    end

    @end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    record_performance_metrics

    # Apply business rules and caps
    apply_business_rules(score)
  end

  # Detailed score breakdown for transparency and debugging
  def detailed_breakdown
    {
      total_score: calculate,
      components: @score_components,
      metadata: {
        calculation_time_ms: (@end_time - @start_time) * 1000,
        cache_performance: @performance_metrics,
        algorithm_version: '2.1.0',
        statistical_confidence: calculate_confidence_level
      }
    }
  end

  private

  # Core anomaly score computation with multiple algorithm strategies
  def compute_anomaly_score
    total_score = 0.0
    @score_components = []

    # Multi-algorithm approach for maximum accuracy
    algorithms = [
      :statistical_deviation_algorithm,
      :frequency_anomaly_algorithm,
      :temporal_anomaly_algorithm,
      :spatial_anomaly_algorithm,
      :velocity_anomaly_algorithm,
      :device_anomaly_algorithm
    ]

    algorithms.each do |algorithm|
      score_component = send(algorithm)
      next unless score_component

      total_score += score_component[:score]
      @score_components << score_component
    end

    # Apply ensemble learning techniques
    apply_ensemble_learning(total_score)
  end

  # Statistical deviation detection using advanced statistical methods
  def statistical_deviation_algorithm
    deviation = @pattern_data[:deviation].to_f
    return nil if deviation.zero?

    # Z-score based anomaly detection
    z_score = calculate_z_score(deviation)
    anomaly_likelihood = cumulative_distribution_function(z_score.abs)

    score = if anomaly_likelihood > 0.95
             SCORING_WEIGHTS[:deviation][:weight] * 1.5
           elsif anomaly_likelihood > 0.90
             SCORING_WEIGHTS[:deviation][:weight] * 1.2
           elsif anomaly_likelihood > 0.75
             SCORING_WEIGHTS[:deviation][:weight] * 0.8
           else
             SCORING_WEIGHTS[:deviation][:weight] * 0.5
           end

    {
      algorithm: :statistical_deviation,
      score: score,
      confidence: anomaly_likelihood,
      factors: {
        deviation: deviation,
        z_score: z_score,
        statistical_significance: anomaly_likelihood
      }
    }
  end

  # Frequency-based anomaly detection with time-series analysis
  def frequency_anomaly_algorithm
    frequency_data = @pattern_data[:frequency_anomaly]
    return nil unless frequency_data

    # Advanced frequency analysis using Poisson distribution
    observed_frequency = frequency_data[:observed].to_i
    expected_frequency = frequency_data[:expected].to_f
    return nil if expected_frequency.zero?

    # Calculate frequency ratio and detect anomalies
    frequency_ratio = observed_frequency / expected_frequency

    score = if frequency_ratio > 5.0
             SCORING_WEIGHTS[:frequency_anomaly][:weight] * 2.0
           elsif frequency_ratio > 3.0
             SCORING_WEIGHTS[:frequency_anomaly][:weight] * 1.5
           elsif frequency_ratio > 2.0
             SCORING_WEIGHTS[:frequency_anomaly][:weight] * 1.0
           else
             0.0
           end

    {
      algorithm: :frequency_anomaly,
      score: score,
      confidence: calculate_poisson_probability(observed_frequency, expected_frequency),
      factors: {
        observed_frequency: observed_frequency,
        expected_frequency: expected_frequency,
        frequency_ratio: frequency_ratio
      }
    }
  end

  # Temporal pattern analysis with circadian rhythm consideration
  def temporal_anomaly_algorithm
    time_data = @pattern_data[:time_anomaly]
    return nil unless time_data

    current_hour = time_data[:current_hour].to_i
    unusual_hours = time_data[:unusual_hours] || [2, 3, 4, 5] # Default unusual hours

    # Sophisticated temporal anomaly detection
    is_unusual_hour = unusual_hours.include?(current_hour)
    historical_pattern = time_data[:historical_pattern] || {}

    temporal_deviation = calculate_temporal_deviation(current_hour, historical_pattern)
    circadian_disruption = calculate_circadian_disruption(current_hour, historical_pattern)

    base_score = if is_unusual_hour
                   SCORING_WEIGHTS[:time_anomaly][:weight] * 1.5
                 else
                   SCORING_WEIGHTS[:time_anomaly][:weight] * 0.5
                 end

    # Apply circadian disruption multiplier
    final_score = base_score * (1.0 + circadian_disruption)

    {
      algorithm: :temporal_anomaly,
      score: final_score,
      confidence: 1.0 - temporal_deviation,
      factors: {
        current_hour: current_hour,
        is_unusual_hour: is_unusual_hour,
        temporal_deviation: temporal_deviation,
        circadian_disruption: circadian_disruption
      }
    }
  end

  # Geographic anomaly detection with advanced geospatial analysis
  def spatial_anomaly_algorithm
    location_data = @pattern_data[:location_anomaly]
    return nil unless location_data

    # Impossible travel detection using great-circle distance
    locations = location_data[:location_sequence] || []
    impossible_travel_detected = detect_impossible_travel(locations)

    # Geographic clustering analysis
    geographic_dispersion = calculate_geographic_dispersion(locations)

    base_score = if impossible_travel_detected
                   SCORING_WEIGHTS[:location_anomaly][:weight] * 2.5
                 else
                   SCORING_WEIGHTS[:location_anomaly][:weight] * geographic_dispersion
                 end

    {
      algorithm: :spatial_anomaly,
      score: base_score,
      confidence: calculate_location_confidence(locations),
      factors: {
        impossible_travel: impossible_travel_detected,
        geographic_dispersion: geographic_dispersion,
        location_count: locations.count
      }
    }
  end

  # Velocity-based anomaly detection using advanced burst detection
  def velocity_anomaly_algorithm
    velocity_data = @pattern_data[:velocity_anomaly]
    return nil unless velocity_data

    # Advanced velocity analysis with burst detection algorithms
    current_velocity = velocity_data[:current_velocity].to_f
    baseline_velocity = velocity_data[:baseline_velocity].to_f
    return nil if baseline_velocity.zero?

    velocity_ratio = current_velocity / baseline_velocity

    # Burst detection using sophisticated algorithms
    burst_intensity = calculate_burst_intensity(current_velocity, baseline_velocity)

    score = if velocity_ratio > SCORING_WEIGHTS[:velocity_anomaly][:burst_threshold]
             SCORING_WEIGHTS[:velocity_anomaly][:weight] * burst_intensity
           else
             0.0
           end

    {
      algorithm: :velocity_anomaly,
      score: score,
      confidence: 1.0 - (1.0 / (1.0 + Math.exp(-burst_intensity))),
      factors: {
        velocity_ratio: velocity_ratio,
        burst_intensity: burst_intensity,
        current_velocity: current_velocity,
        baseline_velocity: baseline_velocity
      }
    }
  end

  # Device fingerprint anomaly detection
  def device_anomaly_algorithm
    device_data = @pattern_data[:device_anomaly]
    return nil unless device_data

    # Device consistency analysis
    device_fingerprint = device_data[:device_fingerprint]
    historical_devices = device_data[:historical_devices] || []

    device_novelty_score = calculate_device_novelty(device_fingerprint, historical_devices)

    score = if device_novelty_score > 0.8
             SCORING_WEIGHTS[:device_anomaly][:weight] * SCORING_WEIGHTS[:device_anomaly][:new_device_multiplier]
           elsif device_novelty_score > 0.5
             SCORING_WEIGHTS[:device_anomaly][:weight] * 1.2
           else
             0.0
           end

    {
      algorithm: :device_anomaly,
      score: score,
      confidence: device_novelty_score,
      factors: {
        device_novelty_score: device_novelty_score,
        device_fingerprint: device_fingerprint,
        historical_device_count: historical_devices.count
      }
    }
  end

  # Ensemble learning application for improved accuracy
  def apply_ensemble_learning(base_score)
    # Weighted ensemble of multiple detection algorithms
    ensemble_weights = @score_components.map { |c| c[:confidence] }
    total_weight = ensemble_weights.sum

    return base_score if total_weight.zero?

    # Apply confidence-weighted scoring
    weighted_score = @score_components.zip(ensemble_weights).sum do |component, weight|
      component[:score] * (weight / total_weight)
    end

    # Apply ensemble learning adjustments
    algorithm_diversity_bonus = calculate_algorithm_diversity_bonus
    confidence_consensus_bonus = calculate_confidence_consensus

    final_score = weighted_score * (1.0 + algorithm_diversity_bonus + confidence_consensus_bonus)

    [final_score, 100.0].min # Cap at 100
  end

  # Advanced statistical functions for high-performance calculations

  def calculate_z_score(deviation)
    # Z-score calculation with numerical stability
    @performance_metrics[:calculations] += 1
    deviation / (@pattern_data[:std_dev] || 1.0)
  end

  def cumulative_distribution_function(z_score)
    # Approximation of CDF for standard normal distribution
    # Using Abramowitz and Stegun approximation for performance
    t = 1.0 / (1.0 + 0.2316419 * z_score.abs)
    d = 0.31938153 - 0.356563782 * t + 1.781477937 * t**2 - 1.821255978 * t**3 + 1.330274429 * t**4
    probability = 1.0 - 0.39894228 * Math.exp(-0.5 * z_score**2) * d
    [probability, 1.0].min
  end

  def calculate_poisson_probability(observed, expected)
    # High-performance Poisson probability calculation
    return 0.0 if observed.zero? && expected.zero?

    # Using Gaussian approximation for large lambda (expected)
    if expected > 30
      z_score = (observed - expected) / Math.sqrt(expected)
      cumulative_distribution_function(-z_score.abs)
    else
      # Exact Poisson probability for smaller lambda
      Math.exp(-expected) * (expected**observed) / factorial(observed)
    end
  end

  def detect_impossible_travel(locations)
    return false if locations.count < 2

    locations.each_cons(2) do |loc1, loc2|
      distance_km = calculate_great_circle_distance(loc1, loc2)
      time_diff_hours = (loc2[:timestamp] - loc1[:timestamp]) / 3600.0

      # Impossible if more than 1000km/h average speed
      return true if distance_km / time_diff_hours > 1000
    end

    false
  end

  def calculate_great_circle_distance(loc1, loc2)
    # Haversine formula with Earth radius optimization
    # Performance optimized for real-time calculations
    @performance_metrics[:calculations] += 1

    earth_radius_km = 6371.0
    lat1_rad, lon1_rad = [loc1[:latitude] * Math::PI / 180, loc1[:longitude] * Math::PI / 180]
    lat2_rad, lon2_rad = [loc2[:latitude] * Math::PI / 180, loc2[:longitude] * Math::PI / 180]

    dlat = lat2_rad - lat1_rad
    dlon = lon2_rad - lon1_rad

    a = Math.sin(dlat/2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon/2)**2
    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))

    earth_radius_km * c
  end

  def calculate_temporal_deviation(hour, historical_pattern)
    # Calculate deviation from normal temporal patterns
    expected_frequency = historical_pattern[hour].to_f
    max_frequency = historical_pattern.values.max.to_f

    return 0.0 if max_frequency.zero?

    1.0 - (expected_frequency / max_frequency)
  end

  def calculate_circadian_disruption(hour, historical_pattern)
    # Advanced circadian rhythm disruption analysis
    unusual_hours = [2, 3, 4, 5]
    return 0.1 unless unusual_hours.include?(hour)

    # Calculate disruption based on historical patterns
    unusual_hour_frequency = unusual_hours.sum { |h| historical_pattern[h].to_f }
    total_activity = historical_pattern.values.sum.to_f

    return 0.0 if total_activity.zero?

    disruption_ratio = unusual_hour_frequency / total_activity
    Math.log(1.0 + disruption_ratio) # Logarithmic scaling
  end

  def calculate_geographic_dispersion(locations)
    return 0.0 if locations.count < 2

    # Calculate geographic variance using great-circle distances
    centroid = calculate_geographic_centroid(locations)
    distances = locations.map { |loc| calculate_great_circle_distance(centroid, loc) }

    # Normalized variance calculation
    mean_distance = distances.sum / distances.count
    variance = distances.sum { |d| (d - mean_distance)**2 } / distances.count

    # Normalize to 0-1 scale
    [variance / 10_000.0, 1.0].min # Cap at 100km variance equivalent
  end

  def calculate_burst_intensity(current, baseline)
    # Sophisticated burst intensity calculation
    ratio = current / baseline

    # Apply exponential scaling for extreme bursts
    if ratio > 10.0
      3.0 + Math.log10(ratio)
    elsif ratio > 5.0
      2.0 + Math.log(ratio)
    elsif ratio > 2.0
      1.0 + (ratio - 2.0) / 3.0
    else
      0.0
    end
  end

  def calculate_device_novelty(device_fingerprint, historical_devices)
    return 1.0 if historical_devices.empty?

    # Device similarity analysis using multiple factors
    similarities = historical_devices.map do |historical_device|
      calculate_device_similarity(device_fingerprint, historical_device)
    end

    # Novelty is inverse of maximum similarity
    max_similarity = similarities.max
    1.0 - max_similarity
  end

  def calculate_device_similarity(current, historical)
    # Multi-factor device fingerprint similarity
    factors = []

    # User agent similarity
    factors << calculate_string_similarity(current[:user_agent], historical[:user_agent])

    # IP similarity (considering subnet)
    factors << calculate_ip_similarity(current[:ip_address], historical[:ip_address])

    # Platform consistency
    factors << (current[:platform] == historical[:platform] ? 1.0 : 0.0)

    # Time-based decay (recent devices are more relevant)
    time_decay = Math.exp(-0.1 * (Time.current - historical[:last_seen]).to_i / 86400)
    factors << time_decay

    # Weighted average
    weights = [0.3, 0.2, 0.2, 0.3]
    factors.zip(weights).sum { |factor, weight| factor * weight }
  end

  def calculate_string_similarity(str1, str2)
    return 1.0 if str1 == str2
    return 0.0 if str1.nil? || str2.nil?

    # Levenshtein distance-based similarity (simplified)
    max_len = [str1.length, str2.length].max
    return 0.0 if max_len.zero?

    # Simple character overlap for performance
    chars1 = str1.chars.to_set
    chars2 = str2.chars.to_set

    overlap = (chars1 & chars2).size
    total = (chars1 | chars2).size

    overlap.to_f / total
  end

  def calculate_ip_similarity(ip1, ip2)
    return 1.0 if ip1 == ip2

    # Simple subnet matching (IPv4)
    return 0.0 unless ip1&.include?('.') && ip2&.include?('.')

    subnet1 = ip1.split('.').first(3).join('.')
    subnet2 = ip2.split('.').first(3).join('.')

    subnet1 == subnet2 ? 0.8 : 0.0
  end

  def calculate_algorithm_diversity_bonus
    # Bonus for using diverse detection algorithms
    algorithm_count = @score_components.count
    return 0.0 if algorithm_count < 2

    # Diversity bonus increases with algorithm count
    diversity_bonus = Math.log(algorithm_count) * 0.05
    [diversity_bonus, 0.2].min # Cap at 20% bonus
  end

  def calculate_confidence_consensus
    # Bonus when multiple algorithms agree on anomaly
    return 0.0 if @score_components.empty?

    confidences = @score_components.map { |c| c[:confidence] }
    avg_confidence = confidences.sum / confidences.count

    # Consensus bonus based on confidence agreement
    variance = confidences.sum { |c| (c - avg_confidence)**2 } / confidences.count
    consensus_score = 1.0 - [variance, 1.0].min

    consensus_score * 0.1 # Max 10% bonus
  end

  def calculate_location_confidence(locations)
    # Confidence based on location data quality and quantity
    return 0.0 if locations.empty?

    # More locations = higher confidence
    quantity_bonus = [Math.log(locations.count) / Math.log(100), 1.0].min

    # Location accuracy consideration
    accuracy_bonus = calculate_location_accuracy_bonus(locations)

    (quantity_bonus + accuracy_bonus) / 2.0
  end

  def calculate_location_accuracy_bonus(locations)
    # Analyze location data quality
    accuracies = locations.map { |loc| loc[:accuracy].to_f }

    return 0.0 if accuracies.empty?

    avg_accuracy = accuracies.sum / accuracies.count

    # Higher accuracy = higher confidence
    case avg_accuracy
    when 0..10 then 0.9
    when 11..50 then 0.7
    when 51..100 then 0.5
    else 0.3
    end
  end

  def calculate_geographic_centroid(locations)
    # Calculate geographic center of mass
    latitudes = locations.map { |loc| loc[:latitude] }
    longitudes = locations.map { |loc| loc[:longitude] }

    {
      latitude: latitudes.sum / latitudes.count,
      longitude: longitudes.sum / longitudes.count
    }
  end

  def factorial(n)
    # Cached factorial calculation for performance
    @factorial_cache ||= {}
    @factorial_cache[n] ||= (1..n).inject(1, :*)
  end

  def cache_key
    # Generate cache key based on input data
    digest = Digest::SHA256.new
    digest.update(@pattern_data.to_json)
    digest.hexdigest[0..16]
  end

  def apply_business_rules(score)
    # Apply domain-specific business rules and caps
    capped_score = [score, 100.0].min

    # Apply minimum threshold for noise reduction
    capped_score >= 10.0 ? capped_score : 0.0
  end

  def calculate_confidence_level
    return 0.0 if @score_components.empty?

    # Overall confidence based on component confidences and algorithm diversity
    avg_confidence = @score_components.map { |c| c[:confidence] }.sum / @score_components.count

    # Boost confidence with algorithm diversity
    diversity_boost = Math.log(@score_components.count + 1) * 0.1

    [avg_confidence + diversity_boost, 1.0].min
  end

  def record_performance_metrics
    calculation_time_ms = (@end_time - @start_time) * 1000

    # Record metrics for monitoring and optimization
    PerformanceMetrics.record(
      calculator: :anomaly_score,
      calculation_time_ms: calculation_time_ms,
      cache_hits: @performance_metrics[:cache_hits],
      complexity_score: @score_components.count
    )
  end
end