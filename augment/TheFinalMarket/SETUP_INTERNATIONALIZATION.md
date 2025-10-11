# Multi-Currency & Internationalization Setup Guide

## Quick Start

Follow these steps to set up the internationalization system:

### 1. Run Database Migrations

```bash
bin/rails db:migrate
```

This will create:
- `currencies` table (25+ currencies)
- `exchange_rates` table (historical rates)
- `countries` table (30+ countries)
- `shipping_zones` table (5 zones)
- `shipping_zone_countries` join table
- `shipping_rates` table (service levels)
- `tax_rates` table (regional taxes)
- `content_translations` table (multi-language)
- `user_currency_preferences` table
- Add columns to `users`, `products`, `orders` tables

### 2. Load Seed Data

```bash
bin/rails runner "load Rails.root.join('db/seeds/internationalization_seeds.rb')"
```

This will create:
- 25 currencies (USD, EUR, GBP, JPY, etc.)
- 30 countries with full details
- 5 shipping zones (Domestic, North America, Europe, Asia Pacific, Rest of World)
- 15 shipping rates (3 service levels per zone)
- 11 tax rates (VAT, GST, Sales Tax)
- Initial exchange rates (if API available)

### 3. Configure Environment Variables (Optional)

For better exchange rate accuracy, add API keys to `.env`:

```bash
# Exchange Rate APIs (choose one or more)
FIXER_API_KEY=your_fixer_api_key
OPENEXCHANGERATES_API_KEY=your_openexchangerates_key
CURRENCYAPI_KEY=your_currencyapi_key

# Translation APIs (optional)
GOOGLE_TRANSLATE_API_KEY=your_google_key
DEEPL_API_KEY=your_deepl_key

# Geocoding (for IP-based location detection)
GEOCODER_API_KEY=your_geocoder_key
```

**Note:** The system works without API keys using the free ExchangeRate-API service.

### 4. Configure Locales

Edit `config/application.rb`:

```ruby
# Add available locales
config.i18n.available_locales = [:en, :es, :fr, :de, :it, :ja, :zh, :pt, :ru, :ar, :hi]
config.i18n.default_locale = :en
config.i18n.fallbacks = true

# Load locale files
config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}')]
```

### 5. Set Up Scheduled Jobs

The exchange rate update job is already configured in `config/schedule.yml`:

```yaml
exchange_rate_update:
  cron: "0 * * * *"  # Every hour
  class: "ExchangeRateUpdateJob"
  queue: default
```

If using Sidekiq Cron, load the schedule:

```bash
# In Rails console
Sidekiq::Cron::Job.load_from_hash YAML.load_file('config/schedule.yml')
```

Or if using whenever:

```bash
whenever --update-crontab
```

### 6. Test the System

```bash
# Start Rails console
bin/rails console

# Test currency conversion
usd = Currency.find_by(code: 'USD')
eur = Currency.find_by(code: 'EUR')
ExchangeRateService.convert(10000, usd, eur)  # Convert $100 to EUR

# Test shipping calculation
zone = ShippingZone.for_country('GB')
zone.calculate_shipping(1000, 'standard')  # 1kg, standard shipping

# Test tax calculation
country = Country.find_by_code('GB')
country.calculate_tax(10000)  # Calculate VAT on £100

# Test internationalization service
i18n = InternationalizationService.new
i18n.detect_currency
i18n.format_price(9999)
```

### 7. Start the Application

```bash
bin/rails server
```

Visit the application and test:
- Currency selector
- Language selector
- Shipping calculator
- Multi-currency checkout

---

## API Endpoints

### Currency APIs

```bash
# Get all currencies
GET /currencies

# Get specific currency
GET /currencies/EUR

# Get exchange rate
GET /currencies/EUR/rate?from=USD&amount=10000
```

### Country APIs

```bash
# Get all countries
GET /countries

# Get countries with shipping support
GET /countries?shipping_supported=true

# Get specific country
GET /countries/GB
```

### Shipping APIs

```bash
# Calculate shipping
POST /shipping/calculate
{
  "country_code": "GB",
  "weight_grams": 1000
}

# Get shipping zones
GET /shipping/zones
```

### User Settings

```bash
# Update currency preference
POST /settings/update_currency
{
  "currency_code": "EUR"
}

# Update locale
POST /settings/update_locale
{
  "locale": "fr"
}

# Update timezone
POST /settings/update_timezone
{
  "timezone": "Europe/Paris"
}
```

---

## Configuration

### Add More Currencies

```ruby
Currency.create!(
  code: 'XYZ',
  name: 'Example Currency',
  symbol: 'X',
  symbol_position: 'before',
  decimal_places: 2,
  active: true,
  supported: true
)
```

