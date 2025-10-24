class PriceExperiment < ApplicationRecord
  belongs_to :product
  belongs_to :user
  
  # Status
  enum status: {
    draft: 0,
    active: 1,
    paused: 2,
    completed: 3,
    archived: 4
  }
  
  validates :name, presence: true
  validates :control_price_cents, presence: true, numericality: { greater_than: 0 }
  validates :variant_price_cents, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true
  
  scope :active, -> { where(status: :active) }
  scope :completed, -> { where(status: :completed) }
  scope :recent, -> { order(created_at: :desc) }
  
  # Calculate conversion rates
  def control_conversion_rate
    calculation_service.control_conversion_rate
  end

  def variant_conversion_rate
    calculation_service.variant_conversion_rate
  end

  # Calculate improvement
  def conversion_improvement
    calculation_service.conversion_improvement
  end

  # Calculate statistical significance (simplified z-test)
  def calculate_significance
    calculation_service.calculate_significance
  end

  # Determine winner
  def determine_winner
    management_service.determine_winner
  end
  
  # Record a view
  def record_view(variant_type)
    management_service.record_view(variant_type)
  end

  # Record a conversion
  def record_conversion(variant_type)
    management_service.record_conversion(variant_type)
  end

  # Get price for variant
  def price_for_variant(variant_type)
    management_service.price_for_variant(variant_type)
  end

  # Assign variant to user (50/50 split)
  def assign_variant
    management_service.assign_variant
  end

  # Check if experiment has enough data
  def has_sufficient_data?
    management_service.has_sufficient_data?
  end
  
  # Get experiment summary
  def summary
    {
      name: name,
      status: status,
      control: {
        price: control_price_cents,
        views: control_views,
        conversions: control_conversions,
        conversion_rate: control_conversion_rate
      },
      variant: {
        price: variant_price_cents,
        views: variant_views,
        conversions: variant_conversions,
        conversion_rate: variant_conversion_rate
      },
      improvement: conversion_improvement,
      confidence: confidence_level,
      winner: winner,
      duration_days: duration_days
    }
    end

  # Additional methods that delegate to services
  def price_elasticity
    calculation_service.price_elasticity
  end

  def revenue_impact
    calculation_service.revenue_impact
  end

  def statistical_power
    calculation_service.statistical_power
  end

  def start_experiment!
    management_service.start_experiment!
  end

  def pause_experiment!
    management_service.pause_experiment!
  end

  def resume_experiment!
    management_service.resume_experiment!
  end

  def stop_experiment!(reason = nil)
    management_service.stop_experiment!(reason)
  end

  def archive_experiment!
    management_service.archive_experiment!
  end

  def experiment_summary
    {
      name: name,
      status: status,
      control: {
        price: control_price_cents,
        views: control_views,
        conversions: control_conversions,
        conversion_rate: control_conversion_rate
      },
      variant: {
        price: variant_price_cents,
        views: variant_views,
        conversions: variant_conversions,
        conversion_rate: variant_conversion_rate
      },
      improvement: conversion_improvement,
      confidence: confidence_level,
      winner: winner,
      duration_days: duration_days,
      price_elasticity: price_elasticity,
      revenue_impact: revenue_impact,
      statistical_power: statistical_power
    }
  end

  private

  def calculation_service
    @calculation_service ||= PriceExperimentCalculationService.new(self)
  end

  def management_service
    @management_service ||= PriceExperimentManagementService.new(self)
  end

  def duration_days
    return 0 unless started_at
    end_date = ended_at || Time.current
    ((end_date - started_at) / 1.day).round
  end</search>
</search_and_replace>
end

