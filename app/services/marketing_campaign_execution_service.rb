class MarketingCampaignExecutionService
  attr_reader :campaign

  def initialize(campaign)
    @campaign = campaign
  end

  def launch!
    Rails.logger.info("Launching MarketingCampaign ID: #{campaign.id}")
    return false unless campaign.draft? || campaign.scheduled?

    campaign.update!(
      status: :active,
      launched_at: Time.current
    )

    # Queue campaign execution
    MarketingCampaignJob.perform_later(campaign.id)
    Rails.logger.info("MarketingCampaign ID: #{campaign.id} launched successfully")
    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Validation error launching MarketingCampaign ID: #{campaign.id} - #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Error launching MarketingCampaign ID: #{campaign.id} - #{e.message}")
    raise
  end

  def pause!
    Rails.logger.info("Pausing MarketingCampaign ID: #{campaign.id}")
    campaign.update!(status: :paused)
    Rails.logger.info("MarketingCampaign ID: #{campaign.id} paused successfully")
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Validation error pausing MarketingCampaign ID: #{campaign.id} - #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Error pausing MarketingCampaign ID: #{campaign.id} - #{e.message}")
    raise
  end

  def resume!
    Rails.logger.info("Resuming MarketingCampaign ID: #{campaign.id}")
    campaign.update!(status: :active)
    Rails.logger.info("MarketingCampaign ID: #{campaign.id} resumed successfully")
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Validation error resuming MarketingCampaign ID: #{campaign.id} - #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Error resuming MarketingCampaign ID: #{campaign.id} - #{e.message}")
    raise
  end

  def complete!
    Rails.logger.info("Completing MarketingCampaign ID: #{campaign.id}")
    campaign.update!(
      status: :completed,
      completed_at: Time.current
    )
    Rails.logger.info("MarketingCampaign ID: #{campaign.id} completed successfully")
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Validation error completing MarketingCampaign ID: #{campaign.id} - #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Error completing MarketingCampaign ID: #{campaign.id} - #{e.message}")
    raise
  end

  def send_to_audience
    Rails.logger.info("Sending to audience for MarketingCampaign ID: #{campaign.id}")
    audience = MarketingCampaignAudienceService.new(campaign).target_audience

    audience.find_each do |user|
      next unless MarketingCampaignPersonalizationService.new(campaign).can_send_to?(user)

      campaign.campaign_emails.create!(
        user: user,
        subject: MarketingCampaignPersonalizationService.new(campaign).personalize_subject(user),
        content: MarketingCampaignPersonalizationService.new(campaign).personalize_content(user),
        scheduled_for: Time.current,
        status: :pending
      )
    end

    # Queue email sending
    SendCampaignEmailsJob.perform_later(campaign.id)
    Rails.logger.info("Audience emails queued for MarketingCampaign ID: #{campaign.id}")
  rescue StandardError => e
    Rails.logger.error("Error sending to audience for MarketingCampaign ID: #{campaign.id} - #{e.message}")
    raise
  end
end