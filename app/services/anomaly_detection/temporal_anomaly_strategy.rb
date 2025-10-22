# frozen_string_literal: true

# Temporal Anomaly Detection Strategy
# Advanced time-series analysis for detecting temporal behavioral anomalies
# Implements circadian rhythm analysis and time-based pattern recognition
module AnomalyDetection
  class TemporalAnomalyStrategy < BaseStrategy
    # Circadian rhythm configuration
    CIRCADIAN_PHASES = {
      sleep: { start_hour: 22, end_hour: 6, weight: 0.8 },
      morning: { start_hour: 6, end_hour: 12, weight: 1.2 },
      afternoon: { start_hour: 12, end_hour: 18, weight: 1.0 },
      evening: { start_hour: 18, end_hour: 22, weight: 1.1 }
    }.freeze

    # Unusual activity time windows (in hours)
    UNUSUAL_HOURS = [2, 3, 4, 5].freeze # 2 AM - 6 AM

    # Time-based anomaly thresholds
    TEMPORAL_THRESHOLDS = {
      rapid_sequence: 5, # minutes between actions
      unusual_hour_penalty: 1.3,
      circadian_disruption_bonus: 1.2,
      historical_deviation_threshold: 2.5 # standard deviations
    }.freeze

    def algorithm_name
      :temporal_anomaly
    end

    def algorithm_version
      '2.1.3'
    end

    protected

    def prepare_detection_data
      @time_series_data = @user_behavior_data[:time_series_data] || []
      @current_time = @user_behavior_data[:current_time] || Time.current
      @historical_patterns = @user_behavior_data[:historical_patterns] || {}

      # Pre-calculate temporal features for performance
      @temporal_features = calculate_temporal_features
    end

    def analyze_behavior_patterns
      @temporal_analysis = {
        circadian_anomalies: detect_circadian_anomalies,
        unusual_timing_anomalies: detect_unusual_timing_anomalies,
        rapid_sequence_anomalies: detect_rapid_sequence_anomalies,
        historical_pattern_anomalies: detect_historical_pattern_anomalies,
        burst_activity_anomalies: detect_burst_activity_anomalies
      }
    end

    def identify_anomalies
      @anomalies = []

      # Aggregate temporal anomalies from different detection methods
      @temporal_analysis.each_value do |method_anomalies|
        @anomalies.concat(method_anomalies)
      end

      # Apply temporal clustering to group related anomalies
      @anomalies = cluster_temporal_anomalies(@anomalies)
    end

    def calculate_confidence_scores
      @confidence_scores = @anomalies.map do |anomaly|
        calculate_temporal_confidence(anomaly)
      end
    end

    def generate_detection_result
      if @anomalies.any?
        {
          anomalous: true,
          anomalies: @anomalies,
          confidence_scores: @confidence_scores,
          temporal_summary: generate_temporal_summary,
          circadian_analysis: @temporal_features[:circadian_analysis],
          algorithm_details: {
            name: algorithm_name,
            version: algorithm_version,
            current_phase: current_circadian_phase,
            temporal_features: @temporal_features
          }
        }
      else
        format_normal_result
      end
    end

    private

    def calculate_temporal_features
      features = {}

      # Current circadian phase analysis
      features[:current_circadian_phase] = current_circadian_phase
      features[:current_phase_weight] = circadian_phase_weight(@current_time.hour)

      # Historical activity patterns
      features[:hourly_patterns] = calculate_hourly_patterns
      features[:daily_patterns] = calculate_daily_patterns
      features[:weekly_patterns] = calculate_weekly_patterns

      # Activity intensity metrics
      features[:activity_intensity] = calculate_activity_intensity
      features[:temporal_variance] = calculate_temporal_variance

      # Circadian rhythm stability
      features[:circadian_stability] = calculate_circadian_stability

      features
    end

    def detect_circadian_anomalies
      anomalies = []
      current_phase = current_circadian_phase

      # Check if current activity is unusual for this circadian phase
      phase_activity = @historical_patterns[current_phase] || {}
      expected_activity = phase_activity[:expected_frequency] || 0
      current_activity_level = calculate_current_activity_level

      if current_activity_level > expected_activity * 2.0
        anomalies << {
          anomaly_type: :circadian_disruption,
          circadian_phase: current_phase,
          expected_activity: expected_activity,
          current_activity: current_activity_level,
          disruption_ratio: current_activity_level / expected_activity,
          temporal_context: {
            hour: @current_time.hour,
            day_of_week: @current_time.wday,
            is_weekend: weekend?(current_phase)
          }
        }
      end

      anomalies
    end

    def detect_unusual_timing_anomalies
      anomalies = []

      if UNUSUAL_HOURS.include?(@current_time.hour)
        # Activity during unusual hours
        activity_during_unusual_hours = @time_series_data
          .select { |event| UNUSUAL_HOURS.include?(event[:timestamp].hour) }
          .count

        if activity_during_unusual_hours > 0
          anomalies << {
            anomaly_type: :unusual_timing,
            unusual_hour: @current_time.hour,
            activity_count: activity_during_unusual_hours,
            historical_unusual_activity: calculate_historical_unusual_activity,
            penalty_multiplier: TEMPORAL_THRESHOLDS[:unusual_hour_penalty]
          }
        end
      end

      anomalies
    end

    def detect_rapid_sequence_anomalies
      anomalies = []

      # Sort time series data by timestamp
      sorted_events = @time_series_data.sort_by { |event| event[:timestamp] }

      # Find rapid sequences (events within threshold minutes)
      rapid_sequences = find_rapid_sequences(sorted_events)

      rapid_sequences.each do |sequence|
        anomalies << {
          anomaly_type: :rapid_sequence,
          sequence_duration: sequence[:duration_minutes],
          event_count: sequence[:event_count],
          average_interval: sequence[:average_interval],
          events: sequence[:events].map { |e| e[:id] }
        }
      end

      anomalies
    end

    def detect_historical_pattern_anomalies
      anomalies = []
      current_hour = @current_time.hour

      # Compare current activity with historical patterns for this hour
      historical_hourly = @historical_patterns[:hourly] || {}
      current_hour_pattern = historical_hourly[current_hour] || {}

      expected_frequency = current_hour_pattern[:mean_frequency] || 0
      expected_std_dev = current_hour_pattern[:std_dev_frequency] || 1

      current_activity = calculate_current_hour_activity

      # Z-score analysis for this specific hour
      z_score = (current_activity - expected_frequency) / expected_std_dev

      if z_score.abs > TEMPORAL_THRESHOLDS[:historical_deviation_threshold]
        anomalies << {
          anomaly_type: :historical_pattern_deviation,
          hour: current_hour,
          current_activity: current_activity,
          expected_activity: expected_frequency,
          z_score: z_score,
          deviation_type: z_score > 0 ? :above_normal : :below_normal,
          historical_sample_size: current_hour_pattern[:sample_size] || 0
        }
      end

      anomalies
    end

    def detect_burst_activity_anomalies
      anomalies = []

      # Detect activity bursts using sliding window analysis
      burst_windows = find_activity_bursts

      burst_windows.each do |burst|
        anomalies << {
          anomaly_type: :activity_burst,
          burst_duration: burst[:duration_minutes],
          event_count: burst[:event_count],
          burst_intensity: burst[:intensity],
          time_window: burst[:window_start]..burst[:window_end]
        }
      end

      anomalies
    end

    def cluster_temporal_anomalies(anomalies)
      return [] if anomalies.empty?

      # Group anomalies that are temporally related (within 1 hour)
      clustered = []
      used_indices = Set.new

      anomalies.each_with_index do |anomaly, index|
        next if used_indices.include?(index)

        cluster = [anomaly]
        used_indices.add(index)

        # Find related anomalies within temporal proximity
        anomalies.each_with_index do |other_anomaly, other_index|
          next if used_indices.include?(other_index) || index == other_index

          if temporally_related?(anomaly, other_anomaly)
            cluster << other_anomaly
            used_indices.add(other_index)
          end
        end

        # Merge cluster into single representative anomaly if multiple
        if cluster.count > 1
          clustered << merge_anomaly_cluster(cluster)
        else
          clustered << anomaly
        end
      end

      clustered
    end

    def calculate_temporal_confidence(anomaly)
      base_confidence = case anomaly[:anomaly_type]
                       when :circadian_disruption then 0.85
                       when :unusual_timing then 0.80
                       when :rapid_sequence then 0.75
                       when :historical_pattern_deviation then 0.90
                       when :activity_burst then 0.70
                       else 0.65
                       end

      # Adjust based on temporal evidence strength
      evidence_multiplier = calculate_evidence_strength(anomaly)
      sample_size_bonus = calculate_sample_size_bonus(anomaly)

      confidence = base_confidence * evidence_multiplier * sample_size_bonus
      [confidence, 1.0].min
    end

    def generate_temporal_summary
      {
        analysis_window: calculate_analysis_window,
        total_events: @time_series_data.count,
        anomaly_count: @anomalies.count,
        circadian_compliance: calculate_circadian_compliance,
        temporal_stability: @temporal_features[:circadian_stability],
        unusual_activity_ratio: calculate_unusual_activity_ratio
      }
    end

    # Helper methods for temporal calculations

    def current_circadian_phase
      hour = @current_time.hour

      case hour
      when 6..11 then :morning
      when 12..17 then :afternoon
      when 18..21 then :evening
      when 22..23, 0..5 then :sleep
      else :sleep
      end
    end

    def circadian_phase_weight(hour)
      CIRCADIAN_PHASES.each do |phase, config|
        if hour >= config[:start_hour] && hour <= config[:end_hour]
          return config[:weight]
        end
      end

      1.0 # Default weight
    end

    def calculate_hourly_patterns
      patterns = Hash.new { |h, k| h[k] = { count: 0, total_value: 0.0 } }

      @time_series_data.each do |event|
        hour = event[:timestamp].hour
        patterns[hour][:count] += 1
        patterns[hour][:total_value] += event[:value].to_f
      end

      # Convert to statistical measures
      patterns.each do |hour, data|
        if data[:count] > 0
          data[:mean_value] = data[:total_value] / data[:count]
          data[:frequency] = data[:count]
        end
      end

      patterns
    end

    def calculate_daily_patterns
      daily_activity = @time_series_data.group_by do |event|
        event[:timestamp].to_date
      end

      daily_activity.transform_values do |events|
        {
          count: events.count,
          total_value: events.sum { |e| e[:value].to_f },
          mean_value: events.sum { |e| e[:value].to_f } / events.count
        }
      end
    end

    def calculate_weekly_patterns
      weekly_activity = @time_series_data.group_by do |event|
        event[:timestamp].wday
      end

      weekly_activity.transform_values do |events|
        {
          count: events.count,
          mean_value: events.sum { |e| e[:value].to_f } / events.count,
          day_name: Date::DAYNAMES[events.first[:timestamp].wday]
        }
      end
    end

    def calculate_current_activity_level
      # Calculate activity level for current circadian phase
      phase_start_hour = CIRCADIAN_PHASES[current_circadian_phase][:start_hour]
      phase_end_hour = CIRCADIAN_PHASES[current_circadian_phase][:end_hour]

      phase_events = @time_series_data.select do |event|
        event_hour = event[:timestamp].hour
        event_hour >= phase_start_hour && event_hour <= phase_end_hour
      end

      phase_events.count
    end

    def calculate_current_hour_activity
      current_hour_events = @time_series_data.select do |event|
        event[:timestamp].hour == @current_time.hour
      end

      current_hour_events.count
    end

    def find_rapid_sequences(sorted_events)
      rapid_sequences = []
      return rapid_sequences if sorted_events.count < 2

      current_sequence = [sorted_events.first]
      threshold_minutes = TEMPORAL_THRESHOLDS[:rapid_sequence]

      sorted_events[1..-1].each do |event|
        time_diff = (event[:timestamp] - current_sequence.last[:timestamp]) / 60.0 # minutes

        if time_diff <= threshold_minutes
          current_sequence << event
        else
          # Check if current sequence qualifies as rapid
          if current_sequence.count >= 3
            rapid_sequences << build_rapid_sequence_info(current_sequence)
          end

          # Start new sequence
          current_sequence = [event]
        end
      end

      # Check final sequence
      if current_sequence.count >= 3
        rapid_sequences << build_rapid_sequence_info(current_sequence)
      end

      rapid_sequences
    end

    def build_rapid_sequence_info(sequence)
      duration = (sequence.last[:timestamp] - sequence.first[:timestamp]) / 60.0
      event_count = sequence.count
      intervals = sequence.each_cons(2).map do |e1, e2|
        (e2[:timestamp] - e1[:timestamp]) / 60.0
      end

      {
        duration_minutes: duration,
        event_count: event_count,
        average_interval: intervals.sum / intervals.count,
        events: sequence
      }
    end

    def find_activity_bursts
      bursts = []
      return bursts if @time_series_data.count < 5

      # Use sliding window approach to find activity bursts
      window_size = 30 # minutes
      min_burst_events = 10

      sorted_events = @time_series_data.sort_by { |e| e[:timestamp] }

      (0..(sorted_events.count - min_burst_events)).each do |start_idx|
        window_events = []
        window_start = sorted_events[start_idx][:timestamp]

        # Collect events within window
        sorted_events[start_idx..-1].each do |event|
          break if (event[:timestamp] - window_start) > (window_size * 60)

          window_events << event
        end

        next if window_events.count < min_burst_events

        # Calculate burst intensity
        intensity = window_events.count.to_f / window_size

        if intensity > 0.5 # Threshold for burst detection
          bursts << {
            window_start: window_start,
            window_end: window_start + (window_size * 60),
            duration_minutes: window_size,
            event_count: window_events.count,
            intensity: intensity,
            events: window_events
          }
        end
      end

      bursts
    end

    def temporally_related?(anomaly1, anomaly2)
      # Check if anomalies are within 1 hour of each other
      time1 = extract_anomaly_time(anomaly1)
      time2 = extract_anomaly_time(anomaly2)

      return false unless time1 && time2

      (time1 - time2).abs < 3600 # 1 hour
    end

    def extract_anomaly_time(anomaly)
      # Extract timestamp from different anomaly types
      case anomaly[:anomaly_type]
      when :rapid_sequence
        anomaly[:events]&.first&.dig(:timestamp)
      when :activity_burst
        anomaly[:time_window]&.begin
      else
        @current_time
      end
    end

    def merge_anomaly_cluster(cluster)
      # Merge multiple related anomalies into single representative
      primary_anomaly = cluster.first
      merged_events = cluster.flat_map { |a| a[:events] || [] }.uniq

      {
        anomaly_type: :temporal_cluster,
        cluster_size: cluster.count,
        constituent_anomalies: cluster.map { |a| a[:anomaly_type] },
        merged_events: merged_events,
        time_range: calculate_cluster_time_range(cluster),
        combined_confidence: cluster.map { |a| calculate_temporal_confidence(a) }.sum / cluster.count
      }
    end

    def calculate_cluster_time_range(cluster)
      all_times = cluster.flat_map do |anomaly|
        case anomaly[:anomaly_type]
        when :rapid_sequence
          anomaly[:events]&.map { |e| e[:timestamp] } || []
        when :activity_burst
          [anomaly[:time_window]&.begin, anomaly[:time_window]&.end].compact
        else
          [@current_time]
        end
      end

      return nil if all_times.empty?

      min_time = all_times.min
      max_time = all_times.max

      min_time..max_time
    end

    def calculate_evidence_strength(anomaly)
      case anomaly[:anomaly_type]
      when :circadian_disruption
        anomaly[:disruption_ratio] || 1.0
      when :historical_pattern_deviation
        1.0 / (1.0 + anomaly[:z_score].abs)
      when :rapid_sequence
        1.0 / (1.0 + anomaly[:average_interval])
      else
        1.0
      end
    end

    def calculate_sample_size_bonus(anomaly)
      # Bonus for larger sample sizes in historical data
      sample_size = case anomaly[:anomaly_type]
                   when :historical_pattern_deviation
                     anomaly[:historical_sample_size] || 0
                   when :circadian_disruption
                     @historical_patterns.dig(current_circadian_phase, :sample_size) || 0
                   else
                     0
                   end

      # Diminishing returns formula for sample size bonus
      1.0 + (Math.log(1.0 + sample_size) / Math.log(100.0)) * 0.2
    end

    def calculate_analysis_window
      return nil if @time_series_data.empty?

      first_event = @time_series_data.min_by { |e| e[:timestamp] }
      last_event = @time_series_data.max_by { |e| e[:timestamp] }

      {
        start_time: first_event[:timestamp],
        end_time: last_event[:timestamp],
        duration_hours: (last_event[:timestamp] - first_event[:timestamp]) / 3600.0
      }
    end

    def calculate_circadian_compliance
      current_phase = current_circadian_phase
      expected_activity = @historical_patterns.dig(current_phase, :expected_frequency) || 0
      current_activity = calculate_current_activity_level

      return 1.0 if expected_activity.zero?

      compliance_ratio = current_activity / expected_activity
      [compliance_ratio, 2.0].min / 2.0 # Normalize to 0-1 scale, cap at 2x expected
    end

    def calculate_unusual_activity_ratio
      unusual_events = @time_series_data.count do |event|
        UNUSUAL_HOURS.include?(event[:timestamp].hour)
      end

      unusual_events.to_f / @time_series_data.count
    end

    def calculate_activity_intensity
      return 0.0 if @time_series_data.empty?

      # Calculate events per hour rate
      analysis_duration = calculate_analysis_window[:duration_hours] || 24.0
      @time_series_data.count.to_f / analysis_duration
    end

    def calculate_temporal_variance
      return 0.0 if @time_series_data.count < 2

      # Calculate variance in inter-event times
      sorted_events = @time_series_data.sort_by { |e| e[:timestamp] }

      intervals = sorted_events.each_cons(2).map do |e1, e2|
        (e2[:timestamp] - e1[:timestamp]) / 60.0 # minutes
      end

      return 0.0 if intervals.empty?

      mean_interval = intervals.sum / intervals.count
      variance = intervals.sum { |interval| (interval - mean_interval)**2 } / intervals.count

      Math.sqrt(variance) # Return standard deviation
    end

    def calculate_circadian_stability
      # Measure how consistent activity patterns are across circadian phases
      phase_activities = CIRCADIAN_PHASES.keys.map do |phase|
        @historical_patterns[phase] || {}
      end

      activities = phase_activities.map { |p| p[:expected_frequency] || 0 }

      return 0.0 if activities.empty? || activities.max.zero?

      # Coefficient of variation
      mean_activity = activities.sum / activities.count.to_f
      variance = activities.sum { |a| (a - mean_activity)**2 } / activities.count

      1.0 - [Math.sqrt(variance) / mean_activity, 1.0].min
    end

    def calculate_historical_unusual_activity
      # Calculate historical activity during unusual hours
      historical_unusual = @historical_patterns[:unusual_hours] || {}

      historical_unusual[:total_events] || 0
    end

    def weekend?(day_of_week)
      day_of_week == 0 || day_of_week == 6 # Sunday or Saturday
    end
  end
end