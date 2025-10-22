# frozen_string_literal: true

module Charity
  module Events
    # Domain Event representing a donation received by a charity
    class DonationReceivedEvent < DomainEvent
      attr_reader :charity_id, :donation_id, :amount, :donor_id, :campaign_id

      # Initialize new donation received event
      # @param charity_id [String] charity receiving donation
      # @param donation_id [String] unique donation identifier
      # @param amount [ValueObjects::Money] donation amount
      # @param donor_id [String] donor identifier
      # @param campaign_id [String] associated campaign (optional)
      def initialize(charity_id, donation_id, amount, donor_id, campaign_id = nil)
        super(:donation_received, Time.current, {
          charity_id: charity_id,
          donation_id: donation_id,
          amount_cents: amount.amount_cents,
          currency: amount.currency,
          donor_id: donor_id,
          campaign_id: campaign_id,
          metadata: {
            donation_source: detect_donation_source(donor_id, campaign_id),
            impact_multiplier: 1.0, # Could be enhanced based on matching gifts, etc.
            tax_deductible_amount: calculate_tax_deductible_amount(amount),
            processing_fee: calculate_processing_fee(amount),
            net_amount: calculate_net_amount(amount)
          }
        })

        @charity_id = charity_id
        @donation_id = donation_id
        @amount = amount
        @donor_id = donor_id
        @campaign_id = campaign_id
      end

      # Apply this event to a charity aggregate
      # @param charity [Entities::Charity] charity aggregate
      def apply_to(charity)
        charity.apply_donation_received(self)
      end

      private

      # Detect the source/channel of the donation
      # @param donor_id [String] donor identifier
      # @param campaign_id [String] campaign identifier
      # @return [Symbol] donation source
      def detect_donation_source(donor_id, campaign_id)
        return :campaign if campaign_id.present?
        return :recurring if recurring_donation?(donor_id)
        return :mobile_app if mobile_donation?(donor_id)

        :web_platform
      end

      # Check if this is a recurring donation
      # @param donor_id [String] donor identifier
      # @return [Boolean] true if recurring
      def recurring_donation?(donor_id)
        # This would check against subscription/payment history
        # For now, return false as placeholder
        false
      end

      # Check if donation came via mobile app
      # @param donor_id [String] donor identifier
      # @return [Boolean] true if mobile donation
      def mobile_donation?(donor_id)
        # This would check device metadata, user agent, etc.
        # For now, return false as placeholder
        false
      end

      # Calculate tax-deductible portion of donation
      # @param amount [ValueObjects::Money] donation amount
      # @return [Integer] tax-deductible amount in cents
      def calculate_tax_deductible_amount(amount)
        # Most charitable donations are fully tax-deductible
        # This could be made more sophisticated based on charity type
        amount.amount_cents
      end

      # Calculate payment processing fee
      # @param amount [ValueObjects::Money] donation amount
      # @return [Integer] processing fee in cents
      def calculate_processing_fee(amount)
        # Standard payment processing fee calculation
        # This would integrate with actual payment processor APIs
        base_fee = 30 # $0.30 base fee
        percentage_fee = (amount.amount_cents * 0.029).round # 2.9% percentage

        base_fee + percentage_fee
      end

      # Calculate net amount after fees
      # @param amount [ValueObjects::Money] donation amount
      # @return [Integer] net amount in cents
      def calculate_net_amount(amount)
        processing_fee = calculate_processing_fee(amount)
        amount.amount_cents - processing_fee
      end
    end
  end
end