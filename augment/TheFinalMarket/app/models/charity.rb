class Charity < ApplicationRecord
  has_many :charity_donations
  has_many :donors, through: :charity_donations, source: :user
  
  validates :name, presence: true
  validates :ein, presence: true, uniqueness: true
  validates :category, presence: true
  
  scope :verified, -> { where(verified: true) }
  scope :by_category, ->(category) { where(category: category) }
  
  enum category: {
    education: 0,
    health: 1,
    environment: 2,
    poverty: 3,
    animals: 4,
    disaster_relief: 5,
    human_rights: 6,
    arts_culture: 7
  }
  
  def tax_deductible?
    verified? && ein.present?
  end
  
  def impact_report
    {
      total_raised: total_donations_cents / 100.0,
      donor_count: donors.distinct.count,
      average_donation: charity_donations.average(:amount_cents).to_f / 100.0,
      recent_donations: charity_donations.recent.count
    }
  end
end

