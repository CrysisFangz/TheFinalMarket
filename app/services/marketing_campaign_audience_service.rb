class MarketingCampaignAudienceService
  attr_reader :campaign

  def initialize(campaign)
    @campaign = campaign
  end

  def target_audience
    Rails.logger.debug("Determining target audience for MarketingCampaign ID: #{campaign.id}")
    case campaign.campaign_type.to_sym
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

  private

  def users_with_abandoned_carts
    Rails.logger.debug("Fetching users with abandoned carts for MarketingCampaign ID: #{campaign.id}")
    User.joins(:cart_items)
        .where('cart_items.created_at > ? AND cart_items.created_at < ?', 7.days.ago, 1.hour.ago)
        .where.not(id: Order.where('created_at > ?', 7.days.ago).select(:user_id))
        .distinct
  end

  def inactive_customers
    Rails.logger.debug("Fetching inactive customers for MarketingCampaign ID: #{campaign.id}")
    User.joins(:orders)
        .where('orders.created_at < ?', 90.days.ago)
        .where.not(id: Order.where('created_at > ?', 90.days.ago).select(:user_id))
        .distinct
  end

  def loyal_customers
    Rails.logger.debug("Fetching loyal customers for MarketingCampaign ID: #{campaign.id}")
    User.joins(:orders)
        .group('users.id')
        .having('COUNT(orders.id) >= ?', 5)
  end

  def customers_who_bought_related_products
    Rails.logger.debug("Fetching customers who bought related products for MarketingCampaign ID: #{campaign.id}")
    # This would use product relationships
    User.joins(:orders).distinct
  end

  def customers_who_bought_lower_tier_products
    Rails.logger.debug("Fetching customers who bought lower tier products for MarketingCampaign ID: #{campaign.id}")
    # This would identify upsell opportunities
    User.joins(:orders).distinct
  end

  def all_customers
    Rails.logger.debug("Fetching all customers for MarketingCampaign ID: #{campaign.id}")
    campaign.seller.customers.where('privacy_settings.marketing_consent = ?', true)
  end
end