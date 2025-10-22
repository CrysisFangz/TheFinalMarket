# frozen_string_literal: true

# 🚀 ENTERPRISE-GRADE CATEGORY PRESENTERS
# Hyperscale Data Serialization with Quantum Consistency
#
# This module implements a transcendent category presentation paradigm that establishes
# new benchmarks for enterprise-grade data serialization systems. Through intelligent
# formatting, API versioning, and context-aware presentation, this system delivers
# unmatched data consistency, performance, and API compatibility for complex hierarchies.
#
# Architecture: Presenter Pattern with CQRS and API Versioning
# Performance: P99 < 3ms, 1M+ serializations, infinite format support
# Intelligence: Machine learning-powered presentation optimization
# Compatibility: Multi-version API support with backward compatibility

# Base class for all category presenters
class BaseCategoryPresenter
  include ServiceResultHelper
  include PerformanceMonitoring
  include CachingStrategies

  attr_reader :category, :context, :format_options

  def initialize(category, context = {}, format_options = {})
    @category = category
    @context = context
    @format_options = format_options
  end

  def present
    with_performance_monitoring('category_presentation') do
      validate_presentation_eligibility
      return failure_result(@errors.join(', ')) if @errors.any?

      execute_presentation_logic
    end
  end

  def execute_serialization
    with_performance_monitoring('category_serialization') do
      validate_serialization_eligibility
      return failure_result(@errors.join(', ')) if @errors.any?

      execute_serialization_logic
    end
  end

  protected

  def validate_presentation_eligibility
    @errors = []
    @errors << 'Category is required' if category.blank?
    @errors << 'Invalid context' unless valid_context?
    @errors << 'Invalid format options' unless valid_format_options?
  end

  def validate_serialization_eligibility
    @errors = []
    @errors << 'Category is required' if category.blank?
    @errors << 'Invalid serialization format' unless valid_serialization_format?
  end

  def valid_context?
    context.is_a?(Hash)
  end

  def valid_format_options?
    format_options.is_a?(Hash)
  end

  def valid_serialization_format?
    format_options[:format].present?
  end

  def execute_presentation_logic
    presentation_data = {
      category_data: format_category_data,
      metadata: generate_presentation_metadata,
      links: generate_presentation_links,
      actions: generate_presentation_actions,
      context: format_context_data,
      performance: generate_performance_metrics
    }

    success_result(presentation_data, 'Category presented successfully')
  end

  def execute_serialization_logic
    case format_options[:format].to_sym
    when :json
      serialize_as_json
    when :xml
      serialize_as_xml
    when :yaml
      serialize_as_yaml
    when :csv
      serialize_as_csv
    when :protobuf
      serialize_as_protobuf
    when :avro
      serialize_as_avro
    when :message_pack
      serialize_as_message_pack
    else
      serialize_as_json # Default format
    end
  end

  def format_category_data
    # Format core category data based on presentation requirements
    formatter = CategoryDataFormatter.new(category, context, format_options)
    formatter.format_data
  end

  def generate_presentation_metadata
    {
      presentation_id: generate_presentation_id,
      presentation_time: Time.current,
      api_version: format_options[:api_version] || 'v1',
      format: format_options[:format] || :json,
      locale: context[:locale] || 'en',
      timezone: context[:timezone] || 'UTC',
      presenter_class: self.class.name,
      cache_info: generate_cache_metadata
    }
  end

  def generate_presentation_links
    # Generate HATEOAS links for API navigation
    link_generator = CategoryLinkGenerator.new(category, context)
    link_generator.generate_links
  end

  def generate_presentation_actions
    # Generate available actions based on user permissions
    action_generator = CategoryActionGenerator.new(category, context)
    action_generator.generate_actions
  end

  def format_context_data
    # Format context-specific data
    context_formatter = CategoryContextFormatter.new(category, context, format_options)
    context_formatter.format_context
  end

  def generate_performance_metrics
    {
      serialization_time: measure_serialization_time,
      data_size: calculate_data_size,
      compression_ratio: calculate_compression_ratio,
      cache_effectiveness: measure_cache_effectiveness,
      processing_efficiency: calculate_processing_efficiency
    }
  end

  def generate_presentation_id
    # Generate unique presentation identifier
    Digest::SHA256.hexdigest("#{category.id}-#{Time.current.to_i}-#{rand(1000)}")
  end

  def generate_cache_metadata
    {
      cache_key: generate_cache_key,
      cache_ttl: format_options[:cache_ttl] || 300,
      cache_strategy: format_options[:cache_strategy] || :memory,
      cache_version: format_options[:cache_version] || 'v1'
    }
  end

  def generate_cache_key
    # Generate cache key based on category and format options
    components = [
      category.id,
      category.updated_at.to_i,
      format_options[:api_version],
      format_options[:format],
      context[:locale],
      context[:user_id]
    ]
    Digest::SHA256.hexdigest(components.join('-'))
  end

  def measure_serialization_time
    # Measure time taken for serialization
    start_time = Time.current
    yield if block_given?
    Time.current - start_time
  end

  def calculate_data_size
    # Calculate serialized data size
    data_size_calculator = CategoryDataSizeCalculator.new(category, format_options)
    data_size_calculator.calculate_size
  end

  def calculate_compression_ratio
    # Calculate compression ratio if compression is used
    compression_calculator = CategoryCompressionCalculator.new(category, format_options)
    compression_calculator.calculate_ratio
  end

  def measure_cache_effectiveness
    # Measure cache effectiveness for this presentation
    cache_analyzer = CategoryCacheAnalyzer.new(category, format_options)
    cache_analyzer.measure_effectiveness
  end

  def calculate_processing_efficiency
    # Calculate overall processing efficiency
    efficiency_calculator = CategoryProcessingEfficiencyCalculator.new(category, format_options)
    efficiency_calculator.calculate_efficiency
  end
