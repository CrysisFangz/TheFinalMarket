# frozen_string_literal: true

module Charity
  module Events
    # Domain Event representing charity registration
    class CharityRegisteredEvent < DomainEvent
      attr_reader :charity_id, :name, :ein, :category, :verification_status

      # Initialize new charity registration event
      # @param charity_id [String] unique charity identifier
      # @param name [String] charity name
      # @param ein [ValueObjects::EIN] employer identification number
      # @param category [ValueObjects::CharityCategory] charity category
      # @param verification_status [Symbol] initial verification status
      def initialize(charity_id, name, ein, category, verification_status = :pending)
        super(:charity_registered, Time.current, {
          charity_id: charity_id,
          name: name,
          ein: ein.to_s,
          category: category.to_s,
          verification_status: verification_status,
          metadata: {
            registration_source: 'web_form', # Could be 'api', 'import', etc.
            initial_risk_score: calculate_initial_risk_score(ein, category)
          }
        })

        @charity_id = charity_id
        @name = name
        @ein = ein
        @category = category
        @verification_status = verification_status
      end

      # Apply this event to a charity aggregate
      # @param charity [Entities::Charity] charity aggregate
      def apply_to(charity)
        charity.apply_charity_registered(self)
      end

      private

      # Calculate initial risk score for the charity
      # @param ein [ValueObjects::EIN] EIN value object
      # @param category [ValueObjects::CharityCategory] category value object
      # @return [Float] risk score between 0.0 and 1.0
      def calculate_initial_risk_score(ein, category)
        risk_score = 0.5 # Base risk

        # Lower risk for established categories
        case category.verification_priority
        when :critical
          risk_score += 0.2
        when :high
          risk_score += 0.1
        when :medium
          risk_score -= 0.1
        when :low
          risk_score -= 0.2
        end

        # Normalize to 0.0-1.0 range
        [[0.0, risk_score].max, 1.0].min
      end
    end
  end
end