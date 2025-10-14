#!/usr/bin/env ruby
require 'pg'
require 'yaml'
require 'erb'

# Load database configuration
db_yaml = ERB.new(File.read('config/database.yml')).result
db_config = YAML.safe_load(db_yaml, aliases: true)['development']

# Connect to PostgreSQL
conn = PG.connect(
  host: db_config['host'] || 'localhost',
  dbname: db_config['database'],
  user: db_config['username'],
  password: db_config['password']
)

puts "Connected to database: #{db_config['database']}"

# Get already executed migrations
executed_migrations = conn.exec("SELECT version FROM schema_migrations ORDER BY version").map { |row| row['version'] }
puts "Already executed #{executed_migrations.count} migrations"
puts "Latest: #{executed_migrations.last}"

# Get all migration files
migration_files = Dir.glob('db/migrate/*.rb').sort

puts "\nTotal migration files: #{migration_files.count}"
puts "Remaining migrations to execute: #{migration_files.count - executed_migrations.count}"

# Helper methods for migration execution
def column_exists?(conn, table, column)
  result = conn.exec_params(
    "SELECT column_name FROM information_schema.columns WHERE table_name=$1 AND column_name=$2",
    [table.to_s, column.to_s]
  )
  result.ntuples > 0
end

def index_exists?(conn, table, columns)
  column_list = Array(columns).join(', ')
  result = conn.exec_params(
    "SELECT indexname FROM pg_indexes WHERE tablename=$1 AND indexdef LIKE '%' || $2 || '%'",
    [table.to_s, column_list]
  )
  result.ntuples > 0
end

def table_exists?(conn, table)
  result = conn.exec_params(
    "SELECT tablename FROM pg_tables WHERE tablename=$1",
    [table.to_s]
  )
  result.ntuples > 0
end

# Execute next pending migration
migration_files.each do |file|
  version = File.basename(file).split('_').first
  
  next if executed_migrations.include?(version)
  
  puts "\n" + "="*80
  puts "Executing migration: #{File.basename(file)}"
  puts "Version: #{version}"
  puts "="*80
  
  # Read migration file
  migration_content = File.read(file)
  
  # Try to execute it - this will show us what the next error is
  puts "Manual execution required for: #{file}"
  puts "Please check this migration for potential issues"
  
  # Just show the first pending migration and exit
  puts "\nMigration content:"
  puts migration_content
  break
end

conn.close