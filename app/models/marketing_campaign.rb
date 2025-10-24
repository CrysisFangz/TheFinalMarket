class MarketingCampaign < ApplicationRecord
  belongs_to :seller, class_name: 'User'
  
  has_many :campaign_emails, dependent: :destroy
  has_many :campaign_analytics, dependent: :destroy
  
  validates :name, presence: true
  validates :campaign_type, presence: true
  
  scope :active, -> { where(status: :active) }
  scope :scheduled, -> { where(status: :scheduled) }
  scope :by_type, ->(type) { where(campaign_type: type) }
  
  # Campaign types
  enum campaign_type: {
    email_blast: 0,
    abandoned_cart: 1,
    product_launch: 2,
    seasonal_promotion: 3,
    customer_winback: 4,
    loyalty_reward: 5,
    cross_sell: 6,
    upsell: 7
  }
  
  # Campaign status
  enum status: {
    draft: 0,
    scheduled: 1,
    active: 2,
    paused: 3,
    completed: 4,
    cancelled: 5
  }
  
  # Delegated to MarketingCampaignExecutionService
  def launch!
    @execution_service ||= MarketingCampaignExecutionService.new(self)
    @execution_service.launch!
  end
  
  # Delegated to MarketingCampaignExecutionService
  def pause!
    @execution_service ||= MarketingCampaignExecutionService.new(self)
    @execution_service.pause!
  end

  def resume!
    @execution_service ||= MarketingCampaignExecutionService.new(self)
    @execution_service.resume!
  end

  def complete!
    @execution_service ||= MarketingCampaignExecutionService.new(self)
    @execution_service.complete!
  end
  
  # Delegated to MarketingCampaignAudienceService
  def target_audience
    @audience_service ||= MarketingCampaignAudienceService.new(self)
    @audience_service.target_audience
  end
  
  # Delegated to MarketingCampaignExecutionService
  def send_to_audience
    @execution_service ||= MarketingCampaignExecutionService.new(self)
    @execution_service.send_to_audience
  end
  
  # Delegated to MarketingCampaignAnalyticsService
  def performance_metrics
    @analytics_service ||= MarketingCampaignAnalyticsService.new(self)
    @analytics_service.performance_metrics
  end
  
  # Delegated to MarketingCampaignABTestService
  def create_ab_test(variant_name, changes = {})
    @ab_test_service ||= MarketingCampaignABTestService.new(self)
    @ab_test_service.create_ab_test(variant_name, changes)
  end
  
  # Delegated to MarketingCampaignABTestService
  def winning_variant
    @ab_test_service ||= MarketingCampaignABTestService.new(self)
    @ab_test_service.winning_variant
  end
  
  private
  
  def users_with_abandoned_carts
    User.joins(:cart_items)
        .where('cart_items.created_at > ? AND cart_items.created_at < ?', 7.days.ago, 1.hour.ago)
        .where.not(id: Order.where('created_at > ?', 7.days.ago).select(:user_id))
        .distinct
  end
  
  def inactive_customers
    User.joins(:orders)
        .where('orders.created_at < ?', 90.days.ago)
        .where.not(id: Order.where('created_at > ?', 90.days.ago).select(:user_id))
        .distinct
  end
  
  def loyal_customers
    User.joins(:orders)
        .group('users.id')
        .having('COUNT(orders.id) >= ?', 5)
  end
  
  def customers_who_bought_related_products
    # This would use product relationships
    User.joins(:orders).distinct
  end
  
  def customers_who_bought_lower_tier_products
    # This would identify upsell opportunities
    User.joins(:orders).distinct
  end
  
  def all_customers
    seller.customers.where('privacy_settings.marketing_consent = ?', true)
  end
  
  def can_send_to?(user)
    # Check marketing consent
    return false unless user.privacy_setting&.marketing_allowed?(:email)
    
    # Check frequency cap (max 1 email per day)
    last_email = campaign_emails.where(user: user).order(created_at: :desc).first
    return false if last_email && last_email.created_at > 24.hours.ago
    
    true
  end
  
  def personalize_subject(user)
    subject_line
      .gsub('{first_name}', user.first_name || 'there')
      .gsub('{last_name}', user.last_name || '')
  end
  
  def personalize_content(user)
    email_content
      .gsub('{first_name}', user.first_name || 'there')
      .gsub('{last_name}', user.last_name || '')
      .gsub('{email}', user.email)
  end
  
  def calculate_rate(numerator_status, denominator_status)
    denominator = campaign_emails.send(denominator_status).count
    return 0 if denominator.zero?
    
    numerator = campaign_emails.send(numerator_status).count
    (numerator.to_f / denominator * 100).round(2)
  end
  
  def calculate_roi
    cost = budget_cents || 0
    return 0 if cost.zero?
    
    revenue = campaign_emails.sum(:revenue_generated_cents)
    ((revenue - cost).to_f / cost * 100).round(2)
  end
end

