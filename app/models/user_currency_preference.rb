class UserCurrencyPreference < ApplicationRecord
  belongs_to :user
  belongs_to :currency
  
  validates :user_id, uniqueness: true
end

