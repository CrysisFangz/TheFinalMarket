module Seller
  class PricingController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_seller!
    before_action :set_product, only: [:show, :recommendations, :apply_recommendation]
    
    def index
      @products = current_user.products.includes(:pricing_rules, :price_changes)
      @analytics_service = PricingAnalyticsService.new(current_user)
      @performance = @analytics_service.pricing_performance
      @optimization_score = @analytics_service.price_optimization_score
    end
    
    def show
      @pricing_service = DynamicPricingService.new(@product)
      @recommendation = @pricing_service.price_recommendation
      @insights = @pricing_service.pricing_insights
      @price_history = @product.price_changes.recent.limit(20)
      @active_rules = @product.pricing_rules.active
    end
    
    def recommendations
      @pricing_service = DynamicPricingService.new(@product)
      @recommendation = @pricing_service.price_recommendation
      
      respond_to do |format|
        format.json { render json: @recommendation }
        format.html
      end
    end
    
    def apply_recommendation
      @pricing_service = DynamicPricingService.new(@product)
      recommended_price = @pricing_service.optimal_price
      
      old_price = @product.price_cents
      
      if @product.update(price_cents: recommended_price)
        # Create price change record
        @product.price_changes.create!(
          old_price_cents: old_price,
          new_price_cents: recommended_price,
          user: current_user,
          reason: "Applied AI recommendation",
          metadata: { recommendation: @pricing_service.price_recommendation }
        )
        
        redirect_to seller_pricing_path(@product), notice: 'Price updated successfully based on recommendation'
      else
        redirect_to seller_pricing_path(@product), alert: 'Failed to update price'
      end
    end
    
    def analytics
      @analytics_service = PricingAnalyticsService.new(current_user)
      @performance = @analytics_service.pricing_performance(30.days)
      @elasticity_analysis = @analytics_service.elasticity_analysis
      @competitive_analysis = @analytics_service.competitive_analysis
      @pricing_trends = @analytics_service.pricing_trends(30)
      @rule_performance = @analytics_service.rule_performance_report
    end
    
    def rules
      @pricing_rules = current_user.products.flat_map(&:pricing_rules).uniq
      @rule_templates = pricing_rule_templates
    end
    
    def create_rule
      @product = current_user.products.find(params[:product_id])
      @pricing_rule = @product.pricing_rules.build(pricing_rule_params)
      @pricing_rule.user = current_user
      
      if @pricing_rule.save
        redirect_to seller_pricing_rules_path, notice: 'Pricing rule created successfully'
      else
        render :rules, alert: 'Failed to create pricing rule'
      end
    end
    
    def update_rule
      @pricing_rule = PricingRule.find(params[:id])
      authorize_rule_access!(@pricing_rule)
      
      if @pricing_rule.update(pricing_rule_params)
        redirect_to seller_pricing_rules_path, notice: 'Pricing rule updated successfully'
      else
        render :rules, alert: 'Failed to update pricing rule'
      end
    end
    
    def delete_rule
      @pricing_rule = PricingRule.find(params[:id])
      authorize_rule_access!(@pricing_rule)
      
      @pricing_rule.destroy
      redirect_to seller_pricing_rules_path, notice: 'Pricing rule deleted successfully'
    end
    
    def bulk_optimize
      products = current_user.products.where(id: params[:product_ids])
      
      optimized_count = 0
      products.each do |product|
        service = DynamicPricingService.new(product)
        optimal_price = service.optimal_price
        
        next if optimal_price == product.price_cents
        
        old_price = product.price_cents
        if product.update(price_cents: optimal_price)
          product.price_changes.create!(
            old_price_cents: old_price,
            new_price_cents: optimal_price,
            user: current_user,
            reason: "Bulk optimization",
            metadata: { bulk: true }
          )
          optimized_count += 1
        end
      end
      
      redirect_to seller_pricing_index_path, notice: "Optimized pricing for #{optimized_count} products"
    end
    
    private
    
    def set_product
      @product = current_user.products.find(params[:id] || params[:product_id])
    end
    
    def ensure_seller!
      redirect_to root_path, alert: 'Access denied' unless current_user.can_sell?
    end
    
    def authorize_rule_access!(rule)
      unless rule.product.user_id == current_user.id
        redirect_to seller_pricing_rules_path, alert: 'Access denied'
      end
    end
    
    def pricing_rule_params
      params.require(:pricing_rule).permit(
        :name, :description, :rule_type, :status, :priority,
        :min_price_cents, :max_price_cents, :start_date, :end_date,
        :config, pricing_rule_conditions_attributes: [
          :id, :condition_type, :operator, :value, :_destroy
        ]
      )
    end
    
    def pricing_rule_templates
      [
        {
          name: 'Flash Sale',
          rule_type: 'time_based',
          description: 'Temporary discount for limited time',
          config: { flash_sale_discount: 30, flash_sale_active: true }
        },
        {
          name: 'Clearance Sale',
          rule_type: 'inventory_based',
          description: 'Discount when stock is low',
          config: { low_stock_threshold: 10, clearance_discount: 25 }
        },
        {
          name: 'Surge Pricing',
          rule_type: 'demand_based',
          description: 'Increase price during high demand',
          config: { high_demand_threshold: 50, surge_percentage: 15 }
        },
        {
          name: 'Price Match',
          rule_type: 'competitor_based',
          description: 'Match competitor prices',
          config: { competitor_strategy: 'match_lowest' }
        },
        {
          name: 'Volume Discount',
          rule_type: 'volume',
          description: 'Discount for bulk purchases',
          config: {
            volume_tiers: [
              { min: 10, discount: 5 },
              { min: 50, discount: 10 },
              { min: 100, discount: 15 }
            ]
          }
        }
      ]
    end
  end
end

