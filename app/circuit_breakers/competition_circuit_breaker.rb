module CircuitBreakers
  class CompetitionCircuitBreaker < BaseCircuitBreaker
    def initialize
      super('competition_operations', failure_threshold: 3, recovery_timeout: 30)
    end
  end
end