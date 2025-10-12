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
    return 0 if control_views.zero?
    (control_conversions.to_f / control_views * 100).round(2)
  end
  
  def variant_conversion_rate
    return 0 if variant_views.zero?
    (variant_conversions.to_f / variant_views * 100).round(2)
  end
  
  # Calculate improvement
  def conversion_improvement
    return 0 if control_conversion_rate.zero?
    ((variant_conversion_rate - control_conversion_rate) / control_conversion_rate * 100).round(2)
  end
  
  # Calculate statistical significance (simplified z-test)
  def calculate_significance
    return 0 if control_views.zero? || variant_views.zero?
    
    p1 = control_conversions.to_f / control_views
    p2 = variant_conversions.to_f / variant_views
    
    p_pool = (control_conversions + variant_conversions).to_f / (control_views + variant_views)
    
    se = Math.sqrt(p_pool * (1 - p_pool) * (1.0/control_views + 1.0/variant_views))
    
    return 0 if se.zero?
    
    z_score = (p2 - p1) / se
    
    # Convert z-score to confidence level (simplified)
    confidence = (1 - Math.exp(-z_score.abs)) * 100
    
    update!(confidence_level: confidence.round(2))
    confidence.round(2)
  end
  
  # Determine winner
  def determine_winner
    return nil unless active? || completed?
    
    significance = calculate_significance
    
    # Need at least 95% confidence and 100 views per variant
    return nil if significance < 95 || control_views < 100 || variant_views < 100
    
    winner = variant_conversion_rate > control_conversion_rate ? 'variant' : 'control'
    
    update!(
      winner: winner,
      status: :completed,
      ended_at: Time.current,
      results: {
        control_conversion_rate: control_conversion_rate,
        variant_conversion_rate: variant_conversion_rate,
        improvement: conversion_improvement,
        confidence: significance,
        winner: winner
      }
    )
    
    winner
  end
  
  # Record a view
  def record_view(variant_type)
    if variant_type == 'control'
      increment!(:control_views)
    else
      increment!(:variant_views)
    end
  end
  
  # Record a conversion
  def record_conversion(variant_type)
    if variant_type == 'control'
      increment!(:control_conversions)
    else
      increment!(:variant_conversions)
    end
    
    # Check if we can determine a winner
    determine_winner if active?
  end
  
  # Get price for variant
  def price_for_variant(variant_type)
    variant_type == 'control' ? control_price_cents : variant_price_cents
  end
  
  # Assign variant to user (50/50 split)
  def assign_variant
    rand < 0.5 ? 'control' : 'variant'
  end
  
  # Check if experiment has enough data
  def has_sufficient_data?
    control_views >= 100 && variant_views >= 100
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
  
  private
  
  def duration_days
    return 0 unless started_at
    end_date = ended_at || Time.current
    ((end_date - started_at) / 1.day).round
  end
end

