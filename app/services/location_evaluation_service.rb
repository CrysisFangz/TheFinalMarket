class LocationEvaluationService
  def self.evaluate(rule, context)
    return false unless context[:ip_address]

    # Check if location is in blocked countries
    blocked_countries = rule.conditions['blocked_countries'] || []

    begin
      result = with_circuit_breaker(name: 'geolocation_api') do
        with_retry do
          Geocoder.search(context[:ip_address]).first
        end
      end

      return false unless result

      blocked_countries.include?(result.country_code)
    rescue
      false
    end
  end
end