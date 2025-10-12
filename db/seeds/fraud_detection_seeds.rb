puts "🔒 Seeding Fraud Detection System..."

# Create Fraud Rules
puts "Creating fraud rules..."

fraud_rules_data = [
  {
    name: "High Velocity Login Attempts",
    description: "Detect rapid login attempts that may indicate brute force attack",
    rule_type: :velocity_check,
    conditions: { threshold: 10, timeframe: 3600 },
    risk_weight: 25,
    priority: 10
  },
  {
    name: "Large Transaction Amount",
    description: "Flag transactions over $5000",
    rule_type: :amount_threshold,
    conditions: { threshold: 500000 },
    risk_weight: 15,
    priority: 20
  },
  {
    name: "High-Risk Country Access",
    description: "Detect access from high-risk countries",
    rule_type: :location_check,
    conditions: { blocked_countries: ['XX', 'YY'] },
    risk_weight: 20,
    priority: 15
  },
  {
    name: "Blocked Device Detection",
    description: "Detect access from blocked or suspicious devices",
    rule_type: :device_check,
    conditions: {},
    risk_weight: 30,
    priority: 5
  },
  {
    name: "Unusual Time Activity",
    description: "Detect activity during unusual hours (2 AM - 5 AM)",
    rule_type: :time_check,
    conditions: { blocked_hours: [2, 3, 4, 5] },
    risk_weight: 10,
    priority: 30
  },
  {
    name: "Anomalous Behavior Pattern",
    description: "Detect users with anomalous behavioral patterns",
    rule_type: :pattern_check,
    conditions: {},
    risk_weight: 20,
    priority: 12
  },
  {
    name: "IP Blacklist Check",
    description: "Check if IP address is blacklisted",
    rule_type: :blacklist_check,
    conditions: {},
    risk_weight: 40,
    priority: 3
  },
  {
    name: "Low Reputation Score",
    description: "Flag users with reputation score below 30",
    rule_type: :reputation_check,
    conditions: { threshold: 30 },
    risk_weight: 15,
    priority: 25
  },
  {
    name: "New Account High Activity",
    description: "Detect high activity from new accounts (< 7 days)",
    rule_type: :velocity_check,
    conditions: { threshold: 20, timeframe: 86400 },
    risk_weight: 20,
    priority: 18
  },
  {
    name: "Multiple Failed Payments",
    description: "Detect multiple failed payment attempts",
    rule_type: :velocity_check,
    conditions: { threshold: 3, timeframe: 3600 },
    risk_weight: 25,
    priority: 8
  }
]

fraud_rules_data.each do |data|
  FraudRule.find_or_create_by!(name: data[:name]) do |rule|
    rule.assign_attributes(data)
  end
end

puts "✅ Created #{FraudRule.count} fraud rules"

# Create sample IP blacklist entries
puts "Creating IP blacklist entries..."

sample_ips = [
  { ip: '192.0.2.1', reason: 'Known bot network', severity: 3, permanent: true },
  { ip: '198.51.100.1', reason: 'Multiple fraud attempts', severity: 2, permanent: false, duration: 30.days },
  { ip: '203.0.113.1', reason: 'Spam activity', severity: 1, permanent: false, duration: 7.days }
]

sample_ips.each do |data|
  duration = data.delete(:duration)
  IpBlacklist.find_or_create_by!(ip_address: data[:ip]) do |entry|
    entry.assign_attributes(data)
    entry.expires_at = duration.from_now if duration
  end
end

puts "✅ Created #{IpBlacklist.count} IP blacklist entries"

# Initialize trust scores for existing users
puts "Initializing trust scores for users..."

if defined?(User) && User.any?
  users_to_score = User.limit(10) # Limit to first 10 users for seed data
  
  users_to_score.each do |user|
    begin
      TrustScore.calculate_for(user)
    rescue => e
      puts "  ⚠️  Could not calculate trust score for user #{user.id}: #{e.message}"
    end
  end
  
  puts "✅ Initialized trust scores for #{users_to_score.count} users"
else
  puts "⚠️  No users found to initialize trust scores"
end

# Create sample fraud checks for demonstration
puts "Creating sample fraud checks..."

if defined?(User) && User.any?
  sample_user = User.first
  
  # Low risk check
  FraudCheck.create!(
    user: sample_user,
    checkable: sample_user,
    check_type: :login_attempt,
    risk_score: 15,
    factors: {
      factors: [
        { factor: "Normal login pattern", weight: 0 },
        { factor: "Verified email", weight: 0 },
        { factor: "Known device", weight: 0 }
      ]
    },
    ip_address: '192.168.1.1',
    flagged: false
  )
  
  # Medium risk check
  FraudCheck.create!(
    user: sample_user,
    checkable: sample_user,
    check_type: :profile_update,
    risk_score: 45,
    factors: {
      factors: [
        { factor: "New account (< 30 days)", weight: 5 },
        { factor: "Unusual time of activity", weight: 5 }
      ]
    },
    ip_address: '192.168.1.2',
    flagged: false
  )
  
  # High risk check
  FraudCheck.create!(
    user: sample_user,
    checkable: sample_user,
    check_type: :login_attempt,
    risk_score: 75,
    factors: {
      factors: [
        { factor: "VPN/Proxy detected", weight: 15 },
        { factor: "High activity rate", weight: 15 },
        { factor: "New device", weight: 10 }
      ]
    },
    ip_address: '192.168.1.3',
    flagged: true
  )
  
  puts "✅ Created #{FraudCheck.count} sample fraud checks"
else
  puts "⚠️  No users found to create sample fraud checks"
end

# Create sample device fingerprints
puts "Creating sample device fingerprints..."

if defined?(User) && User.any?
  sample_user = User.first
  
  DeviceFingerprint.create!(
    user: sample_user,
    fingerprint_hash: Digest::SHA256.hexdigest("sample_device_1"),
    device_info: {
      browser: 'Chrome',
      os: 'macOS',
      screen_resolution: '1920x1080',
      timezone: 'America/New_York'
    },
    last_ip_address: '192.168.1.1',
    last_seen_at: Time.current,
    access_count: 25
  )
  
  DeviceFingerprint.create!(
    user: sample_user,
    fingerprint_hash: Digest::SHA256.hexdigest("sample_device_2"),
    device_info: {
      browser: 'Safari',
      os: 'iOS',
      screen_resolution: '390x844',
      timezone: 'America/New_York'
    },
    last_ip_address: '192.168.1.2',
    last_seen_at: 1.day.ago,
    access_count: 10
  )
  
  puts "✅ Created #{DeviceFingerprint.count} sample device fingerprints"
else
  puts "⚠️  No users found to create sample device fingerprints"
end

puts ""
puts "🎉 Fraud Detection System seeded successfully!"
puts ""
puts "Summary:"
puts "  - #{FraudRule.count} fraud rules"
puts "  - #{IpBlacklist.count} IP blacklist entries"
puts "  - #{TrustScore.count} trust scores"
puts "  - #{FraudCheck.count} fraud checks"
puts "  - #{DeviceFingerprint.count} device fingerprints"
puts ""

