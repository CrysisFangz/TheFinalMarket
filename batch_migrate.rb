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

# Get all migration files
migration_files = Dir.glob('db/migrate/*.rb').sort

puts "Total migration files: #{migration_files.count}"
puts "Remaining: #{migration_files.count - executed_migrations.count}\n\n"

# Process each pending migration
migration_files.each do |file|
  version = File.basename(file).split('_').first
  
  next if executed_migrations.include?(version)
  
  puts "=" * 80
  puts "Processing: #{File.basename(file)}"
  puts "=" * 80
  
  # Read and display migration
  content = File.read(file)
  
  # Check if it's a simple CREATE TABLE migration we can auto-execute
  if content.include?('create_table') && !content.include?('drop_table') && !content.include?('remove_')
    puts "✓ Simple CREATE TABLE migration - attempting auto-execution"
    
    begin
      # Use Rails runner to execute this migration
      system("cd /Users/j.u.s.t.v.i.b.e.z.ofyonderclwdrs/TheFinalMarket && eval \"$(rbenv init - zsh)\" && DISABLE_DATABASE_ENVIRONMENT_CHECK=1 rails runner \"require '#{file}'; #{File.basename(file, '.rb').camelize}.new.migrate(:up)\" 2>&1")
      
      if $?.success?
        # Mark as executed
        conn.exec_params("INSERT INTO schema_migrations (version) VALUES ($1)", [version])
        puts "✓ Successfully executed and recorded\n\n"
      else
        puts "✗ Failed - needs manual review\n\n"
        break
      end
    rescue => e
      puts "✗ Error: #{e.message}"
      break
    end
  else
    puts "⚠ Complex migration - needs manual review"
    puts "First 20 lines:"
    puts content.lines.first(20).join
    break
  end
end

conn.close
puts "\n" + "=" * 80
puts "Migration batch processing complete"
puts "=" * 80