class PriceExperimentCalculationService
  attr_reader :experiment

  def initialize(experiment)
    @experiment = experiment
  end

  def control_conversion_rate
    Rails.logger.debug("Calculating control conversion rate for experiment ID: #{experiment.id}")

    begin
      return 0 if experiment.control_views.zero?

      rate = (experiment.control_conversions.to_f / experiment.control_views * 100).round(2)

      Rails.logger.debug("Calculated control conversion rate for experiment ID: #{experiment.id}: #{rate}%")
      rate
    rescue => e
      Rails.logger.error("Failed to calculate control conversion rate for experiment ID: #{experiment.id}. Error: #{e.message}")
      0
    end
  end

  def variant_conversion_rate
    Rails.logger.debug("Calculating variant conversion rate for experiment ID: #{experiment.id}")

    begin
      return 0 if experiment.variant_views.zero?

      rate = (experiment.variant_conversions.to_f / experiment.variant_views * 100).round(2)

      Rails.logger.debug("Calculated variant conversion rate for experiment ID: #{experiment.id}: #{rate}%")
      rate
    rescue => e
      Rails.logger.error("Failed to calculate variant conversion rate for experiment ID: #{experiment.id}. Error: #{e.message}")
      0
    end
  end

  def conversion_improvement
    Rails.logger.debug("Calculating conversion improvement for experiment ID: #{experiment.id}")

    begin
      control_rate = control_conversion_rate
      return 0 if control_rate.zero?

      improvement = ((variant_conversion_rate - control_rate) / control_rate * 100).round(2)

      Rails.logger.debug("Calculated conversion improvement for experiment ID: #{experiment.id}: #{improvement}%")
      improvement
    rescue => e
      Rails.logger.error("Failed to calculate conversion improvement for experiment ID: #{experiment.id}. Error: #{e.message}")
      0
    end
  end

  def calculate_significance
    Rails.logger.debug("Calculating statistical significance for experiment ID: #{experiment.id}")

    begin
      return 0 if experiment.control_views.zero? || experiment.variant_views.zero?

      p1 = experiment.control_conversions.to_f / experiment.control_views
      p2 = experiment.variant_conversions.to_f / experiment.variant_views

      p_pool = (experiment.control_conversions + experiment.variant_conversions).to_f / (experiment.control_views + experiment.variant_views)

      se = Math.sqrt(p_pool * (1 - p_pool) * (1.0/experiment.control_views + 1.0/experiment.variant_views))

      return 0 if se.zero?

      z_score = (p2 - p1) / se

      # Convert z-score to confidence level (simplified)
      confidence = (1 - Math.exp(-z_score.abs)) * 100

      Rails.logger.debug("Calculated significance for experiment ID: #{experiment.id}: #{confidence.round(2)}%")
      confidence.round(2)
    rescue => e
      Rails.logger.error("Failed to calculate significance for experiment ID: #{experiment.id}. Error: #{e.message}")
      0
    end
  end

  def price_elasticity
    Rails.logger.debug("Calculating price elasticity for experiment ID: #{experiment.id}")

    begin
      return 0 if experiment.control_views.zero? || experiment.variant_views.zero?

      control_rate = control_conversion_rate
      variant_rate = variant_conversion_rate

      return 0 if control_rate.zero?

      # Price elasticity = (% change in quantity) / (% change in price)
      price_change_percent = price_change_percentage
      conversion_change_percent = conversion_improvement

      return 0 if price_change_percent.zero?

      elasticity = conversion_change_percent / price_change_percent

      Rails.logger.debug("Calculated price elasticity for experiment ID: #{experiment.id}: #{elasticity.round(3)}")
      elasticity.round(3)
    rescue => e
      Rails.logger.error("Failed to calculate price elasticity for experiment ID: #{experiment.id}. Error: #{e.message}")
      0
    end
  end

  def revenue_impact
    Rails.logger.debug("Calculating revenue impact for experiment ID: #{experiment.id}")

    begin
      control_revenue_per_visitor = (experiment.control_price_cents * control_conversion_rate) / 100.0
      variant_revenue_per_visitor = (experiment.variant_price_cents * variant_conversion_rate) / 100.0

      impact_per_visitor = variant_revenue_per_visitor - control_revenue_per_visitor
      impact_percentage = control_revenue_per_visitor.zero? ? 0 : (impact_per_visitor / control_revenue_per_visitor * 100)

      impact = {
        control_revenue_per_visitor: control_revenue_per_visitor.round(2),
        variant_revenue_per_visitor: variant_revenue_per_visitor.round(2),
        impact_per_visitor: impact_per_visitor.round(2),
        impact_percentage: impact_percentage.round(2)
      }

      Rails.logger.debug("Calculated revenue impact for experiment ID: #{experiment.id}: #{impact}")
      impact
    rescue => e
      Rails.logger.error("Failed to calculate revenue impact for experiment ID: #{experiment.id}. Error: #{e.message}")
      {}
    end
  end

  def statistical_power
    Rails.logger.debug("Calculating statistical power for experiment ID: #{experiment.id}")

    begin
      # Calculate statistical power based on sample size and effect size
      total_views = experiment.control_views + experiment.variant_views
      effect_size = conversion_improvement.abs / 100.0

      # Simplified power calculation
      power = if total_views > 1000 && effect_size > 0.05
        0.9
      elsif total_views > 500 && effect_size > 0.03
        0.7
      elsif total_views > 200 && effect_size > 0.02
        0.5
      else
        0.3
      end

      Rails.logger.debug("Calculated statistical power for experiment ID: #{experiment.id}: #{power}")
      power.round(2)
    rescue => e
      Rails.logger.error("Failed to calculate statistical power for experiment ID: #{experiment.id}. Error: #{e.message}")
      0
    end
  end

  private

  def price_change_percentage
    return 0 if experiment.control_price_cents.zero?

    ((experiment.variant_price_cents - experiment.control_price_cents).to_f / experiment.control_price_cents * 100).round(2)
  end
end