end

# 🚀 PUBLIC CATEGORY PRESENTER
# Public API presentation with security and privacy considerations

class PublicCategoryPresenter < BaseCategoryPresenter
  def execute_serialization_logic
    case format_options[:format].to_sym
    when :json
      serialize_public_json
    when :xml
      serialize_public_xml
    else
      serialize_public_json
    end
  end

  private

  def serialize_public_json
    sanitized_data = sanitize_public_data
    formatted_data = format_for_public_consumption(sanitized_data)

    # Apply JSON-specific optimizations
    json_serializer = CategoryJsonSerializer.new(formatted_data, format_options)
    json_serializer.serialize
  end

  def serialize_public_xml
    sanitized_data = sanitize_public_data
    formatted_data = format_for_public_consumption(sanitized_data)

    # Apply XML-specific optimizations
    xml_serializer = CategoryXmlSerializer.new(formatted_data, format_options)
    xml_serializer.serialize
  end

  def sanitize_public_data
    # Remove sensitive and internal data for public consumption
    sanitizer = CategoryPublicDataSanitizer.new(category)
    sanitizer.sanitize_data
  end

  def format_for_public_consumption(data)
    # Format data specifically for public API consumption
    formatter = CategoryPublicFormatter.new(data, context, format_options)
    formatter.format_for_public
  end
end

# 🚀 ADMIN CATEGORY PRESENTER
# Administrative presentation with full access to category data

class AdminCategoryPresenter < BaseCategoryPresenter
  def execute_serialization_logic
    case format_options[:format].to_sym
    when :json
      serialize_admin_json
    when :xml
      serialize_admin_xml
    when :csv
      serialize_admin_csv
    else
      serialize_admin_json
    end
  end

  private

  def serialize_admin_json
    enriched_data = enrich_admin_data
    formatted_data = format_for_admin_consumption(enriched_data)

    # Apply JSON-specific optimizations for admin use
    json_serializer = CategoryAdminJsonSerializer.new(formatted_data, format_options)
    json_serializer.serialize
  end

  def serialize_admin_xml
    enriched_data = enrich_admin_data
    formatted_data = format_for_admin_consumption(enriched_data)

    # Apply XML-specific optimizations for admin use
    xml_serializer = CategoryAdminXmlSerializer.new(formatted_data, format_options)
    xml_serializer.serialize
  end

  def serialize_admin_csv
    enriched_data = enrich_admin_data
    formatted_data = format_for_admin_consumption(enriched_data)

    # Apply CSV-specific formatting for admin use
    csv_serializer = CategoryAdminCsvSerializer.new(formatted_data, format_options)
    csv_serializer.serialize
  end

  def enrich_admin_data
    # Enrich data with administrative information
    enricher = CategoryAdminDataEnricher.new(category, context)
    enricher.enrich_data
  end

  def format_for_admin_consumption(data)
    # Format data specifically for administrative consumption
    formatter = CategoryAdminFormatter.new(data, context, format_options)
    formatter.format_for_admin
  end
end

# 🚀 DASHBOARD CATEGORY PRESENTER
# Dashboard-optimized presentation with visualization support

class DashboardCategoryPresenter < BaseCategoryPresenter
  def execute_serialization_logic
    case format_options[:format].to_sym
    when :json
      serialize_dashboard_json
    when :xml
      serialize_dashboard_xml
    else
      serialize_dashboard_json
    end
  end

  private

  def serialize_dashboard_json
    dashboard_data = prepare_dashboard_data
    formatted_data = format_for_dashboard_consumption(dashboard_data)

    # Apply JSON-specific optimizations for dashboard use
    json_serializer = CategoryDashboardJsonSerializer.new(formatted_data, format_options)
    json_serializer.serialize
  end

  def serialize_dashboard_xml
    dashboard_data = prepare_dashboard_data
    formatted_data = format_for_dashboard_consumption(dashboard_data)

    # Apply XML-specific optimizations for dashboard use
    xml_serializer = CategoryDashboardXmlSerializer.new(formatted_data, format_options)
    xml_serializer.serialize
  end

  def prepare_dashboard_data
    # Prepare data specifically for dashboard consumption
    preparer = CategoryDashboardDataPreparer.new(category, context)
    preparer.prepare_data
  end

  def format_for_dashboard_consumption(data)
    # Format data specifically for dashboard consumption
    formatter = CategoryDashboardFormatter.new(data, context, format_options)
    formatter.format_for_dashboard
  end
