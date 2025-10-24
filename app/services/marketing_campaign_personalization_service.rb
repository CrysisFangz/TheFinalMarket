class MarketingCampaignPersonalizationService
  attr_reader :campaign

  def initialize(campaign)
    @campaign = campaign
  end

  def can_send_to?(user)
    Rails.logger.debug("Checking if can send to user ID: #{user.id} for MarketingCampaign ID: #{campaign.id}")
    # Check marketing consent
    return false unless user.privacy_setting&.marketing_allowed?(:email)

    # Check frequency cap (max 1 email per day)
    last_email = campaign.campaign_emails.where(user: user).order(created_at: :desc).first
    return false if last_email && last_email.created_at > 24.hours.ago

    true
  end

  def personalize_subject(user)
    Rails.logger.debug("Personalizing subject for user ID: #{user.id} in MarketingCampaign ID: #{campaign.id}")
    campaign.subject_line
      .gsub('{first_name}', user.first_name || 'there')
      .gsub('{last_name}', user.last_name || '')
  end

  def personalize_content(user)
    Rails.logger.debug("Personalizing content for user ID: #{user.id} in MarketingCampaign ID: #{campaign.id}")
    campaign.email_content
      .gsub('{first_name}', user.first_name || 'there')
      .gsub('{last_name}', user.last_name || '')
      .gsub('{email}', user.email)
  end
end