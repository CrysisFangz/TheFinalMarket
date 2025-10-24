class TrustScoreService
  include ActiveSupport::Rescuable

  rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
  rescue_from StandardError, with: :handle_generic_error

  def initialize(user)
    @user = user
  end

  def calculate_and_create
    with_retries(max_tries: 3, rescue: [ActiveRecord::StaleObjectError]) do
      calculator = TrustScoreCalculator.new(@user)
      score_value = calculator.calculate

      trust_score = TrustScore.create!(
        user: @user,
        score: score_value,
        factors: calculator.factors,
        calculation_details: calculator.details
      )

      # Invalidate cache
      Rails.cache.delete("trust_score_current_#{@user.id}")

      trust_score
    end
  end

  def current_for_user
    Rails.cache.fetch("trust_score_current_#{@user.id}", expires_in: 1.hour) do
      TrustScore.where(user: @user).order(created_at: :desc).first
    end
  end

  def improved_since?(since_date)
    current = current_for_user
    return false unless current

    previous = TrustScore.where(user: @user).where('created_at < ?', since_date).order(created_at: :desc).first
    return false unless previous

    current.score > previous.score
  end

  def declined_since?(since_date)
    current = current_for_user
    return false unless current

    previous = TrustScore.where(user: @user).where('created_at < ?', since_date).order(created_at: :desc).first
    return false unless previous

    current.score < previous.score
  end

  private

  def with_retries(max_tries: 3, rescue: [], &block)
    tries = 0
    begin
      tries += 1
      yield
    rescue *rescue
      retry if tries < max_tries
      raise
    end
  end

  def handle_validation_error(error)
    Rails.logger.error("TrustScore validation failed: #{error.message}")
    raise error
  end

  def handle_generic_error(error)
    Rails.logger.error("TrustScore service error: #{error.message}")
    raise error
  end
end