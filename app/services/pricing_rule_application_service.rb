class PricingRuleApplicationService
  attr_reader :rule

  def initialize(rule)
    @rule = rule
  end

  def apply!(context = {})
    Rails.logger.info("Applying pricing rule ID: #{rule.id} with context: #{context}")

    begin
      return false unless calculation_service.applicable?(context)

      old_price = rule.product.price_cents
      new_price = calculation_service.calculate_price(old_price, context)

      if price_changed?(old_price, new_price)
        create_price_change_record(old_price, new_price, context)
        update_product_price(new_price)
        broadcast_price_change(old_price, new_price, context)

        Rails.logger.info("Successfully applied pricing rule ID: #{rule.id}, price: #{old_price} -> #{new_price}")
        true
      else
        Rails.logger.debug("No price change needed for rule ID: #{rule.id}")
        false
      end
    rescue => e
      Rails.logger.error("Failed to apply pricing rule ID: #{rule.id}. Error: #{e.message}")
      Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
      false
    end
  end

  def batch_apply!(contexts = [])
    Rails.logger.info("Batch applying pricing rule ID: #{rule.id} for #{contexts.count} contexts")

    begin
      results = []
      successful_applications = 0

      contexts.each do |context|
        result = apply!(context)
        results << { context: context, success: result }
        successful_applications += 1 if result
      end

      Rails.logger.info("Batch application completed for rule ID: #{rule.id}, successful: #{successful_applications}/#{contexts.count}")
      results
    rescue => e
      Rails.logger.error("Failed to batch apply pricing rule ID: #{rule.id}. Error: #{e.message}")
      contexts.map { |context| { context: context, success: false, error: e.message } }
    end
  end

  def preview_application(context = {})
    Rails.logger.debug("Previewing application for rule ID: #{rule.id}")

    begin
      return {} unless calculation_service.applicable?(context)

      old_price = rule.product.price_cents
      new_price = calculation_service.calculate_price(old_price, context)

      preview = {
        applicable: true,
        old_price: old_price,
        new_price: new_price,
        price_change: new_price - old_price,
        price_change_percentage: old_price.zero? ? 0 : ((new_price - old_price).to_f / old_price * 100).round(2),
        rule_name: rule.name,
        rule_type: rule.rule_type,
        conditions: rule.pricing_rule_conditions.map(&:condition_summary),
        would_apply: price_changed?(old_price, new_price)
      }

      Rails.logger.debug("Generated preview for rule ID: #{rule.id}")
      preview
    rescue => e
      Rails.logger.error("Failed to preview application for rule ID: #{rule.id}. Error: #{e.message}")
      { applicable: false, error: e.message }
    end
  end

  def rollback!(reason = 'Manual rollback')
    Rails.logger.info("Rolling back pricing rule ID: #{rule.id}, reason: #{reason}")

    begin
      # Find the last price change created by this rule
      last_change = rule.price_changes.where(product: rule.product).order(created_at: :desc).first

      if last_change
        # Revert to previous price
        previous_price = last_change.old_price_cents

        # Create rollback price change record
        rule.price_changes.create!(
          product: rule.product,
          old_price_cents: rule.product.price_cents,
          new_price_cents: previous_price,
          reason: "Rollback: #{reason}",
          metadata: { rollback: true, original_change_id: last_change.id }
        )

        rule.product.update!(price_cents: previous_price)

        Rails.logger.info("Successfully rolled back pricing rule ID: #{rule.id}")
        true
      else
        Rails.logger.warn("No price changes found to rollback for rule ID: #{rule.id}")
        false
      end
    rescue => e
      Rails.logger.error("Failed to rollback pricing rule ID: #{rule.id}. Error: #{e.message}")
      false
    end
  end

  def validate_application_context(context)
    Rails.logger.debug("Validating application context for rule ID: #{rule.id}")

    begin
      validation_result = {
        valid: true,
        errors: []
      }

      # Check required context based on rule type
      case rule.rule_type.to_sym
      when :bundle, :volume
        unless context[:quantity].present? && context[:quantity] > 0
          validation_result[:valid] = false
          validation_result[:errors] << 'quantity is required for bundle/volume rules'
        end
      when :user_segment
        unless context[:user].present?
          validation_result[:valid] = false
          validation_result[:errors] << 'user is required for user segment rules'
        end
      when :cart_value
        unless context[:cart_total].present?
          validation_result[:valid] = false
          validation_result[:errors] << 'cart_total is required for cart value rules'
        end
      end

      # Validate condition contexts
      rule.pricing_rule_conditions.each do |condition|
        condition_context = extract_condition_context(condition, context)
        unless condition_context[:valid]
          validation_result[:valid] = false
          validation_result[:errors] << "Invalid context for condition #{condition.id}: #{condition_context[:error]}"
        end
      end

      Rails.logger.debug("Context validation result for rule ID: #{rule.id}: #{validation_result}")
      validation_result
    rescue => e
      Rails.logger.error("Failed to validate application context for rule ID: #{rule.id}. Error: #{e.message}")
      { valid: false, errors: [e.message] }
    end
  end

  private

  def calculation_service
    @calculation_service ||= PricingRuleCalculationService.new(rule)
  end

  def price_changed?(old_price, new_price)
    old_price != new_price
  end

  def create_price_change_record(old_price, new_price, context)
    Rails.logger.debug("Creating price change record for rule ID: #{rule.id}")

    begin
      rule.price_changes.create!(
        product: rule.product,
        old_price_cents: old_price,
        new_price_cents: new_price,
        reason: "Applied rule: #{rule.name}",
        metadata: context.merge(rule_type: rule.rule_type, rule_id: rule.id)
      )

      Rails.logger.debug("Successfully created price change record for rule ID: #{rule.id}")
    rescue => e
      Rails.logger.error("Failed to create price change record for rule ID: #{rule.id}. Error: #{e.message}")
      raise e
    end
  end

  def update_product_price(new_price)
    Rails.logger.debug("Updating product price for rule ID: #{rule.id}")

    begin
      rule.product.update!(price_cents: new_price)

      Rails.logger.debug("Successfully updated product price for rule ID: #{rule.id}")
    rescue => e
      Rails.logger.error("Failed to update product price for rule ID: #{rule.id}. Error: #{e.message}")
      raise e
    end
  end

  def broadcast_price_change(old_price, new_price, context)
    Rails.logger.debug("Broadcasting price change for rule ID: #{rule.id}")

    begin
      # Broadcast to relevant channels
      PriceChangeBroadcaster.broadcast(
        product: rule.product,
        old_price: old_price,
        new_price: new_price,
        rule: rule,
        context: context
      )

      Rails.logger.debug("Successfully broadcasted price change for rule ID: #{rule.id}")
    rescue => e
      Rails.logger.error("Failed to broadcast price change for rule ID: #{rule.id}. Error: #{e.message}")
      # Don't raise here, just log the error
    end
  end

  def extract_condition_context(condition, context)
    # Extract context data relevant to the specific condition
    case condition.condition_type.to_sym
    when :time_of_day, :day_of_week, :stock_level, :view_count, :sales_velocity, :competitor_price, :product_age, :season
      { valid: true } # These don't need special context
    when :user_segment
      { valid: context[:user].present? }
    when :cart_value
      { valid: context[:cart_total].present? }
    else
      { valid: false, error: "Unknown condition type: #{condition.condition_type}" }
    end
  end
end