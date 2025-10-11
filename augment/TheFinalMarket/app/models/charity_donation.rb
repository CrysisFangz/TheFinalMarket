class CharityDonation < ApplicationRecord
  belongs_to :user
  belongs_to :charity
  belongs_to :order, optional: true
  
  validates :amount_cents, presence: true, numericality: { greater_than: 0 }
  
  scope :recent, -> { where('created_at > ?', 30.days.ago) }
  scope :by_charity, ->(charity) { where(charity: charity) }
  
  enum donation_type: {
    one_time: 0,
    round_up: 1,
    monthly: 2,
    percentage: 3
  }
  
  # Create round-up donation
  def self.create_round_up(order)
    return unless order.user.charity_settings&.round_up_enabled?
    
    charity = order.user.charity_settings.selected_charity
    return unless charity
    
    round_up_amount = calculate_round_up(order.total_cents)
    
    create!(
      user: order.user,
      charity: charity,
      order: order,
      amount_cents: round_up_amount,
      donation_type: :round_up
    )
  end
  
  # Process donation
  def process!
    # Process payment
    # For now, just mark as processed
    update!(
      processed: true,
      processed_at: Time.current
    )
    
    # Update charity total
    charity.increment!(:total_donations_cents, amount_cents)
    
    # Send receipt
    CharityMailer.donation_receipt(self).deliver_later
  end
  
  # Get tax receipt
  def tax_receipt
    {
      donation_id: id,
      donor_name: user.name,
      charity_name: charity.name,
      charity_ein: charity.ein,
      amount: amount_cents / 100.0,
      date: created_at,
      tax_deductible: charity.tax_deductible?
    }
  end
  
  private
  
  def self.calculate_round_up(amount_cents)
    # Round up to nearest dollar
    dollars = (amount_cents / 100.0).ceil
    (dollars * 100) - amount_cents
  end
end

