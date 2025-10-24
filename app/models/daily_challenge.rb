class DailyChallenge < ApplicationRecord
  include CircuitBreaker

  has_many :user_daily_challenges, dependent: :destroy
  has_many :users, through: :user_daily_challenges

  enum challenge_type: {
    browse_products: 0,
    add_to_wishlist: 1,
    make_purchase: 2,
    leave_review: 3,
    list_product: 4,
    share_product: 5,
    complete_profile: 6,
    invite_friend: 7,
    participate_in_discussion: 8,
    watch_live_event: 9
  }

  enum difficulty: {
    easy: 0,
    medium: 1,
    hard: 2,
    expert: 3
  }

  validates :title, presence: true
  validates :description, presence: true
  validates :target_value, numericality: { greater_than: 0 }
  validates :reward_points, numericality: { greater_than_or_equal_to: 0 }
  validates :active_date, presence: true

  scope :active, -> { where(active: true) }
  scope :for_date, ->(date) { where(active_date: date.beginning_of_day..date.end_of_day) }
  scope :today, -> { for_date(Date.current) }
  scope :upcoming, -> { where('active_date > ?', Date.current) }
  scope :past, -> { where('active_date < ?', Date.current) }

  after_create :publish_created_event

  def self.generate_for_date(date = Date.current)
    with_retry do
      DailyChallengeService.generate_for_date(date)
    end
  end

  def completed_by?(user)
    user_daily_challenges.exists?(user: user, completed: true)
  end

  def progress_for(user)
    Rails.cache.fetch("challenge:#{id}:progress:#{user.id}", expires_in: 30.minutes) do
      user_challenge = user_daily_challenges.find_or_initialize_by(user: user)
      user_challenge.current_value || 0
    end
  end

  def update_progress(user, increment = 1)
    with_retry do
      DailyChallengeService.new.update_progress(self, user, increment)
    end
  end

  def completion_percentage(user)
    Rails.cache.fetch("challenge:#{id}:percentage:#{user.id}", expires_in: 30.minutes) do
      progress = progress_for(user)
      ((progress.to_f / target_value) * 100).round(2).clamp(0, 100)
    end
  end

  private

  def publish_created_event
    EventPublisher.publish('daily_challenge.created', { challenge_id: id, title: title })
  end

  def with_retry(max_retries: 3, &block)
    retries = 0
    begin
      yield
    rescue StandardError => e
      retries += 1
      retry if retries < max_retries
      Rails.logger.error("Failed after #{retries} retries: #{e.message}")
      raise e
    end
  end
end

