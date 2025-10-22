# frozen_string_literal: true

# Enterprise module registry providing centralized management,
# configuration, and lifecycle control for all enterprise modules
#
# @author Kilo Code Autonomous Agent
# @version 2.0.0
# @since 2025-10-19
#
# @example
#   # Register a new enterprise module
#   EnterpriseModules::ModuleRegistry.register(:custom_module) do
#     include CustomModule
#     configure_with :custom_config
#   end
#
#   # Use in model
#   class User < ApplicationRecord
#     enterprise_modules do
#       security :strict
#       audit :comprehensive
#       custom_module :enabled
#     end
#   end
#
module EnterpriseModules
  class ModuleRegistry
    # Module registry storage
    @modules = {}
    @dependencies = {}
    @configurations = {}

    class << self
      # Register a new enterprise module
      def register(module_name, dependencies: [], &block)
        module_name = module_name.to_sym

        @modules[module_name] = {
          name: module_name,
          block: block,
          dependencies: Array(dependencies),
          registered_at: Time.current
        }

        # Register reverse dependencies
        Array(dependencies).each do |dependency|
          @dependencies[dependency] ||= []
          @dependencies[dependency] << module_name
        end

        # Log registration
        log_module_registration(module_name)
      end

      # Get module configuration
      def get_module(module_name)
        @modules[module_name.to_sym]
      end

      # Check if module is registered
      def registered?(module_name)
        @modules.key?(module_name.to_sym)
      end

      # Get all registered modules
      def registered_modules
        @modules.keys
      end

      # Get module dependencies
      def dependencies(module_name)
        @dependencies[module_name.to_sym] || []
      end

      # Validate module configuration
      def validate_configuration(config)
        validator = ModuleConfigurationValidator.new

        {
          valid: validator.validate(config),
          errors: validator.errors,
          warnings: validator.warnings
        }
      end

      # Load modules for a model class
      def load_modules_for(model_class, config)
        loader = ModuleLoader.new(model_class)

        # Validate configuration first
        validation = validate_configuration(config)
        unless validation[:valid]
          raise ModuleConfigurationError, "Invalid module configuration: #{validation[:errors].join(', ')}"
        end

        # Load requested modules with dependencies
        loader.load_modules_with_dependencies(config)
      end

      # Get module analytics
      def module_analytics
        analytics_service = ModuleAnalyticsService.new

        {
          registered_modules: @modules.count,
          module_usage: analytics_service.module_usage_statistics,
          performance_metrics: analytics_service.performance_metrics,
          configuration_patterns: analytics_service.configuration_patterns
        }
      end

      private

      def log_module_registration(module_name)
        # Log module registration for monitoring
        Rails.logger.info "Enterprise Module Registered: #{module_name}"
      end
    end
  end

  # Module configuration validator
  class ModuleConfigurationValidator
    attr_reader :errors, :warnings

    def initialize
      @errors = []
      @warnings = []
    end

    def validate(config)
      @errors = []
      @warnings = []

      # Validate configuration structure
      validate_structure(config)

      # Validate module names
      validate_module_names(config)

      # Validate module configurations
      validate_module_configurations(config)

      # Validate dependencies
      validate_dependencies(config)

      @errors.empty?
    end

    private

    def validate_structure(config)
      unless config.is_a?(Hash)
        @errors << "Configuration must be a hash"
        return
      end

      # Check for valid configuration keys
      valid_keys = [:modules, :global_config, :module_configs]
      config.keys.each do |key|
        unless valid_keys.include?(key)
          @warnings << "Unknown configuration key: #{key}"
        end
      end
    end

    def validate_module_names(config)
      modules = config[:modules] || {}

      modules.keys.each do |module_name|
        unless ModuleRegistry.registered?(module_name)
          @errors << "Unknown module: #{module_name}"
        end
      end
    end

    def validate_module_configurations(config)
      modules = config[:modules] || {}

      modules.each do |module_name, module_config|
        validate_module_configuration(module_name, module_config)
      end
    end

    def validate_module_configuration(module_name, module_config)
      # Validate module-specific configuration
      case module_name.to_sym
      when :security
        validate_security_configuration(module_config)
      when :audit
        validate_audit_configuration(module_config)
      when :performance
        validate_performance_configuration(module_config)
      when :compliance
        validate_compliance_configuration(module_config)
      when :data_quality
        validate_data_quality_configuration(module_config)
      when :search
        validate_search_configuration(module_config)
      when :notifications
        validate_notification_configuration(module_config)
      when :caching
        validate_caching_configuration(module_config)
      when :integration
        validate_integration_configuration(module_config)
      else
        # Generic validation for unknown modules
        validate_generic_configuration(module_name, module_config)
      end
    end

    def validate_security_configuration(config)
      valid_levels = [:minimal, :standard, :strict, :comprehensive]
      level = config[:level] || config

      unless valid_levels.include?(level.to_sym)
        @errors << "Invalid security level: #{level}. Must be one of: #{valid_levels.join(', ')}"
      end
    end

    def validate_audit_configuration(config)
      valid_levels = [:minimal, :standard, :comprehensive, :forensic]
      level = config[:level] || config

      unless valid_levels.include?(level.to_sym)
        @errors << "Invalid audit level: #{level}. Must be one of: #{valid_levels.join(', ')}"
      end
    end

    def validate_performance_configuration(config)
      valid_levels = [:minimal, :standard, :aggressive, :comprehensive]
      level = config[:level] || config

      unless valid_levels.include?(level.to_sym)
        @errors << "Invalid performance level: #{level}. Must be one of: #{valid_levels.join(', ')}"
      end
    end

    def validate_compliance_configuration(config)
      valid_frameworks = [:gdpr, :ccpa, :sox, :pci_dss, :iso27001, :hipaa]
      frameworks = config[:frameworks] || []

      frameworks.each do |framework|
        unless valid_frameworks.include?(framework.to_sym)
          @errors << "Unknown compliance framework: #{framework}"
        end
      end
    end

    def validate_data_quality_configuration(config)
      valid_levels = [:basic, :standard, :comprehensive, :enterprise]
      level = config[:level] || config

      unless valid_levels.include?(level.to_sym)
        @errors << "Invalid data quality level: #{level}. Must be one of: #{valid_levels.join(', ')}"
      end
    end

    def validate_search_configuration(config)
      valid_providers = [:elasticsearch, :algolia, :solr, :database]
      providers = config[:providers] || []

      providers.each do |provider|
        unless valid_providers.include?(provider.to_sym)
          @errors << "Unknown search provider: #{provider}"
        end
      end
    end

    def validate_notification_configuration(config)
      valid_channels = [:action_cable, :websockets, :email, :sms, :push, :slack]
      channels = config[:channels] || []

      channels.each do |channel|
        unless valid_channels.include?(channel.to_sym)
          @errors << "Unknown notification channel: #{channel}"
        end
      end
    end

    def validate_caching_configuration(config)
      valid_strategies = [:memory, :redis, :file, :database, :memcached]
      strategies = config[:strategies] || []

      strategies.each do |strategy|
        unless valid_strategies.include?(strategy.to_sym)
          @errors << "Unknown caching strategy: #{strategy}"
        end
      end
    end

    def validate_integration_configuration(config)
      valid_providers = [:stripe, :shopify, :square, :paypal, :salesforce, :slack, :zendesk, :mailchimp]
      providers = config[:providers] || []

      providers.each do |provider|
        unless valid_providers.include?(provider.to_sym)
          @errors << "Unknown integration provider: #{provider}"
        end
      end
    end

    def validate_generic_configuration(module_name, module_config)
      # Generic validation for unknown modules
      unless module_config.is_a?(Hash) || module_config.is_a?(Symbol) || module_config.is_a?(String)
        @warnings << "Module #{module_name} configuration should be a hash, symbol, or string"
      end
    end

    def validate_dependencies(config)
      modules = config[:modules] || {}

      # Check for circular dependencies
      check_circular_dependencies(modules)

      # Check for missing dependencies
      check_missing_dependencies(modules)
    end

    def check_circular_dependencies(modules)
      # Implementation for circular dependency detection
      # This would use graph algorithms to detect cycles
    end

    def check_missing_dependencies(modules)
      modules.keys.each do |module_name|
        dependencies = ModuleRegistry.dependencies(module_name)

        dependencies.each do |dependency|
          unless modules.key?(dependency)
            @errors << "Module #{module_name} requires #{dependency} but it's not configured"
          end
        end
      end
    end
  end

  # Module loader for dynamic module inclusion
  class ModuleLoader
    def initialize(model_class)
      @model_class = model_class
    end

    def load_modules_with_dependencies(config)
      modules = config[:modules] || {}

      # Resolve module loading order based on dependencies
      loading_order = resolve_loading_order(modules.keys)

      # Load modules in dependency order
      loading_order.each do |module_name|
        load_module(module_name, modules[module_name], config)
      end
    end

    private

    def resolve_loading_order(module_names)
      # Topological sort to resolve dependencies
      sorter = TopologicalSorter.new

      module_names.each do |module_name|
        sorter.add(module_name, ModuleRegistry.dependencies(module_name))
      end

      sorter.sort
    end

    def load_module(module_name, module_config, global_config)
      # Get module definition
      module_def = ModuleRegistry.get_module(module_name)
      return unless module_def

      # Execute module definition block
      module_def[:block].call(@model_class, module_config, global_config)

      # Log module loading
      log_module_loading(module_name, module_config)
    end

    def log_module_loading(module_name, module_config)
      Rails.logger.info "Loading Enterprise Module: #{module_name} with config: #{module_config}"
    end
  end

  # Topological sorter for dependency resolution
  class TopologicalSorter
    def initialize
      @nodes = Set.new
      @edges = Set.new
      @incoming_edges = Hash.new { |h, k| h[k] = 0 }
    end

    def add(node, dependencies)
      @nodes << node
      dependencies.each do |dependency|
        @edges << [dependency, node]
        @incoming_edges[node] += 1
        @nodes << dependency
      end
    end

    def sort
      # Kahn's algorithm for topological sorting
      queue = @nodes.select { |node| @incoming_edges[node] == 0 }
      result = []

      until queue.empty?
        node = queue.shift
        result << node

        @edges.select { |edge| edge.first == node }.each do |edge|
          dependent = edge.last
          @incoming_edges[dependent] -= 1

          if @incoming_edges[dependent] == 0
            queue << dependent
          end
        end
      end

      if result.size != @nodes.size
        raise ModuleDependencyError, "Circular dependency detected in module configuration"
      end

      result
    end
  end

  # Module analytics service
  class ModuleAnalyticsService
    def module_usage_statistics
      # Analyze module usage patterns across models
      usage_stats = Hash.new(0)

      # Scan all model files for enterprise module usage
      model_files = find_model_files

      model_files.each do |file|
        usage = analyze_module_usage_in_file(file)
        usage.each { |module_name, count| usage_stats[module_name] += count }
      end

      usage_stats
    end

    def performance_metrics
      # Analyze performance impact of modules
      metrics = {}

      ModuleRegistry.registered_modules.each do |module_name|
        metrics[module_name] = analyze_module_performance(module_name)
      end

      metrics
    end

    def configuration_patterns
      # Analyze common configuration patterns
      patterns = []

      # Find common module combinations
      combinations = find_common_module_combinations
      patterns.concat(combinations)

      # Find common configuration values
      configurations = find_common_configurations
      patterns.concat(configurations)

      patterns
    end

    private

    def find_model_files
      # Find all model files in the application
      model_dir = Rails.root.join('app', 'models')
      Dir.glob("#{model_dir}/**/*.rb")
    end

    def analyze_module_usage_in_file(file)
      # Analyze module usage in a specific file
      usage = Hash.new(0)

      begin
        content = File.read(file)

        ModuleRegistry.registered_modules.each do |module_name|
          if content.include?("enterprise_modules") && content.include?(module_name.to_s)
            usage[module_name] += 1
          end
        end
      rescue
        # Skip files that can't be read
      end

      usage
    end

    def analyze_module_performance(module_name)
      # Analyze performance impact of a specific module
      # Implementation for performance analysis
      { average_load_time: 0, memory_usage: 0 }
    end

    def find_common_module_combinations
      # Find commonly used module combinations
      # Implementation for combination analysis
      []
    end

    def find_common_configurations
      # Find common configuration patterns
      # Implementation for configuration analysis
      []
    end
  end

  # Exception classes for module system
  class ModuleConfigurationError < StandardError; end
  class ModuleDependencyError < StandardError; end
  class ModuleLoadingError < StandardError; end

  # Auto-register core enterprise modules
  class ModuleAutoRegistrar
    def self.register_core_modules
      # Register SecurityModule
      ModuleRegistry.register(:security, dependencies: []) do |model_class, config, global_config|
        model_class.include EnterpriseModules::SecurityModule
        configure_security_module(model_class, config, global_config)
      end

      # Register AuditModule
      ModuleRegistry.register(:audit, dependencies: [:security]) do |model_class, config, global_config|
        model_class.include EnterpriseModules::AuditModule
        configure_audit_module(model_class, config, global_config)
      end

      # Register PerformanceModule
      ModuleRegistry.register(:performance, dependencies: []) do |model_class, config, global_config|
        model_class.include EnterpriseModules::PerformanceModule
        configure_performance_module(model_class, config, global_config)
      end

      # Register ComplianceModule
      ModuleRegistry.register(:compliance, dependencies: [:audit]) do |model_class, config, global_config|
        model_class.include EnterpriseModules::ComplianceModule
        configure_compliance_module(model_class, config, global_config)
      end

      # Register DataQualityModule
      ModuleRegistry.register(:data_quality, dependencies: []) do |model_class, config, global_config|
        model_class.include EnterpriseModules::DataQualityModule
        configure_data_quality_module(model_class, config, global_config)
      end

      # Register SearchModule
      ModuleRegistry.register(:search, dependencies: []) do |model_class, config, global_config|
        model_class.include EnterpriseModules::SearchModule
        configure_search_module(model_class, config, global_config)
      end

      # Register NotificationModule
      ModuleRegistry.register(:notifications, dependencies: []) do |model_class, config, global_config|
        model_class.include EnterpriseModules::NotificationModule
        configure_notification_module(model_class, config, global_config)
      end

      # Register CachingModule
      ModuleRegistry.register(:caching, dependencies: [:performance]) do |model_class, config, global_config|
        model_class.include EnterpriseModules::CachingModule
        configure_caching_module(model_class, config, global_config)
      end

      # Register IntegrationModule
      ModuleRegistry.register(:integration, dependencies: [:notifications]) do |model_class, config, global_config|
        model_class.include EnterpriseModules::IntegrationModule
        configure_integration_module(model_class, config, global_config)
      end
    end

    private

    def self.configure_security_module(model_class, config, global_config)
      # Configure security module with provided settings
      level = config[:level] || config || :standard
      model_class.security_level = level

      if config.is_a?(Hash)
        model_class.encryption_config = config[:encryption] || {}
        model_class.access_control_config = config[:access_control] || {}
      end
    end

    def self.configure_audit_module(model_class, config, global_config)
      # Configure audit module with provided settings
      level = config[:level] || config || :standard
      model_class.audit_level = level

      if config.is_a?(Hash)
        model_class.audit_events = config[:events] || []
        model_class.audit_retention = config[:retention] || {}
      end
    end

    def self.configure_performance_module(model_class, config, global_config)
      # Configure performance module with provided settings
      level = config[:level] || config || :standard
      model_class.performance_level = level

      if config.is_a?(Hash)
        model_class.monitoring_config = config[:monitoring] || {}
        model_class.optimization_config = config[:optimization] || {}
      end
    end

    def self.configure_compliance_module(model_class, config, global_config)
      # Configure compliance module with provided settings
      frameworks = config[:frameworks] || config || [:gdpr]
      model_class.compliance_frameworks = Array(frameworks)

      if config.is_a?(Hash)
        model_class.retention_policies = config[:retention] || {}
        model_class.consent_config = config[:consent] || {}
      end
    end

    def self.configure_data_quality_module(model_class, config, global_config)
      # Configure data quality module with provided settings
      level = config[:level] || config || :standard
      model_class.data_quality_level = level

      if config.is_a?(Hash)
        model_class.quality_rules = config[:rules] || {}
        model_class.validation_config = config[:validation] || {}
      end
    end

    def self.configure_search_module(model_class, config, global_config)
      # Configure search module with provided settings
      providers = config[:providers] || config || [:database]
      model_class.search_providers = Array(providers)

      if config.is_a?(Hash)
        model_class.search_mappings = config[:mappings] || {}
        model_class.search_settings = config[:settings] || {}
      end
    end

    def self.configure_notification_module(model_class, config, global_config)
      # Configure notification module with provided settings
      channels = config[:channels] || config || [:action_cable]
      model_class.notification_channels = Array(channels)

      if config.is_a?(Hash)
        model_class.notification_events = config[:events] || {}
        model_class.notification_templates = config[:templates] || {}
      end
    end

    def self.configure_caching_module(model_class, config, global_config)
      # Configure caching module with provided settings
      strategies = config[:strategies] || config || [:memory]
      model_class.cache_strategies = Array(strategies)

      if config.is_a?(Hash)
        model_class.cache_namespaces = config[:namespaces] || {}
        model_class.cache_dependencies = config[:dependencies] || {}
      end
    end

    def self.configure_integration_module(model_class, config, global_config)
      # Configure integration module with provided settings
      providers = config[:providers] || config || []
      model_class.external_providers = Array(providers)

      if config.is_a?(Hash)
        model_class.sync_config = config[:sync] || {}
        model_class.webhook_config = config[:webhooks] || {}
      end
    end
  end

  # Initialize core modules on application startup
  ModuleAutoRegistrar.register_core_modules
end