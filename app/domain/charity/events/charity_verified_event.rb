# frozen_string_literal: true

module Charity
  module Events
    # Domain Event representing charity verification approval
    class CharityVerifiedEvent < DomainEvent
      attr_reader :charity_id, :verified_by, :verification_notes, :previous_status

      # Initialize new charity verified event
      # @param charity_id [String] charity identifier
      # @param verified_by [String] admin user who verified
      # @param verification_notes [String] verification notes (optional)
      # @param previous_status [Symbol] previous verification status
      def initialize(charity_id, verified_by, verification_notes, previous_status)
        super(:charity_verified, Time.current, {
          charity_id: charity_id,
          verified_by: verified_by,
          verification_notes: verification_notes,
          previous_status: previous_status,
          metadata: {
            verification_method: 'manual_admin_review',
            risk_assessment_score: calculate_risk_assessment_score,
            compliance_checklist_completed: true,
            verification_timestamp: Time.current.iso8601
          }
        })

        @charity_id = charity_id
        @verified_by = verified_by
        @verification_notes = verification_notes
        @previous_status = previous_status
      end

      # Apply this event to a charity aggregate
      # @param charity [Entities::Charity] charity aggregate
      def apply_to(charity)
        charity.apply_charity_verified(self)
      end

      private

      # Calculate risk assessment score for verification
      # @return [Float] risk score between 0.0 and 1.0
      def calculate_risk_assessment_score
        # This would integrate with external risk assessment services
        # For now, return a moderate risk score
        0.3
      end
    end
  end
end