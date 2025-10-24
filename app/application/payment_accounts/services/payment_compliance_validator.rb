# frozen_string_literal: true

# Enterprise Payment Compliance Validator
# Multi-jurisdictional compliance validation with regulatory reporting
class PaymentComplianceValidator
  include ServiceResultHelper

  # Validate account compliance status
  def validate_account(payment_account, context = {})
    CircuitBreaker.execute_with_fallback(:compliance_validation) do
      # Execute parallel compliance checks
      compliance_checks = execute_parallel_compliance_checks(payment_account, context)

      # Aggregate compliance results
      compliance_result = aggregate_compliance_results(compliance_checks)

      # Create compliance record
      create_compliance_record(payment_account, compliance_result, context)

      # Handle compliance violations
      handle_compliance_violations(payment_account, compliance_result) if compliance_result.violations?

      success_result(compliance_result, 'Compliance validation completed')
    end
  end

  # Validate specific compliance requirement
  def validate_compliance_requirement(payment_account, requirement, context = {})
    CircuitBreaker.execute_with_fallback(:requirement_validation) do
      validator = get_requirement_validator(requirement)
      validation_result = validator.validate(payment_account, context)

      # Record requirement validation
      record_requirement_validation(payment_account, requirement, validation_result)

      validation_result
    end
  end

  private

  def execute_parallel_compliance_checks(payment_account, context)
    checks = [
      -> { validate_kyc_compliance(payment_account, context) },
      -> { validate_aml_compliance(payment_account, context) },
      -> { validate_sanctions_compliance(payment_account, context) },
      -> { validate_tax_compliance(payment_account, context) },
      -> { validate_privacy_compliance(payment_account, context) },
      -> { validate_financial_reporting_compliance(payment_account, context) }
    ]

    ReactiveParallelExecutor.execute(checks)
  end

  def aggregate_compliance_results(checks)
    violations = []
    warnings = []
    passed_checks = 0
    total_checks = checks.size

    checks.each do |check_result|
      if check_result.success?
        passed_checks += 1
      else
        if check_result.critical?
          violations << check_result
        else
          warnings << check_result
        end
      end
    end

    compliance_score = (passed_checks.to_f / total_checks) * 100

    ComplianceValidationResult.new(
      score: compliance_score,
      violations: violations,
      warnings: warnings,
      passed_checks: passed_checks,
      total_checks: total_checks,
      compliant: violations.empty?
    )
  end

  def create_compliance_record(payment_account, compliance_result, context)
    PaymentComplianceRecord.create!(
      payment_account: payment_account,
      compliance_score: compliance_result.score,
      compliance_status: compliance_result.compliant? ? :compliant : :non_compliant,
      violations: compliance_result.violations.map(&:to_h),
      warnings: compliance_result.warnings.map(&:to_h),
      validation_context: context,
      validated_at: Time.current,
      validation_version: current_validation_version
    )
  end

  def handle_compliance_violations(payment_account, compliance_result)
    # Create compliance violation events
    compliance_result.violations.each do |violation|
      event = PaymentComplianceViolationEvent.new(
        "payment_account_#{payment_account.id}",
        payment_account_id: payment_account.id,
        violation_type: violation.type,
        violation_severity: violation.severity,
        violation_description: violation.description,
        regulatory_framework: violation.framework,
        remediation_required: violation.remediation_required?,
        remediation_deadline: violation.remediation_deadline
      )

      # Store and publish violation event
      event_store = EventStore.new
      event_store.append_events(event.aggregate_id, [event])
      EventPublisher.publish('compliance.events', event)
    end

    # Trigger remediation workflows for critical violations
    critical_violations = compliance_result.violations.select(&:critical?)
    if critical_violations.any?
      ComplianceRemediationJob.perform_async(payment_account.id, critical_violations.map(&:type))
    end

    # Update account compliance status
    payment_account.update!(
      compliance_status: :non_compliant,
      last_compliance_violation_at: Time.current,
      compliance_violations_count: payment_account.compliance_violations_count + compliance_result.violations.size
    )
  end

  def get_requirement_validator(requirement)
    case requirement.to_sym
    when :kyc then KycComplianceValidator.new
    when :aml then AmlComplianceValidator.new
    when :sanctions then SanctionsComplianceValidator.new
    when :tax then TaxComplianceValidator.new
    when :privacy then PrivacyComplianceValidator.new
    when :financial_reporting then FinancialReportingComplianceValidator.new
    else raise ValidationError, "Unknown compliance requirement: #{requirement}"
    end
  end

  def record_requirement_validation(payment_account, requirement, result)
    PaymentComplianceRequirement.create!(
      payment_account: payment_account,
      requirement_type: requirement,
      validation_status: result.success? ? :passed : :failed,
      validation_result: result.to_h,
      validated_at: Time.current
    )
  end

  def current_validation_version
    '3.2.0' # Track compliance validation version
  end

  # Individual compliance validators (simplified implementations)
  def validate_kyc_compliance(payment_account, context)
    # Implementation would validate Know Your Customer requirements
    ComplianceCheckResult.new(
      type: :kyc,
      success: true,
      severity: :low,
      description: 'KYC validation passed'
    )
  end

  def validate_aml_compliance(payment_account, context)
    # Implementation would validate Anti-Money Laundering requirements
    ComplianceCheckResult.new(
      type: :aml,
      success: true,
      severity: :high,
      description: 'AML validation passed'
    )
  end

  def validate_sanctions_compliance(payment_account, context)
    # Implementation would check against sanctions lists
    ComplianceCheckResult.new(
      type: :sanctions,
      success: true,
      severity: :critical,
      description: 'Sanctions screening passed'
    )
  end

  def validate_tax_compliance(payment_account, context)
    # Implementation would validate tax reporting requirements
    ComplianceCheckResult.new(
      type: :tax,
      success: true,
      severity: :medium,
      description: 'Tax compliance validation passed'
    )
  end

  def validate_privacy_compliance(payment_account, context)
    # Implementation would validate privacy regulations (GDPR, CCPA, etc.)
    ComplianceCheckResult.new(
      type: :privacy,
      success: true,
      severity: :high,
      description: 'Privacy compliance validation passed'
    )
  end

  def validate_financial_reporting_compliance(payment_account, context)
    # Implementation would validate financial reporting requirements
    ComplianceCheckResult.new(
      type: :financial_reporting,
      success: true,
      severity: :medium,
      description: 'Financial reporting compliance validation passed'
    )
  end
end

# Supporting classes for compliance validation
class ComplianceValidationResult
  attr_reader :score, :violations, :warnings, :passed_checks, :total_checks, :compliant

  def initialize(score:, violations:, warnings:, passed_checks:, total_checks:, compliant:)
    @score = score
    @violations = violations
    @warnings = warnings
    @passed_checks = passed_checks
    @total_checks = total_checks
    @compliant = compliant
  end

  def violations?
    violations.any?
  end

  def warnings?
    warnings.any?
  end
end

class ComplianceCheckResult
  attr_reader :type, :success, :severity, :description, :framework, :remediation_required, :remediation_deadline

  def initialize(type:, success:, severity:, description:, framework: nil, remediation_required: false, remediation_deadline: nil)
    @type = type
    @success = success
    @severity = severity
    @description = description
    @framework = framework
    @remediation_required = remediation_required
    @remediation_deadline = remediation_deadline
  end

  def critical?
    severity == :critical
  end

  def to_h
    {
      type: type,
      success: success,
      severity: severity,
      description: description,
      framework: framework,
      remediation_required: remediation_required,
      remediation_deadline: remediation_deadline
    }
  end
end