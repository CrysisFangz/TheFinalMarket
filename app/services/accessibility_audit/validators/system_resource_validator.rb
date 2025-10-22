# =============================================================================
# SystemResourceValidator - Advanced System Resource Validation
# =============================================================================

class AccessibilityAudit::SystemResourceValidator
  # Resource thresholds for different system states
  RESOURCE_THRESHOLDS = {
    memory: {
      critical: 0.95,  # 95% memory usage
      warning: 0.85,   # 85% memory usage
      minimum_available: 100_000_000 # 100MB minimum
    }.freeze,

    cpu: {
      critical: 0.90,  # 90% CPU usage
      warning: 0.75,   # 75% CPU usage
      max_load_average: 2.0
    }.freeze,

    disk: {
      critical: 0.95,  # 95% disk usage
      warning: 0.85,   # 85% disk usage
      minimum_available: 1_000_000_000 # 1GB minimum
    }.freeze,

    network: {
      max_latency_ms: 1000,
      max_packet_loss: 0.05, # 5% packet loss
      min_bandwidth_mbps: 10
    }.freeze
  }.freeze

  def initialize(thresholds = {})
    @thresholds = RESOURCE_THRESHOLDS.deep_merge(thresholds)
  end

  # Validate all system resources
  def validate!
    validations = [
      method(:validate_memory),
      method(:validate_cpu),
      method(:validate_disk),
      method(:validate_network)
    ]

    validation_results = validations.map do |validation_method|
      begin
        validation_method.call
        { resource: validation_method.name.to_s.sub('validate_', ''), status: :ok }
      rescue => e
        { resource: validation_method.name.to_s.sub('validate_', ''), status: :error, error: e.message }
      end
    end

    failed_validations = validation_results.select { |result| result[:status] == :error }

    unless failed_validations.empty?
      raise AccessibilityAudit::SystemResourceError.new(
        "System resource validation failed",
        validation_results: validation_results,
        failed_resources: failed_validations
      )
    end

    validation_results
  end

  private

  # Validate memory resources
  def validate_memory
    memory_info = get_memory_info

    # Check memory usage percentage
    memory_usage_percent = memory_info[:used].to_f / memory_info[:total]
    if memory_usage_percent > @thresholds[:memory][:critical]
      raise "Critical memory usage: #{(memory_usage_percent * 100).round(2)}%"
    end

    if memory_usage_percent > @thresholds[:memory][:warning]
      Rails.logger.warn "High memory usage: #{(memory_usage_percent * 100).round(2)}%"
    end

    # Check available memory
    if memory_info[:available] < @thresholds[:memory][:minimum_available]
      raise "Insufficient available memory: #{memory_info[:available]} bytes"
    end
  end

  # Validate CPU resources
  def validate_cpu
    cpu_info = get_cpu_info

    # Check CPU usage percentage
    if cpu_info[:usage_percent] > @thresholds[:cpu][:critical]
      raise "Critical CPU usage: #{cpu_info[:usage_percent].round(2)}%"
    end

    if cpu_info[:usage_percent] > @thresholds[:cpu][:warning]
      Rails.logger.warn "High CPU usage: #{cpu_info[:usage_percent].round(2)}%"
    end

    # Check load average
    if cpu_info[:load_average_1min] > @thresholds[:cpu][:max_load_average]
      raise "High load average: #{cpu_info[:load_average_1min]}"
    end
  end

  # Validate disk resources
  def validate_disk
    disk_info = get_disk_info

    disk_info.each do |mount_point, info|
      usage_percent = info[:used].to_f / info[:total]

      if usage_percent > @thresholds[:disk][:critical]
        raise "Critical disk usage on #{mount_point}: #{(usage_percent * 100).round(2)}%"
      end

      if usage_percent > @thresholds[:disk][:warning]
        Rails.logger.warn "High disk usage on #{mount_point}: #{(usage_percent * 100).round(2)}%"
      end

      if info[:available] < @thresholds[:disk][:minimum_available]
        raise "Insufficient disk space on #{mount_point}: #{info[:available]} bytes"
      end
    end
  end

  # Validate network resources
  def validate_network
    network_info = get_network_info

    if network_info[:latency_ms] > @thresholds[:network][:max_latency_ms]
      raise "High network latency: #{network_info[:latency_ms]}ms"
    end

    if network_info[:packet_loss] > @thresholds[:network][:max_packet_loss]
      raise "High packet loss: #{(network_info[:packet_loss] * 100).round(2)}%"
    end

    if network_info[:bandwidth_mbps] < @thresholds[:network][:min_bandwidth_mbps]
      raise "Insufficient bandwidth: #{network_info[:bandwidth_mbps]} Mbps"
    end
  end

  # Get comprehensive memory information
  def get_memory_info
    case RUBY_PLATFORM
    when /linux/
      get_linux_memory_info
    when /darwin/
      get_darwin_memory_info
    else
      get_generic_memory_info
    end
  end

  # Get Linux memory information
  def get_linux_memory_info
    meminfo = File.read('/proc/meminfo')

    total = extract_memory_value(meminfo, /MemTotal:\s+(\d+)/)
    free = extract_memory_value(meminfo, /MemFree:\s+(\d+)/)
    available = extract_memory_value(meminfo, /MemAvailable:\s+(\d+)/)
    used = total - free

    {
      total: total * 1024,
      used: used * 1024,
      free: free * 1024,
      available: available * 1024,
      usage_percent: (used.to_f / total * 100).round(2)
    }
  rescue
    get_generic_memory_info
  end

  # Get macOS memory information
  def get_darwin_memory_info
    vm_stat = `vm_stat`.strip
    pagesize = `pagesize`.strip.to_i

    # Parse vm_stat output
    free_pages = extract_darwin_memory_value(vm_stat, /Pages free:\s+(\d+)/)
    active_pages = extract_darwin_memory_value(vm_stat, /Pages active:\s+(\d+)/)
    wired_pages = extract_darwin_memory_value(vm_stat, /Pages wired down:\s+(\d+)/)

    free = free_pages * pagesize
    used = (active_pages + wired_pages) * pagesize

    # Estimate total memory
    total_memory_gb = `sysctl -n hw.memsize`.strip.to_i / (1024**3)
    total = total_memory_gb * (1024**3)

    {
      total: total,
      used: used,
      free: free,
      available: free, # Approximation for macOS
      usage_percent: (used.to_f / total * 100).round(2)
    }
  rescue
    get_generic_memory_info
  end

  # Get generic memory information (fallback)
  def get_generic_memory_info
    Rails.logger.warn "Using generic memory detection"

    # Fallback to process memory info
    process_memory = `ps -o rss= -p #{Process.pid}`.strip.to_i * 1024

    {
      total: 8 * 1024**3, # Assume 8GB
      used: process_memory,
      free: 8 * 1024**3 - process_memory,
      available: 8 * 1024**3 - process_memory,
      usage_percent: (process_memory.to_f / (8 * 1024**3) * 100).round(2)
    }
  end

  # Extract memory value from Linux /proc/meminfo
  def extract_memory_value(meminfo, regex)
    match = meminfo.match(regex)
    match ? match[1].to_i : 0
  end

  # Extract memory value from macOS vm_stat
  def extract_darwin_memory_value(vm_stat, regex)
    match = vm_stat.match(regex)
    match ? match[1].to_i : 0
  end

  # Get CPU information
  def get_cpu_info
    case RUBY_PLATFORM
    when /linux/
      get_linux_cpu_info
    when /darwin/
      get_darwin_cpu_info
    else
      get_generic_cpu_info
    end
  end

  # Get Linux CPU information
  def get_linux_cpu_info
    # Get CPU usage
    cpu_usage = get_cpu_usage_linux

    # Get load average
    loadavg = File.read('/proc/loadavg').split.first(3).map(&:to_f)

    {
      usage_percent: cpu_usage,
      load_average_1min: loadavg[0],
      load_average_5min: loadavg[1],
      load_average_15min: loadavg[2],
      cpu_count: Etc.nprocessors
    }
  rescue
    get_generic_cpu_info
  end

  # Get macOS CPU information
  def get_darwin_cpu_info
    # Use sysctl for CPU information
    cpu_count = `sysctl -n hw.ncpu`.strip.to_i

    # Use top command to get CPU usage (simplified)
    top_output = `top -l 1 | grep "CPU usage"`.strip
    usage_percent = 0.0

    if top_output.present?
      # Parse "CPU usage: X%" format
      usage_match = top_output.match(/CPU usage:\s+([\d.]+)%/)
      usage_percent = usage_match[1].to_f if usage_match
    end

    # Get load average
    loadavg_output = `sysctl -n vm.loadavg`.strip
    loadavg = loadavg_output.split.map(&:to_f)

    {
      usage_percent: usage_percent,
      load_average_1min: loadavg[0],
      load_average_5min: loadavg[1],
      load_average_15min: loadavg[2],
      cpu_count: cpu_count
    }
  rescue
    get_generic_cpu_info
  end

  # Get generic CPU information (fallback)
  def get_generic_cpu_info
    Rails.logger.warn "Using generic CPU detection"

    {
      usage_percent: 0.0,
      load_average_1min: 0.0,
      load_average_5min: 0.0,
      load_average_15min: 0.0,
      cpu_count: Etc.nprocessors
    }
  end

  # Get CPU usage for Linux systems
  def get_cpu_usage_linux
    # Read /proc/stat for CPU usage calculation
    stat1 = File.read('/proc/stat').lines.first.split[1..-1].map(&:to_i)
    sleep 1
    stat2 = File.read('/proc/stat').lines.first.split[1..-1].map(&:to_i)

    total1 = stat1.sum
    total2 = stat2.sum

    idle1 = stat1[3]
    idle2 = stat2[3]

    total_diff = total2 - total1
    idle_diff = idle2 - idle1

    return 0.0 if total_diff == 0

    usage = ((total_diff - idle_diff).to_f / total_diff * 100).round(2)
    [usage, 0.0].max # Ensure non-negative
  end

  # Get disk information
  def get_disk_info
    case RUBY_PLATFORM
    when /linux/
      get_linux_disk_info
    when /darwin/
      get_darwin_disk_info
    else
      {}
    end
  rescue
    {}
  end

  # Get Linux disk information
  def get_linux_disk_info
    disk_info = {}

    # Use df command to get disk usage
    df_output = `df -k`.strip

    df_output.lines[1..-1].each do |line|
      parts = line.split
      next if parts.size < 6

      mount_point = parts.last
      total = parts[1].to_i * 1024
      used = parts[2].to_i * 1024
      available = parts[3].to_i * 1024

      disk_info[mount_point] = {
        total: total,
        used: used,
        available: available,
        usage_percent: (used.to_f / total * 100).round(2)
      }
    end

    disk_info
  end

  # Get macOS disk information
  def get_darwin_disk_info
    disk_info = {}

    # Use df command for macOS
    df_output = `df -k`.strip

    df_output.lines[1..-1].each do |line|
      parts = line.split
      next if parts.size < 6

      mount_point = parts.last
      total = parts[1].to_i * 1024
      used = parts[2].to_i * 1024
      available = parts[3].to_i * 1024

      disk_info[mount_point] = {
        total: total,
        used: used,
        available: available,
        usage_percent: (used.to_f / total * 100).round(2)
      }
    end

    disk_info
  end

  # Get network information
  def get_network_info
    # Basic network connectivity check
    latency_ms = check_network_latency
    packet_loss = check_packet_loss

    # Estimate bandwidth (simplified)
    bandwidth_mbps = estimate_bandwidth

    {
      latency_ms: latency_ms,
      packet_loss: packet_loss,
      bandwidth_mbps: bandwidth_mbps,
      connectivity_status: check_connectivity
    }
  rescue
    {
      latency_ms: 0,
      packet_loss: 0.0,
      bandwidth_mbps: 100,
      connectivity_status: :unknown
    }
  end

  # Check network latency
  def check_network_latency
    # Ping a reliable host (like 8.8.8.8) to check latency
    ping_result = `ping -c 3 8.8.8.8 2>/dev/null`

    if $?.success?
      # Extract average latency from ping output
      avg_match = ping_result.match(/avg.*\/([\d.]+)\//)
      avg_match ? avg_match[1].to_f : 100.0
    else
      1000.0 # High latency if ping fails
    end
  rescue
    1000.0
  end

  # Check packet loss
  def check_packet_loss
    ping_result = `ping -c 10 8.8.8.8 2>/dev/null`

    if $?.success?
      # Extract packet loss from ping output
      loss_match = ping_result.match(/(\d+)%\s+packet\s+loss/)
      loss_match ? loss_match[1].to_f / 100.0 : 0.0
    else
      0.10 # 10% packet loss if ping fails
    end
  rescue
    0.10
  end

  # Estimate bandwidth (simplified)
  def estimate_bandwidth
    # This is a simplified estimation
    # In a real implementation, you might use speedtest or similar tools
    100 # Assume 100 Mbps as default
  rescue
    50 # Lower default if estimation fails
  end

  # Check basic connectivity
  def check_connectivity
    # Try to resolve a common DNS name
    begin
      Socket.getaddrinfo('google.com', 'http')
      :connected
    rescue
      :disconnected
    end
  end

  # Custom error class for system resource validation
  class AccessibilityAudit::SystemResourceError < StandardError
    attr_reader :validation_results, :failed_resources

    def initialize(message, validation_results: [], failed_resources: [])
      @validation_results = validation_results
      @failed_resources = failed_resources
      super(message)
    end

    def to_h
      {
        error: message,
        validation_results: validation_results,
        failed_resources: failed_resources,
        timestamp: Time.current
      }
    end
  end
end