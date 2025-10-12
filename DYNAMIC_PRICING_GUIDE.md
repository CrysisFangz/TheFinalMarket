# Dynamic Pricing Engine Guide

## Overview

The Final Market's Dynamic Pricing Engine is an AI-powered system that automatically optimizes product prices based on multiple factors including demand, competition, inventory levels, and market conditions. This system helps sellers maximize revenue while remaining competitive.

---

## Features

### 1. AI-Powered Price Optimization

**What is it?**
The system uses machine learning algorithms to calculate the optimal price for each product based on historical data, current market conditions, and predictive analytics.

**How it works:**
- Analyzes product views, sales velocity, and conversion rates
- Monitors competitor pricing in real-time
- Considers inventory levels and seasonality
- Calculates price elasticity
- Provides confidence scores for recommendations

**Benefits:**
- 📈 Increase revenue by 15-30%
- 🎯 Improve conversion rates
- 💰 Maximize profit margins
- ⚡ Real-time price adjustments

---

### 2. Pricing Rule Types

#### Time-Based Pricing
Adjust prices based on time of day, day of week, or specific dates.

**Use Cases:**
- Flash sales (limited time discounts)
- Happy hour pricing (specific hours)
- Weekend specials
- Holiday pricing

**Example Configuration:**
```ruby
{
  flash_sale_active: true,
  flash_sale_discount: 30,
  happy_hours: [14, 15, 16] # 2-4 PM
}
```

#### Inventory-Based Pricing
Automatically adjust prices based on stock levels.

**Use Cases:**
- Clearance sales for low stock
- Premium pricing for limited availability
- Automatic discounts to move inventory

**Example Configuration:**
```ruby
{
  low_stock_threshold: 10,
  clearance_discount: 25
}
```

#### Demand-Based Pricing (Surge Pricing)
Increase prices during high demand, decrease during low demand.

**Use Cases:**
- Surge pricing for trending products
- Discounts for slow-moving items
- Dynamic adjustment based on traffic

**Example Configuration:**
```ruby
{
  high_demand_threshold: 50,
  surge_percentage: 15,
  low_demand_threshold: 5,
  low_demand_discount: 10
}
```

#### Competitor-Based Pricing
Match or beat competitor prices automatically.

**Use Cases:**
- Price matching guarantees
- Undercutting competitors
- Premium positioning

**Strategies:**
- `match_lowest`: Match the lowest competitor price
- `undercut`: Beat competitors by X%
- `match_average`: Match average market price
- `premium`: Stay above market by X%

**Example Configuration:**
```ruby
{
  competitor_strategy: 'undercut',
  undercut_percentage: 5
}
```

#### Seasonal Pricing
Adjust prices based on seasons or months.

**Use Cases:**
- Holiday pricing
- Seasonal product adjustments
- Back-to-school sales

**Example Configuration:**
```ruby
{
  seasonal_adjustments: {
    '11' => 10,  # November: +10%
    '12' => 15,  # December: +15%
    '1' => -20   # January: -20%
  }
}
```

#### Bundle Pricing
Offer discounts for multiple item purchases.

**Use Cases:**
- Buy 2 get 5% off
- Bulk purchase discounts
- Package deals

**Example Configuration:**
```ruby
{
  bundle_discount_tier1: 5,   # 2-4 items
  bundle_discount_tier2: 10,  # 5-9 items
  bundle_discount_tier3: 15   # 10+ items
}
```

#### Volume Pricing
Tiered pricing based on quantity.

**Use Cases:**
- Wholesale pricing
- Bulk discounts
- B2B pricing

**Example Configuration:**
```ruby
{
  volume_tiers: [
    { min: 10, discount: 5 },
    { min: 50, discount: 10 },
    { min: 100, discount: 15 }
  ]
}
```

#### AI-Optimized Dynamic Pricing
Fully automated pricing using machine learning.

**Use Cases:**
- Hands-off price optimization
- Complex multi-factor pricing
- Continuous improvement

---

### 3. Pricing Rule Conditions

Add conditions to control when rules apply:

