# Multi-Currency & Internationalization Guide

## Overview

The Final Market's Internationalization System provides comprehensive support for global commerce, including multi-currency transactions, multi-language content, international shipping, and regional tax handling.

---

## Features

### 1. Multi-Currency Support

**Supported Currencies: 25+**
- USD (US Dollar) - Base currency
- EUR (Euro)
- GBP (British Pound)
- JPY (Japanese Yen)
- CNY (Chinese Yuan)
- And 20+ more major currencies

**Features:**
- Real-time exchange rate updates
- Automatic currency conversion
- User currency preferences
- Price display in local currency
- Multi-currency checkout

**How it works:**
1. All prices stored in base currency (USD)
2. Converted to user's preferred currency on display
3. Exchange rates updated hourly via API
4. Conversion rate locked at checkout

---

### 2. Multi-Language Support (i18n)

**Supported Locales: 30+**
- English (US, GB, CA, AU)
- Spanish (ES, MX)
- French (FR, CA)
- German (DE, CH)
- Italian (IT)
- Japanese (JP)
- Chinese (CN, HK)
- And many more...

**Features:**
- Automatic locale detection
- User locale preferences
- Content translations
- Localized date/time formats
- RTL language support

---

### 3. International Shipping

**Shipping Zones:**
- Domestic (US)
- North America (CA, MX)
- Europe (27 countries)
- Asia Pacific (9 countries)
- Rest of World

**Shipping Services:**
- Economy (7-14 days)
- Standard (3-7 days)
- Express (1-3 days)
- Overnight (next day)

**Features:**
- Weight-based pricing
- Zone-based rates
- Carrier integration ready
- Tracking support
- Signature requirements
- Customs documentation

---

### 4. Regional Tax Handling

**Tax Types Supported:**
- VAT (Value Added Tax) - Europe
- GST (Goods and Services Tax) - Canada, Australia, India
- Sales Tax - United States
- Consumption Tax - Japan

**Features:**
- Automatic tax calculation
- Tax-inclusive/exclusive pricing
- Category-specific rates
- Customs duties calculation
- Tax exemptions

---

## Usage

### Currency Conversion

```ruby
# Get user's preferred currency
currency = Currency.for_user(current_user)

# Convert price
base_price = 9999 # cents in USD
local_price = currency.convert_from_base(base_price)

# Format for display
formatted = currency.format_amount(local_price)
# => "€92.45" or "$99.99" depending on currency
```

### Internationalization Service

```ruby
# Initialize service
i18n = InternationalizationService.new(current_user, request)

# Detect locale
locale = i18n.detect_locale # => "fr-FR"

# Detect currency
currency = i18n.detect_currency # => Currency(EUR)

# Format price
price = i18n.format_price(9999) # => "€92.45"

# Get shipping options
options = i18n.shipping_options('FR', 1000) # country_code, weight_grams
# => [
#   { service_level: 'standard', cost_cents: 1500, delivery_estimate: '3-7 business days' },
#   { service_level: 'express', cost_cents: 3000, delivery_estimate: '1-3 business days' }
# ]

# Calculate total with tax
total = i18n.calculate_total_with_tax(9999, 'FR')
# => 11999 (includes 20% VAT)
```

### Shipping Calculation

```ruby
# Find shipping zone for country
zone = ShippingZone.for_country('GB')

# Calculate shipping cost
weight = 1500 # grams
cost = zone.calculate_shipping(weight, 'standard')
# => 1500 (cents)

# Get delivery estimate
estimate = zone.estimated_delivery_days('express')
# => { min: 1, max: 3 }
```

### Tax Calculation

```ruby
# Get tax rate for country
country = Country.find_by_code('GB')
tax_rate = country.tax_rate_for

# Calculate tax
subtotal = 10000 # cents
tax = country.calculate_tax(subtotal)
# => 2000 (20% VAT)

# Total with tax
total = subtotal + tax
# => 12000
```

### Content Translation

```ruby
# Auto-translate product
product = Product.first
ContentTranslation.auto_translate(product, :name, 'en', 'fr')
ContentTranslation.auto_translate(product, :description, 'en', 'fr')

# Get translated content
i18n = InternationalizationService.new
translated_name = i18n.localized_content(product, :name)
```

---

## API Integration

### Exchange Rate APIs

The system supports multiple exchange rate providers:

1. **ExchangeRate-API** (Free, no API key)
   - Default provider
   - Updates every 24 hours
   - 150+ currencies

2. **Fixer.io** (Paid)
   - Set `ENV['FIXER_API_KEY']`
   - Real-time rates
   - Historical data

3. **Open Exchange Rates** (Freemium)
   - Set `ENV['OPENEXCHANGERATES_API_KEY']`
   - Hourly updates
   - 170+ currencies

4. **CurrencyAPI** (Paid)
   - Set `ENV['CURRENCYAPI_KEY']`
   - Real-time rates
   - High accuracy

### Translation APIs

1. **Google Translate**
   - Set `ENV['GOOGLE_TRANSLATE_API_KEY']`
   - 100+ languages
   - High quality

2. **DeepL**
   - Set `ENV['DEEPL_API_KEY']`
   - 26 languages
   - Best quality

---

## Database Schema

### Tables Created

