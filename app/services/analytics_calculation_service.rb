# frozen_string_literal: true

# Service class for handling AnalyticsMetric calculations and statistical analysis
# Extracted from the monolithic model to improve modularity and performance
# Implements Clean Architecture Application Layer for computational use cases
class AnalyticsCalculationService
  include AnalyticsMetricConfiguration

  # Dependency injection for external services
  attr_accessor :statistical_service, :machine_learning_service, :cache

  def initialize(statistical_service: StatisticalAnalysisService.new,
                 machine_learning_service: MachineLearningService.new,
                 cache: Rails.cache)
    @statistical_service = statistical_service
    @machine_learning_service = machine_learning_service
    @cache = cache
  end

  # Calculate comprehensive trend analysis
  def calculate_trend_analysis(metric, days: 30, include_confidence: true)
    cache_key = "trend_analysis:#{metric.id}:#{days}:#{include_confidence}"

    cache.fetch(cache_key, expires_in: cache_expiration(:medium)) do
      historical_data = get_historical_data(metric, days)

      trend_analysis = statistical_service.analyze_trend(
        data: historical_data,
        include_confidence: include_confidence
      )

      enrich_trend_with_context(trend_analysis, metric)
    end
  rescue StandardError => e
    handle_calculation_error(e, 'trend_analysis', metric)
  end

  # Generate predictive forecast
  def generate_predictive_forecast(metric, horizon: 30.days, confidence_interval: 0.95)
    return unless predictive_analytics_enabled?(metric)

    cache_key = "predictive_forecast:#{metric.id}:#{horizon}:#{confidence_interval}"

    cache.fetch(cache_key, expires_in: cache_expiration(:long)) do
      training_data = prepare_training_data(metric, horizon * 2)

      forecast = machine_learning_service.train_and_forecast(
        metric_name: metric.metric_name,
        training_data: training_data,
        horizon: horizon,
        confidence_interval: confidence_interval
      )

      enrich_forecast_with_context(forecast, metric)
    end
  rescue StandardError => e
    handle_calculation_error(e, 'predictive_forecast', metric)
  end

  # Calculate statistical insights
  def calculate_statistical_insights(metric, window: 30.days)
    cache_key = "statistical_insights:#{metric.id}:#{window}"

    cache.fetch(cache_key, expires_in: cache_expiration(:medium)) do
      data = get_historical_data(metric, window)

      {
        mean: statistical_service.calculate_mean(data),
        median: statistical_service.calculate_median(data),
        standard_deviation: statistical_service.calculate_standard_deviation(data),
        variance: statistical_service.calculate_variance(data),
        skewness: statistical_service.calculate_skewness(data),
        kurtosis: statistical_service.calculate_kurtosis(data),
        min: data.min,
        max: data.max,
        range: data.max - data.min,
        quartiles: statistical_service.calculate_quartiles(data),
        outliers: statistical_service.detect_outliers(data),
        confidence_intervals: statistical_service.calculate_confidence_intervals(data, 0.95)
      }
    end
  rescue StandardError => e
    handle_calculation_error(e, 'statistical_insights', metric)
  end

  # Calculate derived metrics
  def calculate_derived_metrics(metric)
    case metric.metric_type.to_sym
    when :conversion
      calculate_conversion_rate(metric)
    when :customer_lifetime_value
      calculate_clv_score(metric)
    when :bounce_rate
      calculate_engagement_score(metric)
    else
      {}
    end
  rescue StandardError => e
    handle_calculation_error(e, 'derived_metrics', metric)
  end

  # Calculate seasonal factors
  def calculate_seasonal_factor(metric)
    cache_key = "seasonal_factor:#{metric.metric_name}:#{metric.date}"

    cache.fetch(cache_key, expires_in: cache_expiration(:long)) do
      SeasonalAnalysisService.calculate_seasonal_factor(
        metric_name: metric.metric_name,
        date: metric.date
      )
    end
  rescue StandardError => e
    handle_calculation_error(e, 'seasonal_factor', metric)
  end

  # Determine business cycle phase
  def determine_business_cycle_phase(metric)
    cache_key = "business_cycle:#{metric.metric_type}:#{metric.date}"

    cache.fetch(cache_key, expires_in: cache_expiration(:long)) do
      BusinessCycleService.determine_phase(
        metric_type: metric.metric_type,
        date: metric.date,
        value: metric.value
      )
    end
  rescue StandardError => e
    handle_calculation_error(e, 'business_cycle', metric)
  end

  # Calculate external correlations
  def calculate_external_correlations(metric)
    cache_key = "external_correlations:#{metric.id}"

    cache.fetch(cache_key, expires_in: cache_expiration(:medium)) do
      ExternalCorrelationService.calculate_correlations(
        metric: metric,
        factors: external_factors
      )
    end
  rescue StandardError => e
    handle_calculation_error(e, 'external_correlations', metric)
  end

  # Calculate volatility score
  def calculate_volatility_score(metric)
    return 0.1 unless metric.standard_deviation && metric.mean_value

    # Coefficient of variation
    (metric.standard_deviation / metric.mean_value.abs) * 100
  rescue StandardError => e
    handle_calculation_error(e, 'volatility_score', metric)
  end

  # Calculate mean value for metric
  def calculate_mean_value(metric)
    return metric.value unless metric.parent_metric

    # Calculate weighted mean from child metrics
    child_values = metric.child_metrics.pluck(:value)
    statistical_service.calculate_weighted_mean(child_values)
  rescue StandardError => e
    handle_calculation_error(e, 'mean_value', metric)
  end

  # Calculate standard deviation
  def calculate_standard_deviation(metric)
    return 0.0 unless metric.parent_metric

    values = metric.child_metrics.pluck(:value)
    statistical_service.calculate_standard_deviation(values)
  rescue StandardError => e
    handle_calculation_error(e, 'standard_deviation', metric)
  end

  # Determine trend direction
  def determine_trend_direction(metric)
    return :stable unless metric.parent_metric

    trend_analysis = calculate_trend_analysis(metric, days: 7)
    trend_analysis[:direction]
  rescue StandardError => e
    handle_calculation_error(e, 'trend_direction', metric)
  end

  # Perform advanced statistical analysis
  def perform_advanced_analysis(metric, analysis_type: :comprehensive)
    case analysis_type.to_sym
    when :comprehensive
      comprehensive_analysis(metric)
    when :trend
      trend_only_analysis(metric)
    when :seasonal
      seasonal_analysis(metric)
    when :correlation
      correlation_analysis(metric)
    else
      raise ArgumentError, "Unknown analysis type: #{analysis_type}"
    end
  rescue StandardError => e
    handle_calculation_error(e, 'advanced_analysis', metric)
  end

  # Calculate cohort analysis
  def calculate_cohort_analysis(metric, cohort_period: 30.days)
    cache_key = "cohort_analysis:#{metric.id}:#{cohort_period}"

    cache.fetch(cache_key, expires_in: cache_expiration(:long)) do
      CohortAnalysisService.analyze(
        metric: metric,
        period: cohort_period
      )
    end
  rescue StandardError => e
    handle_calculation_error(e, 'cohort_analysis', metric)
  end

  # Calculate segmentation analysis
  def calculate_segmentation_analysis(metric, segments: [])
    cache_key = "segmentation_analysis:#{metric.id}:#{segments.hash}"

    cache.fetch(cache_key, expires_in: cache_expiration(:medium)) do
      SegmentationAnalysisService.analyze(
        metric: metric,
        segments: segments
      )
    end
  rescue StandardError => e
    handle_calculation_error(e, 'segmentation_analysis', metric)
  end

  # Calculate lifetime value analysis
  def calculate_lifetime_value_analysis(metric)
    cache_key = "lifetime_value:#{metric.id}"

    cache.fetch(cache_key, expires_in: cache_expiration(:long)) do
      LifetimeValueService.calculate(
        metric: metric
      )
    end
  rescue StandardError => e
    handle_calculation_error(e, 'lifetime_value', metric)
  end

  # Calculate ROI analysis
  def calculate_roi_analysis(metric, investment_data: {})
    cache_key = "roi_analysis:#{metric.id}:#{investment_data.hash}"

    cache.fetch(cache_key, expires_in: cache_expiration(:medium)) do
      ROIAnalysisService.calculate(
        metric: metric,
        investment: investment_data
      )
    end
  rescue StandardError => e
    handle_calculation_error(e, 'roi_analysis', metric)
  end

  # Calculate efficiency metrics
  def calculate_efficiency_metrics(metric)
    cache_key = "efficiency_metrics:#{metric.id}"

    cache.fetch(cache_key, expires_in: cache_expiration(:medium)) do
      EfficiencyAnalysisService.calculate(
        metric: metric
      )
    end
  rescue StandardError => e
    handle_calculation_error(e, 'efficiency_metrics', metric)
  end

  # Calculate demand forecasting
  def calculate_demand_forecast(metric, horizon: 90.days)
    cache_key = "demand_forecast:#{metric.id}:#{horizon}"

    cache.fetch(cache_key, expires_in: cache_expiration(:long)) do
      DemandForecastingService.forecast(
        metric: metric,
        horizon: horizon
      )
    end
  rescue StandardError => e
    handle_calculation_error(e, 'demand_forecast', metric)
  end

  # Calculate inventory optimization
  def calculate_inventory_optimization(metric)
    cache_key = "inventory_optimization:#{metric.id}"

    cache.fetch(cache_key, expires_in: cache_expiration(:medium)) do
      InventoryOptimizationService.optimize(
        metric: metric
      )
    end
  rescue StandardError => e
    handle_calculation_error(e, 'inventory_optimization', metric)
  end

  # Calculate popularity metrics
  def calculate_popularity_metrics(metric)
    cache_key = "popularity_metrics:#{metric.id}"

    cache.fetch(cache_key, expires_in: cache_expiration(:medium)) do
      PopularityAnalysisService.calculate(
        metric: metric
      )
    end
  rescue StandardError => e
    handle_calculation_error(e, 'popularity_metrics', metric)
  end

  # Calculate optimization recommendations
  def calculate_optimization_recommendations(metric)
    cache_key = "optimization_recommendations:#{metric.id}"

    cache.fetch(cache_key, expires_in: cache_expiration(:medium)) do
      OptimizationService.recommend(
        metric: metric
      )
    end
  rescue StandardError => e
    handle_calculation_error(e, 'optimization_recommendations', metric)
  end

  # Calculate sentiment analysis
  def calculate_sentiment_analysis(metric)
    cache_key = "sentiment_analysis:#{metric.id}"

    cache.fetch(cache_key, expires_in: cache_expiration(:medium)) do
      SentimentAnalysisService.analyze(
        metric: metric
      )
    end
  rescue StandardError => e
    handle_calculation_error(e, 'sentiment_analysis', metric)
  end

  # Calculate correlation analysis
  def calculate_correlation_analysis(metric)
    cache_key = "correlation_analysis:#{metric.id}"

    cache.fetch(cache_key, expires_in: cache_expiration(:medium)) do
      CorrelationAnalysisService.analyze(
        metric: metric
      )
    end
  rescue StandardError => e
    handle_calculation_error(e, 'correlation_analysis', metric)
  end

  private

  def get_historical_data(metric, days)
    # Retrieve historical data for the metric
    AnalyticsMetric.where(metric_name: metric.metric_name)
                   .where('date >= ?', days.ago)
                   .order(date: :asc)
                   .pluck(:value)
  end

  def prepare_training_data(metric, size)
    # Prepare training data for ML models
    get_historical_data(metric, size)
  end

  def predictive_analytics_enabled?(metric)
    metric_type_config(metric.metric_type)[:predictive_analytics]
  end

  def comprehensive_analysis(metric)
    {
      trend: calculate_trend_analysis(metric),
      forecast: generate_predictive_forecast(metric),
      statistical: calculate_statistical_insights(metric),
      derived: calculate_derived_metrics(metric),
      seasonal: calculate_seasonal_factor(metric),
      business_cycle: determine_business_cycle_phase(metric),
      correlations: calculate_external_correlations(metric),
      volatility: calculate_volatility_score(metric)
    }
  end

  def trend_only_analysis(metric)
    {
      trend: calculate_trend_analysis(metric),
      direction: determine_trend_direction(metric)
    }
  end

  def seasonal_analysis(metric)
    {
      seasonal_factor: calculate_seasonal_factor(metric),
      business_cycle: determine_business_cycle_phase(metric)
    }
  end

  def correlation_analysis(metric)
    {
      external_correlations: calculate_external_correlations(metric),
      statistical_correlations: calculate_correlation_analysis(metric)
    }
  end

  def calculate_conversion_rate(metric)
    # Implementation for conversion rate calculation
    {}
  end

  def calculate_clv_score(metric)
    # Implementation for CLV calculation
    {}
  end

  def calculate_engagement_score(metric)
    # Implementation for engagement score calculation
    {}
  end

  def enrich_trend_with_context(trend, metric)
    # Add contextual information to trend analysis
    trend.merge(
      metric_name: metric.metric_name,
      metric_type: metric.metric_type,
      context: {
        seasonal_factor: calculate_seasonal_factor(metric),
        business_cycle: determine_business_cycle_phase(metric)
      }
    )
  end

  def enrich_forecast_with_context(forecast, metric)
    # Add contextual information to forecast
    forecast.merge(
      metric_name: metric.metric_name,
      confidence_threshold: prediction_confidence_threshold,
      model_version: '1.0'
    )
  end

  def cache_expiration(type)
    CACHE_EXPIRATION[type.to_sym] || 15.minutes
  end

  def handle_calculation_error(error, operation, metric)
    Rails.logger.error("#{operation} failed for metric #{metric.id}: #{error.message}")
    # Implement fallback calculations or error recovery
    {}
  end
end