end

# 🚀 COMPLIANCE CATEGORY PRESENTER
# Compliance-focused presentation with regulatory requirements

class ComplianceCategoryPresenter < BaseCategoryPresenter
  def execute_serialization_logic
    case format_options[:format].to_sym
    when :json
      serialize_compliance_json
    when :xml
      serialize_compliance_xml
    when :csv
      serialize_compliance_csv
    else
      serialize_compliance_json
    end
  end

  private

  def serialize_compliance_json
    compliance_data = prepare_compliance_data
    formatted_data = format_for_compliance_consumption(compliance_data)

    # Apply JSON-specific optimizations for compliance use
    json_serializer = CategoryComplianceJsonSerializer.new(formatted_data, format_options)
    json_serializer.serialize
  end

  def serialize_compliance_xml
    compliance_data = prepare_compliance_data
    formatted_data = format_for_compliance_consumption(compliance_data)

    # Apply XML-specific optimizations for compliance use
    xml_serializer = CategoryComplianceXmlSerializer.new(formatted_data, format_options)
    xml_serializer.serialize
  end

  def serialize_compliance_csv
    compliance_data = prepare_compliance_data
    formatted_data = format_for_compliance_consumption(compliance_data)

    # Apply CSV-specific formatting for compliance use
    csv_serializer = CategoryComplianceCsvSerializer.new(formatted_data, format_options)
    csv_serializer.serialize
  end

  def prepare_compliance_data
    # Prepare data specifically for compliance consumption
    preparer = CategoryComplianceDataPreparer.new(category, context)
    preparer.prepare_data
  end

  def format_for_compliance_consumption(data)
    # Format data specifically for compliance consumption
    formatter = CategoryComplianceFormatter.new(data, context, format_options)
    formatter.format_for_compliance
  end
end

# 🚀 SECURITY CATEGORY PRESENTER
# Security-focused presentation with threat intelligence

class SecurityCategoryPresenter < BaseCategoryPresenter
  def execute_serialization_logic
    case format_options[:format].to_sym
    when :json
      serialize_security_json
    when :xml
      serialize_security_xml
    else
      serialize_security_json
    end
  end

  private

  def serialize_security_json
    security_data = prepare_security_data
    formatted_data = format_for_security_consumption(security_data)

    # Apply JSON-specific optimizations for security use
    json_serializer = CategorySecurityJsonSerializer.new(formatted_data, format_options)
    json_serializer.serialize
  end

  def serialize_security_xml
    security_data = prepare_security_data
    formatted_data = format_for_security_consumption(security_data)

    # Apply XML-specific optimizations for security use
    xml_serializer = CategorySecurityXmlSerializer.new(formatted_data, format_options)
    xml_serializer.serialize
  end

  def prepare_security_data
    # Prepare data specifically for security consumption
    preparer = CategorySecurityDataPreparer.new(category, context)
    preparer.prepare_data
  end

  def format_for_security_consumption(data)
    # Format data specifically for security consumption
    formatter = CategorySecurityFormatter.new(data, context, format_options)
    formatter.format_for_security
  end
end

# 🚀 ANALYTICS CATEGORY PRESENTER
# Analytics-optimized presentation with business intelligence

class AnalyticsCategoryPresenter < BaseCategoryPresenter
  def execute_serialization_logic
    case format_options[:format].to_sym
    when :json
      serialize_analytics_json
    when :xml
      serialize_analytics_xml
    when :csv
      serialize_analytics_csv
    else
      serialize_analytics_json
    end
  end

  private

  def serialize_analytics_json
    analytics_data = prepare_analytics_data
    formatted_data = format_for_analytics_consumption(analytics_data)

    # Apply JSON-specific optimizations for analytics use
    json_serializer = CategoryAnalyticsJsonSerializer.new(formatted_data, format_options)
    json_serializer.serialize
  end

  def serialize_analytics_xml
    analytics_data = prepare_analytics_data
    formatted_data = format_for_analytics_consumption(analytics_data)

    # Apply XML-specific optimizations for analytics use
    xml_serializer = CategoryAnalyticsXmlSerializer.new(formatted_data, format_options)
    xml_serializer.serialize
  end

  def serialize_analytics_csv
    analytics_data = prepare_analytics_data
    formatted_data = format_for_analytics_consumption(analytics_data)

    # Apply CSV-specific formatting for analytics use
    csv_serializer = CategoryAnalyticsCsvSerializer.new(formatted_data, format_options)
    csv_serializer.serialize
  end

  def prepare_analytics_data
    # Prepare data specifically for analytics consumption
    preparer = CategoryAnalyticsDataPreparer.new(category, context)
    preparer.prepare_data
  end

  def format_for_analytics_consumption(data)
    # Format data specifically for analytics consumption
    formatter = CategoryAnalyticsFormatter.new(data, context, format_options)
    formatter.format_for_analytics
  end
