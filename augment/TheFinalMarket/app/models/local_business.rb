class LocalBusiness < ApplicationRecord
  belongs_to :seller, class_name: 'User'
  
  validates :business_name, presence: true
  validates :city, presence: true
  validates :state, presence: true
  
  scope :verified, -> { where(verified: true) }
  scope :in_city, ->(city) { where(city: city) }
  scope :in_state, ->(state) { where(state: state) }
  
  def verify!
    update!(verified: true, verified_at: Time.current)
  end
  
  def local_badge
    {
      icon: '🏪',
      text: "Local Business - #{city}, #{state}",
      verified: verified?
    }
  end
end

