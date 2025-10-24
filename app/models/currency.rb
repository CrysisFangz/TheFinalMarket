class Currency < ApplicationRecord
  include CircuitBreaker

  has_many :exchange_rates, dependent: :destroy
  has_many :user_currency_preferences, dependent: :destroy

  validates :code, presence: true, uniqueness: true, length: { is: 3 }
  validates :name, presence: true
  validates :symbol, presence: true

  after_update :publish_updated_event
  scope :active, -> { where(active: true) }
  scope :supported, -> { where(supported: true) }
  scope :by_popularity, -> { order(popularity_rank: :asc) }

  MAJOR_CURRENCIES = %w[USD EUR GBP JPY CNY AUD CAD CHF].freeze

  def self.base_currency
    find_by(code: 'USD') || find_by(is_base: true) || first
  end

  def self.for_user(user)
    return base_currency unless user

    user.currency_preference&.currency || detect_from_locale || base_currency
  end

  def self.detect_from_locale
    locale_currency_map = {
      'en-US' => 'USD',
      'en-GB' => 'GBP',
      'en-CA' => 'CAD',
      'en-AU' => 'AUD',
      'fr-FR' => 'EUR',
      'de-DE' => 'EUR',
      'es-ES' => 'EUR',
      'it-IT' => 'EUR',
      'ja-JP' => 'JPY',
      'zh-CN' => 'CNY',
      'ko-KR' => 'KRW',
      'pt-BR' => 'BRL',
      'ru-RU' => 'RUB',
      'ar-SA' => 'SAR',
      'hi-IN' => 'INR'
    }

    currency_code = locale_currency_map[I18n.locale.to_s] || 'USD'
    find_by(code: currency_code)
  end

  def convert_from_base(amount_cents)
    return amount_cents if is_base?

    rate = current_exchange_rate
    return amount_cents unless rate

    (amount_cents * rate).round
  end

  def convert_to_base(amount_cents)
    return amount_cents if is_base?

    rate = current_exchange_rate
    return amount_cents unless rate

    (amount_cents / rate).round
  end

  def current_exchange_rate
    Rails.cache.fetch("exchange_rate:#{code}", expires_in: 1.hour) do
      exchange_rates.recent.first&.rate || fetch_live_rate
    end
  end

  def fetch_live_rate
    with_retry do
      self.class.with_circuit_breaker(name: 'exchange_rate_api') do
        ExchangeRateService.fetch_rate(Currency.base_currency.code, code)
      end
    end
  end

  def format_amount(amount_cents)
    amount = amount_cents / 100.0

    if symbol_position == 'before'
      "#{symbol}#{format_number(amount)}"
    else
      "#{format_number(amount)}#{symbol}"
    end
  end

  def is_base?
    is_base == true
  end

  private

  def format_number(amount)
  def publish_updated_event
    EventPublisher.publish('currency.updated', { currency_id: id, code: code })
  end
    delimiter = thousands_separator || ','
    separator = decimal_separator || '.'

    parts = amount.round(decimal_places).to_s.split('.')
    parts[0].gsub!(/(\d)(?=(\d{3})+(?!\d))/, "\\1#{delimiter}")
    parts.join(separator)
  end

  def with_retry(max_retries: 3, &block)
    retries = 0
    begin
      yield
    rescue StandardError => e
      retries += 1
      retry if retries < max_retries
      Rails.logger.error("Failed after #{retries} retries: #{e.message}")
      raise e
    end
  end
end

