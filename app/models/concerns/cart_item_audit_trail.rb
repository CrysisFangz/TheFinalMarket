# frozen_string_literal: true

# Cart Item Audit Trail
# Comprehensive audit logging for compliance, debugging, and business intelligence
module CartItemAuditTrail
  extend ActiveSupport::Concern

  included do
    # === Audit Events ===

    # Audits cart item creation
    # @param creation_params [Hash] parameters used for creation
    def audit_creation(creation_params)
      audit_event = build_audit_event(
        event_type: 'cart_item_created',
        details: {
          user_id: user_id,
          item_id: item_id,
          quantity: quantity,
          unit_price: unit_price,
          total_price: total_price,
          creation_params: sanitize_params(creation_params)
        }
      )

      record_audit_event(audit_event)
    end

    # Audits cart item updates
    # @param changes [Hash] changes made to the item
    def audit_update(changes)
      audit_event = build_audit_event(
        event_type: 'cart_item_updated',
        details: {
          user_id: user_id,
          item_id: item_id,
          changes: sanitize_changes(changes)
        }
      )

      record_audit_event(audit_event)
    end

    # Audits cart item deletion
    # @param deletion_reason [String] reason for deletion
    def audit_deletion(deletion_reason = nil)
      audit_event = build_audit_event(
        event_type: 'cart_item_deleted',
        details: {
          user_id: user_id,
          item_id: item_id,
          quantity: quantity,
          total_price: total_price,
          deletion_reason: deletion_reason
        }
      )

      record_audit_event(audit_event)
    end

    # Audits business rule violations
    # @param rule_name [String] name of violated rule
    # @param rule_details [Hash] details about the violation
    def audit_business_rule_violation(rule_name, rule_details)
      audit_event = build_audit_event(
        event_type: 'business_rule_violation',
        severity: 'warning',
        details: {
          rule_name: rule_name,
          rule_details: rule_details,
          user_id: user_id,
          item_id: item_id
        }
      )

      record_audit_event(audit_event)
    end

    # Audits inventory operations
    # @param operation [String] type of inventory operation
    # @param details [Hash] operation details
    def audit_inventory_operation(operation, details)
      audit_event = build_audit_event(
        event_type: 'inventory_operation',
        details: {
          operation: operation,
          quantity_affected: details[:quantity],
          item_id: item_id,
          user_id: user_id
        }
      )

      record_audit_event(audit_event)
    end

    # === Compliance & Reporting ===

    # Gets audit history for compliance reporting
    # @param limit [Integer] maximum number of events to return
    # @return [Array<Hash>] audit events
    def audit_history(limit = 100)
      metadata['audit_trail']&.last(limit) || []
    end

    # Gets audit events by type
    # @param event_type [String] type of events to retrieve
    # @return [Array<Hash>] matching audit events
    def audit_events_by_type(event_type)
      metadata['audit_trail']&.select { |event| event['event_type'] == event_type } || []
    end

    # Checks if audit trail is compliant with retention policies
    # @return [Boolean] true if compliant
    def audit_compliant?
      return true unless metadata['audit_trail']

      oldest_event = metadata['audit_trail'].min_by { |event| event['timestamp'] }
      return false unless oldest_event

      # Check if events are within retention period
      retention_period = audit_retention_period
      Time.parse(oldest_event['timestamp']) > retention_period.ago
    end

    private

    # Builds standardized audit event structure
    # @param event_type [String] type of audit event
    # @param severity [String] event severity level
    # @param details [Hash] event details
    # @return [Hash] formatted audit event
    def build_audit_event(event_type:, severity: 'info', details: {})
      {
        event_type: event_type,
        severity: severity,
        timestamp: Time.current.utc.iso8601,
        user_id: user_id,
        item_id: item_id,
        cart_item_id: id,
        session_id: Current.session_id,
        request_id: Current.request_id,
        ip_address: Current.ip_address,
        user_agent: Current.user_agent,
        details: details
      }
    end

    # Records audit event in metadata and external log
    # @param audit_event [Hash] audit event to record
    def record_audit_event(audit_event)
      # Initialize audit trail if not present
      self.metadata['audit_trail'] ||= []

      # Add event to trail
      self.metadata['audit_trail'] << audit_event

      # Maintain audit trail size (keep last 1000 events)
      self.metadata['audit_trail'] = metadata['audit_trail'].last(1000) if metadata['audit_trail'].size > 1000

      # Update audit metadata
      self.metadata['last_audit_event_at'] = audit_event[:timestamp]
      self.metadata['audit_event_count'] = metadata['audit_trail'].size

      # Log to external audit system
      log_external_audit_event(audit_event)

      # Publish audit event for real-time monitoring
      publish_audit_event(audit_event)
    rescue StandardError => e
      CartItemLogger.error("Failed to record audit event for cart_item_#{id}", e)
    end

    # Logs audit event to external audit system
    # @param audit_event [Hash] audit event to log
    def log_external_audit_event(audit_event)
      CartItemLogger.audit(
        "Cart item audit: #{audit_event[:event_type]}",
        audit_event
      )
    end

    # Publishes audit event for real-time processing
    # @param audit_event [Hash] audit event to publish
    def publish_audit_event(audit_event)
      EventPublisher.publish('audit.cart_item', audit_event)
    end

    # Sanitizes parameters for audit logging
    # @param params [Hash] parameters to sanitize
    # @return [Hash] sanitized parameters
    def sanitize_params(params)
      # Remove sensitive information
      sanitized = params.except('password', 'password_confirmation', 'credit_card')
      # Hash sensitive values
      sanitized.transform_values do |value|
        case value
        when String
          value.length > 50 ? "HASHED_#{Digest::SHA256.hexdigest(value)[0..16]}" : value
        else
          value
        end
      end
    end

    # Sanitizes changes for audit logging
    # @param changes [Hash] changes to sanitize
    # @return [Hash] sanitized changes
    def sanitize_changes(changes)
      changes.except('updated_at', 'metadata').transform_values do |change_data|
        old_value, new_value = change_data

        {
          from: sanitize_value(old_value),
          to: sanitize_value(new_value)
        }
      end
    end

    # Sanitizes individual values for audit logging
    # @param value [Object] value to sanitize
    # @return [Object] sanitized value
    def sanitize_value(value)
      case value
      when String
        value.length > 100 ? "#{value[0..50]}...[TRUNCATED]" : value
      when BigDecimal
        value.to_s('F')
      else
        value
      end
    end

    # Gets audit retention period based on business rules
    # @return [ActiveSupport::Duration] retention period
    def audit_retention_period
      case state
      when CartItemStates::PURCHASED
        7.years # Legal requirement for purchased items
      when CartItemStates::CANCELLED
        3.years # Business requirement for cancelled items
      else
        1.year  # Standard retention for other items
      end
    end
  end

  # === Class Methods ===

  module ClassMethods
    # Gets audit statistics for compliance reporting
    # @param user_id [Integer] user ID to get stats for
    # @return [Hash] audit statistics
    def audit_statistics(user_id = nil)
      scope = user_id ? where(user_id: user_id) : all

      {
        total_cart_items: scope.count,
        audited_items: scope.where.not(metadata: {}).count,
        total_audit_events: scope.sum('CAST(metadata->>\'audit_event_count\' AS INTEGER)'),
        compliance_rate: calculate_compliance_rate(scope),
        last_audit_at: scope.maximum('CAST(metadata->>\'last_audit_event_at\' AS TIMESTAMP)')
      }
    end

    # Gets audit events across all cart items
    # @param event_type [String] type of events to retrieve
    # @param limit [Integer] maximum events to return
    # @return [Array<Hash>] audit events
    def global_audit_events(event_type = nil, limit = 1000)
      events = []

      find_each do |cart_item|
        trail = cart_item.metadata['audit_trail'] || []
        filtered_events = event_type ? trail.select { |e| e['event_type'] == event_type } : trail
        events.concat(filtered_events)
      end

      events.sort_by { |event| event['timestamp'] }.reverse.first(limit)
    end

    private

    # Calculates compliance rate for audit trails
    # @param scope [ActiveRecord::Relation] scope of cart items
    # @return [Float] compliance rate as percentage
    def calculate_compliance_rate(scope)
      return 0.0 if scope.empty?

      compliant_items = scope.select do |item|
        item.audit_compliant?
      end.count

      (compliant_items.to_f / scope.count * 100).round(2)
    end
  end
end