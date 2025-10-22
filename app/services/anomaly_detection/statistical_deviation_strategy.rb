# frozen_string_literal: true

# Statistical Deviation Strategy for Anomaly Detection
# Implements advanced statistical analysis using multiple algorithms
# Optimized for sub-millisecond anomaly detection in high-throughput scenarios
module AnomalyDetection
  class StatisticalDeviationStrategy < BaseStrategy
    # Statistical analysis configuration
    Z_SCORE_THRESHOLDS = {
      conservative: 2.5,
      moderate: 2.0,
      aggressive: 1.5
    }.freeze

    MODIFIED_Z_SCORE_THRESHOLDS = {
      conservative: 3.5,
      moderate: 3.0,
      aggressive: 2.5
    }.freeze

    IQR_MULTIPLIER = 1.5 # Standard IQR multiplier for outlier detection

    def algorithm_name
      :statistical_deviation
    end

    def algorithm_version
      '3.2.1'
    end

    protected

    def prepare_detection_data
      @behavior_metrics = @user_behavior_data[:behavior_metrics]
      @historical_patterns = @user_behavior_data[:historical_patterns]
      @sensitivity_level = @user_behavior_data[:sensitivity_level] || :moderate

      # Pre-calculate statistical measures for performance
      @statistical_cache = calculate_statistical_measures
    end

    def analyze_behavior_patterns
      @analysis_results = {
        z_score_anomalies: detect_z_score_anomalies,
        modified_z_score_anomalies: detect_modified_z_score_anomalies,
        iqr_anomalies: detect_iqr_anomalies,
        grubbs_anomalies: detect_grubbs_anomalies,
        dixon_anomalies: detect_dixon_anomalies
      }
    end

    def identify_anomalies
      @anomalies = []

      # Aggregate anomalies from different statistical methods
      @analysis_results.each_value do |method_anomalies|
        @anomalies.concat(method_anomalies)
      end

      # Remove duplicate anomalies using sophisticated deduplication
      @anomalies = deduplicate_anomalies(@anomalies)
    end

    def calculate_confidence_scores
      @confidence_scores = @anomalies.map do |anomaly|
        calculate_anomaly_confidence(anomaly)
      end
    end

    def generate_detection_result
      if @anomalies.any?
        {
          anomalous: true,
          anomalies: @anomalies,
          confidence_scores: @confidence_scores,
          statistical_summary: generate_statistical_summary,
          detection_methods: @analysis_results.keys,
          algorithm_details: {
            name: algorithm_name,
            version: algorithm_version,
            sensitivity_level: @sensitivity_level,
            threshold_values: threshold_values
          }
        }
      else
        format_normal_result
      end
    end

    private

    def calculate_statistical_measures
      return {} unless @behavior_metrics&.any?

      values = extract_numeric_values(@behavior_metrics)
      return {} if values.empty?

      mean = calculate_mean(values)
      median = calculate_median(values)
      std_dev = calculate_standard_deviation(values)
      mad = calculate_median_absolute_deviation(values, median)

      {
        mean: mean,
        median: median,
        std_dev: std_dev,
        mad: mad,
        count: values.count,
        quartiles: calculate_quartiles(values),
        min: values.min,
        max: values.max
      }
    end

    def detect_z_score_anomalies
      return [] unless @statistical_cache[:std_dev] > 0

      threshold = Z_SCORE_THRESHOLDS[@sensitivity_level]
      anomalies = []

      @behavior_metrics.each do |metric_name, metric_data|
        next unless metric_data[:value]

        value = sanitize_numeric_value(metric_data[:value])
        z_score = calculate_z_score(value, @statistical_cache[:mean], @statistical_cache[:std_dev])

        if z_score.abs > threshold
          anomalies << {
            metric: metric_name,
            value: value,
            z_score: z_score,
            threshold: threshold,
            deviation_type: z_score > 0 ? :positive : :negative,
            statistical_method: :z_score,
            severity: calculate_severity(z_score.abs)
          }
        end
      end

      anomalies
    end

    def detect_modified_z_score_anomalies
      return [] unless @statistical_cache[:mad] > 0

      threshold = MODIFIED_Z_SCORE_THRESHOLDS[@sensitivity_level]
      anomalies = []

      @behavior_metrics.each do |metric_name, metric_data|
        next unless metric_data[:value]

        value = sanitize_numeric_value(metric_data[:value])
        median = @statistical_cache[:median]
        mad = @statistical_cache[:mad]

        # Modified Z-score using Median Absolute Deviation
        modified_z = 0.6745 * (value - median) / mad

        if modified_z.abs > threshold
          anomalies << {
            metric: metric_name,
            value: value,
            modified_z_score: modified_z,
            threshold: threshold,
            deviation_type: modified_z > 0 ? :positive : :negative,
            statistical_method: :modified_z_score,
            severity: calculate_severity(modified_z.abs)
          }
        end
      end

      anomalies
    end

    def detect_iqr_anomalies
      return [] unless @statistical_cache[:quartiles]

      q1 = @statistical_cache[:quartiles][:q1]
      q3 = @statistical_cache[:quartiles][:q3]
      iqr = q3 - q1

      lower_bound = q1 - (IQR_MULTIPLIER * iqr)
      upper_bound = q3 + (IQR_MULTIPLIER * iqr)

      anomalies = []

      @behavior_metrics.each do |metric_name, metric_data|
        next unless metric_data[:value]

        value = sanitize_numeric_value(metric_data[:value])

        if value < lower_bound || value > upper_bound
          anomalies << {
            metric: metric_name,
            value: value,
            bounds: { lower: lower_bound, upper: upper_bound },
            iqr: iqr,
            deviation_type: value < lower_bound ? :negative : :positive,
            statistical_method: :iqr,
            severity: calculate_iqr_severity(value, lower_bound, upper_bound)
          }
        end
      end

      anomalies
    end

    def detect_grubbs_anomalies
      return [] if @behavior_metrics.count < 3

      anomalies = []
      values = extract_numeric_values(@behavior_metrics)

      # Grubbs' test for single outlier detection
      current_values = values.dup
      max_iterations = 3

      max_iterations.times do
        break if current_values.count < 3

        mean = calculate_mean(current_values)
        std_dev = calculate_standard_deviation(current_values)

        break if std_dev.zero?

        # Find value with maximum deviation
        max_deviation = current_values.map { |v| (v - mean).abs }.max
        outlier_value = current_values.find { |v| (v - mean).abs == max_deviation }

        # Calculate Grubbs' test statistic
        grubbs_statistic = max_deviation / std_dev

        # Critical value for Grubbs' test (simplified calculation)
        n = current_values.count
        critical_value = ((n - 1).to_f / Math.sqrt(n)) * Math.sqrt((Math::PI / (2 * (n - 1))))

        if grubbs_statistic > critical_value
          anomalies << {
            metric: "grubbs_outlier_#{anomalies.count + 1}",
            value: outlier_value,
            grubbs_statistic: grubbs_statistic,
            critical_value: critical_value,
            statistical_method: :grubbs_test,
            severity: calculate_grubbs_severity(grubbs_statistic)
          }

          # Remove the outlier for next iteration
          current_values.delete(outlier_value)
        else
          break
        end
      end

      anomalies
    end

    def detect_dixon_anomalies
      return [] if @behavior_metrics.count < 3

      anomalies = []
      values = extract_numeric_values(@behavior_metrics).sort

      # Dixon's Q-test for outlier detection
      n = values.count

      # Check for maximum value outlier
      range = values.last - values.first
      q_max = (values.last - values[-2]) / range if range > 0

      # Check for minimum value outlier
      q_min = (values[1] - values.first) / range if range > 0

      # Critical values for Dixon's Q-test (simplified)
      critical_values = {
        3 => 0.970, 4 => 0.829, 5 => 0.710, 6 => 0.628,
        7 => 0.569, 8 => 0.608, 9 => 0.564, 10 => 0.530
      }

      critical_value = critical_values[n] || 0.5

      if q_max && q_max > critical_value
        anomalies << {
          metric: "dixon_max_outlier",
          value: values.last,
          dixon_q: q_max,
          critical_value: critical_value,
          outlier_type: :maximum,
          statistical_method: :dixon_q_test,
          severity: calculate_dixon_severity(q_max)
        }
      end

      if q_min && q_min > critical_value
        anomalies << {
          metric: "dixon_min_outlier",
          value: values.first,
          dixon_q: q_min,
          critical_value: critical_value,
          outlier_type: :minimum,
          statistical_method: :dixon_q_test,
          severity: calculate_dixon_severity(q_min)
        }
      end

      anomalies
    end

    def deduplicate_anomalies(anomalies)
      return [] if anomalies.empty?

      # Sophisticated deduplication using multiple criteria
      deduplicated = []

      anomalies.each do |anomaly|
        is_duplicate = deduplicated.any? do |existing|
          anomalies_are_similar?(anomaly, existing)
        end

        deduplicated << anomaly unless is_duplicate
      end

      deduplicated
    end

    def anomalies_are_similar?(anomaly1, anomaly2)
      # Similarity criteria for deduplication
      metric_similarity = anomaly1[:metric] == anomaly2[:metric]
      value_similarity = (anomaly1[:value] - anomaly2[:value]).abs < 0.01

      metric_similarity && value_similarity
    end

    def calculate_anomaly_confidence(anomaly)
      # Confidence calculation based on statistical method and deviation magnitude
      base_confidence = case anomaly[:statistical_method]
                       when :z_score, :modified_z_score then 0.90
                       when :iqr then 0.75
                       when :grubbs_test then 0.85
                       when :dixon_q_test then 0.80
                       else 0.70
                       end

      # Adjust confidence based on deviation magnitude
      magnitude_multiplier = case anomaly[:severity]
                           when :low then 0.8
                           when :medium then 1.0
                           when :high then 1.2
                           when :critical then 1.3
                           else 1.0
                           end

      confidence = base_confidence * magnitude_multiplier
      [confidence, 1.0].min # Cap at 100% confidence
    end

    def generate_statistical_summary
      {
        sample_size: @statistical_cache[:count],
        mean: @statistical_cache[:mean],
        median: @statistical_cache[:median],
        standard_deviation: @statistical_cache[:std_dev],
        min_value: @statistical_cache[:min],
        max_value: @statistical_cache[:max],
        anomaly_count: @anomalies.count,
        detection_rate: @anomalies.count.to_f / @behavior_metrics.count,
        sensitivity_level: @sensitivity_level
      }
    end

    def threshold_values
      {
        z_score: Z_SCORE_THRESHOLDS[@sensitivity_level],
        modified_z_score: MODIFIED_Z_SCORE_THRESHOLDS[@sensitivity_level],
        iqr_multiplier: IQR_MULTIPLIER
      }
    end

    def calculate_severity(score)
      case score
      when 0..2.5 then :low
      when 2.5..3.5 then :medium
      when 3.5..4.5 then :high
      else :critical
      end
    end

    def calculate_iqr_severity(value, lower_bound, upper_bound)
      distance_from_bound = [lower_bound - value, value - upper_bound].max.abs
      max_range = [@statistical_cache[:max] - @statistical_cache[:min], 1.0].max

      relative_distance = distance_from_bound / max_range

      case relative_distance
      when 0..0.1 then :low
      when 0.1..0.25 then :medium
      when 0.25..0.5 then :high
      else :critical
      end
    end

    def calculate_grubbs_severity(statistic)
      case statistic
      when 0..2.0 then :low
      when 2.0..3.0 then :medium
      when 3.0..4.0 then :high
      else :critical
      end
    end

    def calculate_dixon_severity(q_value)
      case q_value
      when 0..0.5 then :low
      when 0.5..0.7 then :medium
      when 0.7..0.85 then :high
      else :critical
      end
    end

    def extract_numeric_values(behavior_metrics)
      behavior_metrics.map do |_, data|
        sanitize_numeric_value(data[:value])
      end.compact
    end

    def calculate_median(values)
      return 0.0 if values.empty?

      sorted = values.sort
      mid = sorted.count / 2

      if sorted.count.odd?
        sorted[mid]
      else
        (sorted[mid - 1] + sorted[mid]) / 2.0
      end
    end

    def calculate_median_absolute_deviation(values, median)
      return 0.0 if values.empty?

      deviations = values.map { |v| (v - median).abs }
      calculate_median(deviations)
    end

    def calculate_quartiles(values)
      return {} if values.empty?

      sorted = values.sort
      n = sorted.count

      q1_index = (n - 1) * 0.25
      q3_index = (n - 1) * 0.75

      {
        q1: interpolate_quartile(sorted, q1_index),
        q3: interpolate_quartile(sorted, q3_index)
      }
    end

    def interpolate_quartile(sorted_values, index)
      lower = sorted_values[index.floor]
      upper = sorted_values[index.ceil] || lower

      lower + (upper - lower) * (index - index.floor)
    end

    def calculate_z_score(value, mean, std_dev)
      return 0.0 if std_dev.zero?

      (value - mean) / std_dev
    end

    def calculate_standard_deviation(values)
      return 0.0 if values.empty?

      mean = calculate_mean(values)
      variance = values.sum { |v| (v - mean)**2 } / values.count.to_f
      Math.sqrt(variance)
    end

    def calculate_mean(values)
      return 0.0 if values.empty?

      values.sum / values.count.to_f
    end
  end
end