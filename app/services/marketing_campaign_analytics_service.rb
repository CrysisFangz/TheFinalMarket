class MarketingCampaignAnalyticsService
  attr_reader :campaign

  def initialize(campaign)
    @campaign = campaign
  end

  def performance_metrics
    Rails.logger.debug("Calculating performance metrics for MarketingCampaign ID: #{campaign.id}")
    metrics = {
      sent: campaign.campaign_emails.sent.count,
      delivered: campaign.campaign_emails.delivered.count,
      opened: campaign.campaign_emails.opened.count,
      clicked: campaign.campaign_emails.clicked.count,
      converted: campaign.campaign_emails.converted.count,
      revenue_generated: campaign.campaign_emails.sum(:revenue_generated_cents) / 100.0,
      open_rate: calculate_rate(:opened, :delivered),
      click_rate: calculate_rate(:clicked, :opened),
      conversion_rate: calculate_rate(:converted, :clicked),
      roi: calculate_roi
    }
    Rails.logger.debug("Performance metrics calculated for MarketingCampaign ID: #{campaign.id}")
    metrics
  end

  private

  def calculate_rate(numerator_status, denominator_status)
    denominator = campaign.campaign_emails.send(denominator_status).count
    return 0 if denominator.zero?

    numerator = campaign.campaign_emails.send(numerator_status).count
    (numerator.to_f / denominator * 100).round(2)
  end

  def calculate_roi
    cost = campaign.budget_cents || 0
    return 0 if cost.zero?

    revenue = campaign.campaign_emails.sum(:revenue_generated_cents)
    ((revenue - cost).to_f / cost * 100).round(2)
  end
end