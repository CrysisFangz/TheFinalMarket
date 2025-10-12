module AnalyticsEngine
  class MarketBasketReport < BaseReport
    def generate_data
      {
        frequent_itemsets: find_frequent_itemsets,
        association_rules: generate_association_rules,
        product_affinities: calculate_product_affinities,
        bundle_recommendations: generate_bundle_recommendations
      }
    end
    
    def generate_summary
      rules = generate_association_rules
      
      {
        total_transactions: total_transactions,
        unique_products: unique_products_count,
        total_rules: rules.count,
        avg_confidence: format_percentage(rules.map { |r| r[:confidence] }.sum / [rules.count, 1].max.to_f),
        top_rule: rules.max_by { |r| r[:lift] }
      }
    end
    
    def generate_visualizations
      [
        {
          type: 'network_graph',
          title: 'Product Association Network',
          data: product_association_network
        },
        {
          type: 'bar_chart',
          title: 'Top Product Pairs by Lift',
          data: top_product_pairs
        }
      ]
    end
    
    private
    
    def min_support
      params[:min_support] || 0.01
    end
    
    def min_confidence
      params[:min_confidence] || 0.3
    end
    
    def total_transactions
      @total_transactions ||= Order.where(created_at: date_range, status: 'completed').count
    end
    
    def unique_products_count
      @unique_products_count ||= LineItem.joins(:order)
                                          .where(orders: { created_at: date_range, status: 'completed' })
                                          .distinct
                                          .count(:product_id)
    end
    
    def transactions
      @transactions ||= begin
        Order.where(created_at: date_range, status: 'completed')
             .includes(line_items: :product)
             .map do |order|
          order.line_items.map { |li| li.product_id }
        end
      end
    end
    
    def find_frequent_itemsets
      # Find frequent 1-itemsets
      item_counts = Hash.new(0)
      transactions.each do |transaction|
        transaction.uniq.each { |item| item_counts[item] += 1 }
      end
      
      min_support_count = (total_transactions * min_support).ceil
      frequent_1_itemsets = item_counts.select { |_, count| count >= min_support_count }
      
      # Find frequent 2-itemsets
      pair_counts = Hash.new(0)
      transactions.each do |transaction|
        transaction.combination(2).each { |pair| pair_counts[pair.sort] += 1 }
      end
      
      frequent_2_itemsets = pair_counts.select { |_, count| count >= min_support_count }
      
      # Convert to product names
      product_names = Product.where(id: item_counts.keys).pluck(:id, :name).to_h
      
      {
        single_items: frequent_1_itemsets.transform_keys { |id| product_names[id] }
                                        .transform_values { |count| (count.to_f / total_transactions).round(4) },
        item_pairs: frequent_2_itemsets.transform_keys { |ids| ids.map { |id| product_names[id] } }
                                      .transform_values { |count| (count.to_f / total_transactions).round(4) }
      }
    end
    
    def generate_association_rules
      itemsets = find_frequent_itemsets
      rules = []
      
      itemsets[:item_pairs].each do |pair, pair_support|
        product_a, product_b = pair
        
        # Rule: A => B
        support_a = itemsets[:single_items][product_a] || 0
        if support_a > 0
          confidence = pair_support / support_a
          lift = confidence / (itemsets[:single_items][product_b] || 0.0001)
          
          if confidence >= min_confidence
            rules << {
              antecedent: product_a,
              consequent: product_b,
              support: pair_support.round(4),
              confidence: confidence.round(4),
              lift: lift.round(4)
            }
          end
        end
        
        # Rule: B => A
        support_b = itemsets[:single_items][product_b] || 0
        if support_b > 0
          confidence = pair_support / support_b
          lift = confidence / (itemsets[:single_items][product_a] || 0.0001)
          
          if confidence >= min_confidence
            rules << {
              antecedent: product_b,
              consequent: product_a,
              support: pair_support.round(4),
              confidence: confidence.round(4),
              lift: lift.round(4)
            }
          end
        end
      end
      
      rules.sort_by { |r| -r[:lift] }.first(50)
    end
    
    def calculate_product_affinities
      affinities = {}
      
      Product.limit(100).each do |product|
        related_products = find_related_products(product.id)
        affinities[product.name] = related_products if related_products.any?
      end
      
      affinities
    end
    
    def find_related_products(product_id)
      # Find products frequently bought together
      related = LineItem.joins(:order)
                       .where(orders: { created_at: date_range, status: 'completed' })
                       .where(orders: { id: LineItem.where(product_id: product_id).select(:order_id) })
                       .where.not(product_id: product_id)
                       .group(:product_id)
                       .count
                       .sort_by { |_, count| -count }
                       .first(5)
      
      product_names = Product.where(id: related.map(&:first)).pluck(:id, :name).to_h
      related.map { |id, count| { name: product_names[id], count: count } }
    end
    
    def generate_bundle_recommendations
      rules = generate_association_rules
      
      # Group by antecedent to create bundles
      bundles = {}
      
      rules.group_by { |r| r[:antecedent] }.each do |product, product_rules|
        next if product_rules.count < 2
        
        bundle_items = product_rules.sort_by { |r| -r[:lift] }.first(3).map { |r| r[:consequent] }
        bundles[product] = {
          items: bundle_items,
          avg_lift: product_rules.map { |r| r[:lift] }.sum / product_rules.count.to_f
        }
      end
      
      bundles.sort_by { |_, data| -data[:avg_lift] }.first(10).to_h
    end
    
    def product_association_network
      rules = generate_association_rules.first(30)
      
      nodes = rules.flat_map { |r| [r[:antecedent], r[:consequent]] }.uniq
      edges = rules.map do |r|
        {
          from: r[:antecedent],
          to: r[:consequent],
          weight: r[:lift]
        }
      end
      
      { nodes: nodes, edges: edges }
    end
    
    def top_product_pairs
      itemsets = find_frequent_itemsets
      
      itemsets[:item_pairs]
        .sort_by { |_, support| -support }
        .first(10)
        .transform_keys { |pair| pair.join(' + ') }
    end
  end
end

