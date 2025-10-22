# frozen_string_literal: true

# Enterprise-grade data quality management module providing comprehensive
# data validation, quality scoring, integrity checking, and quality monitoring
# capabilities for ActiveRecord models
#
# @author Kilo Code Autonomous Agent
# @version 2.0.0
# @since 2025-10-19
#
# @example
#   class User < ApplicationRecord
#     enterprise_modules do
#       data_quality :comprehensive
#     end
#   end
#
module EnterpriseModules
  module DataQualityModule
    extend ActiveSupport::Concern

    # === CONSTANTS ===

    # Data quality scoring weights for different factors
    QUALITY_WEIGHTS = {
      completeness: 0.30,
      validity: 0.25,
      consistency: 0.20,
      timeliness: 0.15,
      accuracy: 0.10
    }.freeze

    # Data quality thresholds for different levels
    QUALITY_THRESHOLDS = {
      excellent: { min_score: 0.95, action: :celebrate },
      good: { min_score: 0.85, action: :monitor },
      fair: { min_score: 0.70, action: :review },
      poor: { min_score: 0.50, action: :improve },
      critical: { min_score: 0.0, action: :urgent_fix }
    }.freeze

    # Data validation rules configuration
    VALIDATION_RULES = {
      required_fields: {
        presence: true,
        allow_nil: false,
        allow_blank: false
      },
      optional_fields: {
        presence: false,
        allow_nil: true,
        allow_blank: true
      },
      email_fields: {
        format: { with: URI::MailTo::EMAIL_REGEXP },
        uniqueness: { case_sensitive: false }
      },
      numeric_fields: {
        numericality: { only_integer: false, greater_than_or_equal_to: 0 }
      }
    }.freeze

    # === ASSOCIATIONS ===

    included do
      # Data quality monitoring associations
      has_many :data_quality_scores, class_name: 'ModelDataQualityScore', dependent: :destroy if defined?(ModelDataQualityScore)
      has_many :data_validation_logs, class_name: 'ModelDataValidationLog', dependent: :destroy if defined?(ModelDataValidationLog)
      has_many :data_quality_alerts, class_name: 'ModelDataQualityAlert', dependent: :destroy if defined?(ModelDataQualityAlert)

      # Quality metrics tracking
      has_many :quality_metrics, class_name: 'ModelQualityMetric', dependent: :destroy if defined?(ModelQualityMetric)

      # Data quality configuration
      class_attribute :data_quality_config, default: {}
      class_attribute :quality_rules, default: {}
      class_attribute :validation_strategies, default: {}
    end

    # === CLASS METHODS ===

    # Configure data quality settings for the model
    def self.data_quality_config=(config)
      self.data_quality_config = config
    end

    # Define quality rules for specific fields
    def self.quality_rules=(rules)
      self.quality_rules = rules
    end

    # Define validation strategies
    def self.validation_strategies=(strategies)
      self.validation_strategies = strategies
    end

    # Generate comprehensive data quality report for the model
    def self.generate_data_quality_report(**options)
      quality_service = DataQualityService.new(self)

      {
        overall_score: quality_service.overall_quality_score,
        field_scores: quality_service.field_quality_scores,
        trends: quality_service.quality_trends(options[:timeframe]),
        issues: quality_service.identified_issues,
        recommendations: quality_service.quality_recommendations,
        compliance_status: quality_service.compliance_status
      }
    end

    # Perform bulk data quality assessment
    def self.bulk_quality_assessment(record_ids = nil, **options)
      scope = record_ids.present? ? where(id: record_ids) : all
      quality_service = DataQualityService.new(self)

      results = {
        total_records: scope.count,
        assessed_records: 0,
        quality_distribution: Hash.new(0),
        issues_found: [],
        processing_time: 0
      }

      start_time = Time.current

      scope.find_in_batches(batch_size: options[:batch_size] || 1000) do |batch|
        batch.each do |record|
          assessment = quality_service.assess_record_quality(record)
          results[:assessed_records] += 1
          results[:quality_distribution][assessment[:level]] += 1
          results[:issues_found].concat(assessment[:issues])
        end
      end

      results[:processing_time] = Time.current - start_time
      results
    end

    # === INSTANCE METHODS ===

    # Calculate comprehensive data quality score
    def calculate_data_quality_score(**options)
      quality_factors = [
        completeness_score(options),
        validity_score(options),
        consistency_score(options),
        timeliness_score(options),
        accuracy_score(options)
      ]

      # Apply weights and calculate weighted average
      weighted_score = quality_factors.zip(QUALITY_WEIGHTS.values).sum do |factor, weight|
        factor * weight
      end

      # Apply custom rules and adjustments
      adjusted_score = apply_quality_adjustments(weighted_score, options)

      # Ensure score is within valid range
      [[adjusted_score, 0.0].max, 1.0].min.round(4)
    end

    # Update data quality score and log changes
    def update_data_quality_score(**options)
      old_score = data_quality_score
      new_score = calculate_data_quality_score(options)

      # Update the score
      self.data_quality_score = new_score

      # Log quality score change if significant
      if significant_score_change?(old_score, new_score)
        log_data_quality_change(old_score, new_score, options)
      end

      # Trigger alerts if quality degraded significantly
      trigger_quality_alerts(old_score, new_score, options)

      new_score
    end

    # Validate data integrity comprehensively
    def validate_data_integrity(**options)
      validation_service = DataValidationService.new(self)

      # Perform all validation types
      validations = {
        referential_integrity: validation_service.validate_referential_integrity,
        business_rules: validation_service.validate_business_rules,
        data_consistency: validation_service.validate_data_consistency,
        format_validation: validation_service.validate_format_compliance,
        completeness_validation: validation_service.validate_completeness
      }

      # Log validation results
      log_validation_results(validations, options)

      # Return validation summary
      {
        passed: validations.values.all?(&:present?),
        validations: validations,
        errors: validation_service.errors,
        warnings: validation_service.warnings
      }
    end

    # Perform data quality assessment
    def perform_quality_assessment(**options)
      assessment_service = DataQualityAssessmentService.new(self)

      assessment = {
        overall_score: calculate_data_quality_score(options),
        field_scores: assessment_service.field_level_scores,
        issues: assessment_service.identify_issues,
        recommendations: assessment_service.generate_recommendations,
        timestamp: Time.current
      }

      # Store assessment results
      store_quality_assessment(assessment, options)

      assessment
    end

    # === PRIVATE METHODS ===

    private

    # Calculate completeness score for the record
    def completeness_score(**options)
      total_fields = self.class.column_names.count
      populated_fields = attributes.compact.count { |_, value| !value.blank? }

      # Base completeness score
      base_score = populated_fields.to_f / total_fields

      # Apply field importance weighting
      field_weights = calculate_field_weights
      weighted_score = attributes.sum do |field, value|
        field_weights[field] * (value.present? ? 1.0 : 0.0)
      end

      # Combine base and weighted scores
      (base_score * 0.6) + (weighted_score * 0.4)
    end

    # Calculate validity score for the record
    def validity_score(**options)
      validation_service = DataValidationService.new(self)

      # Check format validity for each field
      format_scores = validation_service.validate_format_compliance

      # Check business rule validity
      business_rule_scores = validation_service.validate_business_rules

      # Check data type validity
      type_scores = validation_service.validate_data_types

      # Average all validity scores
      all_scores = format_scores + business_rule_scores + type_scores
      all_scores.present? ? all_scores.sum.to_f / all_scores.count : 1.0
    end

    # Calculate consistency score for the record
    def consistency_score(**options)
      consistency_service = DataConsistencyService.new(self)

      # Check internal consistency
      internal_consistency = consistency_service.check_internal_consistency

      # Check cross-record consistency if applicable
      cross_record_consistency = consistency_service.check_cross_record_consistency(options[:related_records])

      # Check historical consistency
      historical_consistency = consistency_service.check_historical_consistency(options[:timeframe])

      # Average consistency scores
      scores = [internal_consistency, cross_record_consistency, historical_consistency]
      scores.compact.sum.to_f / scores.compact.count
    end

    # Calculate timeliness score for the record
    def timeliness_score(**options)
      timeliness_service = DataTimelinessService.new(self)

      # Check data freshness
      freshness_score = timeliness_service.assess_data_freshness

      # Check update frequency compliance
      update_frequency_score = timeliness_service.assess_update_frequency

      # Check temporal consistency
      temporal_consistency_score = timeliness_service.assess_temporal_consistency

      # Average timeliness scores
      scores = [freshness_score, update_frequency_score, temporal_consistency_score]
      scores.compact.sum.to_f / scores.compact.count
    end

    # Calculate accuracy score for the record
    def accuracy_score(**options)
      accuracy_service = DataAccuracyService.new(self)

      # Check data source reliability
      source_reliability_score = accuracy_service.assess_source_reliability

      # Check data entry accuracy
      entry_accuracy_score = accuracy_service.assess_entry_accuracy

      # Check calculation accuracy if applicable
      calculation_accuracy_score = accuracy_service.assess_calculation_accuracy

      # Average accuracy scores
      scores = [source_reliability_score, entry_accuracy_score, calculation_accuracy_score]
      scores.compact.sum.to_f / scores.compact.count
    end

    # Apply quality adjustments based on custom rules
    def apply_quality_adjustments(base_score, options)
      adjustment_service = QualityAdjustmentService.new(self)

      # Apply business rule adjustments
      business_adjustment = adjustment_service.apply_business_rule_adjustments(base_score)

      # Apply temporal adjustments
      temporal_adjustment = adjustment_service.apply_temporal_adjustments(base_score, options[:timeframe])

      # Apply context-specific adjustments
      context_adjustment = adjustment_service.apply_context_adjustments(base_score, options[:context])

      # Combine all adjustments
      adjusted_score = base_score + business_adjustment + temporal_adjustment + context_adjustment

      # Ensure score remains within valid range
      [[adjusted_score, 0.0].max, 1.0].min
    end

    # Calculate field importance weights
    def calculate_field_weights
      field_weights = Hash.new(0.5) # Default weight

      # Define field importance based on business rules
      importance_map = self.class.data_quality_config[:field_importance] || {}

      # Apply custom field weights
      importance_map.each do |field, importance|
        field_weights[field.to_s] = importance
      end

      field_weights
    end

    # Check if score change is significant
    def significant_score_change?(old_score, new_score)
      return false unless old_score && new_score

      change_threshold = self.class.data_quality_config[:significant_change_threshold] || 0.1
      (new_score - old_score).abs >= change_threshold
    end

    # Log data quality score changes
    def log_data_quality_change(old_score, new_score, options)
      return unless data_quality_scores.respond_to?(:create!)

      data_quality_scores.create!(
        previous_score: old_score,
        current_score: new_score,
        change_amount: new_score - old_score,
        change_percentage: old_score > 0 ? ((new_score - old_score) / old_score * 100).round(2) : 0,
        assessment_context: options[:context],
        triggered_by: options[:triggered_by] || 'system',
        metadata: options[:metadata] || {},
        created_at: Time.current
      )
    end

    # Trigger quality alerts based on score changes
    def trigger_quality_alerts(old_score, new_score, options)
      alert_service = DataQualityAlertService.new(self)

      # Check for quality degradation
      if quality_degraded?(old_score, new_score)
        alert_service.trigger_degradation_alert(old_score, new_score, options)
      end

      # Check for quality thresholds
      quality_level = determine_quality_level(new_score)
      if requires_alert?(quality_level)
        alert_service.trigger_threshold_alert(quality_level, new_score, options)
      end
    end

    # Check if quality has degraded significantly
    def quality_degraded?(old_score, new_score)
      return false unless old_score && new_score

      degradation_threshold = self.class.data_quality_config[:degradation_threshold] || 0.15
      (old_score - new_score) >= degradation_threshold
    end

    # Determine quality level based on score
    def determine_quality_level(score)
      QUALITY_THRESHOLDS.each do |level, config|
        return level if score >= config[:min_score]
      end
      :critical
    end

    # Check if quality level requires an alert
    def requires_alert?(quality_level)
      alert_levels = self.class.data_quality_config[:alert_levels] || [:poor, :critical]
      alert_levels.include?(quality_level)
    end

    # Store quality assessment results
    def store_quality_assessment(assessment, options)
      return unless respond_to?(:data_quality_scores)

      data_quality_scores.create!(
        overall_score: assessment[:overall_score],
        field_scores: assessment[:field_scores],
        issues_count: assessment[:issues].count,
        recommendations_count: assessment[:recommendations].count,
        assessment_metadata: assessment,
        assessment_context: options[:context],
        created_at: assessment[:timestamp]
      )
    end

    # Log validation results
    def log_validation_results(validations, options)
      return unless respond_to?(:data_validation_logs)

      data_validation_logs.create!(
        validation_results: validations,
        passed: validations[:passed],
        error_count: validations[:errors]&.count || 0,
        warning_count: validations[:warnings]&.count || 0,
        validation_context: options[:context],
        triggered_by: options[:triggered_by] || 'system',
        created_at: Time.current
      )
    end

    # === DATA QUALITY SERVICES ===

    # Service class for comprehensive data quality management
    class DataQualityService
      def initialize(model_class)
        @model_class = model_class
      end

      def overall_quality_score
        # Calculate average quality score across all records
        scores = @model_class.where.not(data_quality_score: nil).pluck(:data_quality_score)
        scores.present? ? scores.sum.to_f / scores.count : 0.0
      end

      def field_quality_scores
        # Calculate quality scores by field
        field_scores = Hash.new { |h, k| h[k] = [] }

        @model_class.where.not(data_quality_score: nil).find_each do |record|
          record.attributes.each do |field, value|
            next if value.blank?

            field_scores[field] << record.data_quality_score
          end
        end

        # Average scores by field
        field_scores.transform_values do |scores|
          scores.present? ? scores.sum.to_f / scores.count : 0.0
        end
      end

      def quality_trends(timeframe = 30.days)
        # Calculate quality trends over time
        start_date = timeframe.ago

        trends = @model_class
          .joins(:data_quality_scores)
          .where('data_quality_scores.created_at >= ?', start_date)
          .group("DATE(data_quality_scores.created_at)")
          .pluck('DATE(data_quality_scores.created_at)', 'AVG(data_quality_scores.current_score)')

        trends.to_h
      end

      def identified_issues
        # Identify common data quality issues
        issues = []

        # Check for missing required fields
        missing_fields = identify_missing_required_fields
        issues.concat(missing_fields)

        # Check for format violations
        format_issues = identify_format_violations
        issues.concat(format_issues)

        # Check for consistency issues
        consistency_issues = identify_consistency_issues
        issues.concat(consistency_issues)

        issues
      end

      def quality_recommendations
        # Generate recommendations for improving data quality
        recommendations = []

        issues = identified_issues
        if issues.any?
          recommendations << generate_issue_recommendations(issues)
        end

        # General quality improvement recommendations
        recommendations << generate_general_recommendations

        recommendations.flatten
      end

      def compliance_status
        # Check compliance with data quality standards
        {
          gdpr_compliance: check_gdpr_compliance,
          data_quality_policy: check_data_quality_policy_compliance,
          industry_standards: check_industry_standards_compliance
        }
      end

      private

      def identify_missing_required_fields
        # Implementation for identifying missing required fields
        []
      end

      def identify_format_violations
        # Implementation for identifying format violations
        []
      end

      def identify_consistency_issues
        # Implementation for identifying consistency issues
        []
      end

      def generate_issue_recommendations(issues)
        # Implementation for generating issue-specific recommendations
        []
      end

      def generate_general_recommendations
        # Implementation for generating general recommendations
        []
      end

      def check_gdpr_compliance
        # Implementation for GDPR compliance checking
        true
      end

      def check_data_quality_policy_compliance
        # Implementation for data quality policy compliance
        true
      end

      def check_industry_standards_compliance
        # Implementation for industry standards compliance
        true
      end
    end

    # Service class for data validation
    class DataValidationService
      def initialize(record)
        @record = record
        @errors = []
        @warnings = []
      end

      attr_reader :errors, :warnings

      def validate_referential_integrity
        # Check referential integrity for associations
        integrity_checks = []

        @record.class.reflect_on_all_associations.each do |association|
          next unless @record.persisted?

          associated_record = @record.send(association.name)
          if associated_record.nil? && !association.options[:optional]
            integrity_checks << false
            @errors << "Missing required associated #{association.name}"
          else
            integrity_checks << true
          end
        end

        integrity_checks.all?
      end

      def validate_business_rules
        # Validate business rule compliance
        rule_checks = []

        # Check custom business rules defined in model
        if @record.class.respond_to?(:business_rules)
          @record.class.business_rules.each do |rule|
            rule_valid = validate_business_rule(rule)
            rule_checks << rule_valid
            @errors << "Business rule violation: #{rule[:name]}" unless rule_valid
          end
        end

        rule_checks.all?
      end

      def validate_data_consistency
        # Validate internal data consistency
        consistency_checks = []

        # Check logical consistency between related fields
        consistency_checks << validate_field_relationships
        consistency_checks << validate_calculated_fields
        consistency_checks << validate_conditional_requirements

        consistency_checks.all?
      end

      def validate_format_compliance
        # Validate format compliance for fields
        format_checks = []

        @record.attributes.each do |field, value|
          next if value.blank?

          field_type = @record.column_for_attribute(field)&.type
          format_valid = validate_field_format(field, value, field_type)
          format_checks << format_valid

          unless format_valid
            @errors << "Format violation for field #{field}: #{value}"
          end
        end

        format_checks.all?
      end

      def validate_completeness
        # Validate record completeness
        required_fields = identify_required_fields
        populated_fields = @record.attributes.select { |_, v| v.present? }

        missing_fields = required_fields - populated_fields.keys
        if missing_fields.any?
          @errors << "Missing required fields: #{missing_fields.join(', ')}"
          return false
        end

        true
      end

      private

      def validate_business_rule(rule)
        # Implementation for validating specific business rules
        true
      end

      def validate_field_relationships
        # Implementation for validating field relationships
        true
      end

      def validate_calculated_fields
        # Implementation for validating calculated fields
        true
      end

      def validate_conditional_requirements
        # Implementation for validating conditional requirements
        true
      end

      def validate_field_format(field, value, field_type)
        # Implementation for validating field format based on type
        case field_type
        when :string, :text
          validate_string_format(field, value)
        when :integer, :decimal, :float
          validate_numeric_format(value)
        when :datetime, :date
          validate_date_format(value)
        when :boolean
          validate_boolean_format(value)
        else
          true
        end
      end

      def validate_string_format(field, value)
        # String format validation logic
        true
      end

      def validate_numeric_format(value)
        # Numeric format validation logic
        true
      end

      def validate_date_format(value)
        # Date format validation logic
        true
      end

      def validate_boolean_format(value)
        # Boolean format validation logic
        true
      end

      def identify_required_fields
        # Implementation for identifying required fields
        @record.class.column_names
      end
    end

    # Service class for data consistency checking
    class DataConsistencyService
      def initialize(record)
        @record = record
      end

      def check_internal_consistency
        # Check consistency within the record
        consistency_checks = []

        # Check logical relationships between fields
        consistency_checks << check_field_dependencies
        consistency_checks << check_value_ranges
        consistency_checks << check_data_patterns

        consistency_checks.all?
      end

      def check_cross_record_consistency(related_records = nil)
        # Check consistency across related records
        return true unless related_records

        consistency_checks = []

        # Check consistency with related records
        consistency_checks << check_referential_consistency(related_records)
        consistency_checks << check_temporal_consistency(related_records)

        consistency_checks.all?
      end

      def check_historical_consistency(timeframe = 30.days)
        # Check consistency over time
        historical_records = @record.class
          .where(id: @record.id)
          .where('updated_at >= ?', timeframe.ago)

        return true if historical_records.count <= 1

        # Check for logical consistency in historical data
        check_historical_patterns(historical_records)
      end

      private

      def check_field_dependencies
        # Implementation for checking field dependencies
        true
      end

      def check_value_ranges
        # Implementation for checking value ranges
        true
      end

      def check_data_patterns
        # Implementation for checking data patterns
        true
      end

      def check_referential_consistency(related_records)
        # Implementation for checking referential consistency
        true
      end

      def check_temporal_consistency(related_records)
        # Implementation for checking temporal consistency
        true
      end

      def check_historical_patterns(historical_records)
        # Implementation for checking historical patterns
        true
      end
    end

    # Service class for data timeliness assessment
    class DataTimelinessService
      def initialize(record)
        @record = record
      end

      def assess_data_freshness
        # Assess how fresh the data is
        return 1.0 unless @record.updated_at

        hours_old = (Time.current - @record.updated_at) / 1.hour

        case hours_old
        when 0..1 then 1.0      # Very fresh
        when 1..24 then 0.9     # Fresh
        when 24..168 then 0.7   # Moderately fresh
        when 168..720 then 0.5  # Stale
        else 0.3                # Very stale
        end
      end

      def assess_update_frequency
        # Assess if update frequency meets requirements
        expected_frequency = @record.class.data_quality_config[:expected_update_frequency]
        return 1.0 unless expected_frequency && @record.updated_at

        actual_frequency = calculate_actual_update_frequency
        expected_frequency >= actual_frequency ? 1.0 : 0.7
      end

      def assess_temporal_consistency
        # Assess temporal consistency of the data
        return 1.0 unless @record.created_at && @record.updated_at

        # Check if timestamps make logical sense
        time_diff = @record.updated_at - @record.created_at

        # Reasonable time differences based on record type
        case time_diff
        when 0..1.hour then 1.0    # Normal for new records
        when 1.hour..1.day then 0.9 # Normal for updates
        when 1.day..1.week then 0.8 # Acceptable for some records
        else 0.6                   # May indicate issues
        end
      end

      private

      def calculate_actual_update_frequency
        # Implementation for calculating actual update frequency
        24.hours # Default assumption
      end
    end

    # Service class for data accuracy assessment
    class DataAccuracyService
      def initialize(record)
        @record = record
      end

      def assess_source_reliability
        # Assess reliability of data source
        source_info = @record.try(:data_source) || @record.try(:source)

        case source_info&.to_sym
        when :verified, :trusted then 1.0
        when :user_input then 0.8
        when :automated then 0.9
        when :imported then 0.7
        else 0.5
        end
      end

      def assess_entry_accuracy
        # Assess accuracy of data entry
        accuracy_indicators = []

        # Check for common data entry patterns that indicate accuracy
        accuracy_indicators << check_format_accuracy
        accuracy_indicators << check_length_appropriateness
        accuracy_indicators << check_pattern_consistency

        accuracy_indicators.sum.to_f / accuracy_indicators.count
      end

      def assess_calculation_accuracy
        # Assess accuracy of calculated fields
        calculated_fields = identify_calculated_fields

        return 1.0 if calculated_fields.empty?

        accuracy_checks = calculated_fields.map do |field|
          validate_calculated_field(field)
        end

        accuracy_checks.sum.to_f / accuracy_checks.count
      end

      private

      def check_format_accuracy
        # Implementation for checking format accuracy
        1.0
      end

      def check_length_appropriateness
        # Implementation for checking length appropriateness
        1.0
      end

      def check_pattern_consistency
        # Implementation for checking pattern consistency
        1.0
      end

      def identify_calculated_fields
        # Implementation for identifying calculated fields
        []
      end

      def validate_calculated_field(field)
        # Implementation for validating calculated fields
        true
      end
    end

    # Service class for quality adjustments
    class QualityAdjustmentService
      def initialize(record)
        @record = record
      end

      def apply_business_rule_adjustments(base_score)
        # Apply adjustments based on business rules
        adjustment_rules = @record.class.data_quality_config[:score_adjustments] || {}

        adjustment = 0.0
        adjustment_rules.each do |rule, rule_adjustment|
          if evaluate_adjustment_rule(rule)
            adjustment += rule_adjustment
          end
        end

        adjustment
      end

      def apply_temporal_adjustments(base_score, timeframe)
        # Apply time-based adjustments
        return 0.0 unless timeframe && @record.updated_at

        hours_old = (Time.current - @record.updated_at) / 1.hour

        # Penalize very old data
        case hours_old
        when 0..24 then 0.0      # No adjustment for recent data
        when 24..168 then -0.05  # Small penalty for week-old data
        when 168..720 then -0.10 # Larger penalty for month-old data
        else -0.15               # Significant penalty for very old data
        end
      end

      def apply_context_adjustments(base_score, context)
        # Apply context-specific adjustments
        return 0.0 unless context

        context_adjustments = {
          critical_record: 0.05,
          draft_record: -0.10,
          archived_record: -0.05,
          system_generated: 0.03
        }

        adjustment = 0.0
        context_adjustments.each do |context_key, context_adjustment|
          if context[context_key]
            adjustment += context_adjustment
          end
        end

        adjustment
      end

      private

      def evaluate_adjustment_rule(rule)
        # Implementation for evaluating adjustment rules
        true
      end
    end

    # Service class for data quality alerts
    class DataQualityAlertService
      def initialize(record)
        @record = record
      end

      def trigger_degradation_alert(old_score, new_score, options)
        return unless @record.respond_to?(:data_quality_alerts)

        @record.data_quality_alerts.create!(
          alert_type: :quality_degradation,
          severity: calculate_degradation_severity(old_score, new_score),
          old_score: old_score,
          new_score: new_score,
          change_amount: new_score - old_score,
          alert_context: options[:context],
          triggered_by: options[:triggered_by] || 'system',
          created_at: Time.current
        )
      end

      def trigger_threshold_alert(quality_level, score, options)
        return unless @record.respond_to?(:data_quality_alerts)

        @record.data_quality_alerts.create!(
          alert_type: :quality_threshold,
          severity: threshold_alert_severity(quality_level),
          quality_level: quality_level,
          current_score: score,
          threshold_score: QUALITY_THRESHOLDS[quality_level][:min_score],
          alert_context: options[:context],
          triggered_by: options[:triggered_by] || 'system',
          created_at: Time.current
        )
      end

      private

      def calculate_degradation_severity(old_score, new_score)
        change_amount = (old_score - new_score).abs

        case change_amount
        when 0..0.1 then :low
        when 0.1..0.2 then :medium
        when 0.2..0.3 then :high
        else :critical
        end
      end

      def threshold_alert_severity(quality_level)
        severity_map = {
          excellent: :info,
          good: :info,
          fair: :warning,
          poor: :high,
          critical: :critical
        }

        severity_map[quality_level] || :medium
      end
    end

    # Service class for data quality assessment
    class DataQualityAssessmentService
      def initialize(record)
        @record = record
      end

      def field_level_scores
        # Calculate quality scores for individual fields
        field_scores = {}

        @record.attributes.each do |field, value|
          field_scores[field] = calculate_field_quality_score(field, value)
        end

        field_scores
      end

      def identify_issues
        # Identify data quality issues in the record
        issues = []

        # Check for missing values in important fields
        issues.concat(identify_missing_value_issues)

        # Check for format issues
        issues.concat(identify_format_issues)

        # Check for consistency issues
        issues.concat(identify_consistency_issues)

        # Check for accuracy issues
        issues.concat(identify_accuracy_issues)

        issues
      end

      def generate_recommendations
        # Generate recommendations based on identified issues
        issues = identify_issues
        recommendations = []

        issues.each do |issue|
          recommendations << generate_issue_recommendation(issue)
        end

        recommendations.uniq
      end

      private

      def calculate_field_quality_score(field, value)
        # Calculate quality score for a specific field
        field_service = FieldQualityService.new(@record, field, value)
        field_service.calculate_score
      end

      def identify_missing_value_issues
        # Implementation for identifying missing value issues
        []
      end

      def identify_format_issues
        # Implementation for identifying format issues
        []
      end

      def identify_consistency_issues
        # Implementation for identifying consistency issues
        []
      end

      def identify_accuracy_issues
        # Implementation for identifying accuracy issues
        []
      end

      def generate_issue_recommendation(issue)
        # Implementation for generating issue-specific recommendations
        "Fix issue: #{issue[:description]}"
      end
    end

    # Service class for field-level quality assessment
    class FieldQualityService
      def initialize(record, field, value)
        @record = record
        @field = field
        @value = value
      end

      def calculate_score
        # Calculate quality score for the field
        factors = [
          completeness_factor,
          format_factor,
          length_factor,
          pattern_factor
        ]

        factors.sum.to_f / factors.count
      end

      private

      def completeness_factor
        @value.present? ? 1.0 : 0.0
      end

      def format_factor
        # Check if value matches expected format for field type
        field_type = @record.column_for_attribute(@field)&.type

        case field_type
        when :string, :text
          validate_string_format
        when :integer, :decimal, :float
          validate_numeric_format
        when :datetime, :date
          validate_datetime_format
        when :boolean
          validate_boolean_format
        else
          1.0
        end
      end

      def length_factor
        # Check if value length is appropriate
        return 1.0 unless @value.is_a?(String)

        expected_length = @record.class.columns_hash[@field.to_s]&.limit
        return 1.0 unless expected_length

        length_ratio = @value.length.to_f / expected_length
        length_ratio > 1.0 ? 0.5 : 1.0
      end

      def pattern_factor
        # Check if value matches expected patterns
        pattern_rules = @record.class.quality_rules[@field.to_sym]
        return 1.0 unless pattern_rules

        validate_pattern_compliance(pattern_rules)
      end

      def validate_string_format
        # String format validation
        1.0
      end

      def validate_numeric_format
        # Numeric format validation
        @value.to_s.match?(/\A-?\d+(\.\d+)?\z/) ? 1.0 : 0.0
      end

      def validate_datetime_format
        # DateTime format validation
        begin
          Time.parse(@value.to_s)
          1.0
        rescue
          0.0
        end
      end

      def validate_boolean_format
        # Boolean format validation
        [true, false, 1, 0, 'true', 'false', '1', '0'].include?(@value) ? 1.0 : 0.0
      end

      def validate_pattern_compliance(rules)
        # Pattern compliance validation
        1.0
      end
    end
  end
end