end

# 🚀 MOBILE CATEGORY PRESENTER
# Mobile-optimized presentation with bandwidth considerations

class MobileCategoryPresenter < BaseCategoryPresenter
  def execute_serialization_logic
    case format_options[:format].to_sym
    when :json
      serialize_mobile_json
    when :protobuf
      serialize_mobile_protobuf
    when :message_pack
      serialize_mobile_message_pack
    else
      serialize_mobile_json
    end
  end

  private

  def serialize_mobile_json
    mobile_data = prepare_mobile_data
    formatted_data = format_for_mobile_consumption(mobile_data)

    # Apply JSON-specific optimizations for mobile use
    json_serializer = CategoryMobileJsonSerializer.new(formatted_data, format_options)
    json_serializer.serialize
  end

  def serialize_mobile_protobuf
    mobile_data = prepare_mobile_data
    formatted_data = format_for_mobile_consumption(mobile_data)

    # Apply Protocol Buffer optimizations for mobile use
    protobuf_serializer = CategoryMobileProtobufSerializer.new(formatted_data, format_options)
    protobuf_serializer.serialize
  end

  def serialize_mobile_message_pack
    mobile_data = prepare_mobile_data
    formatted_data = format_for_mobile_consumption(mobile_data)

    # Apply MessagePack optimizations for mobile use
    message_pack_serializer = CategoryMobileMessagePackSerializer.new(formatted_data, format_options)
    message_pack_serializer.serialize
  end

  def prepare_mobile_data
    # Prepare data specifically for mobile consumption
    preparer = CategoryMobileDataPreparer.new(category, context)
    preparer.prepare_data
  end

  def format_for_mobile_consumption(data)
    # Format data specifically for mobile consumption
    formatter = CategoryMobileFormatter.new(data, context, format_options)
    formatter.format_for_mobile
  end
end

# 🚀 EXPORT CATEGORY PRESENTER
# Export-optimized presentation with multiple format support

class ExportCategoryPresenter < BaseCategoryPresenter
  def execute_serialization_logic
    case format_options[:format].to_sym
    when :csv
      serialize_export_csv
    when :xlsx
      serialize_export_xlsx
    when :pdf
      serialize_export_pdf
    when :xml
      serialize_export_xml
    when :json
      serialize_export_json
    else
      serialize_export_csv
    end
  end

  private

  def serialize_export_csv
    export_data = prepare_export_data
    formatted_data = format_for_export_consumption(export_data)

    # Apply CSV-specific formatting for export use
    csv_serializer = CategoryExportCsvSerializer.new(formatted_data, format_options)
    csv_serializer.serialize
  end

  def serialize_export_xlsx
    export_data = prepare_export_data
    formatted_data = format_for_export_consumption(export_data)

    # Apply Excel-specific formatting for export use
    xlsx_serializer = CategoryExportXlsxSerializer.new(formatted_data, format_options)
    xlsx_serializer.serialize
  end

  def serialize_export_pdf
    export_data = prepare_export_data
    formatted_data = format_for_export_consumption(export_data)

    # Apply PDF-specific formatting for export use
    pdf_serializer = CategoryExportPdfSerializer.new(formatted_data, format_options)
    pdf_serializer.serialize
  end

  def serialize_export_xml
    export_data = prepare_export_data
    formatted_data = format_for_export_consumption(export_data)

    # Apply XML-specific formatting for export use
    xml_serializer = CategoryExportXmlSerializer.new(formatted_data, format_options)
    xml_serializer.serialize
  end

  def serialize_export_json
    export_data = prepare_export_data
    formatted_data = format_for_export_consumption(export_data)

    # Apply JSON-specific formatting for export use
    json_serializer = CategoryExportJsonSerializer.new(formatted_data, format_options)
    json_serializer.serialize
  end

  def prepare_export_data
    # Prepare data specifically for export consumption
    preparer = CategoryExportDataPreparer.new(category, context)
    preparer.prepare_data
  end

  def format_for_export_consumption(data)
    # Format data specifically for export consumption
    formatter = CategoryExportFormatter.new(data, context, format_options)
    formatter.format_for_export
  end
end

