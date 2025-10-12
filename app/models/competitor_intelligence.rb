class CompetitorIntelligence < ApplicationRecord
  belongs_to :product
  belongs_to :seller, class_name: 'User'
  
  validates :competitor_name, presence: true
  validates :data_source, presence: true
  
  scope :recent, -> { where('scraped_at > ?', 24.hours.ago) }
  scope :by_competitor, ->(name) { where(competitor_name: name) }
  scope :price_alerts, -> { where('price_difference_percentage > ?', 10) }
  
  # Data sources
  enum data_source: {
    manual: 0,
    web_scraper: 1,
    api: 2,
    price_comparison_site: 3
  }
  
  # Scrape competitor data
  def self.scrape_for_product(product)
    # This would integrate with web scraping service
    # For now, generate mock data
    
    competitors = [
      'Amazon',
      'eBay',
      'Walmart',
      'Target',
      'Best Buy'
    ]
    
    competitors.each do |competitor|
      create!(
        product: product,
        seller: product.seller,
        competitor_name: competitor,
        competitor_price_cents: product.price_cents + rand(-2000..2000),
        competitor_stock_status: ['in_stock', 'low_stock', 'out_of_stock'].sample,
        competitor_rating: rand(3.5..5.0).round(1),
        competitor_reviews_count: rand(10..1000),
        competitor_shipping_cost_cents: rand(0..1000),
        competitor_delivery_days: rand(2..7),
        data_source: :web_scraper,
        scraped_at: Time.current,
        competitor_url: "https://#{competitor.downcase}.com/product/#{product.id}"
      )
    end
  end
  
  # Analyze pricing
  def self.pricing_analysis(product)
    competitors = where(product: product).recent
    
    return nil if competitors.empty?
    
    prices = competitors.pluck(:competitor_price_cents)
    product_price = product.price_cents
    
    {
      your_price: product_price / 100.0,
      market_average: prices.sum / prices.count.to_f / 100.0,
      market_min: prices.min / 100.0,
      market_max: prices.max / 100.0,
      your_position: calculate_price_position(product_price, prices),
      price_competitiveness: calculate_competitiveness(product_price, prices),
      recommendation: generate_pricing_recommendation(product_price, prices)
    }
  end
  
  # Get price alerts
  def self.price_alerts(seller)
    alerts = []
    
    seller.products.each do |product|
      competitors = where(product: product).recent
      next if competitors.empty?
      
      avg_competitor_price = competitors.average(:competitor_price_cents).to_f
      price_diff = ((product.price_cents - avg_competitor_price) / avg_competitor_price * 100).round(2)
      
      if price_diff.abs > 10
        alerts << {
          product: product,
          your_price: product.price_cents / 100.0,
          market_average: avg_competitor_price / 100.0,
          difference_percentage: price_diff,
          alert_type: price_diff > 0 ? 'overpriced' : 'underpriced',
          recommendation: price_diff > 0 ? 'Consider lowering price' : 'Opportunity to increase price'
        }
      end
    end
    
    alerts
  end
  
  # Get market trends
  def self.market_trends(product, period = 30)
    data = where(product: product)
          .where('scraped_at > ?', period.days.ago)
          .order(:scraped_at)
    
    return nil if data.count < 7
    
    {
      price_trend: calculate_price_trend(data),
      stock_trend: calculate_stock_trend(data),
      rating_trend: calculate_rating_trend(data),
      market_share_estimate: estimate_market_share(product, data)
    }
  end
  
  # Competitive advantages
  def self.competitive_advantages(product)
    competitors = where(product: product).recent
    
    return [] if competitors.empty?
    
    advantages = []
    
    # Price advantage
    if product.price_cents < competitors.average(:competitor_price_cents)
      advantages << {
        type: 'price',
        description: 'Lower price than competitors',
        strength: 'high'
      }
    end
    
    # Rating advantage
    product_rating = product.average_rating || 0
    avg_competitor_rating = competitors.average(:competitor_rating).to_f
    
    if product_rating > avg_competitor_rating
      advantages << {
        type: 'rating',
        description: 'Higher customer rating',
        strength: 'medium'
      }
    end
    
    # Shipping advantage
    if product.free_shipping && competitors.where('competitor_shipping_cost_cents > 0').any?
      advantages << {
        type: 'shipping',
        description: 'Free shipping offered',
        strength: 'medium'
      }
    end
    
    # Delivery speed advantage
    product_delivery = product.estimated_delivery_days || 7
    avg_competitor_delivery = competitors.average(:competitor_delivery_days).to_f
    
    if product_delivery < avg_competitor_delivery
      advantages << {
        type: 'delivery',
        description: 'Faster delivery time',
        strength: 'high'
      }
    end
    
    advantages
  end
  
  # Competitive weaknesses
  def self.competitive_weaknesses(product)
    competitors = where(product: product).recent
    
    return [] if competitors.empty?
    
    weaknesses = []
    
    # Price disadvantage
    if product.price_cents > competitors.average(:competitor_price_cents) * 1.1
      weaknesses << {
        type: 'price',
        description: 'Higher price than competitors',
        severity: 'high'
      }
    end
    
    # Rating disadvantage
    product_rating = product.average_rating || 0
    avg_competitor_rating = competitors.average(:competitor_rating).to_f
    
    if product_rating < avg_competitor_rating - 0.5
      weaknesses << {
        type: 'rating',
        description: 'Lower customer rating',
        severity: 'medium'
      }
    end
    
    # Stock disadvantage
    if product.stock_quantity < 10 && competitors.where(competitor_stock_status: 'in_stock').count > 3
      weaknesses << {
        type: 'stock',
        description: 'Low stock compared to competitors',
        severity: 'medium'
      }
    end
    
    weaknesses
  end
  
  private
  
  def self.calculate_price_position(product_price, competitor_prices)
    sorted_prices = (competitor_prices + [product_price]).sort
    position = sorted_prices.index(product_price) + 1
    total = sorted_prices.count
    
    percentile = (position.to_f / total * 100).round
    
    case percentile
    when 0..25
      'lowest_quartile'
    when 26..50
      'below_average'
    when 51..75
      'above_average'
    else
      'highest_quartile'
    end
  end
  
  def self.calculate_competitiveness(product_price, competitor_prices)
    avg_price = competitor_prices.sum / competitor_prices.count.to_f
    diff_percentage = ((product_price - avg_price) / avg_price * 100).abs
    
    if diff_percentage < 5
      'highly_competitive'
    elsif diff_percentage < 10
      'competitive'
    elsif diff_percentage < 20
      'moderately_competitive'
    else
      'not_competitive'
    end
  end
  
  def self.generate_pricing_recommendation(product_price, competitor_prices)
    avg_price = competitor_prices.sum / competitor_prices.count.to_f
    min_price = competitor_prices.min
    
    if product_price > avg_price * 1.1
      "Consider lowering price to $#{(avg_price * 0.95 / 100.0).round(2)} to be more competitive"
    elsif product_price < min_price
      "You have the lowest price. Consider increasing to $#{(min_price * 1.05 / 100.0).round(2)} for better margins"
    else
      "Your pricing is competitive. Monitor competitors regularly."
    end
  end
  
  def self.calculate_price_trend(data)
    prices = data.group_by { |d| d.scraped_at.to_date }
                .map { |date, records| records.average(:competitor_price_cents) }
    
    return 'stable' if prices.count < 2
    
    first_half = prices.first(prices.count / 2).sum / (prices.count / 2).to_f
    second_half = prices.last(prices.count / 2).sum / (prices.count / 2).to_f
    
    change = ((second_half - first_half) / first_half * 100).round(2)
    
    if change > 5
      'increasing'
    elsif change < -5
      'decreasing'
    else
      'stable'
    end
  end
  
  def self.calculate_stock_trend(data)
    in_stock_count = data.where(competitor_stock_status: 'in_stock').count
    total_count = data.count
    
    availability_rate = (in_stock_count.to_f / total_count * 100).round(2)
    
    if availability_rate > 80
      'high_availability'
    elsif availability_rate > 50
      'moderate_availability'
    else
      'low_availability'
    end
  end
  
  def self.calculate_rating_trend(data)
    ratings = data.group_by { |d| d.scraped_at.to_date }
                 .map { |date, records| records.average(:competitor_rating) }
    
    return 'stable' if ratings.count < 2
    
    first_half = ratings.first(ratings.count / 2).sum / (ratings.count / 2).to_f
    second_half = ratings.last(ratings.count / 2).sum / (ratings.count / 2).to_f
    
    change = second_half - first_half
    
    if change > 0.2
      'improving'
    elsif change < -0.2
      'declining'
    else
      'stable'
    end
  end
  
  def self.estimate_market_share(product, competitor_data)
    # Simple estimation based on reviews count
    product_reviews = product.reviews_count || 0
    competitor_reviews = competitor_data.sum(:competitor_reviews_count)
    
    total_reviews = product_reviews + competitor_reviews
    return 0 if total_reviews.zero?
    
    (product_reviews.to_f / total_reviews * 100).round(2)
  end
end

