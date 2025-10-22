# frozen_string_literal: true

module Charity
  module Entities
    # Charity Aggregate Root - the central domain entity for charity management
    # Implements event sourcing for complete audit trail and state reconstruction
    class Charity
      attr_reader :id, :name, :ein, :category, :verification_status, :total_raised,
                  :donor_count, :created_at, :updated_at, :version, :uncommitted_events

      # Initialize new charity aggregate
      # @param id [String] unique charity identifier
      def initialize(id)
        @id = id
        @version = 0
        @uncommitted_events = []

        # Mutable state (reconstructed from events)
        @name = nil
        @ein = nil
        @category = nil
        @verification_status = :pending
        @total_raised = ValueObjects::Money.zero(:usd)
        @donor_count = 0
        @created_at = nil
        @updated_at = nil
      end

      # Factory method - register a new charity
      # @param id [String] charity identifier
      # @param name [String] charity name
      # @param ein [ValueObjects::EIN] employer identification number
      # @param category [ValueObjects::CharityCategory] charity category
      # @return [Charity] new charity aggregate
      def self.register(id, name, ein, category)
        charity = new(id)
        event = Events::CharityRegisteredEvent.new(id, name, ein, category)

        charity.apply(event)
        charity
      end

      # Load charity from event stream
      # @param id [String] charity identifier
      # @param events [Array<DomainEvent>] event history
      # @return [Charity] reconstructed charity aggregate
      def self.from_events(id, events)
        charity = new(id)
        events.each { |event| charity.apply_event(event) }
        charity.mark_events_committed
        charity
      end

      # Record a donation received
      # @param donation_id [String] unique donation identifier
      # @param amount [ValueObjects::Money] donation amount
      # @param donor_id [String] donor identifier
      # @param campaign_id [String] associated campaign (optional)
      def receive_donation(donation_id, amount, donor_id, campaign_id = nil)
        ensure_active_charity

        event = Events::DonationReceivedEvent.new(
          @id, donation_id, amount, donor_id, campaign_id
        )

        apply(event)
      end

      # Verify charity (for admin use)
      # @param verified_by [String] admin user who verified
      # @param verification_notes [String] verification notes
      def verify(verified_by, verification_notes = nil)
        return if @verification_status == :verified

        apply_charity_verified(verified_by, verification_notes)
      end

      # Check if charity is tax deductible
      # @return [Boolean] true if tax deductible
      def tax_deductible?
        @verification_status == :verified && @ein.present?
      end

      # Check if charity is verified
      # @return [Boolean] true if verified
      def verified?
        @verification_status == :verified
      end

      # Get impact metrics for reporting
      # @return [Hash] comprehensive impact metrics
      def impact_metrics
        {
          total_raised: @total_raised.format,
          total_raised_cents: @total_raised.amount_cents,
          donor_count: @donor_count,
          average_donation: calculate_average_donation,
          verification_status: @verification_status,
          category_impact_multiplier: @category&.tax_benefit_multiplier || 1.0,
          enhanced_impact_score: calculate_enhanced_impact_score,
          days_active: calculate_days_active,
          growth_rate: calculate_growth_rate
        }
      end

      # Apply domain event to this aggregate
      # @param event [DomainEvent] event to apply
      def apply(event)
        @version += 1
        @updated_at = event.occurred_at

        case event
        when Events::CharityRegisteredEvent
          apply_charity_registered(event)
        when Events::DonationReceivedEvent
          apply_donation_received(event)
        else
          raise ArgumentError, "Unknown event type: #{event.event_type}"
        end

        @uncommitted_events << event
      end

      # Mark all uncommitted events as committed
      def mark_events_committed
        @uncommitted_events.clear
      end

      # Get uncommitted events for persistence
      # @return [Array<DomainEvent>] events to persist
      def get_uncommitted_events
        @uncommitted_events.dup
      end

      private

      # Apply charity registered event
      def apply_charity_registered(event)
        @name = event.name
        @ein = event.ein
        @category = event.category
        @verification_status = event.verification_status
        @created_at = event.occurred_at
        @updated_at = event.occurred_at
      end

      # Apply donation received event
      def apply_donation_received(event)
        @total_raised = @total_raised.add(event.amount)
        @donor_count += 1 unless existing_donor?(event.donor_id)
        @updated_at = event.occurred_at
      end

      # Custom event application methods for specific events

      def apply_charity_verified(verified_by, verification_notes)
        event_data = {
          charity_id: @id,
          verified_by: verified_by,
          verification_notes: verification_notes,
          previous_status: @verification_status,
          metadata: {
            verification_method: 'manual_review',
            compliance_score: calculate_compliance_score
          }
        }

        event = Events::CharityVerifiedEvent.new(
          @id, verified_by, verification_notes, @verification_status
        )

        apply(event)
      end

      # Helper methods for business logic

      def ensure_active_charity
        raise DomainError, 'Charity is suspended' if @verification_status == :suspended
        raise DomainError, 'Charity is not verified' unless verified?
      end

      def existing_donor?(donor_id)
        # This would check against historical donation events
        # For now, assume new donor
        false
      end

      def calculate_average_donation
        return ValueObjects::Money.zero(:usd) if @donor_count.zero?

        @total_raised.divide(@donor_count)
      end

      def calculate_enhanced_impact_score
        base_impact = @total_raised.amount_cents
        multiplier = @category&.tax_benefit_multiplier || 1.0

        (base_impact * multiplier / 100.0).round(2)
      end

      def calculate_days_active
        return 0 unless @created_at

        (@updated_at.to_date - @created_at.to_date).to_i
      end

      def calculate_growth_rate
        # Simplified growth rate calculation
        # In real implementation, would analyze donation trends over time
        return 0.0 if @donor_count < 2

        # Placeholder calculation
        Math.log(@donor_count + 1) * 10
      end

      def calculate_compliance_score
        # Calculate compliance score based on various factors
        score = 50.0 # Base score

        # Adjust based on category compliance requirements
        if @category&.critical_verification?
          score += 20.0
        elsif @category&.verification_priority == :high
          score += 10.0
        end

        # Normalize to 0-100 range
        [[0.0, score].max, 100.0].min
      end
    end
  end
end