**Condition Types:**
- `time_of_day`: Specific hours (0-23)
- `day_of_week`: Days (0=Sunday, 6=Saturday)
- `stock_level`: Current inventory
- `view_count`: Product views (24h)
- `sales_velocity`: Sales rate (7d)
- `competitor_price`: Competitor pricing
- `user_segment`: Customer type
- `cart_value`: Shopping cart total
- `product_age`: Days since listing
- `season`: Current season

**Operators:**
- `equals`, `not_equals`
- `greater_than`, `less_than`
- `greater_than_or_equal`, `less_than_or_equal`
- `between`
- `in_list`, `not_in_list`

**Example:**
```ruby
# Only apply flash sale on weekends
PricingRuleCondition.create!(
  pricing_rule: rule,
  condition_type: :day_of_week,
  operator: :in_list,
  value: '0,6' # Sunday and Saturday
)
```

---

### 4. Competitor Price Monitoring

**Features:**
- Track competitor prices across multiple platforms
- Automatic price scraping (API or web scraping)
- Historical price tracking
- Significant change alerts

**Supported Competitors:**
- Amazon
- eBay
- Walmart
- Target
- Best Buy
- Custom competitors

**How it works:**
1. Schedule `CompetitorPriceScraperJob` to run daily
2. System fetches prices from competitor sites
3. Prices are stored and tracked over time
4. Pricing rules automatically adjust based on competitor data

---

### 5. Price Analytics & Insights

**Metrics Tracked:**
- Price optimization score (0-100)
- Total price changes
- Revenue impact
- Conversion rate impact
- Price elasticity
- Competitive position

**Analytics Dashboard:**
- Performance overview
- Pricing trends over time
- Rule effectiveness
- A/B test results
- Elasticity analysis
- Competitive analysis

**Insights Provided:**
- Demand trends (growing/declining)
- Competitive position (low/competitive/high)
- Optimal price range
- Revenue projections
- Margin analysis

---

### 6. Price Experiments (A/B Testing)

Test different price points to find the optimal price.

**How it works:**
1. Create experiment with control and variant prices
2. System randomly assigns prices to visitors
3. Track views and conversions for each variant
4. Calculate statistical significance
5. Declare winner when confidence level is reached

**Metrics:**
- Conversion rate
- Revenue per visitor
- Statistical confidence
- Z-score

---

## User Interface

### Pricing Dashboard
Access at `/seller/pricing`

**Sections:**
1. **Performance Overview**
   - Optimization score
   - Price changes count
   - Revenue impact
   - Average price change

2. **Products Table**
   - Current price
   - Recommended price
   - Price change percentage
   - Active rules
   - Quick actions

3. **Quick Stats**
   - Top performing rules
   - Conversion impact
   - Quick actions

### Product Pricing Page
Access at `/seller/pricing/:product_id`

**Features:**
- Current price vs recommended price
- Confidence score
- Detailed reasoning
- Expected impact projections
- Price history chart
- Active rules list
- One-click price application

### Analytics Page
Access at `/seller/pricing/analytics`

**Features:**
- 30-day performance metrics
- Elasticity analysis
- Competitive analysis
- Pricing trends chart
- Rule performance report

### Pricing Rules Page
Access at `/seller/pricing/rules`

**Features:**
- List of all pricing rules
- Rule templates
- Create/edit/delete rules
- Rule conditions management

---

## API Integration

### Calculate Optimal Price

```ruby
service = DynamicPricingService.new(product)
optimal_price = service.optimal_price
```

### Get Price Recommendation

```ruby
service = DynamicPricingService.new(product)
recommendation = service.price_recommendation

# Returns:
{
  current_price: 9999,
  recommended_price: 10499,
  change_percentage: 5.0,
  confidence: 85,
  reasoning: "High demand detected - price increase recommended",
  expected_impact: {
    volume_change_percentage: -2.5,
    revenue_change_percentage: 2.4,
    estimated_units_per_week: 39,
    estimated_revenue_per_week: 409461
  },
  factors: { ... }
}
```

### Apply Pricing Rules

```ruby
service = DynamicPricingService.new(product)
new_price = service.apply_pricing_rules(context)
```

### Get Pricing Insights

```ruby
service = DynamicPricingService.new(product)
insights = service.pricing_insights

# Returns:
{
  elasticity: 1.2,
  demand_trend: 'growing',
  competitor_position: 'competitive',
  optimal_price_range: { min: 9500, optimal: 10000, max: 10500 },
  revenue_projection: { ... },
  margin_analysis: { ... }
}
```

