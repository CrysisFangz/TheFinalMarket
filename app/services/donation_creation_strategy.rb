# frozen_string_literal: true

# Strategy Pattern Implementation for Donation Creation
# Provides extensible donation type handling with proper validation
class DonationCreationStrategy
  include ServiceResultHelper

  # Strategy registry for different donation types
  STRATEGIES = {
    one_time: OneTimeCreationStrategy,
    round_up: RoundUpCreationStrategy,
    monthly: MonthlyCreationStrategy,
    percentage: PercentageCreationStrategy
  }.freeze

  def self.for_type(donation_type)
    strategy_class = STRATEGIES[donation_type.to_sym]
    raise ArgumentError, "Unknown donation type: #{donation_type}" unless strategy_class

    strategy_class.new
  end

  def create!(user:, charity:, amount_cents:, metadata: {})
    raise NotImplementedError, "Subclasses must implement create!"
  end

  # One-time donation strategy
  class OneTimeCreationStrategy < DonationCreationStrategy
    def create!(user:, charity:, amount_cents:, metadata: {})
      validate_inputs(user, charity, amount_cents)

      CharityDonation.transaction do
        donation = CharityDonation.create!(
          user: user,
          charity: charity,
          amount_cents: amount_cents,
          donation_type: :one_time,
          metadata: metadata,
          status: :pending
        )

        # Publish creation event
        EventSourcing::EventStore.append_event(
          donation,
          :donation_created,
          {
            amount_cents: amount_cents,
            donation_type: :one_time,
            created_at: Time.current
          }
        )

        donation
      end
    end

    private

    def validate_inputs(user, charity, amount_cents)
      raise ArgumentError, "Valid user required" unless user&.active?
      raise ArgumentError, "Valid charity required" unless charity&.tax_deductible?
      raise ArgumentError, "Valid amount required" unless amount_cents&.positive?
    end
  end

  # Round-up donation strategy with order integration
  class RoundUpCreationStrategy < DonationCreationStrategy
    def create!(user:, charity:, amount_cents:, metadata: {})
      order = metadata[:order]
      raise ArgumentError, "Order required for round-up donation" unless order

      validate_inputs(user, charity, amount_cents, order)

      CharityDonation.transaction do
        donation = CharityDonation.create!(
          user: user,
          charity: charity,
          order: order,
          amount_cents: amount_cents,
          donation_type: :round_up,
          metadata: metadata.merge(
            order_total_cents: order.total_cents,
            round_up_calculated_at: Time.current
          ),
          status: :pending
        )

        # Publish creation event with order context
        EventSourcing::EventStore.append_event(
          donation,
          :round_up_donation_created,
          {
            amount_cents: amount_cents,
            order_id: order.id,
            order_total_cents: order.total_cents,
            created_at: Time.current
          }
        )

        donation
      end
    end

    private

    def validate_inputs(user, charity, amount_cents, order)
      raise ArgumentError, "Valid user required" unless user&.active?
      raise ArgumentError, "Valid charity required" unless charity&.tax_deductible?
      raise ArgumentError, "Valid amount required" unless amount_cents&.positive?
      raise ArgumentError, "Valid order required" unless order&.persisted?
    end
  end

  # Monthly recurring donation strategy
  class MonthlyCreationStrategy < DonationCreationStrategy
    def create!(user:, charity:, amount_cents:, metadata: {})
      validate_inputs(user, charity, amount_cents)

      CharityDonation.transaction do
        donation = CharityDonation.create!(
          user: user,
          charity: charity,
          amount_cents: amount_cents,
          donation_type: :monthly,
          metadata: metadata.merge(
            recurring: true,
            billing_cycle: :monthly,
            next_billing_date: next_monthly_billing_date
          ),
          status: :pending
        )

        # Schedule recurring job
        schedule_recurring_donation(donation)

        # Publish creation event
        EventSourcing::EventStore.append_event(
          donation,
          :monthly_donation_created,
          {
            amount_cents: amount_cents,
            next_billing_date: next_monthly_billing_date,
            created_at: Time.current
          }
        )

        donation
      end
    end

    private

    def validate_inputs(user, charity, amount_cents)
      raise ArgumentError, "Valid user required" unless user&.active?
      raise ArgumentError, "Valid charity required" unless charity&.tax_deductible?
      raise ArgumentError, "Valid amount required" unless amount_cents&.positive?
    end

    def next_monthly_billing_date
      Time.current.next_month.beginning_of_month
    end

    def schedule_recurring_donation(donation)
      RecurringDonationJob.set(wait_until: next_monthly_billing_date)
                         .perform_later(donation.id)
    end
  end

  # Percentage-based donation strategy
  class PercentageCreationStrategy < DonationCreationStrategy
    def create!(user:, charity:, amount_cents:, metadata: {})
      percentage = metadata[:percentage]
      base_amount_cents = metadata[:base_amount_cents]

      validate_inputs(user, charity, amount_cents, percentage, base_amount_cents)

      CharityDonation.transaction do
        donation = CharityDonation.create!(
          user: user,
          charity: charity,
          amount_cents: amount_cents,
          donation_type: :percentage,
          metadata: metadata.merge(
            percentage: percentage,
            base_amount_cents: base_amount_cents,
            calculated_at: Time.current
          ),
          status: :pending
        )

        # Publish creation event
        EventSourcing::EventStore.append_event(
          donation,
          :percentage_donation_created,
          {
            amount_cents: amount_cents,
            percentage: percentage,
            base_amount_cents: base_amount_cents,
            created_at: Time.current
          }
        )

        donation
      end
    end

    private

    def validate_inputs(user, charity, amount_cents, percentage, base_amount_cents)
      raise ArgumentError, "Valid user required" unless user&.active?
      raise ArgumentError, "Valid charity required" unless charity&.tax_deductible?
      raise ArgumentError, "Valid amount required" unless amount_cents&.positive?
      raise ArgumentError, "Valid percentage required" unless percentage&.between?(0, 100)
      raise ArgumentError, "Valid base amount required" unless base_amount_cents&.positive?
    end
  end
end