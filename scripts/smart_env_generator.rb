#!/usr/bin/env ruby
# frozen_string_literal: true

###############################################################################
# The Final Market - Smart Environment Configuration Generator
# Autonomous Value Addition: Interactive .env setup with validation
#
# Features:
# - Interactive prompts for all required variables
# - Real-time validation
# - Secure input for sensitive data
# - API connectivity testing
# - Sane defaults for development
# - Color-coded output
###############################################################################

require 'io/console'
require 'uri'
require 'net/http'
require 'json'

# Color codes
class Colors
  RESET = "\e[0m"
  BOLD = "\e[1m"
  RED = "\e[31m"
  GREEN = "\e[32m"
  YELLOW = "\e[33m"
  BLUE = "\e[34m"
  MAGENTA = "\e[35m"
  CYAN = "\e[36m"
end

class SmartEnvGenerator
  include Colors

  REQUIRED_VARS = {
    'SECRET_KEY_BASE' => {
      description: 'Rails secret key for session encryption',
      validator: ->(v) { v.length >= 128 },
      generator: -> { SecureRandom.hex(64) },
      sensitive: true
    },
    'DATABASE_PASSWORD' => {
      description: 'PostgreSQL database password',
      validator: ->(v) { v.length >= 8 },
      default: 'postgres',
      sensitive: true
    },
    'SQUARE_ACCESS_TOKEN' => {
      description: 'Square API access token (from developer.squareup.com)',
      validator: ->(v) { v.start_with?('sq') || v.empty? },
      default: '',
      sensitive: true,
      optional: true
    },
    'SQUARE_LOCATION_ID' => {
      description: 'Square location ID',
      validator: ->(v) { v.length >= 10 || v.empty? },
      default: '',
      optional: true
    },
    'REDIS_URL' => {
      description: 'Redis connection URL',
      validator: ->(v) { v.start_with?('redis://') },
      default: 'redis://localhost:6379/1',
      tester: ->(v) { test_redis(v) }
    }
  }

  OPTIONAL_VARS = {
    'ELASTICSEARCH_URL' => {
      description: 'Elasticsearch connection URL (optional, for advanced search)',
      validator: ->(v) { v.start_with?('http') },
      default: 'http://localhost:9200',
      tester: ->(v) { test_elasticsearch(v) }
    },
    'SMTP_ADDRESS' => {
      description: 'SMTP server for email (optional)',
      default: 'smtp.gmail.com',
      optional: true
    },
    'SMTP_USERNAME' => {
      description: 'SMTP username',
      default: '',
      optional: true
    },
    'SMTP_PASSWORD' => {
      description: 'SMTP password',
      default: '',
      sensitive: true,
      optional: true
    }
  }

  def initialize
    @config = {}
    @env_file_path = File.join(Dir.pwd, '.env')
    @example_file_path = File.join(Dir.pwd, '.env.example')
  end

  def run
    print_header
    check_existing_env
    collect_required_vars
    collect_optional_vars
    write_env_file
    print_summary
  end

  private

  def print_header
    puts "#{GREEN}#{BOLD}"
    puts "╔═══════════════════════════════════════════════════════════════╗"
    puts "║                                                               ║"
    puts "║        The Final Market - Smart .env Generator               ║"
    puts "║                                                               ║"
    puts "║          Interactive Configuration with Validation           ║"
    puts "║                                                               ║"
    puts "╚═══════════════════════════════════════════════════════════════╝"
    puts "#{RESET}\n"
    puts "#{CYAN}This wizard will help you create a properly configured .env file.#{RESET}"
    puts "#{CYAN}Press Enter to accept default values shown in [brackets].#{RESET}\n\n"
  end

  def check_existing_env
    if File.exist?(@env_file_path)
      puts "#{YELLOW}⚠️  .env file already exists!#{RESET}"
      print "Do you want to overwrite it? (y/N): "
      response = STDIN.gets.chomp
      
      unless response.downcase == 'y'
        puts "#{GREEN}Keeping existing .env file. Exiting.#{RESET}"
        exit 0
      end
      
      # Backup existing file
      backup_path = "#{@env_file_path}.backup.#{Time.now.to_i}"
      FileUtils.cp(@env_file_path, backup_path)
      puts "#{GREEN}✓ Backed up existing .env to #{backup_path}#{RESET}\n\n"
    end
  end

  def collect_required_vars
    puts "#{BOLD}#{BLUE}=== Required Configuration ===${RESET}\n\n"
    
    REQUIRED_VARS.each do |key, config|
      collect_variable(key, config, required: true)
    end
  end

  def collect_optional_vars
    puts "\n#{BOLD}#{BLUE}=== Optional Configuration ===${RESET}\n\n"
    puts "#{CYAN}These are optional but recommended for full functionality.#{RESET}"
    print "Configure optional settings? (Y/n): "
    response = STDIN.gets.chomp
    
    return if response.downcase == 'n'
    
    OPTIONAL_VARS.each do |key, config|
      collect_variable(key, config, required: false)
    end
  end

  def collect_variable(key, config, required:)
    puts "\n#{BOLD}#{key}#{RESET}"
    puts "  #{config[:description]}"
    
    # Show default or generate value
    default_value = if config[:generator]
                      config[:generator].call
                    else
                      config[:default]
                    end
    
    # Show default if not sensitive
    default_display = if config[:sensitive] && default_value && !default_value.empty?
                        "[auto-generated]"
                      elsif default_value && !default_value.empty?
                        "[#{default_value}]"
                      else
                        ""
                      end
    
    print "  Value #{default_display}: "
    
    # Get input (hidden for sensitive data)
    value = if config[:sensitive]
              read_sensitive_input
            else
              STDIN.gets.chomp
            end
    
    # Use default if empty
    value = default_value if value.empty?
    
    # Validate
    if required && (value.nil? || value.empty?)
      puts "#{RED}✗ This field is required!#{RESET}"
      collect_variable(key, config, required: required)
      return
    end
    
    if config[:validator] && !value.empty? && !config[:validator].call(value)
      puts "#{RED}✗ Invalid format!#{RESET}"
      collect_variable(key, config, required: required)
      return
    end
    
    # Test connectivity if tester provided
    if config[:tester] && !value.empty?
      print "  Testing connection... "
      if config[:tester].call(value)
        puts "#{GREEN}✓ Connected#{RESET}"
      else
        puts "#{YELLOW}⚠️  Connection failed (continuing anyway)#{RESET}"
      end
    end
    
    @config[key] = value
    puts "#{GREEN}✓ Configured#{RESET}"
  end

  def read_sensitive_input
    if STDIN.respond_to?(:noecho)
      input = STDIN.noecho(&:gets).chomp
      puts  # Add newline after hidden input
      input
    else
      STDIN.gets.chomp
    end
  end

  def write_env_file
    puts "\n#{BOLD}#{BLUE}=== Writing Configuration ===${RESET}\n"
    
    # Read template from .env.example if exists
    template_content = if File.exist?(@example_file_path)
                         File.read(@example_file_path)
                       else
                         ""
                       end
    
    # Update or add variables
    @config.each do |key, value|
      if template_content.match?(/^#{key}=/)
        # Update existing
        template_content.gsub!(/^#{key}=.*$/, "#{key}=#{value}")
      else
        # Add new
        template_content += "#{key}=#{value}\n"
      end
    end
    
    # Write file
    File.write(@env_file_path, template_content)
    
    # Secure permissions
    File.chmod(0600, @env_file_path)
    
    puts "#{GREEN}✓ .env file created successfully#{RESET}"
    puts "#{GREEN}✓ File permissions set to 600 (owner read/write only)#{RESET}"
  end

  def print_summary
    puts "\n#{GREEN}#{BOLD}"
    puts "╔═══════════════════════════════════════════════════════════════╗"
    puts "║                                                               ║"
    puts "║                  ✓ CONFIGURATION COMPLETE!                   ║"
    puts "║                                                               ║"
    puts "╚═══════════════════════════════════════════════════════════════╝"
    puts "#{RESET}\n"
    
    puts "#{CYAN}Configuration Summary:#{RESET}"
    puts "  • #{@config.keys.count} variables configured"
    puts "  • .env file: #{@env_file_path}"
    puts "  • File permissions: 600 (secure)"
    
    # Warnings for missing optional configs
    missing_optional = OPTIONAL_VARS.keys.select { |k| @config[k].nil? || @config[k].empty? }
    unless missing_optional.empty?
      puts "\n#{YELLOW}⚠️  Optional configurations not set:#{RESET}"
      missing_optional.each do |key|
        puts "  • #{key} - #{OPTIONAL_VARS[key][:description]}"
      end
      puts "\n#{CYAN}You can add these later by editing .env file.#{RESET}"
    end
    
    puts "\n#{GREEN}Next steps:#{RESET}"
    puts "  1. Review .env file if needed: #{@env_file_path}"
    puts "  2. Run database setup: rails db:setup"
    puts "  3. Start the application: rails server"
    puts ""
  end

  def self.test_redis(url)
    require 'redis'
    Redis.new(url: url).ping == 'PONG'
  rescue StandardError
    false
  end

  def self.test_elasticsearch(url)
    uri = URI(url)
    response = Net::HTTP.get_response(uri)
    response.is_a?(Net::HTTPSuccess)
  rescue StandardError
    false
  end
end

# Run generator if called directly
if __FILE__ == $PROGRAM_NAME
  generator = SmartEnvGenerator.new
  generator.run
end