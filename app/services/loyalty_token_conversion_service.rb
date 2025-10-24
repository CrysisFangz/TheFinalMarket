class LoyaltyTokenConversionService
  attr_reader :loyalty_token

  def initialize(loyalty_token)
    @loyalty_token = loyalty_token
  end

  def value_usd
    Rails.logger.debug("Converting balance to USD for LoyaltyToken ID: #{loyalty_token.id}")
    self.class.tokens_to_usd(loyalty_token.balance)
  end

  def self.usd_to_tokens(usd_amount)
    Rails.logger.debug("Converting USD #{usd_amount} to tokens")
    (usd_amount * LoyaltyToken::USD_TO_TOKEN_RATE).to_i
  end

  def self.tokens_to_usd(token_amount)
    Rails.logger.debug("Converting #{token_amount} tokens to USD")
    (token_amount * LoyaltyToken::TOKEN_TO_USD_RATE).round(2)
  end
end