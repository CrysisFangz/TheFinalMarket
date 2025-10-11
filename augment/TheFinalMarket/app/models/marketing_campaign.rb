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
  
  # Launch campaign
  def launch!
    return false unless draft? || scheduled?
    
    update!(
      status: :active,
      launched_at: Time.current
    )
    
    # Queue campaign execution
    MarketingCampaignJob.perform_later(id)
  end
  
  # Pause campaign
  def pause!
    update!(status: :paused)
  end
  
  # Resume campaign
  def resume!
    update!(status: :active)
  end
  
  # Complete campaign
  def complete!
    update!(
      status: :completed,
      completed_at: Time.current
    )
  end
  
  # Get target audience
  def target_audience
    case campaign_type.to_sym
    when :abandoned_cart
      users_with_abandoned_carts
    when :customer_winback
      inactive_customers
    when :loyalty_reward
      loyal_customers
    when :cross_sell
      customers_who_bought_related_products
    when :upsell
      customers_who_bought_lower_tier_products
    else
      all_customers
    end
  end
  
  # Send to audience
  def send_to_audience
    audience = target_audience
    
    audience.find_each do |user|
      next unless can_send_to?(user)
      
      campaign_emails.create!(
        user: user,
        subject: personalize_subject(user),
        content: personalize_content(user),
        scheduled_for: Time.current,
        status: :pending
      )
    end
    
    # Queue email sending
    SendCampaignEmailsJob.perform_later(id)
  end
  
  # Get campaign performance
  def performance_metrics
    {
      sent: campaign_emails.sent.count,
      delivered: campaign_emails.delivered.count,
      opened: campaign_emails.opened.count,
      clicked: campaign_emails.clicked.count,
      converted: campaign_emails.converted.count,
      revenue_generated: campaign_emails.sum(:revenue_generated_cents) / 100.0,
      open_rate: calculate_rate(:opened, :delivered),
      click_rate: calculate_rate(:clicked, :opened),
      conversion_rate: calculate_rate(:converted, :clicked),
      roi: calculate_roi
    }
  end
  
  # A/B test
  def create_ab_test(variant_name, changes = {})
    variant = dup
    variant.name = "#{name} - #{variant_name}"
    variant.ab_test_variant = variant_name
    variant.ab_test_parent_id = id
    variant.subject_line = changes[:subject_line] if changes[:subject_line]
    variant.email_content = changes[:email_content] if changes[:email_content]
    variant.save!
    
    variant
  end
  
  # Get winning variant
  def winning_variant
    variants = MarketingCampaign.where(ab_test_parent_id: id)
    return nil if variants.empty?
    
    variants.max_by { |v| v.performance_metrics[:conversion_rate] }
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

