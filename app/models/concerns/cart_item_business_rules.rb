# frozen_string_literal: true

# Cart Item Business Rules
# Sophisticated business rule engine for cart item validation and processing
module CartItemBusinessRules
  extend ActiveSupport::Concern

  included do
    # === Business Rule Validation ===

    # Validates all business rules for the cart item
    # @return [Result] Success/Failure with validation details
    def validate_business_rules
      BusinessRuleEngine.validate_cart_item(self)
    end

    # Checks if item can be added to cart
    # @param user [User] user attempting to add item
    # @param item [Item] item to be added
    # @param quantity [Integer] quantity to add
    # @return [Result] Success/Failure with eligibility details
    def self.can_add_to_cart?(user, item, quantity)
      rules = [
        BusinessRuleEngine::SellerCannotBuyOwnItemRule,
        BusinessRuleEngine::ItemAvailabilityRule,
        BusinessRuleEngine::InventoryAvailabilityRule,
        BusinessRuleEngine::PricingConsistencyRule,
        BusinessRuleEngine::QuantityLimitRule,
        BusinessRuleEngine::CartExpiryRule
      ]

      validate_against_rules(user, item, quantity, rules)
    end

    # Checks if cart item can be purchased
    # @return [Result] Success/Failure with purchase eligibility
    def can_purchase?
      rules = [
        BusinessRuleEngine::PurchaseEligibilityRule,
        BusinessRuleEngine::InventoryReservationRule,
        BusinessRuleEngine::PricingValidationRule,
        BusinessRuleEngine::CartItemExpiryRule
      ]

      validate_against_rules(user, item, quantity, rules)
    end

    # === Advanced Business Logic ===

    # Calculates dynamic pricing with business rules
    # @param base_price [BigDecimal] base item price
    # @param quantity [Integer] item quantity
    # @param user_context [Hash] user context for pricing rules
    # @return [PricingResult] calculated pricing with rules applied
    def calculate_dynamic_pricing(base_price, quantity, user_context = {})
      PricingEngine.calculate(
        base_price: base_price,
        quantity: quantity,
        user: user,
        item: item,
        user_context: user_context
      )
    end

    # Applies promotional discounts with business rules
    # @param promo_code [String] promotional code
    # @return [DiscountResult] discount calculation results
    def apply_promotion(promo_code)
      PromotionEngine.apply(
        promo_code: promo_code,
        user: user,
        item: item,
        quantity: quantity
      )
    end

    # Validates inventory availability with business rules
    # @return [InventoryResult] availability check results
    def check_inventory_availability
      InventoryBusinessEngine.check_availability(
        item: item,
        requested_quantity: quantity,
        reserved_quantity: reserved_quantity
      )
    end

    private

    # Validates against multiple business rules
    # @param user [User] user context
    # @param item [Item] item context
    # @param quantity [Integer] quantity context
    # @param rules [Array<Class>] business rule classes
    # @return [Result] Success/Failure with rule validation results
    def validate_against_rules(user, item, quantity, rules)
      context = BusinessRuleContext.new(
        user: user,
        item: item,
        quantity: quantity,
        cart_item: self
      )

      rule_results = rules.map do |rule_class|
        rule_class.validate(context)
      end

      failed_rules = rule_results.select(&:failure?)

      if failed_rules.any?
        Failure(BusinessRuleViolation.new(failed_rules.map(&:errors).flatten))
      else
        Success(rule_results)
      end
    end

    # Gets currently reserved quantity for this cart item
    # @return [Integer] reserved quantity
    def reserved_quantity
      metadata['reserved_quantity'] || 0
    end
  end

  # === Business Rule Context ===

  # Encapsulates context for business rule evaluation
  class BusinessRuleContext
    attr_reader :user, :item, :quantity, :cart_item, :timestamp

    # @param user [User] user context
    # @param item [Item] item context
    # @param quantity [Integer] quantity context
    # @param cart_item [CartItem] cart item context
    def initialize(user:, item:, quantity:, cart_item:)
      @user = user
      @item = item
      @quantity = quantity
      @cart_item = cart_item
      @timestamp = Time.current
    end

    # Gets additional context for rule evaluation
    # @return [Hash] contextual information
    def context
      {
        user_tier: user&.tier,
        item_category: item&.category,
        current_time: timestamp,
        day_of_week: timestamp.wday,
        is_peak_hour: peak_hour?,
        user_purchase_history: user_purchase_history
      }
    end

    private

    # Checks if current time is peak hour
    # @return [Boolean] true if peak hour
    def peak_hour?
      hour = timestamp.hour
      hour >= 18 && hour <= 22 # 6 PM to 10 PM
    end

    # Gets user's purchase history summary
    # @return [Hash] purchase history metrics
    def user_purchase_history
      {
        total_purchases: user&.orders&.completed&.count || 0,
        total_spent: user&.orders&.completed&.sum(&:total_amount) || 0,
        average_order_value: user&.orders&.completed&.average(&:total_amount) || 0
      }
    end
  end

  # === Business Rule Violation ===

  # Represents a business rule violation
  class BusinessRuleViolation < StandardError
    attr_reader :rule_name, :description, :severity, :context

    # @param rule_name [String] name of violated rule
    # @param description [String] human-readable description
    # @param severity [String] violation severity
    # @param context [Hash] additional context
    def initialize(rule_name, description, severity = 'error', context = {})
      @rule_name = rule_name
      @description = description
      @severity = severity
      @context = context

      super("#{rule_name}: #{description}")
    end
  end
end