### Add More Countries

```ruby
Country.create!(
  code: 'XY',
  name: 'Example Country',
  currency_code: 'USD',
  locale_code: 'en-XY',
  timezone: 'UTC',
  phone_code: '999',
  continent: 'Example',
  active: true,
  supported_for_shipping: true
)
```

### Configure Shipping Zones

```ruby
# Create zone
zone = ShippingZone.create!(
  name: 'Custom Zone',
  code: 'CUSTOM',
  priority: 10
)

# Add countries
zone.countries << Country.find_by(code: 'US')

# Add shipping rates
zone.shipping_rates.create!(
  service_level: :standard,
  base_rate_cents: 1000,
  per_kg_rate_cents: 300,
  min_delivery_days: 3,
  max_delivery_days: 7,
  includes_tracking: true
)
```

### Configure Tax Rates

```ruby
country = Country.find_by(code: 'US')

TaxRate.create!(
  country: country,
  name: 'Sales Tax',
  tax_type: 'sales_tax',
  rate: 8.5,
  included_in_price: false
)
```

---

## Troubleshooting

### Exchange rates not updating

**Problem:** Exchange rates are not being fetched

**Solutions:**
1. Check internet connectivity
2. Verify API keys in `.env`
3. Check API rate limits
4. Run manually: `ExchangeRateService.update_all_rates`
5. Check logs: `tail -f log/development.log`

### Currency not displaying correctly

**Problem:** Prices showing in wrong currency

**Solutions:**
1. Check user currency preference
2. Verify session currency
3. Check locale detection
4. Clear browser cookies
5. Check currency is active and supported

### Shipping not available

**Problem:** No shipping options for country

**Solutions:**
1. Verify country is supported: `Country.find_by_code('XX').supported_for_shipping?`
2. Check shipping zone exists: `ShippingZone.for_country('XX')`
3. Verify shipping rates are active
4. Check weight is within limits
5. Review zone configuration

### Tax calculation incorrect

**Problem:** Wrong tax amount

**Solutions:**
1. Verify tax rate: `Country.find_by_code('XX').tax_rate_for`
2. Check `included_in_price` setting
3. Verify product category
4. Check calculation logic
5. Review tax rate configuration

### Locale not changing

**Problem:** Language not switching

**Solutions:**
1. Check locale is in `available_locales`
2. Verify locale files exist
3. Check session/cookie
4. Clear cache
5. Restart server

---

## Performance Optimization

### Caching

```ruby
# Cache exchange rates (1 hour)
Rails.cache.fetch("exchange_rate:EUR", expires_in: 1.hour) do
  currency.current_exchange_rate
end

# Cache shipping zones
Rails.cache.fetch("shipping_zone:GB", expires_in: 1.day) do
  ShippingZone.for_country('GB')
end
```

### Database Indexes

All necessary indexes are created by the migration:
- Currency code (unique)
- Country code (unique)
- Exchange rates (currency_id, created_at)
- Shipping zones (code, active, priority)
- Tax rates (country_id, product_category)

### Eager Loading

```ruby
# Load with associations
Currency.includes(:exchange_rates)
Country.includes(:shipping_zones, :tax_rates)
ShippingZone.includes(:countries, :shipping_rates)
```

---

## Security Considerations

1. **API Keys:** Store in environment variables, never commit
2. **Rate Limiting:** Implement for currency/shipping APIs
3. **Input Validation:** Validate country codes, currency codes
4. **SQL Injection:** Use parameterized queries (ActiveRecord does this)
5. **XSS:** Sanitize user input in translations

---

## Monitoring

### Key Metrics to Track

1. Exchange rate update success rate
2. API call failures
3. Currency conversion errors
4. Shipping calculation time
5. Tax calculation accuracy

### Logging

```ruby
# Enable detailed logging
Rails.logger.info "Currency conversion: #{from_code} -> #{to_code} = #{rate}"
Rails.logger.error "Failed to fetch exchange rate: #{e.message}"
```

### Error Tracking

```ruby
# Sentry integration (if available)
Sentry.capture_exception(e) if defined?(Sentry)
```

---

## Next Steps

1. ✅ Run migrations
2. ✅ Load seed data
3. ✅ Configure environment variables
4. ✅ Set up scheduled jobs
5. ✅ Test the system
6. ✅ Deploy to production
7. 📝 Create locale translation files
8. 📝 Integrate with payment gateway
9. 📝 Add carrier shipping APIs
10. 📝 Implement address validation

---

## Support

For questions or issues:
- Review `INTERNATIONALIZATION_GUIDE.md`
- Check code comments
- Test in Rails console
- Review logs
- Contact development team

---

**Multi-Currency & Internationalization System v1.0**
Built for The Final Market