### Track Price Change

```ruby
PriceChange.create!(
  product: product,
  old_price_cents: 9999,
  new_price_cents: 10499,
  user: current_user,
  reason: "Applied AI recommendation"
)
```

---

## Database Schema

### Tables

**pricing_rules**
- Product and user associations
- Rule type, status, priority
- Min/max price constraints
- Date range
- Configuration (JSONB)

**pricing_rule_conditions**
- Condition type and operator
- Value to compare
- Associated pricing rule

**price_changes**
- Historical price changes
- Old and new prices
- Reason and metadata
- Associated rule (if automated)

**competitor_prices**
- Competitor name
- Product identifier (SKU)
- Current and previous prices
- URL and stock status
- Last checked timestamp

**price_experiments**
- A/B test configuration
- Control and variant prices
- Views and conversions
- Statistical results

### Product Columns Added
- `cost_cents`: Product cost for margin calculations
- `min_price_cents`: Minimum allowed price
- `max_price_cents`: Maximum allowed price
- `auto_pricing_enabled`: Enable/disable auto-pricing
- `last_price_update_at`: Last price change timestamp
- `price_optimization_score`: Current optimization score

---

## Setup Instructions

### 1. Run Migrations

```bash
rails db:migrate
```

### 2. Seed Initial Data

```bash
# Load pricing seeds
load Rails.root.join('db/seeds/pricing_seeds.rb')
```

### 3. Schedule Background Jobs

Add to `config/schedule.rb` (using whenever gem):

```ruby
# Optimize prices hourly
every 1.hour do
  runner "PricingOptimizationJob.perform_later"
end

# Scrape competitor prices daily
every 1.day, at: '2:00 am' do
  runner "CompetitorPriceScraperJob.perform_later"
end
```

Or use Sidekiq cron:

```ruby
# config/initializers/sidekiq.rb
Sidekiq::Cron::Job.create(
  name: 'Pricing Optimization',
  cron: '0 * * * *', # Every hour
  class: 'PricingOptimizationJob'
)

Sidekiq::Cron::Job.create(
  name: 'Competitor Price Scraping',
  cron: '0 2 * * *', # Daily at 2 AM
  class: 'CompetitorPriceScraperJob'
)
```

### 4. Configure Redis (for analytics)

Ensure Redis is running for real-time analytics caching.

---

## Best Practices

### For Sellers

1. **Set Price Bounds**: Always set min/max prices to prevent extreme changes
2. **Start Conservative**: Begin with small adjustments (5-10%)
3. **Monitor Results**: Check analytics weekly
4. **Test Gradually**: Use A/B tests before full rollout
5. **Consider Margins**: Ensure minimum 20% profit margin

### For Developers

1. **Cache Aggressively**: Cache optimal prices for 1 hour
2. **Background Processing**: Run optimization jobs asynchronously
3. **Monitor Performance**: Track job execution times
4. **Error Handling**: Gracefully handle scraping failures
5. **Rate Limiting**: Respect competitor site rate limits

---

## Troubleshooting

### Prices Not Updating
- Check if `auto_pricing_enabled` is true
- Verify pricing rules are active
- Check background job queue
- Review min/max price constraints

### Competitor Prices Not Scraping
- Verify API credentials
- Check rate limits
- Review scraper logs
- Ensure product SKUs match

### Low Optimization Score
- Insufficient historical data
- No competitor price data
- Prices already optimal
- Need more active rules

---

## Future Enhancements

- [ ] Machine learning model training
- [ ] Multi-currency support
- [ ] Geographic pricing
- [ ] Customer segment pricing
- [ ] Predictive demand forecasting
- [ ] Automated A/B test creation
- [ ] Price recommendation notifications
- [ ] Bulk rule management
- [ ] Advanced analytics dashboards
- [ ] Integration with more competitors

---

## Support

For questions or issues:
- Review this documentation
- Check the ENHANCEMENTS_ROADMAP.md
- Contact development team

---

## Credits

Dynamic Pricing Engine v1.0
Developed for The Final Market
Built with Ruby on Rails 8.0, AI/ML algorithms, and real-time analytics

