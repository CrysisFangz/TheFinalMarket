class ProductAbTest < ApplicationRecord
  belongs_to :product
  belongs_to :seller, class_name: 'User'
  
  has_many :ab_test_variants, dependent: :destroy
  has_many :ab_test_impressions, dependent: :destroy
  
  validates :test_name, presence: true
  validates :test_type, presence: true
  
  scope :active, -> { where(status: :active) }
  scope :completed, -> { where(status: :completed) }
  
  # Test types
  enum test_type: {
    title: 0,
    description: 1,
    price: 2,
    images: 3,
    call_to_action: 4,
    product_features: 5
  }
  
  # Test status
  enum status: {
    draft: 0,
    active: 1,
    paused: 2,
    completed: 3
  }
  
  # Start test
  def start!
    return false unless draft?
    return false if ab_test_variants.count < 2
    
    update!(
      status: :active,
      started_at: Time.current
    )
  end
  
  # Stop test
  def stop!
    update!(
      status: :completed,
      completed_at: Time.current
    )
    
    # Determine winner
    determine_winner
  end
  
  # Record impression
  def record_impression(variant, user)
    ab_test_impressions.create!(
      ab_test_variant: variant,
      user: user,
      viewed_at: Time.current
    )
  end
  
  # Record conversion
  def record_conversion(variant, user, order)
    impression = ab_test_impressions.find_by(
      ab_test_variant: variant,
      user: user
    )
    
    return unless impression
    
    impression.update!(
      converted: true,
      converted_at: Time.current,
      order: order,
      revenue_cents: order.total_cents
    )
  end
  
  # Get results
  def results
    variants_data = ab_test_variants.map do |variant|
      impressions = ab_test_impressions.where(ab_test_variant: variant)
      conversions = impressions.where(converted: true)
      
      {
        variant: variant,
        impressions: impressions.count,
        conversions: conversions.count,
        conversion_rate: calculate_conversion_rate(impressions, conversions),
        revenue: conversions.sum(:revenue_cents) / 100.0,
        average_order_value: calculate_aov(conversions),
        statistical_significance: calculate_significance(variant)
      }
    end
    
    {
      test_name: test_name,
      test_type: test_type,
      status: status,
      started_at: started_at,
      duration_days: duration_days,
      variants: variants_data,
      winner: winning_variant,
      recommendation: generate_recommendation
    }
  end
  
  # Determine winner
  def determine_winner
    return if ab_test_variants.count < 2
    
    winner = ab_test_variants.max_by do |variant|
      impressions = ab_test_impressions.where(ab_test_variant: variant)
      conversions = impressions.where(converted: true)
      calculate_conversion_rate(impressions, conversions)
    end
    
    update!(winning_variant_id: winner.id)
    
    winner
  end
  
  # Apply winner
  def apply_winner!
    return unless winning_variant_id
    
    winner = ab_test_variants.find(winning_variant_id)
    
    case test_type.to_sym
    when :title
      product.update!(name: winner.variant_data['title'])
    when :description
      product.update!(description: winner.variant_data['description'])
    when :price
      product.update!(price_cents: winner.variant_data['price_cents'])
    when :call_to_action
      product.update!(cta_text: winner.variant_data['cta_text'])
    end
    
    update!(applied: true, applied_at: Time.current)
  end
  
  # Check if statistically significant
  def statistically_significant?
    return false if ab_test_variants.count < 2
    
    variants = ab_test_variants.limit(2)
    
    variant_a = variants.first
    variant_b = variants.second
    
    significance = calculate_significance_between(variant_a, variant_b)
    
    significance > 95 # 95% confidence level
  end
  
  private
  
  def duration_days
    return 0 unless started_at
    
    end_time = completed_at || Time.current
    ((end_time - started_at) / 1.day).round
  end
  
  def calculate_conversion_rate(impressions, conversions)
    return 0 if impressions.count.zero?
    
    (conversions.count.to_f / impressions.count * 100).round(2)
  end
  
  def calculate_aov(conversions)
    return 0 if conversions.count.zero?
    
    (conversions.sum(:revenue_cents) / conversions.count.to_f / 100).round(2)
  end
  
  def calculate_significance(variant)
    return 0 if ab_test_variants.count < 2
    
    control = ab_test_variants.where(is_control: true).first || ab_test_variants.first
    return 0 if variant == control
    
    calculate_significance_between(control, variant)
  end
  
  def calculate_significance_between(variant_a, variant_b)
    # Simplified chi-square test
    impressions_a = ab_test_impressions.where(ab_test_variant: variant_a).count
    conversions_a = ab_test_impressions.where(ab_test_variant: variant_a, converted: true).count
    
    impressions_b = ab_test_impressions.where(ab_test_variant: variant_b).count
    conversions_b = ab_test_impressions.where(ab_test_variant: variant_b, converted: true).count
    
    return 0 if impressions_a.zero? || impressions_b.zero?
    
    rate_a = conversions_a.to_f / impressions_a
    rate_b = conversions_b.to_f / impressions_b
    
    pooled_rate = (conversions_a + conversions_b).to_f / (impressions_a + impressions_b)
    
    se = Math.sqrt(pooled_rate * (1 - pooled_rate) * (1.0/impressions_a + 1.0/impressions_b))
    
    return 0 if se.zero?
    
    z_score = ((rate_b - rate_a) / se).abs
    
    # Convert z-score to confidence level (simplified)
    if z_score > 2.58
      99
    elsif z_score > 1.96
      95
    elsif z_score > 1.65
      90
    else
      50
    end
  end
  
  def winning_variant
    return nil unless winning_variant_id
    
    ab_test_variants.find(winning_variant_id)
  end
  
  def generate_recommendation
    return "Test is still running" if active?
    return "Not enough data" if ab_test_impressions.count < 100
    
    if statistically_significant?
      winner = winning_variant
      "Apply variant '#{winner.variant_name}' - statistically significant improvement"
    else
      "No clear winner. Consider running test longer or trying different variants"
    end
  end
end

