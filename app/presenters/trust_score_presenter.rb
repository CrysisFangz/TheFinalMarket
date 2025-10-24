class TrustScorePresenter
  def initialize(trust_score)
    @trust_score = trust_score
  end

  def badge
    case @trust_score.trust_level.to_sym
    when :highly_trusted
      { name: 'Highly Trusted', color: 'gold', icon: '⭐⭐⭐' }
    when :trusted
      { name: 'Trusted', color: 'green', icon: '⭐⭐' }
    when :moderate_trust
      { name: 'Verified', color: 'blue', icon: '⭐' }
    when :low_trust
      { name: 'New User', color: 'gray', icon: '○' }
    when :untrusted
      { name: 'Unverified', color: 'red', icon: '⚠' }
    else
      { name: 'Unknown', color: 'gray', icon: '❓' }
    end
  end

  def factors_array
    @trust_score.factors['factors'] || []
  end

  def calculation_details
    @trust_score.calculation_details || {}
  end

  def as_json(options = {})
    {
      score: @trust_score.score,
      trust_level: @trust_score.trust_level,
      badge: badge,
      factors: factors_array,
      details: calculation_details,
      created_at: @trust_score.created_at
    }
  end
end