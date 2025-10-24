class MarketingCampaignABTestService
  attr_reader :campaign

  def initialize(campaign)
    @campaign = campaign
  end

  def create_ab_test(variant_name, changes = {})
    Rails.logger.info("Creating A/B test variant '#{variant_name}' for MarketingCampaign ID: #{campaign.id}")
    variant = campaign.dup
    variant.name = "#{campaign.name} - #{variant_name}"
    variant.ab_test_variant = variant_name
    variant.ab_test_parent_id = campaign.id
    variant.subject_line = changes[:subject_line] if changes[:subject_line]
    variant.email_content = changes[:email_content] if changes[:email_content]
    variant.save!

    Rails.logger.info("A/B test variant created for MarketingCampaign ID: #{campaign.id}")
    variant
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Validation error creating A/B test for MarketingCampaign ID: #{campaign.id} - #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Error creating A/B test for MarketingCampaign ID: #{campaign.id} - #{e.message}")
    raise
  end

  def winning_variant
    Rails.logger.debug("Finding winning variant for MarketingCampaign ID: #{campaign.id}")
    variants = MarketingCampaign.where(ab_test_parent_id: campaign.id)
    return nil if variants.empty?

    winning = variants.max_by { |v| MarketingCampaignAnalyticsService.new(v).performance_metrics[:conversion_rate] }
    Rails.logger.debug("Winning variant found for MarketingCampaign ID: #{campaign.id}")
    winning
  rescue StandardError => e
    Rails.logger.error("Error finding winning variant for MarketingCampaign ID: #{campaign.id} - #{e.message}")
    nil
  end
end