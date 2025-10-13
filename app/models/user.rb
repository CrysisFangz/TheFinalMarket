class User < ApplicationRecord
  include UserReputation
  include UserLeveling
  include SellerFeesConcern
  include SellerBondConcern
  include PasswordSecurity

  has_many :seller_orders, class_name: 'Order', foreign_key: 'seller_id'
  has_many :orders, foreign_key: 'user_id', dependent: :destroy

  has_secure_password
  has_one :wishlist, dependent: :destroy
  has_many :wishlist_items, through: :wishlist
  
  # ActiveStorage attachment for avatar
  has_one_attached :avatar

  enum role: { user: 0, moderator: 1, admin: 2 }
  enum user_type: { seeker: 'seeker', gem: 'gem' }
  enum seller_status: {
    not_applied: 'not_applied',
    pending_approval: 'pending_approval',
    pending_bond: 'pending_bond',
    approved: 'approved',
    rejected: 'rejected',
    suspended: 'suspended'
  }

  after_initialize :set_default_user_type_and_status, if: :new_record?

  attribute :suspended_until, :datetime

  has_one :seller_application, dependent: :destroy

  validates :name, presence: true, length: { maximum: 50 }
  validates :email, presence: true, length: { maximum: 255 },
                   format: { with: URI::MailTo::EMAIL_REGEXP },
                   uniqueness: { case_sensitive: false }
  validates :password, presence: true, length: { minimum: 8 }, allow_nil: true

  before_save { self.email = email.downcase }
  
  has_one :cart, dependent: :destroy
  has_many :products, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :reviewed_products, through: :reviews, source: :product
  
  # Dispute associations
  has_many :reported_disputes, class_name: 'Dispute', foreign_key: 'reporter_id', dependent: :destroy
  has_many :disputes_against, class_name: 'Dispute', foreign_key: 'reported_user_id'
  has_many :moderated_disputes, class_name: 'Dispute', foreign_key: 'moderator_id'

  # Notifications
  has_many :notifications, as: :recipient, dependent: :destroy

  # Internationalization
  has_one :user_currency_preference, dependent: :destroy
  has_one :currency, through: :user_currency_preference
  belongs_to :country, optional: true, foreign_key: :country_code, primary_key: :code

  # User warnings
  has_many :warnings, class_name: 'UserWarning', dependent: :destroy

  # Cart related
  has_many :cart_items, dependent: :destroy
  has_many :cart_items_count, -> { select('item_id, COUNT(*) as count').group('item_id') }, class_name: 'CartItem'

  # Gamification associations
  has_many :user_achievements, dependent: :destroy
  has_many :achievements, through: :user_achievements
  has_many :user_daily_challenges, dependent: :destroy
  has_many :daily_challenges, through: :user_daily_challenges
  has_many :points_transactions, dependent: :destroy
  has_many :coins_transactions, dependent: :destroy
  has_many :unlocked_features, dependent: :destroy
  
  def notify(actor:, action:, notifiable:)
    notifications.create!(
      actor: actor,
      action: action,
      notifiable: notifiable
    )
  end

  def unread_notifications_count
    notifications.where(read_at: nil).count
  end

  def gem?
    user_type == 'gem'
  end

  def seeker?
    user_type == 'seeker'
  end

  def can_sell?
    gem? && seller_status == 'approved'
  end

  # Gamification methods
  def update_login_streak!
    today = Date.current

    if last_login_date.nil?
      # First login
      update!(
        current_login_streak: 1,
        longest_login_streak: 1,
        last_login_date: today
      )
    elsif last_login_date == today - 1.day
      # Consecutive day
      new_streak = current_login_streak + 1
      update!(
        current_login_streak: new_streak,
        longest_login_streak: [longest_login_streak, new_streak].max,
        last_login_date: today
      )
    elsif last_login_date == today
      # Already logged in today
      return
    else
      # Streak broken
      update!(
        current_login_streak: 1,
        last_login_date: today
      )
    end
  end

  def update_challenge_streak!
    # Update streak for completing daily challenges
    if user_daily_challenges.today.completed.count == DailyChallenge.today.count
      increment!(:challenge_streak)
    end
  end

  def has_feature?(feature_name)
    unlocked_features.exists?(feature_name: feature_name)
  end

  def avatar_url_for_display
    if avatar.attached?
      Rails.application.routes.url_helpers.rails_blob_path(avatar, only_path: true)
    else
      avatar_url.presence || '/assets/default-avatar.png'
    end
  end
  
  def profile_completion_percentage
    fields = [name, email, (avatar.attached? || avatar_url.present?), bio, location]
    completed = fields.select { |f| f.present? }.count
    (completed.to_f / fields.count * 100).round
  end

  def total_spent
    orders.completed.sum(:total_amount)
  end

  def total_earned
    sold_orders.completed.sum(:total_amount)
  end

  # Account security methods
  def record_failed_login!
    increment!(:failed_login_attempts, 1)
    if failed_login_attempts >= 5
      lock_account!(30.minutes)
    end
  end

  def record_successful_login!
    update_columns(failed_login_attempts: 0, locked_until: nil, last_login_at: Time.current)
  end

  def lock_account!(duration)
    update_column(:locked_until, Time.current + duration)
  end

  def account_locked?
    locked_until.present? && locked_until > Time.current
  end

  private

  def set_default_role
    self.role ||= :user
  end

  def set_default_user_type_and_status
    self.user_type ||= 'seeker'
    self.seller_status ||= 'not_applied'
    self.level ||= 1
  end

  def level_up!
    return if level >= 6
    update(level: level + 1)
  end

  # Cart methods with race condition protection
  def add_to_cart(item, quantity = 1)
    ActiveRecord::Base.transaction do
      cart_item = cart_items.lock.find_or_initialize_by(item: item)
      cart_item.quantity = cart_item.new_record? ? quantity : cart_item.quantity + quantity
      cart_item.save!
      cart_item
    end
  rescue ActiveRecord::RecordNotUnique
    # Handle race condition where two requests try to create the same cart item
    retry
  end

  def remove_from_cart(item, quantity = nil)
    cart_item = cart_items.find_by(item: item)
    return unless cart_item

    if quantity.nil? || cart_item.quantity <= quantity
      cart_item.destroy
    else
      cart_item.update(quantity: cart_item.quantity - quantity)
    end
  end

  def cart_total
    cart_items.sum(&:subtotal)
  end

  def clear_cart
    cart_items.destroy_all
  end

  def level_name
    case level
    when 1 then "Garnet"
    when 2 then "Topaz"
    when 3 then "Emerald"
    when 4 then "Sapphire"
    when 5 then "Ruby"
    when 6 then "Diamond"
    end
  end
end
