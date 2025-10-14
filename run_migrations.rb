#!/usr/bin/env ruby
# Simple script to run migrations without full Rails boot
require 'bundler/setup'
ENV['RAILS_ENV'] ||= 'development'

# Load only what we need
require 'active_record'
require 'pg'
require 'yaml'
require 'erb'

# Load database configuration
db_config = YAML.load(ERB.new(File.read('config/database.yml')).result, aliases: true)
ActiveRecord::Base.establish_connection(db_config['development'])

# Load migrations
ActiveRecord::MigrationContext.new('db/migrate').migrate

puts "Migrations completed successfully!"