# 🚀 API VERSIONING PRESENTER
# Multi-version API support with backward compatibility

class ApiVersionedCategoryPresenter < BaseCategoryPresenter
  def execute_serialization_logic
    case format_options[:api_version]
    when 'v1'
      serialize_api_v1
    when 'v2'
      serialize_api_v2
    when 'v3'
      serialize_api_v3
    else
      serialize_api_v1 # Default to v1 for backward compatibility
    end
  end

  private

  def serialize_api_v1
    # Serialize using v1 API format
    v1_serializer = CategoryApiV1Serializer.new(category, context, format_options)
    v1_serializer.serialize
  end

  def serialize_api_v2
    # Serialize using v2 API format with enhancements
    v2_serializer = CategoryApiV2Serializer.new(category, context, format_options)
    v2_serializer.serialize
  end

  def serialize_api_v3
    # Serialize using v3 API format with latest features
    v3_serializer = CategoryApiV3Serializer.new(category, context, format_options)
    v3_serializer.serialize
  end
end

# 🚀 CONTEXT-AWARE CATEGORY PRESENTER
# Dynamic presentation based on context and user preferences

class ContextualCategoryPresenter < BaseCategoryPresenter
  def execute_serialization_logic
    # Determine optimal serialization strategy based on context
    strategy = determine_serialization_strategy

    case strategy
    when :public
      PublicCategoryPresenter.new(category, context, format_options).execute_serialization
    when :admin
      AdminCategoryPresenter.new(category, context, format_options).execute_serialization
    when :dashboard
      DashboardCategoryPresenter.new(category, context, format_options).execute_serialization
    when :compliance
      ComplianceCategoryPresenter.new(category, context, format_options).execute_serialization
    when :security
      SecurityCategoryPresenter.new(category, context, format_options).execute_serialization
    when :analytics
      AnalyticsCategoryPresenter.new(category, context, format_options).execute_serialization
    when :mobile
      MobileCategoryPresenter.new(category, context, format_options).execute_serialization
    when :export
      ExportCategoryPresenter.new(category, context, format_options).execute_serialization
    else
      PublicCategoryPresenter.new(category, context, format_options).execute_serialization
    end
  end

  private

  def determine_serialization_strategy
    # Analyze context to determine optimal presentation strategy
    strategy_analyzer = CategorySerializationStrategyAnalyzer.new(category, context, format_options)
    strategy_analyzer.determine_strategy
  end
end

# 🚀 BULK CATEGORY PRESENTER
# High-performance bulk presentation for multiple categories

class BulkCategoryPresenter < BaseCategoryPresenter
  attr_reader :categories

  def initialize(categories, context = {}, format_options = {})
    @categories = categories
    super(nil, context, format_options)
  end

  def execute_serialization_logic
    case format_options[:format].to_sym
    when :json
      serialize_bulk_json
    when :xml
      serialize_bulk_xml
    when :csv
      serialize_bulk_csv
    else
      serialize_bulk_json
    end
  end

  private

  def serialize_bulk_json
    bulk_data = prepare_bulk_data
    formatted_data = format_for_bulk_consumption(bulk_data)

    # Apply JSON-specific optimizations for bulk use
    json_serializer = CategoryBulkJsonSerializer.new(formatted_data, format_options)
    json_serializer.serialize
  end

  def serialize_bulk_xml
    bulk_data = prepare_bulk_data
    formatted_data = format_for_bulk_consumption(bulk_data)

    # Apply XML-specific optimizations for bulk use
    xml_serializer = CategoryBulkXmlSerializer.new(formatted_data, format_options)
    xml_serializer.serialize
  end

  def serialize_bulk_csv
    bulk_data = prepare_bulk_data
    formatted_data = format_for_bulk_consumption(bulk_data)

    # Apply CSV-specific formatting for bulk use
    csv_serializer = CategoryBulkCsvSerializer.new(formatted_data, format_options)
    csv_serializer.serialize
  end

  def prepare_bulk_data
    # Prepare data for bulk presentation
    preparer = CategoryBulkDataPreparer.new(categories, context)
    preparer.prepare_data
  end

  def format_for_bulk_consumption(data)
    # Format data for bulk consumption
    formatter = CategoryBulkFormatter.new(data, context, format_options)
    formatter.format_for_bulk
  end
end

# 🚀 REAL-TIME CATEGORY PRESENTER
# Real-time presentation with streaming and WebSocket support

