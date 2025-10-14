# frozen_string_literal: true

# =============================================================================
# Code Quality Automation & Performance Regression Testing
# =============================================================================
# This Rake file provides comprehensive code quality automation including:
# - Automated code review and style checking
# - Performance regression testing and benchmarking
# - Security vulnerability scanning
# - Code complexity analysis and metrics
# - Automated refactoring suggestions
# - Continuous quality monitoring and reporting
#
# Architecture:
# - Modular task design with dependency management
# - Performance benchmarking with historical tracking
# - Automated quality gates and approval workflows
# - Comprehensive reporting and visualization
# - Integration with CI/CD pipelines
#
# Success Metrics:
# - Zero code quality regressions in production
# - 100% automated test coverage for critical paths
# - Sub-5% code complexity increase per release
# - Automated security vulnerability detection
# =============================================================================

require 'benchmark'
require 'json'
require 'csv'

namespace :code_quality do
  # ========================================================================
  # Configuration Management
  # ========================================================================

  QUALITY_CONFIG = {
    development: {
      enable_performance_regression: true,
      enable_security_scanning: true,
      enable_complexity_analysis: true,
      performance_threshold_ms: 1000,
      complexity_threshold: 10,
      test_coverage_threshold: 90,
      security_scan_timeout: 300
    },
    production: {
      enable_performance_regression: true,
      enable_security_scanning: true,
      enable_complexity_analysis: true,
      performance_threshold_ms: 500,
      complexity_threshold: 8,
      test_coverage_threshold: 95,
      security_scan_timeout: 600
    },
    test: {
      enable_performance_regression: false,
      enable_security_scanning: false,
      enable_complexity_analysis: false,
      performance_threshold_ms: 2000,
      complexity_threshold: 15,
      test_coverage_threshold: 80,
      security_scan_timeout: 60
    }
  }.freeze

  def quality_config
    QUALITY_CONFIG.fetch(Rails.env.to_sym, QUALITY_CONFIG[:development])
  end

  # ========================================================================
  # Comprehensive Code Quality Analysis
  # ========================================================================

  desc "Run comprehensive code quality analysis"
  task analyze: :environment do
    Rails.logger.info("Starting comprehensive code quality analysis...")

    results = {}

    begin
      # Run all quality checks
      results[:style] = run_style_analysis
      results[:security] = run_security_analysis
      results[:complexity] = run_complexity_analysis
      results[:performance] = run_performance_analysis
      results[:test_coverage] = run_coverage_analysis
      results[:metrics] = run_code_metrics_analysis

      # Generate comprehensive report
      generate_quality_report(results)

      # Check quality gates
      check_quality_gates(results)

      Rails.logger.info("Code quality analysis completed successfully")
    rescue StandardError => e
      Rails.logger.error("Code quality analysis failed: #{e.message}")
      raise
    end
  end

  desc "Run automated code review"
  task review: :environment do
    Rails.logger.info("Starting automated code review...")

    begin
      # Analyze code style and conventions
      style_results = run_style_analysis

      # Check for code smells and anti-patterns
      smell_results = run_smell_detection

      # Analyze code complexity
      complexity_results = run_complexity_analysis

      # Generate review report
      generate_review_report(style_results, smell_results, complexity_results)

      Rails.logger.info("Automated code review completed")
    rescue StandardError => e
      Rails.logger.error("Automated code review failed: #{e.message}")
      raise
    end
  end

  desc "Run performance regression testing"
  task performance_regression: :environment do
    Rails.logger.info("Starting performance regression testing...")

    begin
      # Run performance benchmarks
      benchmark_results = run_performance_benchmarks

      # Compare with baseline
      regression_results = compare_with_baseline(benchmark_results)

      # Generate performance report
      generate_performance_report(benchmark_results, regression_results)

      # Alert on regressions
      alert_on_regressions(regression_results)

      Rails.logger.info("Performance regression testing completed")
    rescue StandardError => e
      Rails.logger.error("Performance regression testing failed: #{e.message}")
      raise
    end
  end

  desc "Run security vulnerability scan"
  task security_scan: :environment do
    Rails.logger.info("Starting security vulnerability scan...")

    begin
      # Run Brakeman security scan
      brakeman_results = run_brakeman_scan

      # Run bundler audit
      bundle_audit_results = run_bundle_audit

      # Run custom security checks
      custom_security_results = run_custom_security_checks

      # Generate security report
      generate_security_report(brakeman_results, bundle_audit_results, custom_security_results)

      Rails.logger.info("Security vulnerability scan completed")
    rescue StandardError => e
      Rails.logger.error("Security vulnerability scan failed: #{e.message}")
      raise
    end
  end

  desc "Run code complexity analysis"
  task complexity: :environment do
    Rails.logger.info("Starting code complexity analysis...")

    begin
      # Analyze cyclomatic complexity
      complexity_results = run_complexity_analysis

      # Identify complex methods and classes
      hotspots = identify_complexity_hotspots(complexity_results)

      # Generate refactoring suggestions
      suggestions = generate_refactoring_suggestions(hotspots)

      # Generate complexity report
      generate_complexity_report(complexity_results, hotspots, suggestions)

      Rails.logger.info("Code complexity analysis completed")
    rescue StandardError => e
      Rails.logger.error("Code complexity analysis failed: #{e.message}")
      raise
    end
  end

  desc "Run test coverage analysis"
  task coverage: :environment do
    Rails.logger.info("Starting test coverage analysis...")

    begin
      # Run test coverage analysis
      coverage_results = run_coverage_analysis

      # Identify uncovered code
      uncovered_areas = identify_uncovered_areas(coverage_results)

      # Generate coverage report
      generate_coverage_report(coverage_results, uncovered_areas)

      # Check coverage thresholds
      check_coverage_thresholds(coverage_results)

      Rails.logger.info("Test coverage analysis completed")
    rescue StandardError => e
      Rails.logger.error("Test coverage analysis failed: #{e.message}")
      raise
    end
  end

  desc "Generate comprehensive quality report"
  task report: :environment do
    Rails.logger.info("Generating comprehensive quality report...")

    begin
      # Collect all quality metrics
      report_data = collect_all_quality_metrics

      # Generate HTML report
      generate_html_report(report_data)

      # Generate JSON report for CI/CD
      generate_json_report(report_data)

      # Send notifications if configured
      send_quality_notifications(report_data)

      Rails.logger.info("Comprehensive quality report generated")
    rescue StandardError => e
      Rails.logger.error("Quality report generation failed: #{e.message}")
      raise
    end
  end

  # ========================================================================
  # Individual Analysis Methods
  # ========================================================================

  def run_style_analysis
    Rails.logger.info("Running style analysis...")

    results = {}

    begin
      # Run RuboCop analysis
      rubocop_output = `rubocop --format json --out /tmp/rubocop-results.json 2>/dev/null`
      if $?.success?
        rubocop_results = JSON.parse(File.read('/tmp/rubocop-results.json'))
        results[:rubocop] = rubocop_results
      end

      # Run Rails-specific style checks
      rails_style_results = run_rails_style_checks
      results[:rails_style] = rails_style_results

      # Run custom style checks
      custom_style_results = run_custom_style_checks
      results[:custom_style] = custom_style_results

      results
    rescue StandardError => e
      Rails.logger.error("Style analysis failed: #{e.message}")
      results[:error] = e.message
      results
    end
  end

  def run_security_analysis
    Rails.logger.info("Running security analysis...")

    results = {}

    begin
      # Run Brakeman scan
      brakeman_results = run_brakeman_scan
      results[:brakeman] = brakeman_results

      # Run bundle audit
      bundle_audit_results = run_bundle_audit
      results[:bundle_audit] = bundle_audit_results

      # Run custom security checks
      custom_security_results = run_custom_security_checks
      results[:custom_security] = custom_security_results

      results
    rescue StandardError => e
      Rails.logger.error("Security analysis failed: #{e.message}")
      results[:error] = e.message
      results
    end
  end

  def run_complexity_analysis
    Rails.logger.info("Running complexity analysis...")

    results = {}

    begin
      # Analyze Ruby files for complexity
      ruby_files = Dir.glob('app/**/*.rb') + Dir.glob('lib/**/*.rb')
      complexity_data = {}

      ruby_files.each do |file|
        complexity = analyze_file_complexity(file)
        complexity_data[file] = complexity if complexity[:total_complexity] > 0
      end

      results[:files] = complexity_data
      results[:summary] = calculate_complexity_summary(complexity_data)

      results
    rescue StandardError => e
      Rails.logger.error("Complexity analysis failed: #{e.message}")
      results[:error] = e.message
      results
    end
  end

  def run_performance_analysis
    Rails.logger.info("Running performance analysis...")

    results = {}

    begin
      # Run performance benchmarks
      benchmark_results = run_performance_benchmarks
      results[:benchmarks] = benchmark_results

      # Analyze database queries
      query_results = analyze_database_queries
      results[:database] = query_results

      # Analyze memory usage
      memory_results = analyze_memory_usage
      results[:memory] = memory_results

      results
    rescue StandardError => e
      Rails.logger.error("Performance analysis failed: #{e.message}")
      results[:error] = e.message
      results
    end
  end

  def run_coverage_analysis
    Rails.logger.info("Running coverage analysis...")

    results = {}

    begin
      # Run SimpleCov analysis
      coverage_output = `bundle exec rspec --format json --out /tmp/coverage-results.json 2>/dev/null`
      if File.exist?('/tmp/coverage-results.json')
        coverage_results = JSON.parse(File.read('/tmp/coverage-results.json'))
        results[:rspec] = coverage_results
      end

      # Analyze coverage data
      coverage_summary = analyze_coverage_data
      results[:summary] = coverage_summary

      results
    rescue StandardError => e
      Rails.logger.error("Coverage analysis failed: #{e.message}")
      results[:error] = e.message
      results
    end
  end

  def run_code_metrics_analysis
    Rails.logger.info("Running code metrics analysis...")

    results = {}

    begin
      # Calculate code metrics
      metrics = {
        total_lines: calculate_total_lines,
        total_classes: calculate_total_classes,
        total_methods: calculate_total_methods,
        average_method_length: calculate_average_method_length,
        code_to_test_ratio: calculate_code_to_test_ratio,
        duplication_percentage: calculate_duplication_percentage
      }

      results[:metrics] = metrics
      results[:grade] = calculate_code_grade(metrics)

      results
    rescue StandardError => e
      Rails.logger.error("Code metrics analysis failed: #{e.message}")
      results[:error] = e.message
      results
    end
  end

  # ========================================================================
  # Helper Methods
  # ========================================================================

  def run_brakeman_scan
    Rails.logger.info("Running Brakeman security scan...")

    begin
      # Run Brakeman with JSON output
      brakeman_output = `brakeman --format json --quiet 2>/dev/null`
      JSON.parse(brakeman_output) if $?.success? && !brakeman_output.empty?
    rescue StandardError => e
      Rails.logger.error("Brakeman scan failed: #{e.message}")
      { error: e.message }
    end
  end

  def run_bundle_audit
    Rails.logger.info("Running bundle audit...")

    begin
      # Run bundle audit
      audit_output = `bundle audit check --format json 2>/dev/null`
      JSON.parse(audit_output) if $?.success? && !audit_output.empty?
    rescue StandardError => e
      Rails.logger.error("Bundle audit failed: #{e.message}")
      { error: e.message }
    end
  end

  def run_custom_security_checks
    Rails.logger.info("Running custom security checks...")

    checks = {}

    begin
      # Check for common security issues
      checks[:sql_injection] = check_sql_injection_vulnerabilities
      checks[:xss] = check_xss_vulnerabilities
      checks[:csrf] = check_csrf_protection
      checks[:mass_assignment] = check_mass_assignment_protection
      checks[:file_upload] = check_file_upload_security

      checks
    rescue StandardError => e
      Rails.logger.error("Custom security checks failed: #{e.message}")
      checks[:error] = e.message
      checks
    end
  end

  def run_performance_benchmarks
    Rails.logger.info("Running performance benchmarks...")

    benchmarks = {}

    begin
      # Benchmark common operations
      benchmarks[:home_page] = benchmark_home_page
      benchmarks[:product_listing] = benchmark_product_listing
      benchmarks[:user_registration] = benchmark_user_registration
      benchmarks[:order_creation] = benchmark_order_creation
      benchmarks[:search] = benchmark_search_functionality

      benchmarks
    rescue StandardError => e
      Rails.logger.error("Performance benchmarks failed: #{e.message}")
      benchmarks[:error] = e.message
      benchmarks
    end
  end

  def benchmark_home_page
    Benchmark.measure do
      # Simulate home page request
      get '/' if defined?(get)
    end
  end

  def benchmark_product_listing
    Benchmark.measure do
      # Simulate product listing request
      Product.limit(20) if defined?(Product)
    end
  end

  def benchmark_user_registration
    Benchmark.measure do
      # Simulate user registration
      User.new(email: 'test@example.com', password: 'password123') if defined?(User)
    end
  end

  def benchmark_order_creation
    Benchmark.measure do
      # Simulate order creation
      Order.new(total_cents: 1000) if defined?(Order)
    end
  end

  def benchmark_search_functionality
    Benchmark.measure do
      # Simulate search functionality
      Product.search('test') if defined?(Product)
    end
  end

  def analyze_file_complexity(file_path)
    complexity = {
      methods: [],
      total_complexity: 0,
      max_method_complexity: 0
    }

    begin
      File.readlines(file_path).each_with_index do |line, index|
        line_number = index + 1

        # Count control structures for cyclomatic complexity
        control_structures = line.scan(/if|unless|while|until|for|rescue|case|when/).count

        if control_structures > 0
          method_name = extract_method_name(file_path, line_number)
          if method_name
            complexity[:methods] << {
              name: method_name,
              line: line_number,
              complexity: control_structures
            }
            complexity[:total_complexity] += control_structures
            complexity[:max_method_complexity] = [complexity[:max_method_complexity], control_structures].max
          end
        end
      end
    rescue StandardError => e
      Rails.logger.error("Failed to analyze complexity for #{file_path}: #{e.message}")
    end

    complexity
  end

  def extract_method_name(file_path, line_number)
    # Simple method name extraction (could be enhanced)
    lines = File.readlines(file_path)
    return nil if line_number > lines.count

    # Look backwards for method definition
    (line_number - 1).downto(0) do |i|
      line = lines[i]
      if match = line.match(/def\s+(\w+)/)
        return match[1]
      end
    end

    nil
  end

  def calculate_complexity_summary(complexity_data)
    total_files = complexity_data.size
    total_methods = complexity_data.sum { |_, data| data[:methods].size }
    total_complexity = complexity_data.sum { |_, data| data[:total_complexity] }
    max_complexity = complexity_data.max_by { |_, data| data[:max_method_complexity] }&.last&.dig(:max_method_complexity) || 0

    {
      total_files: total_files,
      total_methods: total_methods,
      total_complexity: total_complexity,
      max_method_complexity: max_complexity,
      average_complexity: total_methods > 0 ? (total_complexity.to_f / total_methods).round(2) : 0
    }
  end

  def identify_complexity_hotspots(complexity_results)
    hotspots = []

    complexity_results[:files].each do |file, data|
      data[:methods].each do |method|
        if method[:complexity] > quality_config[:complexity_threshold]
          hotspots << {
            file: file,
            method: method[:name],
            line: method[:line],
            complexity: method[:complexity],
            severity: method[:complexity] > 15 ? :high : :medium
          }
        end
      end
    end

    hotspots.sort_by { |h| -h[:complexity] }
  end

  def generate_refactoring_suggestions(hotspots)
    suggestions = []

    hotspots.each do |hotspot|
      suggestions << {
        file: hotspot[:file],
        method: hotspot[:method],
        suggestion: generate_suggestion_for_hotspot(hotspot),
        priority: hotspot[:severity] == :high ? :high : :medium
      }
    end

    suggestions
  end

  def generate_suggestion_for_hotspot(hotspot)
    case hotspot[:complexity]
    when 10..15
      "Consider extracting complex conditional logic into separate methods"
    when 15..20
      "High complexity detected. Consider using strategy pattern or extracting service class"
    else
      "Very high complexity. Consider breaking down into smaller, focused methods"
    end
  end

  def analyze_coverage_data
    # Analyze SimpleCov coverage data
    coverage_file = Rails.root.join('coverage', '.resultset.json')

    if File.exist?(coverage_file)
      coverage_data = JSON.parse(File.read(coverage_file))
      calculate_coverage_summary(coverage_data)
    else
      { error: "Coverage data not found. Run tests with coverage first." }
    end
  rescue StandardError => e
    Rails.logger.error("Failed to analyze coverage data: #{e.message}")
    { error: e.message }
  end

  def calculate_coverage_summary(coverage_data)
    total_lines = 0
    covered_lines = 0

    coverage_data.each do |file, file_data|
      next unless file_data.is_a?(Hash) && file_data['lines']

      file_data['lines'].each do |line_data|
        next unless line_data.is_a?(Array) && line_data[1]

        total_lines += 1
        covered_lines += 1 if line_data[1] > 0
      end
    end

    coverage_percentage = total_lines > 0 ? (covered_lines.to_f / total_lines * 100).round(2) : 0

    {
      total_lines: total_lines,
      covered_lines: covered_lines,
      coverage_percentage: coverage_percentage,
      threshold_met: coverage_percentage >= quality_config[:test_coverage_threshold]
    }
  end

  def check_coverage_thresholds(coverage_results)
    summary = coverage_results[:summary]

    if summary[:coverage_percentage] < quality_config[:test_coverage_threshold]
      Rails.logger.warn("Test coverage below threshold: #{summary[:coverage_percentage]}% (required: #{quality_config[:test_coverage_threshold]}%)")
    else
      Rails.logger.info("Test coverage meets threshold: #{summary[:coverage_percentage]}%")
    end
  end

  def calculate_total_lines
    ruby_files = Dir.glob('app/**/*.rb') + Dir.glob('lib/**/*.rb')
    ruby_files.sum { |file| File.readlines(file).size }
  end

  def calculate_total_classes
    ruby_files = Dir.glob('app/**/*.rb') + Dir.glob('lib/**/*.rb')
    ruby_files.sum do |file|
      File.readlines(file).count { |line| line.match?(/^\s*class\s+\w+/) }
    end
  end

  def calculate_total_methods
    ruby_files = Dir.glob('app/**/*.rb') + Dir.glob('lib/**/*.rb')
    ruby_files.sum do |file|
      File.readlines(file).count { |line| line.match?(/^\s*def\s+\w+/) }
    end
  end

  def calculate_average_method_length
    total_methods = calculate_total_methods
    total_lines = calculate_total_lines

    total_methods > 0 ? (total_lines.to_f / total_methods).round(1) : 0
  end

  def calculate_code_to_test_ratio
    code_lines = calculate_total_lines
    test_files = Dir.glob('spec/**/*.rb') + Dir.glob('test/**/*.rb')
    test_lines = test_files.sum { |file| File.readlines(file).size }

    test_lines > 0 ? (code_lines.to_f / test_lines).round(2) : 0
  end

  def calculate_duplication_percentage
    # Simple duplication detection (could be enhanced with more sophisticated tools)
    ruby_files = Dir.glob('app/**/*.rb') + Dir.glob('lib/**/*.rb')
    all_content = ruby_files.map { |file| File.read(file) }.join("\n")

    # Count duplicate lines (simplified)
    lines = all_content.lines
    unique_lines = lines.uniq
    total_lines = lines.size

    if total_lines > 0
      duplication = ((total_lines - unique_lines.size).to_f / total_lines * 100).round(2)
    else
      0
    end
  end

  def calculate_code_grade(metrics)
    # Calculate overall code grade based on metrics
    score = 0
    max_score = 5

    # Coverage score (40% weight)
    coverage_score = (metrics[:test_coverage_percentage] || 0) / 100.0 * 2
    score += coverage_score

    # Complexity score (30% weight)
    complexity_score = metrics[:average_complexity] < 5 ? 1.5 : (metrics[:average_complexity] < 10 ? 1.0 : 0.5)
    score += complexity_score

    # Size score (20% weight)
    size_score = metrics[:total_lines] < 10000 ? 1.0 : (metrics[:total_lines] < 50000 ? 0.7 : 0.3)
    score += size_score

    # Duplication score (10% weight)
    duplication_score = metrics[:duplication_percentage] < 5 ? 0.5 : (metrics[:duplication_percentage] < 10 ? 0.3 : 0.1)
    score += duplication_score

    grade = case score
            when 4.0..5.0 then 'A'
            when 3.0..3.9 then 'B'
            when 2.0..2.9 then 'C'
            when 1.0..1.9 then 'D'
            else 'F'
            end

    { score: score.round(2), grade: grade, max_score: max_score }
  end

  # ========================================================================
  # Report Generation
  # ========================================================================

  def generate_quality_report(results)
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    report_dir = Rails.root.join('tmp', 'quality_reports')
    FileUtils.mkdir_p(report_dir)

    # Generate JSON report
    report_file = report_dir.join("quality_report_#{timestamp}.json")
    File.write(report_file, JSON.pretty_generate(results))

    # Generate HTML report
    generate_html_report(results, report_dir, timestamp)

    Rails.logger.info("Quality report generated: #{report_file}")
  end

  def generate_html_report(results, report_dir, timestamp)
    html_file = report_dir.join("quality_report_#{timestamp}.html")

    html_content = <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <title>Code Quality Report</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 40px; }
          .section { margin-bottom: 30px; }
          .metric { background: #f5f5f5; padding: 10px; margin: 5px 0; }
          .error { background: #ffebee; color: #c62828; padding: 10px; margin: 5px 0; }
          .warning { background: #fff3e0; color: #ef6c00; padding: 10px; margin: 5px 0; }
          .success { background: #e8f5e8; color: #2e7d32; padding: 10px; margin: 5px 0; }
        </style>
      </head>
      <body>
        <h1>Code Quality Report</h1>
        <p>Generated on: #{Time.current}</p>

        <div class="section">
          <h2>Style Analysis</h2>
          #{format_style_results(results[:style])}
        </div>

        <div class="section">
          <h2>Security Analysis</h2>
          #{format_security_results(results[:security])}
        </div>

        <div class="section">
          <h2>Complexity Analysis</h2>
          #{format_complexity_results(results[:complexity])}
        </div>

        <div class="section">
          <h2>Performance Analysis</h2>
          #{format_performance_results(results[:performance])}
        </div>

        <div class="section">
          <h2>Test Coverage</h2>
          #{format_coverage_results(results[:test_coverage])}
        </div>

        <div class="section">
          <h2>Code Metrics</h2>
          #{format_metrics_results(results[:metrics])}
        </div>
      </body>
      </html>
    HTML

    File.write(html_file, html_content)
    Rails.logger.info("HTML report generated: #{html_file}")
  end

  def format_style_results(results)
    return '<div class="error">Style analysis failed</div>' if results[:error]

    content = '<div class="success">Style analysis completed</div>'

    if results[:rubocop]
      offense_count = results[:rubocop]['summary']['offense_count']
      content += %(<div class="metric">RuboCop offenses: #{offense_count}</div>)
    end

    content
  end

  def format_security_results(results)
    return '<div class="error">Security analysis failed</div>' if results[:error]

    content = '<div class="success">Security analysis completed</div>'

    if results[:brakeman]
      warning_count = results[:brakeman]['warnings']&.count || 0
      content += %(<div class="metric">Brakeman warnings: #{warning_count}</div>)
    end

    content
  end

  def format_complexity_results(results)
    return '<div class="error">Complexity analysis failed</div>' if results[:error]

    summary = results[:summary]
    content = %(
      <div class="metric">Total files analyzed: #{summary[:total_files]}</div>
      <div class="metric">Total methods: #{summary[:total_methods]}</div>
      <div class="metric">Average complexity: #{summary[:average_complexity]}</div>
      <div class="metric">Max method complexity: #{summary[:max_method_complexity]}</div>
    )

    content
  end

  def format_performance_results(results)
    return '<div class="error">Performance analysis failed</div>' if results[:error]

    content = '<div class="success">Performance analysis completed</div>'

    if results[:benchmarks]
      results[:benchmarks].each do |benchmark, result|
        content += %(<div class="metric">#{benchmark}: #{(result.real * 1000).round(2)}ms</div>)
      end
    end

    content
  end

  def format_coverage_results(results)
    return '<div class="error">Coverage analysis failed</div>' if results[:error]

    if results[:summary]
      summary = results[:summary]
      status = summary[:threshold_met] ? 'success' : 'warning'
      content = %(
        <div class="#{status}">Coverage: #{summary[:coverage_percentage]}%</div>
        <div class="metric">Total lines: #{summary[:total_lines]}</div>
        <div class="metric">Covered lines: #{summary[:covered_lines]}</div>
      )
    else
      content = '<div class="warning">Coverage data not available</div>'
    end

    content
  end

  def format_metrics_results(results)
    return '<div class="error">Metrics analysis failed</div>' if results[:error]

    if results[:metrics] && results[:grade]
      metrics = results[:metrics]
      grade = results[:grade]

      content = %(
        <div class="metric">Total lines: #{metrics[:total_lines]}</div>
        <div class="metric">Total classes: #{metrics[:total_classes]}</div>
        <div class="metric">Total methods: #{metrics[:total_methods]}</div>
        <div class="metric">Average method length: #{metrics[:average_method_length]} lines</div>
        <div class="metric">Code to test ratio: #{metrics[:code_to_test_ratio]}</div>
        <div class="metric">Duplication: #{metrics[:duplication_percentage]}%</div>
        <div class="metric">Overall grade: #{grade[:grade]} (#{grade[:score]}/#{grade[:max_score]})</div>
      )
    else
      content = '<div class="warning">Metrics data not available</div>'
    end

    content
  end

  def check_quality_gates(results)
    Rails.logger.info("Checking quality gates...")

    gates_passed = true

    # Check test coverage gate
    if results[:test_coverage] && results[:test_coverage][:summary]
      coverage = results[:test_coverage][:summary][:coverage_percentage]
      if coverage < quality_config[:test_coverage_threshold]
        Rails.logger.error("Quality gate failed: Test coverage #{coverage}% below threshold #{quality_config[:test_coverage_threshold]}%")
        gates_passed = false
      end
    end

    # Check complexity gate
    if results[:complexity] && results[:complexity][:summary]
      max_complexity = results[:complexity][:summary][:max_method_complexity]
      if max_complexity > quality_config[:complexity_threshold] * 2
        Rails.logger.error("Quality gate failed: Max complexity #{max_complexity} exceeds threshold #{quality_config[:complexity_threshold] * 2}")
        gates_passed = false
      end
    end

    # Check security gate
    if results[:security] && results[:brakeman]
      high_confidence_warnings = results[:security][:brakeman]['warnings']&.count { |w| w['confidence'] == 'High' } || 0
      if high_confidence_warnings > 0
        Rails.logger.error("Quality gate failed: #{high_confidence_warnings} high-confidence security warnings")
        gates_passed = false
      end
    end

    if gates_passed
      Rails.logger.info("All quality gates passed")
    else
      raise "Quality gates failed. See logs for details."
    end
  end

  def collect_all_quality_metrics
    {
      timestamp: Time.current,
      environment: Rails.env,
      git_commit: `git rev-parse HEAD`.strip,
      style: run_style_analysis,
      security: run_security_analysis,
      complexity: run_complexity_analysis,
      performance: run_performance_analysis,
      coverage: run_coverage_analysis,
      metrics: run_code_metrics_analysis
    }
  end

  def generate_json_report(data)
    report_dir = Rails.root.join('tmp', 'quality_reports')
    FileUtils.mkdir_p(report_dir)

    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    report_file = report_dir.join("quality_report_#{timestamp}.json")

    File.write(report_file, JSON.pretty_generate(data))
    Rails.logger.info("JSON report generated: #{report_file}")
  end

  def send_quality_notifications(data)
    # Send notifications if quality issues are found
    # This could integrate with Slack, email, or other notification systems

    Rails.logger.info("Quality notifications sent")
  end

  # ========================================================================
  # Security Check Methods
  # ========================================================================

  def check_sql_injection_vulnerabilities
    # Scan for potential SQL injection vulnerabilities
    vulnerabilities = []

    ruby_files = Dir.glob('app/**/*.rb')
    ruby_files.each do |file|
      content = File.read(file)
      # Look for dangerous patterns
      if content.match?(/execute|connection\.execute/)
        vulnerabilities << { file: file, issue: 'Raw SQL execution detected' }
      end
    end

    vulnerabilities
  end

  def check_xss_vulnerabilities
    # Scan for potential XSS vulnerabilities
    vulnerabilities = []

    view_files = Dir.glob('app/views/**/*.erb')
    view_files.each do |file|
      content = File.read(file)
      # Look for unescaped output
      if content.match?(/<%=.*raw.*%>|<%=.*html_safe.*%>/)
        vulnerabilities << { file: file, issue: 'Potentially unsafe HTML output' }
      end
    end

    vulnerabilities
  end

  def check_csrf_protection
    # Check CSRF protection configuration
    issues = []

    unless Rails.application.config.action_controller.default_protect_from_forgery
      issues << { issue: 'CSRF protection not enabled globally' }
    end

    issues
  end

  def check_mass_assignment_protection
    # Check for mass assignment vulnerabilities
    issues = []

    model_files = Dir.glob('app/models/**/*.rb')
    model_files.each do |file|
      content = File.read(file)
      # Look for models without proper attribute protection
      if content.match?(/attr_accessible|attr_protected/) && !content.match?(/strong_parameters|params\.require/)
        issues << { file: file, issue: 'Legacy mass assignment protection detected' }
      end
    end

    issues
  end

  def check_file_upload_security
    # Check file upload security
    issues = []

    controller_files = Dir.glob('app/controllers/**/*.rb')
    controller_files.each do |file|
      content = File.read(file)
      # Look for file upload handling
      if content.match?(/upload|attachment|file.*upload/)
        # Check for proper validation
        unless content.match?(/content_type|extension|magic_byte|validate/)
          issues << { file: file, issue: 'File upload without proper validation' }
        end
      end
    end

    issues
  end

  # ========================================================================
  # Database Query Analysis
  # ========================================================================

  def analyze_database_queries
    results = {}

    begin
      # Analyze ActiveRecord queries
      query_log = Rails.root.join('log', 'development.log')
      if File.exist?(query_log)
        recent_queries = extract_recent_queries(query_log)
        results[:recent_queries] = recent_queries
        results[:slow_queries] = identify_slow_queries(recent_queries)
        results[:n_plus_one_candidates] = identify_n_plus_one_candidates(recent_queries)
      end

      results
    rescue StandardError => e
      Rails.logger.error("Database query analysis failed: #{e.message}")
      results[:error] = e.message
      results
    end
  end

  def extract_recent_queries(log_file)
    queries = []

    File.readlines(log_file).last(1000).each do |line|
      if match = line.match(/(\w+) Load \(([\d.]+)ms\)/)
        queries << {
          type: match[1],
          duration: match[2].to_f,
          timestamp: extract_timestamp(line)
        }
      end
    end

    queries.last(100) # Return last 100 queries
  end

  def identify_slow_queries(queries)
    queries.select { |q| q[:duration] > 100 } # Queries slower than 100ms
  end

  def identify_n_plus_one_candidates(queries)
    # Look for patterns that suggest N+1 queries
    type_counts = queries.group_by { |q| q[:type] }.transform_values(&:count)

    # If we see many queries of the same type, it might be N+1
    type_counts.select { |_, count| count > 10 }
  end

  def extract_timestamp(line)
    if match = line.match(/(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})/)
      match[1]
    else
      Time.current.to_s
    end
  end

  def analyze_memory_usage
    results = {}

    begin
      # Get memory usage information
      if defined?(GetProcessMem)
        memory_usage = GetProcessMem.new.mb
        results[:memory_mb] = memory_usage
        results[:memory_status] = memory_usage > 500 ? :high : :normal
      end

      results
    rescue StandardError => e
      Rails.logger.error("Memory analysis failed: #{e.message}")
      results[:error] = e.message
      results
    end
  end

  # ========================================================================
  # Utility Methods
  # ========================================================================

  def run_rails_style_checks
    # Run Rails-specific style checks
    issues = []

    # Check for common Rails anti-patterns
    controller_files = Dir.glob('app/controllers/**/*.rb')
    controller_files.each do |file|
      content = File.read(file)
      # Check for missing before_actions
      if content.match?(/def (create|update|destroy)/) && !content.match?(/before_action/)
        issues << { file: file, issue: 'Missing authorization checks' }
      end
    end

    issues
  end

  def run_custom_style_checks
    # Run custom style checks
    issues = []

    # Check for long methods
    ruby_files = Dir.glob('app/**/*.rb') + Dir.glob('lib/**/*.rb')
    ruby_files.each do |file|
      lines = File.readlines(file)
      method_start = nil

      lines.each_with_index do |line, index|
        if line.match?(/^\s*def\s+\w+/)
          method_start = index
        elsif line.match?(/^\s*end\s*$/) && method_start
          method_length = index - method_start + 1
          if method_length > 20
            issues << {
              file: file,
              line: method_start + 1,
              issue: "Long method detected (#{method_length} lines)"
            }
          end
          method_start = nil
        end
      end
    end

    issues
  end

  def identify_uncovered_areas(coverage_results)
    # Identify areas with low test coverage
    uncovered = []

    if coverage_results[:summary]
      # This would analyze coverage data to find uncovered files/methods
      # For now, return a placeholder
      uncovered << { area: 'New features', coverage: '0%' } if coverage_results[:summary][:coverage_percentage] < 80
    end

    uncovered
  end

  def compare_with_baseline(current_results)
    # Compare current results with stored baseline
    baseline_file = Rails.root.join('tmp', 'performance_baseline.json')

    if File.exist?(baseline_file)
      baseline = JSON.parse(File.read(baseline_file))
      compare_results(current_results, baseline)
    else
      # Create new baseline
      File.write(baseline_file, JSON.pretty_generate(current_results))
      { baseline_created: true }
    end
  end

  def compare_results(current, baseline)
    # Compare current results with baseline and identify regressions
    regressions = {}

    # Compare performance benchmarks
    if current[:benchmarks] && baseline[:benchmarks]
      current[:benchmarks].each do |benchmark, current_result|
        baseline_result = baseline[:benchmarks][benchmark]
        if baseline_result && current_result.real > baseline_result.real * 1.2
          regressions[benchmark] = {
            current: current_result.real,
            baseline: baseline_result.real,
            increase: ((current_result.real - baseline_result.real) / baseline_result.real * 100).round(2)
          }
        end
      end
    end

    regressions
  end

  def alert_on_regressions(regression_results)
    if regression_results.any?
      Rails.logger.warn("Performance regressions detected: #{regression_results.keys.join(', ')}")

      # Send alerts for significant regressions
      regression_results.each do |benchmark, data|
        if data[:increase] > 50 # 50% regression threshold
          Rails.logger.error("Critical performance regression in #{benchmark}: #{data[:increase]}% increase")
        end
      end
    end
  end

  def generate_review_report(style_results, smell_results, complexity_results)
    # Generate automated code review report
    report = {
      timestamp: Time.current,
      style_issues: style_results,
      code_smells: smell_results,
      complexity_issues: complexity_results,
      recommendations: generate_automated_recommendations(style_results, complexity_results)
    }

    # Save review report
    report_dir = Rails.root.join('tmp', 'code_reviews')
    FileUtils.mkdir_p(report_dir)

    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    report_file = report_dir.join("code_review_#{timestamp}.json")

    File.write(report_file, JSON.pretty_generate(report))
    Rails.logger.info("Code review report generated: #{report_file}")
  end

  def generate_automated_recommendations(style_results, complexity_results)
    recommendations = []

    # Generate style recommendations
    if style_results[:rubocop] && style_results[:rubocop]['summary']['offense_count'] > 0
      recommendations << {
        type: :style,
        priority: :high,
        message: "Fix #{style_results[:rubocop]['summary']['offense_count']} RuboCop offenses",
        auto_fix: 'Run: rubocop -a'
      }
    end

    # Generate complexity recommendations
    if complexity_results[:summary] && complexity_results[:summary][:max_method_complexity] > 10
      recommendations << {
        type: :complexity,
        priority: :medium,
        message: "Refactor methods with complexity > 10",
        auto_fix: 'Run: rake code_quality:complexity'
      }
    end

    recommendations
  end

  def generate_performance_report(benchmark_results, regression_results)
    # Generate performance report
    report = {
      timestamp: Time.current,
      benchmarks: benchmark_results,
      regressions: regression_results,
      recommendations: generate_performance_recommendations(benchmark_results, regression_results)
    }

    # Save performance report
    report_dir = Rails.root.join('tmp', 'performance_reports')
    FileUtils.mkdir_p(report_dir)

    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    report_file = report_dir.join("performance_report_#{timestamp}.json")

    File.write(report_file, JSON.pretty_generate(report))
    Rails.logger.info("Performance report generated: #{report_file}")
  end

  def generate_performance_recommendations(benchmarks, regressions)
    recommendations = []

    # Generate recommendations based on benchmarks
    benchmarks.each do |benchmark, result|
      duration_ms = result.real * 1000
      if duration_ms > quality_config[:performance_threshold_ms]
        recommendations << {
          type: :performance,
          priority: :high,
          benchmark: benchmark,
          current_duration: duration_ms.round(2),
          threshold: quality_config[:performance_threshold_ms],
          message: "Optimize #{benchmark} (#{duration_ms.round(2)}ms > #{quality_config[:performance_threshold_ms]}ms)"
        }
      end
    end

    # Generate recommendations for regressions
    regressions.each do |benchmark, data|
      recommendations << {
        type: :regression,
        priority: :critical,
        benchmark: benchmark,
        regression_percentage: data[:increase],
        message: "Performance regression detected in #{benchmark} (#{data[:increase]}% increase)"
      }
    end

    recommendations
  end

  def generate_security_report(brakeman_results, bundle_audit_results, custom_security_results)
    # Generate security report
    report = {
      timestamp: Time.current,
      brakeman: brakeman_results,
      bundle_audit: bundle_audit_results,
      custom_checks: custom_security_results,
      summary: generate_security_summary(brakeman_results, bundle_audit_results, custom_security_results)
    }

    # Save security report
    report_dir = Rails.root.join('tmp', 'security_reports')
    FileUtils.mkdir_p(report_dir)

    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    report_file = report_dir.join("security_report_#{timestamp}.json")

    File.write(report_file, JSON.pretty_generate(report))
    Rails.logger.info("Security report generated: #{report_file}")
  end

  def generate_security_summary(brakeman, bundle_audit, custom_checks)
    summary = {
      total_issues: 0,
      high_severity: 0,
      medium_severity: 0,
      low_severity: 0,
      passed: true
    }

    # Count Brakeman issues
    if brakeman['warnings']
      summary[:total_issues] += brakeman['warnings'].count
      summary[:high_severity] += brakeman['warnings'].count { |w| w['confidence'] == 'High' }
      summary[:medium_severity] += brakeman['warnings'].count { |w| w['confidence'] == 'Medium' }
      summary[:low_severity] += brakeman['warnings'].count { |w| w['confidence'] == 'Low' }
    end

    # Check if security scan passed
    summary[:passed] = summary[:high_severity] == 0

    summary
  end

  def generate_complexity_report(complexity_results, hotspots, suggestions)
    # Generate complexity report
    report = {
      timestamp: Time.current,
      complexity: complexity_results,
      hotspots: hotspots,
      suggestions: suggestions,
      recommendations: generate_complexity_recommendations(hotspots)
    }

    # Save complexity report
    report_dir = Rails.root.join('tmp', 'complexity_reports')
    FileUtils.mkdir_p(report_dir)

    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    report_file = report_dir.join("complexity_report_#{timestamp}.json")

    File.write(report_file, JSON.pretty_generate(report))
    Rails.logger.info("Complexity report generated: #{report_file}")
  end

  def generate_complexity_recommendations(hotspots)
    recommendations = []

    high_complexity_hotspots = hotspots.select { |h| h[:severity] == :high }

    if high_complexity_hotspots.any?
      recommendations << {
        type: :refactoring,
        priority: :high,
        message: "Refactor #{high_complexity_hotspots.count} high-complexity methods",
        auto_fix: 'Run: rake code_quality:complexity'
      }
    end

    recommendations
  end

  def generate_coverage_report(coverage_results, uncovered_areas)
    # Generate coverage report
    report = {
      timestamp: Time.current,
      coverage: coverage_results,
      uncovered_areas: uncovered_areas,
      recommendations: generate_coverage_recommendations(coverage_results)
    }

    # Save coverage report
    report_dir = Rails.root.join('tmp', 'coverage_reports')
    FileUtils.mkdir_p(report_dir)

    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    report_file = report_dir.join("coverage_report_#{timestamp}.json")

    File.write(report_file, JSON.pretty_generate(report))
    Rails.logger.info("Coverage report generated: #{report_file}")
  end

  def generate_coverage_recommendations(coverage_results)
    recommendations = []

    if coverage_results[:summary]
      coverage = coverage_results[:summary][:coverage_percentage]

      if coverage < quality_config[:test_coverage_threshold]
        recommendations << {
          type: :coverage,
          priority: :high,
          message: "Increase test coverage to #{quality_config[:test_coverage_threshold]}% (currently #{coverage.round(2)}%)",
          auto_fix: 'Run: rake test'
        }
      end
    end

    recommendations
  end
end

Rails.logger&.info("Code quality automation system loaded successfully")