# frozen_string_literal: true

###############################################################################
# The Final Market - Database & System Health Check Tasks
# Autonomous Value Addition: Automated monitoring and diagnostics
#
# Usage:
#   rails health:check          # Complete system health check
#   rails health:database       # Database-specific checks
#   rails health:services       # External service checks
#   rails health:performance    # Performance diagnostics
###############################################################################

namespace :health do
  desc "Comprehensive system health check"
  task check: :environment do
    puts "\n" + "="*70
    puts "  THE FINAL MARKET - SYSTEM HEALTH CHECK"
    puts "  #{Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')}"
    puts "="*70 + "\n"

    results = {
      database: check_database_health,
      redis: check_redis_health,
      elasticsearch: check_elasticsearch_health,
      disk: check_disk_space,
      memory: check_memory_usage
    }

    print_health_summary(results)
  end

  desc "Database health and performance check"
  task database: :environment do
    puts "\n🔍 DATABASE HEALTH CHECK\n\n"
    
    # Connection check
    print "PostgreSQL Connection: "
    if ActiveRecord::Base.connection.active?
      puts "✓ Connected".colorize(:green)
    else
      puts "✗ Disconnected".colorize(:red)
      exit 1
    end

    # Database size
    result = ActiveRecord::Base.connection.execute(<<-SQL)
      SELECT pg_size_pretty(pg_database_size(current_database())) as size;
    SQL
    puts "Database Size: #{result.first['size']}"

    # Table statistics
    puts "\nTable Statistics:"
    puts "  #{'Table'.ljust(30)} #{'Rows'.rjust(10)} #{'Size'.rjust(10)}"
    puts "  " + "-"*52

    tables = ActiveRecord::Base.connection.tables.sort
    tables.each do |table|
      next if table.start_with?('ar_') # Skip internal Rails tables
      
      count = ActiveRecord::Base.connection.execute(
        "SELECT COUNT(*) FROM #{table}"
      ).first['count']
      
      size = ActiveRecord::Base.connection.execute(
        "SELECT pg_size_pretty(pg_total_relation_size('#{table}')) as size"
      ).first['size']
      
      puts "  #{table.ljust(30)} #{count.to_s.rjust(10)} #{size.rjust(10)}"
    end

    # Connection pool status
    puts "\nConnection Pool:"
    pool = ActiveRecord::Base.connection_pool
    puts "  Size: #{pool.size}"
    puts "  Connections: #{pool.connections.size}"
    puts "  Available: #{pool.available_connection_count}"

    # Index usage
    puts "\nIndex Usage Analysis:"
    unused_indexes = ActiveRecord::Base.connection.execute(<<-SQL)
      SELECT
        schemaname || '.' || tablename || '.' || indexname AS index_name,
        pg_size_pretty(pg_relation_size(indexrelid::regclass)) AS size
      FROM pg_stat_user_indexes
      WHERE idx_scan = 0
        AND indexrelid IS NOT NULL
      ORDER BY pg_relation_size(indexrelid::regclass) DESC
      LIMIT 10;
    SQL

    if unused_indexes.any?
      puts "  ⚠️  Unused indexes found (consider removing):"
      unused_indexes.each do |row|
        puts "    • #{row['index_name']} (#{row['size']})"
      end
    else
      puts "  ✓ All indexes are being used"
    end

    # Query performance (slow queries)
    puts "\nSlow Query Analysis:"
    slow_queries = ActiveRecord::Base.connection.execute(<<-SQL)
      SELECT
        query,
        calls,
        total_time,
        mean_time,
        max_time
      FROM pg_stat_statements
      WHERE mean_time > 100
      ORDER BY mean_time DESC
      LIMIT 5;
    SQL

    if slow_queries.any?
      puts "  ⚠️  Slow queries detected (mean > 100ms):"
      slow_queries.each do |row|
        puts "    • #{row['query'][0..60]}..."
        puts "      Mean: #{row['mean_time'].to_f.round(2)}ms, Max: #{row['max_time'].to_f.round(2)}ms"
      end
    else
      puts "  ✓ No slow queries detected"
    end
  rescue PG::Error => e
    puts "✗ Database Error: #{e.message}".colorize(:red)
  end

  desc "External service health check"
  task services: :environment do
    puts "\n🔍 EXTERNAL SERVICES CHECK\n\n"

    # Redis check
    print "Redis: "
    begin
      if Redis.new.ping == "PONG"
        puts "✓ Connected".colorize(:green)
        info = Redis.new.info
        puts "  Version: #{info['redis_version']}"
        puts "  Memory: #{info['used_memory_human']}"
        puts "  Connected clients: #{info['connected_clients']}"
      end
    rescue => e
      puts "✗ Not available - #{e.message}".colorize(:yellow)
    end

    # Elasticsearch check (if configured)
    if ENV['ENABLE_ELASTICSEARCH'] == 'true'
      print "\nElasticsearch: "
      begin
        require 'elasticsearch'
        client = Elasticsearch::Client.new(url: ENV['ELASTICSEARCH_URL'])
        health = client.cluster.health
        
        status = health['status']
        color = case status
                when 'green' then :green
                when 'yellow' then :yellow
                else :red
                end
        
        puts "✓ Connected (#{status})".colorize(color)
        puts "  Nodes: #{health['number_of_nodes']}"
        puts "  Indices: #{health['active_primary_shards']}"
      rescue => e
        puts "✗ Not available - #{e.message}".colorize(:yellow)
      end
    end

    # Sidekiq check
    print "\nSidekiq: "
    begin
      stats = Sidekiq::Stats.new
      puts "✓ Running".colorize(:green)
      puts "  Processed: #{stats.processed}"
      puts "  Failed: #{stats.failed}"
      puts "  Enqueued: #{stats.enqueued}"
      puts "  Scheduled: #{stats.scheduled_size}"
      puts "  Retries: #{stats.retry_size}"
      puts "  Dead: #{stats.dead_size}"
      
      if stats.failed > 0
        puts "  ⚠️  Warning: #{stats.failed} failed jobs".colorize(:yellow)
      end
    rescue => e
      puts "✗ Not running - #{e.message}".colorize(:yellow)
    end
  end

  desc "Performance diagnostics"
  task performance: :environment do
    puts "\n🔍 PERFORMANCE DIAGNOSTICS\n\n"

    # Application boot time
    puts "Rails Environment:"
    puts "  Rails version: #{Rails.version}"
    puts "  Ruby version: #{RUBY_VERSION}"
    puts "  Environment: #{Rails.env}"

    # Memory usage
    if defined?(GC)
      puts "\nGarbage Collection:"
      stats = GC.stat
      puts "  Count: #{stats[:count]}"
      puts "  Total time: #{stats[:time] / 1000.0}ms"
      puts "  Heap slots: #{stats[:heap_live_slots]}"
    end

    # Model count
    puts "\nModel Statistics:"
    [User, Product, Order].each do |model|
      count = model.count
      puts "  #{model.name.pluralize}: #{count}"
    end

    # Cache hit rate
    if Rails.cache.respond_to?(:stats)
      puts "\nCache Statistics:"
      stats = Rails.cache.stats
      puts "  Hits: #{stats[:hits]}"
      puts "  Misses: #{stats[:misses]}"
      hit_rate = (stats[:hits].to_f / (stats[:hits] + stats[:misses]) * 100).round(2)
      puts "  Hit rate: #{hit_rate}%"
    end

    # Recent errors (if using error tracking)
    puts "\nRecent Errors:"
    # This would integrate with your error tracking service
    puts "  (Configure error tracking service for details)"
  end

  # Helper methods
  private

  def check_database_health
    {
      connected: ActiveRecord::Base.connection.active?,
      pool_size: ActiveRecord::Base.connection_pool.size,
      available: ActiveRecord::Base.connection_pool.available_connection_count
    }
  rescue => e
    { error: e.message }
  end

  def check_redis_health
    Redis.new.ping == "PONG"
  rescue => e
    false
  end

  def check_elasticsearch_health
    return :disabled unless ENV['ENABLE_ELASTICSEARCH'] == 'true'
    
    require 'elasticsearch'
    client = Elasticsearch::Client.new(url: ENV['ELASTICSEARCH_URL'])
    client.cluster.health['status']
  rescue => e
    :unavailable
  end

  def check_disk_space
    if RUBY_PLATFORM =~ /darwin/
      usage = `df -h . | tail -1 | awk '{print $5}'`.strip
      { usage: usage, available: `df -h . | tail -1 | awk '{print $4}'`.strip }
    else
      { usage: 'N/A', available: 'N/A' }
    end
  end

  def check_memory_usage
    if RUBY_PLATFORM =~ /darwin/
      total_mb = `sysctl -n hw.memsize`.to_i / 1024 / 1024
      { total: "#{total_mb}MB" }
    else
      { total: 'N/A' }
    end
  end

  def print_health_summary(results)
    puts "\n" + "="*70
    puts "  HEALTH SUMMARY"
    puts "="*70 + "\n"

    # Database
    if results[:database][:connected]
      puts "✓ Database: Connected".colorize(:green)
      puts "  Pool: #{results[:database][:available]}/#{results[:database][:pool_size]} available"
    else
      puts "✗ Database: Disconnected".colorize(:red)
    end

    # Redis
    if results[:redis]
      puts "✓ Redis: Connected".colorize(:green)
    else
      puts "⚠️  Redis: Unavailable".colorize(:yellow)
    end

    # Elasticsearch
    case results[:elasticsearch]
    when :disabled
      puts "○ Elasticsearch: Disabled"
    when :unavailable
      puts "⚠️  Elasticsearch: Unavailable".colorize(:yellow)
    else
      puts "✓ Elasticsearch: #{results[:elasticsearch].capitalize}".colorize(:green)
    end

    # Resources
    puts "\nSystem Resources:"
    puts "  Disk usage: #{results[:disk][:usage]}"
    puts "  Disk available: #{results[:disk][:available]}"
    puts "  Memory: #{results[:memory][:total]}"

    puts "\n" + "="*70 + "\n"
  end
end

# String colorization helper
class String
  def colorize(color)
    colors = {
      red: "\e[31m",
      green: "\e[32m",
      yellow: "\e[33m",
      reset: "\e[0m"
    }
    "#{colors[color]}#{self}#{colors[:reset]}"
  end
end