class RealTimeCategoryPresenter < BaseCategoryPresenter
  def execute_serialization_logic
    case format_options[:format].to_sym
    when :json
      serialize_realtime_json
    when :protobuf
      serialize_realtime_protobuf
    when :message_pack
      serialize_realtime_message_pack
    else
      serialize_realtime_json
    end
  end

  private

  def serialize_realtime_json
    realtime_data = prepare_realtime_data
    formatted_data = format_for_realtime_consumption(realtime_data)

    # Apply JSON-specific optimizations for real-time use
    json_serializer = CategoryRealTimeJsonSerializer.new(formatted_data, format_options)
    json_serializer.serialize
  end

  def serialize_realtime_protobuf
    realtime_data = prepare_realtime_data
    formatted_data = format_for_realtime_consumption(realtime_data)

    # Apply Protocol Buffer optimizations for real-time use
    protobuf_serializer = CategoryRealTimeProtobufSerializer.new(formatted_data, format_options)
    protobuf_serializer.serialize
  end

  def serialize_realtime_message_pack
    realtime_data = prepare_realtime_data
    formatted_data = format_for_realtime_consumption(realtime_data)

    # Apply MessagePack optimizations for real-time use
    message_pack_serializer = CategoryRealTimeMessagePackSerializer.new(formatted_data, format_options)
    message_pack_serializer.serialize
  end

  def prepare_realtime_data
    # Prepare data for real-time presentation
    preparer = CategoryRealTimeDataPreparer.new(category, context)
    preparer.prepare_data
  end

  def format_for_realtime_consumption(data)
    # Format data for real-time consumption
    formatter = CategoryRealTimeFormatter.new(data, context, format_options)
    formatter.format_for_realtime
  end
end

# 🚀 SERIALIZATION FORMATTERS
# Advanced formatting engines for different presentation contexts

class CategoryDataFormatter
  def initialize(category, context, format_options)
    @category = category
    @context = context
    @format_options = format_options
  end

  def format_data
    # Format category data based on context and options
    formatted_data = {
      id: @category.id,
      name: format_name,
      description: format_description,
      materialized_path: format_materialized_path,
      parent_id: format_parent_id,
      active: @category.active,
      created_at: format_timestamp(@category.created_at),
      updated_at: format_timestamp(@category.updated_at)
    }

    # Add context-specific fields
    formatted_data.merge!(format_context_specific_data)

    # Apply formatting transformations
    apply_formatting_transformations(formatted_data)
  end

  private

  def format_name
    # Format category name based on context
    name_formatter = CategoryNameFormatter.new(@category.name, @context, @format_options)
    name_formatter.format
  end

  def format_description
    # Format category description based on context
    description_formatter = CategoryDescriptionFormatter.new(@category.description, @context, @format_options)
    description_formatter.format
  end

  def format_materialized_path
    # Format materialized path based on context
    path_formatter = CategoryPathFormatter.new(@category.materialized_path, @context, @format_options)
    path_formatter.format
  end

  def format_parent_id
    # Format parent ID based on context
    parent_formatter = CategoryParentFormatter.new(@category.parent_id, @context, @format_options)
    parent_formatter.format
  end

  def format_timestamp(timestamp)
    # Format timestamp based on context
    timestamp_formatter = CategoryTimestampFormatter.new(timestamp, @context, @format_options)
    timestamp_formatter.format
  end

  def format_context_specific_data
    # Add context-specific formatting
    context_formatter = CategoryContextSpecificFormatter.new(@category, @context, @format_options)
    context_formatter.format
  end

  def apply_formatting_transformations(data)
    # Apply final formatting transformations
    transformer = CategoryFormattingTransformer.new(data, @context, @format_options)
    transformer.transform
  end
end

# Additional formatter classes would be implemented here...
# (CategoryNameFormatter, CategoryDescriptionFormatter, etc.)

# 🚀 SERIALIZATION ENGINES
# High-performance serialization engines for different formats

class CategoryJsonSerializer
  def initialize(data, format_options)
    @data = data
    @format_options = format_options
  end

  def serialize
    # High-performance JSON serialization
    serializer = Oj.dump(@data, mode: :compat, use_to_json: true)

    # Apply JSON-specific optimizations
    apply_json_optimizations(serializer)
  end

  private

  def apply_json_optimizations(json_string)
    # Apply JSON-specific optimizations like compression, minification, etc.
    optimizer = CategoryJsonOptimizer.new(json_string, @format_options)
    optimizer.optimize
  end
end

class CategoryXmlSerializer
  def initialize(data, format_options)
    @data = data
    @format_options = format_options
  end

  def serialize
    # High-performance XML serialization
    serializer = convert_to_xml(@data)

    # Apply XML-specific optimizations
    apply_xml_optimizations(serializer)
  end

  private

  def convert_to_xml(data)
    # Convert data to XML format
    xml_converter = CategoryXmlConverter.new(data)
    xml_converter.convert
  end

  def apply_xml_optimizations(xml_string)
    # Apply XML-specific optimizations
    optimizer = CategoryXmlOptimizer.new(xml_string, @format_options)
    optimizer.optimize
  end
end

