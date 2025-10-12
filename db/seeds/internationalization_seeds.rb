puts "🌍 Seeding Internationalization System..."

# Create Currencies
puts "Creating currencies..."

currencies_data = [
  { code: 'USD', name: 'US Dollar', symbol: '$', is_base: true, popularity_rank: 1 },
  { code: 'EUR', name: 'Euro', symbol: '€', popularity_rank: 2 },
  { code: 'GBP', name: 'British Pound', symbol: '£', popularity_rank: 3 },
  { code: 'JPY', name: 'Japanese Yen', symbol: '¥', decimal_places: 0, popularity_rank: 4 },
  { code: 'CNY', name: 'Chinese Yuan', symbol: '¥', popularity_rank: 5 },
  { code: 'AUD', name: 'Australian Dollar', symbol: 'A$', popularity_rank: 6 },
  { code: 'CAD', name: 'Canadian Dollar', symbol: 'C$', popularity_rank: 7 },
  { code: 'CHF', name: 'Swiss Franc', symbol: 'CHF', popularity_rank: 8 },
  { code: 'INR', name: 'Indian Rupee', symbol: '₹', popularity_rank: 9 },
  { code: 'BRL', name: 'Brazilian Real', symbol: 'R$', popularity_rank: 10 },
  { code: 'MXN', name: 'Mexican Peso', symbol: '$', popularity_rank: 11 },
  { code: 'KRW', name: 'South Korean Won', symbol: '₩', decimal_places: 0, popularity_rank: 12 },
  { code: 'RUB', name: 'Russian Ruble', symbol: '₽', popularity_rank: 13 },
  { code: 'SGD', name: 'Singapore Dollar', symbol: 'S$', popularity_rank: 14 },
  { code: 'HKD', name: 'Hong Kong Dollar', symbol: 'HK$', popularity_rank: 15 },
  { code: 'SEK', name: 'Swedish Krona', symbol: 'kr', symbol_position: 'after', popularity_rank: 16 },
  { code: 'NOK', name: 'Norwegian Krone', symbol: 'kr', symbol_position: 'after', popularity_rank: 17 },
  { code: 'DKK', name: 'Danish Krone', symbol: 'kr', symbol_position: 'after', popularity_rank: 18 },
  { code: 'NZD', name: 'New Zealand Dollar', symbol: 'NZ$', popularity_rank: 19 },
  { code: 'ZAR', name: 'South African Rand', symbol: 'R', popularity_rank: 20 },
  { code: 'AED', name: 'UAE Dirham', symbol: 'د.إ', popularity_rank: 21 },
  { code: 'SAR', name: 'Saudi Riyal', symbol: 'ر.س', popularity_rank: 22 },
  { code: 'THB', name: 'Thai Baht', symbol: '฿', popularity_rank: 23 },
  { code: 'PLN', name: 'Polish Zloty', symbol: 'zł', symbol_position: 'after', popularity_rank: 24 },
  { code: 'TRY', name: 'Turkish Lira', symbol: '₺', popularity_rank: 25 }
]

currencies_data.each do |data|
  Currency.find_or_create_by!(code: data[:code]) do |currency|
    currency.assign_attributes(data)
  end
end

puts "✅ Created #{Currency.count} currencies"

# Create Countries
puts "Creating countries..."