**currencies**
- code, name, symbol
- decimal_places, separators
- is_base, active, supported
- popularity_rank

**exchange_rates**
- currency_id, rate
- source (API provider)
- created_at (for history)

**countries**
- code, name, native_name
- currency_code, locale_code
- timezone, phone_code
- supported_for_shipping
- requires_customs

**shipping_zones**
- name, code, description
- active, priority

**shipping_zone_countries** (join table)
- shipping_zone_id
- country_id

**shipping_rates**
- shipping_zone_id
- service_level (enum)
- base_rate_cents, per_kg_rate_cents
- min/max weight, min/max rate
- delivery days
- tracking, signature

**tax_rates**
- country_id
- name, tax_type, rate
- product_category (optional)
- included_in_price

**content_translations**
- translatable (polymorphic)
- locale, attribute, value
- translator, verified

**user_currency_preferences**
- user_id, currency_id

### Columns Added

**users table:**
- locale
- timezone
- country_code

**products table:**
- weight_grams
- requires_shipping
- ships_internationally
- origin_country_code

**orders table:**
- currency_code
- exchange_rate
- shipping_country_code
- tax_amount_cents
- shipping_cost_cents

---

## Background Jobs

### Exchange Rate Updates

```ruby
# Update all exchange rates
ExchangeRateUpdateJob.perform_now

# Schedule hourly updates
# config/schedule.yml
exchange_rate_update:
  cron: "0 * * * *"  # Every hour
  class: "ExchangeRateUpdateJob"
  queue: default
```

---

## Configuration

### Locale Configuration

```ruby
# config/application.rb
config.i18n.available_locales = [:en, :es, :fr, :de, :it, :ja, :zh, :pt, :ru, :ar, :hi]
config.i18n.default_locale = :en
config.i18n.fallbacks = true
```

### Currency Configuration

```ruby
# Set base currency (default: USD)
Currency.find_by(code: 'USD').update!(is_base: true)

# Enable/disable currencies
Currency.find_by(code: 'EUR').update!(active: true, supported: true)
```

### Shipping Configuration

```ruby
# Create custom shipping zone
zone = ShippingZone.create!(
  name: 'Custom Zone',
  code: 'CUSTOM',
  priority: 10
)

# Add countries to zone
zone.countries << Country.find_by(code: 'US')

# Create shipping rate
zone.shipping_rates.create!(
  service_level: :standard,
  base_rate_cents: 1000,
  per_kg_rate_cents: 300,
  min_delivery_days: 3,
  max_delivery_days: 7
)
```

---

## User Interface

### Currency Selector

```erb
<%= form_with url: update_currency_path, method: :post do |f| %>
  <%= f.select :currency_code, 
      Currency.supported.map { |c| [c.name, c.code] },
      { selected: current_user.currency_preference&.currency&.code } %>
  <%= f.submit "Update Currency" %>
<% end %>
```

### Locale Selector

```erb
<%= form_with url: update_locale_path, method: :post do |f| %>
  <%= f.select :locale,
      I18n.available_locales.map { |l| [t("locales.#{l}"), l] },
      { selected: I18n.locale } %>
  <%= f.submit "Update Language" %>
<% end %>
```

### Price Display

```erb
<%# Automatic currency conversion %>
<%= number_to_currency(
  @product.price_cents / 100.0,
  unit: current_currency.symbol,
  format: current_currency.symbol_position == 'before' ? '%u%n' : '%n%u'
) %>
```

---

## Best Practices

### For Developers

1. **Always store prices in base currency**
2. **Convert on display, not on storage**
3. **Lock exchange rate at checkout**
4. **Cache exchange rates (1 hour)**
5. **Handle currency rounding properly**
6. **Test with multiple currencies**
7. **Validate shipping zones**

### For Content Managers

1. **Provide translations for key content**
2. **Verify auto-translations**
3. **Use locale-specific images**
4. **Consider cultural differences**
5. **Test RTL languages**

### For Operations

1. **Update exchange rates regularly**
2. **Monitor API usage/costs**
3. **Review shipping rates quarterly**
4. **Update tax rates when laws change**
5. **Test international orders**

---

## Troubleshooting

### Exchange rates not updating
- Check API keys in ENV
- Verify internet connectivity
- Check API rate limits
- Review job queue

### Wrong currency displayed
- Check user preferences
- Verify locale detection
- Check browser settings
- Review cookie/session data

### Shipping not available
- Verify country is supported
- Check shipping zone configuration
- Verify weight is within limits
- Review active status

### Tax calculation incorrect
- Verify tax rate for country
- Check product category
- Review included_in_price setting
- Validate calculation logic

---

## Future Enhancements

- [ ] Cryptocurrency support
- [ ] Dynamic shipping rates (carrier APIs)
- [ ] Advanced tax rules (EU VAT MOSS)
- [ ] Multi-warehouse inventory
- [ ] Regional pricing strategies
- [ ] Customs documentation automation
- [ ] Address validation
- [ ] Prohibited items by country
- [ ] Import duty calculator
- [ ] Multi-language customer support

---

## Support

For questions or issues:
- Review this documentation
- Check the code comments
- Test in Rails console
- Contact development team

---

## Credits

Multi-Currency & Internationalization System v1.0
Developed for The Final Market
Built with Ruby on Rails 8.0, i18n, and external APIs

