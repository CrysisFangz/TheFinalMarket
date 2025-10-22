# frozen_string_literal: true

module Charity
  module ValueObjects
    # Immutable Value Object representing a charity category with sophisticated business logic
    class CharityCategory
      # Supported charity categories with metadata
      CATEGORIES = {
        education: {
          id: 0,
          name: 'Education',
          description: 'Educational institutions and programs',
          tax_benefit_multiplier: 1.2,
          verification_priority: :high,
          compliance_requirements: %i[accreditation licensing financial_audit]
        },
        health: {
          id: 1,
          name: 'Health',
          description: 'Healthcare organizations and medical research',
          tax_benefit_multiplier: 1.3,
          verification_priority: :critical,
          compliance_requirements: %i[medical_license hipaa_compliance insurance]
        },
        environment: {
          id: 2,
          name: 'Environment',
          description: 'Environmental conservation and protection',
          tax_benefit_multiplier: 1.1,
          verification_priority: :medium,
          compliance_requirements: %i[environmental_impact_report sustainability_plan]
        },
        poverty: {
          id: 3,
          name: 'Poverty Relief',
          description: 'Organizations fighting poverty and homelessness',
          tax_benefit_multiplier: 1.2,
          verification_priority: :high,
          compliance_requirements: %i[community_impact_assessment financial_transparency]
        },
        animals: {
          id: 4,
          name: 'Animal Welfare',
          description: 'Animal protection and wildlife conservation',
          tax_benefit_multiplier: 1.0,
          verification_priority: :medium,
          compliance_requirements: %i[animal_welfare_standards facility_inspection]
        },
        disaster_relief: {
          id: 5,
          name: 'Disaster Relief',
          description: 'Emergency response and disaster recovery',
          tax_benefit_multiplier: 1.4,
          verification_priority: :critical,
          compliance_requirements: %i[emergency_response_plan rapid_deployment_capability]
        },
        human_rights: {
          id: 6,
          name: 'Human Rights',
          description: 'Human rights advocacy and protection',
          tax_benefit_multiplier: 1.1,
          verification_priority: :high,
          compliance_requirements: %i[human_rights_framework legal_compliance]
        },
        arts_culture: {
          id: 7,
          name: 'Arts & Culture',
          description: 'Arts, cultural preservation, and heritage',
          tax_benefit_multiplier: 1.0,
          verification_priority: :low,
          compliance_requirements: %i[cultural_significance community_engagement]
        }
      }.freeze

      attr_reader :value, :metadata

      # Create a new CharityCategory
      # @param category [Symbol] the category key
      # @raise [ArgumentError] if the category is invalid
      def initialize(category)
        @value = category.to_sym

        raise ArgumentError, 'Invalid charity category' unless valid_category?
        @metadata = CATEGORIES[@value]
      end

      # Create from category ID
      # @param id [Integer] numeric category ID
      # @return [CharityCategory] category object
      def self.from_id(id)
        category_entry = CATEGORIES.find { |_key, metadata| metadata[:id] == id }
        return new(category_entry[0]) if category_entry

        raise ArgumentError, 'Invalid category ID'
      end

      # Get all available categories
      # @return [Array<CharityCategory>] all categories
      def self.all
        CATEGORIES.keys.map { |category| new(category) }
      end

      # Get categories by verification priority
      # @param priority [Symbol] :critical, :high, :medium, :low
      # @return [Array<CharityCategory>] filtered categories
      def self.by_verification_priority(priority)
        all.select { |category| category.verification_priority == priority }
      end

      # Convert to string
      # @return [String] category name
      def to_s
        @metadata[:name]
      end

      # Get category ID for database storage
      # @return [Integer] numeric ID
      def to_i
        @metadata[:id]
      end

      # Get description
      # @return [String] category description
      def description
        @metadata[:description]
      end

      # Get tax benefit multiplier for impact calculations
      # @return [Float] multiplier value
      def tax_benefit_multiplier
        @metadata[:tax_benefit_multiplier]
      end

      # Get verification priority level
      # @return [Symbol] priority level
      def verification_priority
        @metadata[:verification_priority]
      end

      # Get compliance requirements
      # @return [Array<Symbol>] required compliance items
      def compliance_requirements
        @metadata[:compliance_requirements]
      end

      # Check if this category has critical verification priority
      # @return [Boolean] true if critical priority
      def critical_verification?
        verification_priority == :critical
      end

      # Calculate enhanced impact score based on category multiplier
      # @param base_impact [Numeric] base impact value
      # @return [Numeric] enhanced impact value
      def calculate_enhanced_impact(base_impact)
        base_impact * tax_benefit_multiplier
      end

      # Equality comparison
      # @param other [CharityCategory] other category to compare
      # @return [Boolean] true if equal
      def ==(other)
        return false unless other.is_a?(CharityCategory)

        @value == other.value
      end

      # Hash for use in collections
      # @return [Integer] hash value
      def hash
        @value.hash
      end

      # Check if category is valid
      # @return [Boolean] true if valid
      def valid?
        valid_category?
      end

      private

      # Validate category exists in supported list
      # @return [Boolean] true if valid category
      def valid_category?
        CATEGORIES.key?(@value)
      end
    end
  end
end