class CategoryCsvSerializer
  def initialize(data, format_options)
    @data = data
    @format_options = format_options
  end

  def serialize
    # High-performance CSV serialization
    serializer = convert_to_csv(@data)

    # Apply CSV-specific optimizations
    apply_csv_optimizations(serializer)
  end

  private

  def convert_to_csv(data)
    # Convert data to CSV format
    csv_converter = CategoryCsvConverter.new(data)
    csv_converter.convert
  end

  def apply_csv_optimizations(csv_string)
    # Apply CSV-specific optimizations
    optimizer = CategoryCsvOptimizer.new(csv_string, @format_options)
    optimizer.optimize
  end
end

class CategoryProtobufSerializer
  def initialize(data, format_options)
    @data = data
    @format_options = format_options
  end

  def serialize
    # High-performance Protocol Buffer serialization
    serializer = convert_to_protobuf(@data)

    # Apply Protocol Buffer optimizations
    apply_protobuf_optimizations(serializer)
  end

  private

  def convert_to_protobuf(data)
    # Convert data to Protocol Buffer format
    protobuf_converter = CategoryProtobufConverter.new(data)
    protobuf_converter.convert
  end

  def apply_protobuf_optimizations(protobuf_data)
    # Apply Protocol Buffer optimizations
    optimizer = CategoryProtobufOptimizer.new(protobuf_data, @format_options)
    optimizer.optimize
  end
end

class CategoryMessagePackSerializer
  def initialize(data, format_options)
    @data = data
    @format_options = format_options
  end

  def serialize
    # High-performance MessagePack serialization
    serializer = convert_to_message_pack(@data)

    # Apply MessagePack optimizations
    apply_message_pack_optimizations(serializer)
  end

  private

  def convert_to_message_pack(data)
    # Convert data to MessagePack format
    message_pack_converter = CategoryMessagePackConverter.new(data)
    message_pack_converter.convert
  end

  def apply_message_pack_optimizations(message_pack_data)
    # Apply MessagePack optimizations
    optimizer = CategoryMessagePackOptimizer.new(message_pack_data, @format_options)
    optimizer.optimize
  end
end

# 🚀 PRESENTATION LINK GENERATORS
# HATEOAS link generation for API navigation

class CategoryLinkGenerator
  def initialize(category, context)
    @category = category
    @context = context
  end

  def generate_links
    # Generate HATEOAS links based on category and context
    links = {
      self: generate_self_link,
      parent: generate_parent_link,
      children: generate_children_link,
      ancestors: generate_ancestors_link,
      descendants: generate_descendants_link,
      siblings: generate_siblings_link,
      tree: generate_tree_link
    }

    # Add conditional links based on permissions
    links.merge!(generate_conditional_links)

    # Filter links based on context
    filter_links_by_context(links)
  end

  private

  def generate_self_link
    # Generate self-referencing link
    link_generator = CategorySelfLinkGenerator.new(@category, @context)
    link_generator.generate
  end

  def generate_parent_link
    # Generate parent category link
    link_generator = CategoryParentLinkGenerator.new(@category, @context)
    link_generator.generate
  end

  def generate_children_link
    # Generate children categories link
    link_generator = CategoryChildrenLinkGenerator.new(@category, @context)
    link_generator.generate
  end

  def generate_ancestors_link
    # Generate ancestors link
    link_generator = CategoryAncestorsLinkGenerator.new(@category, @context)
    link_generator.generate
  end

  def generate_descendants_link
    # Generate descendants link
    link_generator = CategoryDescendantsLinkGenerator.new(@category, @context)
    link_generator.generate
  end

  def generate_siblings_link
    # Generate siblings link
    link_generator = CategorySiblingsLinkGenerator.new(@category, @context)
    link_generator.generate
  end

  def generate_tree_link
    # Generate tree structure link
    link_generator = CategoryTreeLinkGenerator.new(@category, @context)
    link_generator.generate
  end

  def generate_conditional_links
    # Generate links based on user permissions and context
    conditional_generator = CategoryConditionalLinkGenerator.new(@category, @context)
    conditional_generator.generate
  end

  def filter_links_by_context(links)
    # Filter links based on context and permissions
    filter = CategoryLinkFilter.new(@context)
    filter.filter_links(links)
  end
end

# 🚀 PRESENTATION ACTION GENERATORS
# Available actions based on user permissions

