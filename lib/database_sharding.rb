# frozen_string_literal: true

module DatabaseSharding
  class << self
    # Get shard for a given user
    def shard_for_user(user_id)
      return :primary unless sharding_enabled?
      
      shard_number = (user_id % num_shards) + 1
      "shard_#{shard_number}".to_sym
    end
    
    # Get shard for a given model instance
    def shard_for(record)
      return :primary unless sharding_enabled?
      
      case record
      when User
        shard_for_user(record.id)
      when Product, Order, Cart
        shard_for_user(record.user_id)
      else
        :primary
      end
    end
    
    # Execute query on specific shard
    def on_shard(shard_name, &block)
      return yield unless sharding_enabled?
      
      ActiveRecord::Base.connected_to(shard: shard_name, &block)
    end
    
    # Execute query on all shards
    def on_all_shards(&block)
      return [yield] unless sharding_enabled?
      
      results = []
      (1..num_shards).each do |shard_number|
        shard_name = "shard_#{shard_number}".to_sym
        results << on_shard(shard_name, &block)
      end
      results
    end
    
    # Execute read query on replica
    def on_replica(shard_name = :primary, &block)
      return yield unless read_write_splitting_enabled?
      
      ActiveRecord::Base.connected_to(role: :reading, shard: shard_name, &block)
    end
    
    # Execute write query on primary
    def on_primary(shard_name = :primary, &block)
      ActiveRecord::Base.connected_to(role: :writing, shard: shard_name, &block)
    end
    
    # Migrate all shards
    def migrate_all_shards
      return unless sharding_enabled?
      
      (1..num_shards).each do |shard_number|
        shard_name = "shard_#{shard_number}".to_sym
        puts "Migrating #{shard_name}..."
        
        on_shard(shard_name) do
          ActiveRecord::Tasks::DatabaseTasks.migrate
        end
      end
    end
    
    # Check shard health
    def check_shard_health(shard_name)
      on_shard(shard_name) do
        ActiveRecord::Base.connection.execute("SELECT 1")
        { status: :healthy, shard: shard_name }
      end
    rescue => e
      { status: :unhealthy, shard: shard_name, error: e.message }
    end
    
    # Check all shards health
    def check_all_shards_health
      return [check_shard_health(:primary)] unless sharding_enabled?
      
      (1..num_shards).map do |shard_number|
        shard_name = "shard_#{shard_number}".to_sym
        check_shard_health(shard_name)
      end
    end
    
    # Get shard statistics
    def shard_statistics(shard_name)
      on_shard(shard_name) do
        {
          shard: shard_name,
          users_count: User.count,
          products_count: Product.count,
          orders_count: Order.count,
          database_size: database_size
        }
      end
    end
    
    # Get all shards statistics
    def all_shards_statistics
      return [shard_statistics(:primary)] unless sharding_enabled?
      
      (1..num_shards).map do |shard_number|
        shard_name = "shard_#{shard_number}".to_sym
        shard_statistics(shard_name)
      end
    end
    
    # Rebalance shards (move data between shards)
    def rebalance_shards
      # This is a complex operation that should be done carefully
      # Implementation depends on specific requirements
      raise NotImplementedError, "Shard rebalancing requires careful planning"
    end
    
    private
    
    def sharding_enabled?
      config.dig('sharding', 'enabled') || false
    end
    
    def read_write_splitting_enabled?
      config.dig('read_write_splitting', 'enabled') || false
    end
    
    def num_shards
      config.dig('sharding', 'num_shards') || 1
    end
    
    def config
      @config ||= YAML.load_file(Rails.root.join('config', 'database_sharding.yml'))[Rails.env]
    end
    
    def database_size
      result = ActiveRecord::Base.connection.execute(
        "SELECT pg_size_pretty(pg_database_size(current_database()))"
      )
      result.first['pg_size_pretty']
    end
  end
end

# Extend ActiveRecord::Base with sharding support
module ActiveRecord
  class Base
    class << self
      # Find record across all shards
      def find_across_shards(id)
        return find(id) unless DatabaseSharding.sharding_enabled?
        
        shard_name = DatabaseSharding.shard_for_user(id)
        DatabaseSharding.on_shard(shard_name) { find(id) }
      end
      
      # Query across all shards
      def where_across_shards(conditions)
        return where(conditions) unless DatabaseSharding.sharding_enabled?
        
        results = DatabaseSharding.on_all_shards { where(conditions).to_a }
        results.flatten
      end
      
      # Count across all shards
      def count_across_shards
        return count unless DatabaseSharding.sharding_enabled?
        
        counts = DatabaseSharding.on_all_shards { count }
        counts.sum
      end
    end
  end
end

