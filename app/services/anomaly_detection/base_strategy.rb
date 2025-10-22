# frozen_string_literal: true

# Base Strategy Pattern for Anomaly Detection
# Implements Template Method pattern for consistent anomaly detection workflow
# Provides extensible framework for implementing new detection algorithms
module AnomalyDetection
  class BaseStrategy
    # Template method defining the anomaly detection workflow
    def detect_anomalies(user_behavior_data)
      validate_input_data(user_behavior_data)

      @start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @user_behavior_data = user_behavior_data

      begin
        # Template method steps
        prepare_detection_data
        analyze_behavior_patterns
        identify_anomalies
        calculate_confidence_scores
        generate_detection_result
      rescue StandardError => e
        handle_detection_error(e)
      end
    end

    # Performance tracking for strategy optimization
    def performance_metrics
      return {} unless @start_time

      end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      {
        execution_time_ms: (end_time - @start_time) * 1000,
        algorithm_version: algorithm_version,
        complexity_score: calculate_complexity_score,
        memory_usage: estimate_memory_usage
      }
    end

    protected

    # Abstract methods to be implemented by concrete strategies
    def algorithm_name
      raise NotImplementedError, 'Subclasses must implement algorithm_name'
    end

    def algorithm_version
      '1.0.0'
    end

    def prepare_detection_data
      raise NotImplementedError, 'Subclasses must implement prepare_detection_data'
    end

    def analyze_behavior_patterns
      raise NotImplementedError, 'Subclasses must implement analyze_behavior_patterns'
    end

    def identify_anomalies
      raise NotImplementedError, 'Subclasses must implement identify_anomalies'
    end

    def calculate_confidence_scores
      raise NotImplementedError, 'Subclasses must implement calculate_confidence_scores'
    end

    def generate_detection_result
      raise NotImplementedError, 'Subclasses must implement generate_detection_result'
    end

    # Common utility methods for all strategies

    def validate_input_data(data)
      unless data.is_a?(Hash) && data.key?(:user_id)
        raise ArgumentError, "Invalid input data format for #{algorithm_name}"
      end

      unless data[:behavior_metrics] || data[:historical_patterns]
        raise ArgumentError, "Missing required behavior data for #{algorithm_name}"
      end
    end

    def handle_detection_error(error)
      # Log error with context for debugging and monitoring
      ErrorLogger.log(
        strategy: algorithm_name,
        error: error.class.name,
        message: error.message,
        input_data: @user_behavior_data,
        performance_metrics: performance_metrics
      )

      # Return safe fallback result
      {
        anomalous: false,
        confidence: 0.0,
        error: error.message,
        algorithm: algorithm_name,
        execution_time_ms: performance_metrics[:execution_time_ms]
      }
    end

    def calculate_complexity_score
      # Base complexity calculation - can be overridden by specific strategies
      @user_behavior_data[:behavior_metrics]&.count.to_i
    end

    def estimate_memory_usage
      # Base memory estimation - can be overridden for more accuracy
      1024 * 1024 # 1MB default estimate
    end

    def statistical_analysis
      @statistical_analysis ||= StatisticalAnalysisService.new(@user_behavior_data)
    end

    def pattern_matcher
      @pattern_matcher ||= PatternMatchingService.new
    end

    def risk_assessor
      @risk_assessor ||= RiskAssessmentService.new
    end

    # Common statistical utility methods

    def calculate_z_score(value, mean, standard_deviation)
      return 0.0 if standard_deviation.zero?

      (value - mean) / standard_deviation
    end

    def calculate_standard_deviation(values)
      return 0.0 if values.empty?

      mean = values.sum / values.count.to_f
      variance = values.sum { |v| (v - mean)**2 } / values.count.to_f
      Math.sqrt(variance)
    end

    def calculate_mean(values)
      return 0.0 if values.empty?

      values.sum / values.count.to_f
    end

    def calculate_percentile(values, percentile)
      return 0.0 if values.empty?

      sorted = values.sort
      index = (sorted.count * percentile / 100.0).round
      index = [index, sorted.count - 1].min
      sorted[index]
    end

    # Common pattern analysis utilities

    def detect_temporal_anomalies(time_series_data)
      # Detect anomalies in time-based patterns
      return [] unless time_series_data.is_a?(Array) && time_series_data.count > 5

      anomalies = []
      values = time_series_data.map { |point| point[:value] }

      mean = calculate_mean(values)
      std_dev = calculate_standard_deviation(values)

      time_series_data.each_with_index do |point, index|
        z_score = calculate_z_score(point[:value], mean, std_dev)
        if z_score.abs > 2.5 # 2.5 sigma threshold
          anomalies << {
            timestamp: point[:timestamp],
            value: point[:value],
            z_score: z_score,
            anomaly_type: :temporal
          }
        end
      end

      anomalies
    end

    def detect_frequency_anomalies(frequency_data)
      # Detect anomalies in frequency patterns
      return [] unless frequency_data.is_a?(Hash)

      anomalies = []
      baseline_frequency = frequency_data[:baseline]
      current_frequency = frequency_data[:current]

      return [] unless baseline_frequency && current_frequency

      ratio = current_frequency.to_f / baseline_frequency.to_f

      if ratio > 3.0 || ratio < 0.3 # Significant deviation
        anomalies << {
          baseline_frequency: baseline_frequency,
          current_frequency: current_frequency,
          ratio: ratio,
          anomaly_type: :frequency
        }
      end

      anomalies
    end

    def detect_velocity_anomalies(velocity_data)
      # Detect anomalies in activity velocity
      return [] unless velocity_data.is_a?(Hash)

      anomalies = []
      current_velocity = velocity_data[:current]
      baseline_velocity = velocity_data[:baseline]
      time_window = velocity_data[:time_window] || 3600 # 1 hour default

      return [] unless current_velocity && baseline_velocity

      velocity_ratio = current_velocity.to_f / baseline_velocity.to_f

      # Adaptive threshold based on time window and baseline
      threshold = calculate_velocity_threshold(baseline_velocity, time_window)

      if velocity_ratio > threshold
        anomalies << {
          current_velocity: current_velocity,
          baseline_velocity: baseline_velocity,
          velocity_ratio: velocity_ratio,
          threshold: threshold,
          anomaly_type: :velocity
        }
      end

      anomalies
    end

    def calculate_velocity_threshold(baseline_velocity, time_window)
      # Adaptive threshold calculation based on baseline and time window
      base_threshold = 2.0

      # Lower threshold for higher baseline velocities (more stable)
      stability_multiplier = 1.0 + Math.log(1.0 + baseline_velocity / 100.0)

      # Shorter time windows are more sensitive to bursts
      time_multiplier = Math.log(3600.0 / time_window) + 1.0

      base_threshold * stability_multiplier * time_multiplier
    end

    # Common data validation and sanitization

    def sanitize_numeric_value(value, default = 0.0)
      return default unless value

      case value
      when Numeric then value.to_f
      when String then value.to_f rescue default
      else default
      end
    end

    def sanitize_time_value(time_value)
      case time_value
      when Time then time_value
      when String then Time.parse(time_value) rescue Time.current
      when Integer then Time.at(time_value)
      else Time.current
      end
    end

    def clamp_value(value, min, max)
      [[value, min].max, max].min
    end

    # Common caching and performance optimization

    def cache_result(key, result, ttl = 300) # 5 minute default TTL
      CacheService.set(cache_key(key), result, ttl: ttl)
    end

    def fetch_cached_result(key)
      CacheService.get(cache_key(key))
    end

    def cache_key(base_key)
      "#{algorithm_name}:#{base_key}:#{@user_behavior_data[:user_id]}"
    end

    # Common result formatting

    def format_anomaly_result(anomaly_data)
      {
        algorithm: algorithm_name,
        algorithm_version: algorithm_version,
        detected_at: Time.current,
        anomalous: true,
        anomaly_details: anomaly_data,
        performance_metrics: performance_metrics,
        confidence_score: calculate_overall_confidence(anomaly_data)
      }
    end

    def format_normal_result
      {
        algorithm: algorithm_name,
        algorithm_version: algorithm_version,
        detected_at: Time.current,
        anomalous: false,
        confidence_score: 1.0,
        performance_metrics: performance_metrics
      }
    end

    def calculate_overall_confidence(anomaly_data)
      # Base confidence calculation - can be overridden by specific strategies
      case anomaly_data[:anomaly_type]
      when :temporal then 0.85
      when :frequency then 0.75
      when :velocity then 0.80
      when :spatial then 0.90
      else 0.70
      end
    end
  end
end