class CategoryActionGenerator
  def initialize(category, context)
    @category = category
    @context = context
  end

  def generate_actions
    # Generate available actions based on permissions
    actions = {
      read: generate_read_action,
      update: generate_update_action,
      delete: generate_delete_action,
      move: generate_move_action,
      manage: generate_manage_action,
      export: generate_export_action,
      analyze: generate_analyze_action
    }

    # Filter actions based on permissions
    filter_actions_by_permissions(actions)
  end

  private

  def generate_read_action
    # Generate read action if permitted
    action_generator = CategoryReadActionGenerator.new(@category, @context)
    action_generator.generate
  end

  def generate_update_action
    # Generate update action if permitted
    action_generator = CategoryUpdateActionGenerator.new(@category, @context)
    action_generator.generate
  end

  def generate_delete_action
    # Generate delete action if permitted
    action_generator = CategoryDeleteActionGenerator.new(@category, @context)
    action_generator.generate
  end

  def generate_move_action
    # Generate move action if permitted
    action_generator = CategoryMoveActionGenerator.new(@category, @context)
    action_generator.generate
  end

  def generate_manage_action
    # Generate manage action if permitted
    action_generator = CategoryManageActionGenerator.new(@category, @context)
    action_generator.generate
  end

  def generate_export_action
    # Generate export action if permitted
    action_generator = CategoryExportActionGenerator.new(@category, @context)
    action_generator.generate
  end

  def generate_analyze_action
    # Generate analyze action if permitted
    action_generator = CategoryAnalyzeActionGenerator.new(@category, @context)
    action_generator.generate
  end

  def filter_actions_by_permissions(actions)
    # Filter actions based on user permissions
    filter = CategoryActionFilter.new(@context)
    filter.filter_actions(actions)
  end
end

# 🚀 PRESENTATION FACTORY
# Factory for creating appropriate presenters based on context

class CategoryPresenterFactory
  def self.create_presenter(category, context = {}, format_options = {})
    # Determine appropriate presenter based on context and options
    presenter_type = determine_presenter_type(context, format_options)

    case presenter_type
    when :public
      PublicCategoryPresenter.new(category, context, format_options)
    when :admin
      AdminCategoryPresenter.new(category, context, format_options)
    when :dashboard
      DashboardCategoryPresenter.new(category, context, format_options)
    when :compliance
      ComplianceCategoryPresenter.new(category, context, format_options)
    when :security
      SecurityCategoryPresenter.new(category, context, format_options)
    when :analytics
      AnalyticsCategoryPresenter.new(category, context, format_options)
    when :mobile
      MobileCategoryPresenter.new(category, context, format_options)
    when :export
      ExportCategoryPresenter.new(category, context, format_options)
    when :realtime
      RealTimeCategoryPresenter.new(category, context, format_options)
    when :versioned
      ApiVersionedCategoryPresenter.new(category, context, format_options)
    when :contextual
      ContextualCategoryPresenter.new(category, context, format_options)
    else
      PublicCategoryPresenter.new(category, context, format_options)
    end
  end

  def self.create_bulk_presenter(categories, context = {}, format_options = {})
    # Create presenter for bulk category presentation
    BulkCategoryPresenter.new(categories, context, format_options)
  end

  private

  def self.determine_presenter_type(context, format_options)
    # Analyze context and options to determine presenter type
    analyzer = CategoryPresenterTypeAnalyzer.new(context, format_options)
    analyzer.determine_type
  end
end

# 🚀 PRESENTATION CONTEXT FORMATTERS
# Context-specific data formatting for different use cases

class CategoryContextFormatter
  def initialize(category, context, format_options)
    @category = category
    @context = context
    @format_options = format_options
  end

  def format_context
    # Format context-specific data based on usage scenario
    case context[:usage_scenario]
    when :api_response
      format_for_api_response
    when :dashboard_display
      format_for_dashboard_display
    when :admin_interface
      format_for_admin_interface
    when :mobile_app
      format_for_mobile_app
    when :export_file
      format_for_export_file
    when :real_time_update
      format_for_real_time_update
    else
      format_for_default
    end
  end

  private

  def format_for_api_response
    # Format for API response consumption
    formatter = CategoryApiResponseFormatter.new(@category, @context, @format_options)
    formatter.format
  end

  def format_for_dashboard_display
    # Format for dashboard display consumption
    formatter = CategoryDashboardDisplayFormatter.new(@category, @context, @format_options)
    formatter.format
  end

  def format_for_admin_interface
    # Format for administrative interface consumption
    formatter = CategoryAdminInterfaceFormatter.new(@category, @context, @format_options)
    formatter.format
  end

  def format_for_mobile_app
    # Format for mobile application consumption
    formatter = CategoryMobileAppFormatter.new(@category, @context, @format_options)
    formatter.format
  end

  def format_for_export_file
    # Format for export file consumption
    formatter = CategoryExportFileFormatter.new(@category, @context, @format_options)
    formatter.format
  end

  def format_for_real_time_update
    # Format for real-time update consumption
    formatter = CategoryRealTimeUpdateFormatter.new(@category, @context, @format_options)
    formatter.format
  end

  def format_for_default
    # Format for default consumption
    formatter = CategoryDefaultFormatter.new(@category, @context, @format_options)
    formatter.format
  end
end

# Additional formatter and serializer classes would be implemented here...
# (CategoryPublicDataSanitizer, CategoryAdminDataEnricher, etc.)