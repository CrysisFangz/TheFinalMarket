# frozen_string_literal: true

module Charity
  module Services
    # Domain Service for sophisticated impact calculations and analytics
    class ImpactCalculationService
      # Sophisticated impact calculation algorithms
      IMPACT_ALGORITHMS = {
        basic: :calculate_basic_impact,
        category_weighted: :calculate_category_weighted_impact,
        time_decay: :calculate_time_decay_impact,
        donor_engagement: :calculate_donor_engagement_impact,
        social_proof: :calculate_social_proof_impact,
        compound_growth: :calculate_compound_growth_impact
      }.freeze

      # Calculate comprehensive impact metrics for a charity
      # @param charity [Entities::Charity] charity entity
      # @param algorithm [Symbol] impact calculation algorithm to use
      # @param options [Hash] additional calculation options
      # @return [Hash] comprehensive impact metrics
      def calculate_impact(charity, algorithm = :category_weighted, **options)
        algorithm_method = IMPACT_ALGORITHMS[algorithm] || :calculate_category_weighted_impact

        send(algorithm_method, charity, options)
      rescue NoMethodError
        calculate_category_weighted_impact(charity, options)
      end

      # Calculate real-time impact dashboard metrics
      # @param charity [Entities::Charity] charity entity
      # @return [Hash] real-time dashboard metrics
      def calculate_dashboard_metrics(charity)
        {
          total_impact_score: calculate_total_impact_score(charity),
          monthly_growth_rate: calculate_monthly_growth_rate(charity),
          donor_retention_rate: calculate_donor_retention_rate(charity),
          average_donation_velocity: calculate_donation_velocity(charity),
          social_engagement_score: calculate_social_engagement_score(charity),
          transparency_rating: calculate_transparency_rating(charity),
          sustainability_index: calculate_sustainability_index(charity),
          community_impact_factor: calculate_community_impact_factor(charity)
        }
      end

      private

      # Basic impact calculation (original algorithm)
      # @param charity [Entities::Charity] charity entity
      # @param options [Hash] calculation options
      # @return [Hash] impact metrics
      def calculate_basic_impact(charity, options = {})
        base_amount = charity.total_raised.amount_cents

        {
          raw_impact: base_amount / 100.0,
          efficiency_rating: calculate_efficiency_rating(charity),
          sustainability_score: calculate_sustainability_score(charity),
          donor_satisfaction_index: calculate_donor_satisfaction(charity)
        }
      end

      # Category-weighted impact calculation
      # @param charity [Entities::Charity] charity entity
      # @param options [Hash] calculation options
      # @return [Hash] weighted impact metrics
      def calculate_category_weighted_impact(charity, options = {})
        base_impact = calculate_basic_impact(charity, options)

        category_multiplier = charity.category&.tax_benefit_multiplier || 1.0
        enhanced_impact = base_impact[:raw_impact] * category_multiplier

        base_impact.merge(
          category_enhanced_impact: enhanced_impact,
          category_multiplier: category_multiplier,
          category_impact_bonus: enhanced_impact - base_impact[:raw_impact]
        )
      end

      # Time-decay impact calculation (recent donations worth more)
      # @param charity [Entities::Charity] charity entity
      # @param options [Hash] calculation options
      # @return [Hash] time-weighted impact metrics
      def calculate_time_decay_impact(charity, options = {})
        # This would analyze donation timestamps with exponential decay
        # For now, use simplified calculation
        decay_factor = options[:decay_rate] || 0.95
        time_enhanced_impact = calculate_category_weighted_impact(charity, options)[:category_enhanced_impact] * decay_factor

        {
          time_decay_impact: time_enhanced_impact,
          decay_factor: decay_factor,
          recency_bonus: calculate_recency_bonus(charity)
        }
      end

      # Advanced impact calculation with donor engagement factors
      # @param charity [Entities::Charity] charity entity
      # @param options [Hash] calculation options
      # @return [Hash] engagement-enhanced impact metrics
      def calculate_donor_engagement_impact(charity, options = {})
        engagement_multiplier = calculate_donor_engagement_multiplier(charity)

        base_impact = calculate_time_decay_impact(charity, options)[:time_decay_impact]
        engagement_impact = base_impact * engagement_multiplier

        {
          engagement_enhanced_impact: engagement_impact,
          engagement_multiplier: engagement_multiplier,
          engagement_factors: calculate_engagement_factors(charity)
        }
      end

      # Social proof impact calculation
      # @param charity [Entities::Charity] charity entity
      # @param options [Hash] calculation options
      # @return [Hash] social proof enhanced impact metrics
      def calculate_social_proof_impact(charity, options = {})
        social_proof_multiplier = calculate_social_proof_multiplier(charity)

        base_impact = calculate_donor_engagement_impact(charity, options)[:engagement_enhanced_impact]
        social_impact = base_impact * social_proof_multiplier

        {
          social_proof_impact: social_impact,
          social_proof_multiplier: social_proof_multiplier,
          virality_index: calculate_virality_index(charity)
        }
      end

      # Compound growth impact calculation
      # @param charity [Entities::Charity] charity entity
      # @param options [Hash] calculation options
      # @return [Hash] compound growth impact metrics
      def calculate_compound_growth_impact(charity, options = {})
        growth_rate = calculate_growth_rate(charity)
        compounding_periods = options[:compounding_periods] || 12

        # Calculate compound growth factor
        compound_factor = (1 + growth_rate / 100.0) ** compounding_periods

        base_impact = calculate_social_proof_impact(charity, options)[:social_proof_impact]
        compound_impact = base_impact * compound_factor

        {
          compound_growth_impact: compound_impact,
          compound_factor: compound_factor,
          projected_growth_rate: growth_rate,
          compounding_periods: compounding_periods
        }
      end

      # Helper calculation methods

      def calculate_total_impact_score(charity)
        # Sophisticated scoring algorithm
        metrics = calculate_compound_growth_impact(charity)
        base_score = metrics[:compound_growth_impact] / 1000.0 # Normalize

        # Apply category-based adjustments
        category_adjustment = charity.category&.tax_benefit_multiplier || 1.0

        (base_score * category_adjustment).round(2)
      end

      def calculate_monthly_growth_rate(charity)
        # Analyze donation trends over time
        # Placeholder implementation
        return 0.0 if charity.donor_count < 2

        Math.log(charity.donor_count + 1) * 15.0
      end

      def calculate_donor_retention_rate(charity)
        # Calculate percentage of repeat donors
        # Placeholder implementation
        return 75.0 if charity.donor_count > 10
        return 50.0 if charity.donor_count > 5

        25.0
      end

      def calculate_donation_velocity(charity)
        # Calculate donations per day rate
        days_active = charity.impact_metrics[:days_active] || 1
        velocity = charity.donor_count.to_f / days_active

        (velocity * 30.0).round(1) # Monthly projection
      end

      def calculate_social_engagement_score(charity)
        # Calculate social media and community engagement
        # This would integrate with social media APIs
        base_engagement = charity.donor_count * 2.5
        network_effect = Math.sqrt(charity.donor_count) * 1.5

        (base_engagement + network_effect).round(1)
      end

      def calculate_transparency_rating(charity)
        # Calculate transparency based on reporting frequency and detail
        base_transparency = 50.0

        # Verified charities get transparency bonus
        base_transparency += 30.0 if charity.verified?

        # Regular impact reporting bonus
        base_transparency += 20.0 if charity.updated_at > 7.days.ago

        [base_transparency, 100.0].min
      end

      def calculate_sustainability_index(charity)
        # Calculate long-term sustainability metrics
        donor_diversity = calculate_donor_diversity(charity)
        operational_efficiency = calculate_efficiency_rating(charity)
        growth_stability = calculate_growth_stability(charity)

        average = (donor_diversity + operational_efficiency + growth_stability) / 3.0
        (average * 100.0).round(1)
      end

      def calculate_community_impact_factor(charity)
        # Calculate broader community impact
        local_impact = charity.donor_count * 1.2
        network_impact = Math.sqrt(charity.donor_count) * 2.1
        multiplier_effect = charity.category&.calculate_enhanced_impact(charity.total_raised.amount_cents) || 0

        (local_impact + network_impact + multiplier_effect / 100.0).round(1)
      end

      # Supporting calculation methods

      def calculate_efficiency_rating(charity)
        # Calculate operational efficiency
        return 50.0 if charity.donor_count.zero?

        # Higher donor counts typically indicate better efficiency
        base_efficiency = Math.log(charity.donor_count + 1) * 10.0
        [base_efficiency, 95.0].min
      end

      def calculate_sustainability_score(charity)
        # Calculate long-term sustainability
        consistency_factor = calculate_donation_consistency(charity)
        growth_factor = calculate_growth_rate(charity)

        (consistency_factor + growth_factor).round(1)
      end

      def calculate_donor_satisfaction(charity)
        # Estimate donor satisfaction based on behavior patterns
        return 60.0 if charity.donor_count < 5
        return 75.0 if charity.donor_count < 20

        85.0
      end

      def calculate_recency_bonus(charity)
        # Bonus for recent activity
        days_since_update = (Time.current.to_date - charity.updated_at.to_date).to_i

        case days_since_update
        when 0..1 then 1.2
        when 2..7 then 1.1
        when 8..30 then 1.0
        else 0.9
        end
      end

      def calculate_donor_engagement_multiplier(charity)
        # Calculate multiplier based on donor engagement
        retention_rate = calculate_donor_retention_rate(charity) / 100.0
        satisfaction = calculate_donor_satisfaction(charity) / 100.0

        (retention_rate * satisfaction * 1.5).round(2)
      end

      def calculate_engagement_factors(charity)
        {
          retention_rate: calculate_donor_retention_rate(charity),
          satisfaction_score: calculate_donor_satisfaction(charity),
          activity_level: charity.donor_count > 10 ? :high : :medium
        }
      end

      def calculate_social_proof_multiplier(charity)
        # Calculate social proof effect
        donor_count = charity.donor_count

        case donor_count
        when 0..10 then 1.0
        when 11..50 then 1.1
        when 51..200 then 1.2
        when 201..1000 then 1.3
        else 1.4
        end
      end

      def calculate_virality_index(charity)
        # Calculate potential for viral growth
        network_effect = Math.sqrt(charity.donor_count)
        growth_acceleration = calculate_monthly_growth_rate(charity) / 100.0

        (network_effect * growth_acceleration * 10.0).round(2)
      end

      def calculate_growth_rate(charity)
        # Calculate growth rate based on donation patterns
        return 5.0 if charity.donor_count < 5
        return 10.0 if charity.donor_count < 20

        15.0
      end

      def calculate_donor_diversity(charity)
        # Placeholder for donor demographic diversity calculation
        60.0
      end

      def calculate_growth_stability(charity)
        # Placeholder for growth stability calculation
        70.0
      end

      def calculate_donation_consistency(charity)
        # Placeholder for donation pattern consistency
        65.0
      end
    end
  end
end