countries_data = [
  { code: 'US', name: 'United States', currency_code: 'USD', locale_code: 'en-US', timezone: 'America/New_York', phone_code: '1', continent: 'North America', supported_for_shipping: true },
  { code: 'GB', name: 'United Kingdom', currency_code: 'GBP', locale_code: 'en-GB', timezone: 'Europe/London', phone_code: '44', continent: 'Europe', supported_for_shipping: true },
  { code: 'CA', name: 'Canada', currency_code: 'CAD', locale_code: 'en-CA', timezone: 'America/Toronto', phone_code: '1', continent: 'North America', supported_for_shipping: true },
  { code: 'AU', name: 'Australia', currency_code: 'AUD', locale_code: 'en-AU', timezone: 'Australia/Sydney', phone_code: '61', continent: 'Oceania', supported_for_shipping: true },
  { code: 'DE', name: 'Germany', currency_code: 'EUR', locale_code: 'de-DE', timezone: 'Europe/Berlin', phone_code: '49', continent: 'Europe', supported_for_shipping: true },
  { code: 'FR', name: 'France', currency_code: 'EUR', locale_code: 'fr-FR', timezone: 'Europe/Paris', phone_code: '33', continent: 'Europe', supported_for_shipping: true },
  { code: 'ES', name: 'Spain', currency_code: 'EUR', locale_code: 'es-ES', timezone: 'Europe/Madrid', phone_code: '34', continent: 'Europe', supported_for_shipping: true },
  { code: 'IT', name: 'Italy', currency_code: 'EUR', locale_code: 'it-IT', timezone: 'Europe/Rome', phone_code: '39', continent: 'Europe', supported_for_shipping: true },
  { code: 'JP', name: 'Japan', currency_code: 'JPY', locale_code: 'ja-JP', timezone: 'Asia/Tokyo', phone_code: '81', continent: 'Asia', supported_for_shipping: true, requires_customs: true },
  { code: 'CN', name: 'China', currency_code: 'CNY', locale_code: 'zh-CN', timezone: 'Asia/Shanghai', phone_code: '86', continent: 'Asia', supported_for_shipping: true, requires_customs: true },
  { code: 'IN', name: 'India', currency_code: 'INR', locale_code: 'hi-IN', timezone: 'Asia/Kolkata', phone_code: '91', continent: 'Asia', supported_for_shipping: true, requires_customs: true },
  { code: 'BR', name: 'Brazil', currency_code: 'BRL', locale_code: 'pt-BR', timezone: 'America/Sao_Paulo', phone_code: '55', continent: 'South America', supported_for_shipping: true, requires_customs: true },
  { code: 'MX', name: 'Mexico', currency_code: 'MXN', locale_code: 'es-MX', timezone: 'America/Mexico_City', phone_code: '52', continent: 'North America', supported_for_shipping: true },
  { code: 'KR', name: 'South Korea', currency_code: 'KRW', locale_code: 'ko-KR', timezone: 'Asia/Seoul', phone_code: '82', continent: 'Asia', supported_for_shipping: true, requires_customs: true },
  { code: 'RU', name: 'Russia', currency_code: 'RUB', locale_code: 'ru-RU', timezone: 'Europe/Moscow', phone_code: '7', continent: 'Europe', supported_for_shipping: true, requires_customs: true },
  { code: 'SG', name: 'Singapore', currency_code: 'SGD', locale_code: 'en-SG', timezone: 'Asia/Singapore', phone_code: '65', continent: 'Asia', supported_for_shipping: true },
  { code: 'HK', name: 'Hong Kong', currency_code: 'HKD', locale_code: 'zh-HK', timezone: 'Asia/Hong_Kong', phone_code: '852', continent: 'Asia', supported_for_shipping: true },
  { code: 'SE', name: 'Sweden', currency_code: 'SEK', locale_code: 'sv-SE', timezone: 'Europe/Stockholm', phone_code: '46', continent: 'Europe', supported_for_shipping: true },
  { code: 'NO', name: 'Norway', currency_code: 'NOK', locale_code: 'no-NO', timezone: 'Europe/Oslo', phone_code: '47', continent: 'Europe', supported_for_shipping: true },
  { code: 'DK', name: 'Denmark', currency_code: 'DKK', locale_code: 'da-DK', timezone: 'Europe/Copenhagen', phone_code: '45', continent: 'Europe', supported_for_shipping: true },
  { code: 'NZ', name: 'New Zealand', currency_code: 'NZD', locale_code: 'en-NZ', timezone: 'Pacific/Auckland', phone_code: '64', continent: 'Oceania', supported_for_shipping: true },
  { code: 'ZA', name: 'South Africa', currency_code: 'ZAR', locale_code: 'en-ZA', timezone: 'Africa/Johannesburg', phone_code: '27', continent: 'Africa', supported_for_shipping: true },
  { code: 'AE', name: 'United Arab Emirates', currency_code: 'AED', locale_code: 'ar-AE', timezone: 'Asia/Dubai', phone_code: '971', continent: 'Asia', supported_for_shipping: true },
  { code: 'SA', name: 'Saudi Arabia', currency_code: 'SAR', locale_code: 'ar-SA', timezone: 'Asia/Riyadh', phone_code: '966', continent: 'Asia', supported_for_shipping: true },
  { code: 'TH', name: 'Thailand', currency_code: 'THB', locale_code: 'th-TH', timezone: 'Asia/Bangkok', phone_code: '66', continent: 'Asia', supported_for_shipping: true },
  { code: 'PL', name: 'Poland', currency_code: 'PLN', locale_code: 'pl-PL', timezone: 'Europe/Warsaw', phone_code: '48', continent: 'Europe', supported_for_shipping: true },
  { code: 'TR', name: 'Turkey', currency_code: 'TRY', locale_code: 'tr-TR', timezone: 'Europe/Istanbul', phone_code: '90', continent: 'Europe', supported_for_shipping: true },
  { code: 'NL', name: 'Netherlands', currency_code: 'EUR', locale_code: 'nl-NL', timezone: 'Europe/Amsterdam', phone_code: '31', continent: 'Europe', supported_for_shipping: true },
  { code: 'BE', name: 'Belgium', currency_code: 'EUR', locale_code: 'nl-BE', timezone: 'Europe/Brussels', phone_code: '32', continent: 'Europe', supported_for_shipping: true },
  { code: 'CH', name: 'Switzerland', currency_code: 'CHF', locale_code: 'de-CH', timezone: 'Europe/Zurich', phone_code: '41', continent: 'Europe', supported_for_shipping: true }
]

