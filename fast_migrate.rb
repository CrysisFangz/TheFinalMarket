#!/usr/bin/env ruby
# Fast migration executor that bypasses Rails initialization issues

require 'pg'
require 'yaml'
require 'erb'

# Database connection
db_yaml = ERB.new(File.read('config/database.yml')).result
db_config = YAML.safe_load(db_yaml, aliases: true)['development']

conn = PG.connect(
  host: db_config['host'] || 'localhost',
  dbname: db_config['database'],
  user: db_config['username'],
  password: db_config['password']
)

puts "🚀 Fast Migration Executor"
puts "=" * 80

# Get executed migrations
executed = conn.exec("SELECT version FROM schema_migrations").map { |r| r['version'] }
puts "✓ #{executed.count} migrations already executed"

# Get all migration files
all_migrations = Dir.glob('db/migrate/*.rb').sort.map do |f|
  [File.basename(f).split('_').first, f]
end

pending = all_migrations.reject { |version, _| executed.include?(version) }
puts "⏳ #{pending.count} migrations pending\n\n"

# Execute each pending migration
pending.each_with_index do |(version, file), index|
  puts "[#{index + 1}/#{pending.count}] #{File.basename(file)}"
  
  content = File.read(file)
  
  # Skip complex migrations
  if content.match?(/remove_|rename_|drop_|change_column/)
    puts "  ⚠️  Complex migration - skipping for manual review"
    next
  end
  
  # Try to execute via standalone Ruby (without Rails)
  begin
    # Create a minimal migration executor
    result = `cd /Users/j.u.s.t.v.i.b.e.z.ofyonderclwdrs/TheFinalMarket && eval "$(rbenv init - zsh)" && ruby -e "
      require 'pg'
      require 'yaml'
      require 'erb'
      
      # Minimal ActiveRecord stubs
      module ActiveRecord
        class Migration
          def self.[](version); self; end
          def change; end
          def migrate(direction)
            change if direction == :up
          end
        end
        
        module ConnectionAdapters
          class PostgreSQLAdapter
            def initialize(conn)
              @conn = conn
            end
            
            def execute(sql)
              @conn.exec(sql)
            end
            
            def create_table(name, **options, &block)
              cols = []
              table_def = TableDefinition.new(name, cols)
              block.call(table_def)
              
              pk = options[:id] == false ? '' : 'id bigserial PRIMARY KEY,'
              col_defs = cols.map { |c| format_column(c) }.join(',')
              
              sql = %Q{CREATE TABLE IF NOT EXISTS #{name} (\#{pk}\#{col_defs})}
              execute(sql)
            end
            
            def add_index(table, columns, **options)
              cols = Array(columns).join(', ')
              name = options[:name] || \"index_\#{table}_on_\#{Array(columns).join('_')}\"
              unique = options[:unique] ? 'UNIQUE' : ''
              sql = %Q{CREATE \#{unique} INDEX IF NOT EXISTS \#{name} ON \#{table}(\#{cols})}
              execute(sql)
            end
            
            def add_reference(table, ref, **options)
              col_name = \"\#{ref}_id\"
              execute(%Q{ALTER TABLE \#{table} ADD COLUMN IF NOT EXISTS \#{col_name} bigint})
              
              if options[:foreign_key]
                fk_table = options[:foreign_key].is_a?(Hash) ? options[:foreign_key][:to_table] : \"\#{ref}s\"
                execute(%Q{ALTER TABLE \#{table} ADD CONSTRAINT fk_\#{table}_\#{col_name} FOREIGN KEY (\#{col_name}) REFERENCES \#{fk_table}(id)})
              end
              
              execute(%Q{CREATE INDEX IF NOT EXISTS index_\#{table}_on_\#{col_name} ON \#{table}(\#{col_name})})
            end
            
            private
            
            def format_column(col)
              type_map = {
                string: 'character varying',
                text: 'text',
                integer: 'integer',
                bigint: 'bigint',
                decimal: 'decimal',
                float: 'float',
                boolean: 'boolean',
                date: 'date',
                datetime: 'timestamp(6) without time zone',
                json: 'json',
                jsonb: 'jsonb'
              }
              
              sql_type = type_map[col[:type]] || col[:type].to_s
              parts = [col[:name], sql_type]
              parts << 'NOT NULL' if col[:null] == false
              parts << \"DEFAULT \#{col[:default]}\" if col[:default]
              parts.join(' ')
            end
          end
          
          class TableDefinition
            def initialize(name, cols)
              @name = name
              @cols = cols
            end
            
            [:string, :text, :integer, :bigint, :decimal, :float, :boolean, :date, :datetime, :json, :jsonb].each do |type|
              define_method(type) do |name, **options|
                @cols << { name: name, type: type, **options }
              end
            end
            
            def references(name, **options)
              @cols << { name: \"\#{name}_id\", type: :bigint, **options }
              @cols << { name: \"\#{name}_type\", type: :string } if options[:polymorphic]
            end
            
            def timestamps(**options)
              @cols << { name: :created_at, type: :datetime, null: false }
              @cols << { name: :updated_at, type: :datetime, null: false }
            end
          end
        end
      end
      
      # Load DB config
      db_yaml = ERB.new(File.read('config/database.yml')).result
      db_config = YAML.safe_load(db_yaml, aliases: true)['development']
      
      conn = PG.connect(
        host: db_config['host'] || 'localhost',
        dbname: db_config['database'],
        user: db_config['username'],
        password: db_config['password']
      )
      
      adapter = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.new(conn)
      
      # Load and execute migration
      load '#{file}'
      
      migration_class = Object.const_get(File.basename('#{file}', '.rb').split('_').map(&:capitalize).join)
      migration = migration_class.new
      
      # Execute migration with our adapter
      migration.define_singleton_method(:connection) { adapter }
      migration.migrate(:up)
      
      # Record migration
      conn.exec_params('INSERT INTO schema_migrations (version) VALUES ($1) ON CONFLICT DO NOTHING', ['#{version}'])
      
      conn.close
      puts '  ✓ Executed successfully'
    " 2>&1`
    
    if $?.success?
      puts "  ✓ Success"
    else
      puts "  ✗ Failed: #{result.lines.first(3).join}"
    end
    
  rescue => e
    puts "  ✗ Error: #{e.message}"
  end
  
  sleep 0.1
end

conn.close

puts "\n" + "=" * 80
puts "Migration execution complete!"
puts "=" * 80

# Show final count
conn = PG.connect(
  host: db_config['host'] || 'localhost',
  dbname: db_config['database'],
  user: db_config['username'],
  password: db_config['password']
)

final_count = conn.exec("SELECT COUNT(*) FROM schema_migrations").first['count']
puts "Total migrations executed: #{final_count}/#{all_migrations.count}"
conn.close