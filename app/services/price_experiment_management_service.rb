class PriceExperimentManagementService
  attr_reader :experiment

  def initialize(experiment)
    @experiment = experiment
  end

  def determine_winner
    Rails.logger.info("Determining winner for experiment ID: #{experiment.id}")

    begin
      return nil unless experiment.active? || experiment.completed?

      significance = calculation_service.calculate_significance

      # Need at least 95% confidence and 100 views per variant
      return nil if significance < 95 || experiment.control_views < 100 || experiment.variant_views < 100

      winner = calculation_service.variant_conversion_rate > calculation_service.control_conversion_rate ? 'variant' : 'control'

      update_experiment_results(winner, significance)

      Rails.logger.info("Determined winner for experiment ID: #{experiment.id}: #{winner}")
      winner
    rescue => e
      Rails.logger.error("Failed to determine winner for experiment ID: #{experiment.id}. Error: #{e.message}")
      nil
    end
  end

  def record_view(variant_type)
    Rails.logger.debug("Recording view for experiment ID: #{experiment.id}, variant: #{variant_type}")

    begin
      if variant_type == 'control'
        experiment.increment!(:control_views)
      else
        experiment.increment!(:variant_views)
      end

      # Check if we should run winner determination
      check_for_winner_determination if experiment.active?

      Rails.logger.debug("Successfully recorded view for experiment ID: #{experiment.id}")
      true
    rescue => e
      Rails.logger.error("Failed to record view for experiment ID: #{experiment.id}. Error: #{e.message}")
      false
    end
  end

  def record_conversion(variant_type)
    Rails.logger.debug("Recording conversion for experiment ID: #{experiment.id}, variant: #{variant_type}")

    begin
      if variant_type == 'control'
        experiment.increment!(:control_conversions)
      else
        experiment.increment!(:variant_conversions)
      end

      # Check if we can determine a winner
      determine_winner if experiment.active?

      Rails.logger.debug("Successfully recorded conversion for experiment ID: #{experiment.id}")
      true
    rescue => e
      Rails.logger.error("Failed to record conversion for experiment ID: #{experiment.id}. Error: #{e.message}")
      false
    end
  end

  def assign_variant
    Rails.logger.debug("Assigning variant for experiment ID: #{experiment.id}")

    begin
      # 50/50 split for A/B testing
      variant = rand < 0.5 ? 'control' : 'variant'

      Rails.logger.debug("Assigned variant for experiment ID: #{experiment.id}: #{variant}")
      variant
    rescue => e
      Rails.logger.error("Failed to assign variant for experiment ID: #{experiment.id}. Error: #{e.message}")
      'control' # Default to control on error
    end
  end

  def price_for_variant(variant_type)
    Rails.logger.debug("Getting price for variant: #{variant_type} in experiment ID: #{experiment.id}")

    begin
      price = variant_type == 'control' ? experiment.control_price_cents : experiment.variant_price_cents

      Rails.logger.debug("Got price for variant #{variant_type} in experiment ID: #{experiment.id}: #{price}")
      price
    rescue => e
      Rails.logger.error("Failed to get price for variant #{variant_type} in experiment ID: #{experiment.id}. Error: #{e.message}")
      0
    end
  end

  def has_sufficient_data?
    Rails.logger.debug("Checking if experiment ID: #{experiment.id} has sufficient data")

    begin
      sufficient = experiment.control_views >= 100 && experiment.variant_views >= 100

      Rails.logger.debug("Sufficient data check for experiment ID: #{experiment.id}: #{sufficient}")
      sufficient
    rescue => e
      Rails.logger.error("Failed to check sufficient data for experiment ID: #{experiment.id}. Error: #{e.message}")
      false
    end
  end

  def start_experiment!
    Rails.logger.info("Starting experiment ID: #{experiment.id}")

    begin
      return false unless experiment.draft?

      experiment.update!(
        status: :active,
        started_at: Time.current
      )

      # Initialize counters
      experiment.update!(
        control_views: 0,
        control_conversions: 0,
        variant_views: 0,
        variant_conversions: 0,
        confidence_level: 0,
        winner: nil
      )

      Rails.logger.info("Successfully started experiment ID: #{experiment.id}")
      true
    rescue => e
      Rails.logger.error("Failed to start experiment ID: #{experiment.id}. Error: #{e.message}")
      false
    end
  end

  def pause_experiment!
    Rails.logger.info("Pausing experiment ID: #{experiment.id}")

    begin
      return false unless experiment.active?

      experiment.update!(status: :paused)

      Rails.logger.info("Successfully paused experiment ID: #{experiment.id}")
      true
    rescue => e
      Rails.logger.error("Failed to pause experiment ID: #{experiment.id}. Error: #{e.message}")
      false
    end
  end

  def resume_experiment!
    Rails.logger.info("Resuming experiment ID: #{experiment.id}")

    begin
      return false unless experiment.paused?

      experiment.update!(status: :active)

      Rails.logger.info("Successfully resumed experiment ID: #{experiment.id}")
      true
    rescue => e
      Rails.logger.error("Failed to resume experiment ID: #{experiment.id}. Error: #{e.message}")
      false
    end
  end

  def stop_experiment!(reason = nil)
    Rails.logger.info("Stopping experiment ID: #{experiment.id}, reason: #{reason}")

    begin
      return false unless experiment.active? || experiment.paused?

      experiment.update!(
        status: :completed,
        ended_at: Time.current,
        stop_reason: reason
      )

      Rails.logger.info("Successfully stopped experiment ID: #{experiment.id}")
      true
    rescue => e
      Rails.logger.error("Failed to stop experiment ID: #{experiment.id}. Error: #{e.message}")
      false
    end
  end

  def archive_experiment!
    Rails.logger.info("Archiving experiment ID: #{experiment.id}")

    begin
      return false unless experiment.completed?

      experiment.update!(status: :archived)

      Rails.logger.info("Successfully archived experiment ID: #{experiment.id}")
      true
    rescue => e
      Rails.logger.error("Failed to archive experiment ID: #{experiment.id}. Error: #{e.message}")
      false
    end
  end

  private

  def calculation_service
    @calculation_service ||= PriceExperimentCalculationService.new(experiment)
  end

  def check_for_winner_determination
    Rails.logger.debug("Checking for winner determination in experiment ID: #{experiment.id}")

    begin
      # Auto-determine winner if we have sufficient data and high confidence
      if has_sufficient_data? && calculation_service.calculate_significance > 95
        determine_winner
      end
    rescue => e
      Rails.logger.error("Failed to check for winner determination in experiment ID: #{experiment.id}. Error: #{e.message}")
    end
  end

  def update_experiment_results(winner, significance)
    Rails.logger.debug("Updating experiment results for experiment ID: #{experiment.id}")

    begin
      experiment.update!(
        winner: winner,
        status: :completed,
        ended_at: Time.current,
        confidence_level: significance,
        results: {
          control_conversion_rate: calculation_service.control_conversion_rate,
          variant_conversion_rate: calculation_service.variant_conversion_rate,
          improvement: calculation_service.conversion_improvement,
          confidence: significance,
          winner: winner,
          price_elasticity: calculation_service.price_elasticity,
          revenue_impact: calculation_service.revenue_impact,
          statistical_power: calculation_service.statistical_power
        }
      )

      Rails.logger.debug("Successfully updated experiment results for experiment ID: #{experiment.id}")
    rescue => e
      Rails.logger.error("Failed to update experiment results for experiment ID: #{experiment.id}. Error: #{e.message}")
      raise e
    end
  end
end