countries_data.each do |data|
  Country.find_or_create_by!(code: data[:code]) do |country|
    country.assign_attributes(data)
  end
end

puts "✅ Created #{Country.count} countries"

# Create Shipping Zones
puts "Creating shipping zones..."

# Domestic (US)
domestic_zone = ShippingZone.find_or_create_by!(code: 'US_DOMESTIC') do |zone|
  zone.name = 'United States (Domestic)'
  zone.priority = 1
end
domestic_zone.countries << Country.find_by(code: 'US') unless domestic_zone.countries.exists?(code: 'US')

# North America
north_america_zone = ShippingZone.find_or_create_by!(code: 'NORTH_AMERICA') do |zone|
  zone.name = 'North America'
  zone.priority = 2
end
['CA', 'MX'].each do |code|
  country = Country.find_by(code: code)
  north_america_zone.countries << country unless north_america_zone.countries.include?(country)
end

# Europe
europe_zone = ShippingZone.find_or_create_by!(code: 'EUROPE') do |zone|
  zone.name = 'Europe'
  zone.priority = 3
end
['GB', 'DE', 'FR', 'ES', 'IT', 'NL', 'BE', 'CH', 'SE', 'NO', 'DK', 'PL'].each do |code|
  country = Country.find_by(code: code)
  europe_zone.countries << country unless europe_zone.countries.include?(country)
end

# Asia Pacific
asia_zone = ShippingZone.find_or_create_by!(code: 'ASIA_PACIFIC') do |zone|
  zone.name = 'Asia Pacific'
  zone.priority = 4
end
['JP', 'CN', 'KR', 'SG', 'HK', 'TH', 'AU', 'NZ', 'IN'].each do |code|
  country = Country.find_by(code: code)
  asia_zone.countries << country unless asia_zone.countries.include?(country)
end

# Rest of World
row_zone = ShippingZone.find_or_create_by!(code: 'REST_OF_WORLD') do |zone|
  zone.name = 'Rest of World'
  zone.priority = 5
end
['BR', 'RU', 'ZA', 'AE', 'SA', 'TR'].each do |code|
  country = Country.find_by(code: code)
  row_zone.countries << country unless row_zone.countries.include?(country)
end

puts "✅ Created #{ShippingZone.count} shipping zones"

# Create Shipping Rates
puts "Creating shipping rates..."

[domestic_zone, north_america_zone, europe_zone, asia_zone, row_zone].each_with_index do |zone, index|
  base_multiplier = index + 1
  
  # Economy
  ShippingRate.find_or_create_by!(shipping_zone: zone, service_level: :economy) do |rate|
    rate.base_rate_cents = 500 * base_multiplier
    rate.per_kg_rate_cents = 200 * base_multiplier
    rate.min_delivery_days = 7 + (index * 3)
    rate.max_delivery_days = 14 + (index * 3)
    rate.includes_tracking = false
  end
  
  # Standard
  ShippingRate.find_or_create_by!(shipping_zone: zone, service_level: :standard) do |rate|
    rate.base_rate_cents = 1000 * base_multiplier
    rate.per_kg_rate_cents = 300 * base_multiplier
    rate.min_delivery_days = 3 + (index * 2)
    rate.max_delivery_days = 7 + (index * 2)
    rate.includes_tracking = true
  end
  
  # Express
  ShippingRate.find_or_create_by!(shipping_zone: zone, service_level: :express) do |rate|
    rate.base_rate_cents = 2000 * base_multiplier
    rate.per_kg_rate_cents = 500 * base_multiplier
    rate.min_delivery_days = 1 + index
    rate.max_delivery_days = 3 + index
    rate.includes_tracking = true
    rate.requires_signature = true
  end
end

puts "✅ Created #{ShippingRate.count} shipping rates"

# Create Tax Rates
puts "Creating tax rates..."

tax_rates_data = [
  { country_code: 'US', name: 'Sales Tax', tax_type: 'sales_tax', rate: 8.5 },
  { country_code: 'GB', name: 'VAT', tax_type: 'vat', rate: 20.0, included_in_price: true },
  { country_code: 'CA', name: 'GST', tax_type: 'gst', rate: 5.0 },
  { country_code: 'AU', name: 'GST', tax_type: 'gst', rate: 10.0, included_in_price: true },
  { country_code: 'DE', name: 'VAT', tax_type: 'vat', rate: 19.0, included_in_price: true },
  { country_code: 'FR', name: 'VAT', tax_type: 'vat', rate: 20.0, included_in_price: true },
  { country_code: 'ES', name: 'VAT', tax_type: 'vat', rate: 21.0, included_in_price: true },
  { country_code: 'IT', name: 'VAT', tax_type: 'vat', rate: 22.0, included_in_price: true },
  { country_code: 'JP', name: 'Consumption Tax', tax_type: 'consumption_tax', rate: 10.0 },
  { country_code: 'CN', name: 'VAT', tax_type: 'vat', rate: 13.0 },
  { country_code: 'IN', name: 'GST', tax_type: 'gst', rate: 18.0 }
]

tax_rates_data.each do |data|
  country = Country.find_by(code: data[:country_code])
  next unless country
  
  TaxRate.find_or_create_by!(country: country, product_category: nil) do |tax_rate|
    tax_rate.name = data[:name]
    tax_rate.tax_type = data[:tax_type]
    tax_rate.rate = data[:rate]
    tax_rate.included_in_price = data[:included_in_price] || false
  end
end

puts "✅ Created #{TaxRate.count} tax rates"

# Fetch initial exchange rates
puts "Fetching exchange rates..."
begin
  ExchangeRateService.update_all_rates
  puts "✅ Fetched exchange rates for #{ExchangeRate.count} currencies"
rescue => e
  puts "⚠️  Could not fetch exchange rates: #{e.message}"
  puts "   You can update them later with: ExchangeRateService.update_all_rates"
end

puts ""
puts "🎉 Internationalization System seeded successfully!"
puts ""
puts "Summary:"
puts "  - #{Currency.count} currencies"
puts "  - #{Country.count} countries"
puts "  - #{ShippingZone.count} shipping zones"
puts "  - #{ShippingRate.count} shipping rates"
puts "  - #{TaxRate.count} tax rates"
puts "  - #{ExchangeRate.count} exchange rates"
puts ""

