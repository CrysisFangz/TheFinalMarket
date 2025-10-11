# Advanced Fraud Detection System - Complete Guide

## Overview

The Final Market's Advanced Fraud Detection System provides comprehensive protection against fraudulent activities using ML-based detection, behavioral analysis, trust scoring, and automated risk assessment.

---

## Features

### 1. Real-Time Fraud Detection

**Automated Checks:**
- Account creation
- Login attempts
- Order placement
- Payment methods
- Profile updates
- Listing creation
- Messages sent
- Reviews posted
- Withdrawal requests
- Password resets

**Risk Scoring (0-100):**
- 0-39: Low Risk (green)
- 40-69: Medium Risk (yellow)
- 70-79: High Risk (orange)
- 80-100: Critical Risk (red)

---

### 2. Trust Score System

**Trust Levels:**
- Highly Trusted (90-100) ⭐⭐⭐
- Trusted (70-89) ⭐⭐
- Moderate Trust (50-69) ⭐
- Low Trust (30-49) ○
- Untrusted (0-29) ⚠

**Factors Considered:**
- Account age
- Verification status (email, phone, identity)
- Activity level
- Reputation score
- Transaction history
- Social proof
- Fraud history
- Dispute history
- Suspension history

---

### 3. Behavioral Analysis

**Pattern Detection:**
- Login patterns
- Browsing patterns
- Purchase patterns
- Messaging patterns
- Listing patterns
- Search patterns
- Velocity patterns
- Time patterns
- Location patterns
- Device patterns

**Anomaly Detection:**
- Deviation from normal behavior
- Frequency anomalies
- Time anomalies
- Location anomalies
- Impossible travel detection

---

### 4. Device Fingerprinting

**Tracked Information:**
- Browser type and version
- Operating system
- Screen resolution
- Timezone
- Language
- Plugins
- Canvas fingerprint
- WebGL fingerprint

**Device Checks:**
- New device detection
- Shared device detection
- Blocked device detection
- VPN/Proxy detection
- Inconsistent location detection

---

### 5. Fraud Rules Engine

**Rule Types:**
- Velocity checks
- Amount thresholds
- Location checks
- Device checks
- Time checks
- Pattern checks
- Blacklist checks
- Reputation checks

**Configurable Rules:**
- Custom conditions
- Risk weights
- Priority levels
- Active/inactive status

---

## Usage

### Performing Fraud Checks

```ruby
# Check user login
fraud_check = FraudDetectionService.new(
  user,
  user, # checkable object
  :login_attempt,
  {
    ip_address: request.remote_ip,
    user_agent: request.user_agent,
    device_fingerprint: params[:device_fingerprint]
  }
).check

# Check order placement
fraud_check = FraudDetectionService.new(
  current_user,
  order,
  :order_placement,
  {
    ip_address: request.remote_ip,
    user_agent: request.user_agent,
    amount: order.total_cents
  }
).check

# Access results
fraud_check.risk_score # => 45
fraud_check.risk_level # => "medium"
fraud_check.flagged? # => false
fraud_check.risk_factors_array # => [{ factor: "...", weight: 10 }]
```

### Calculating Trust Scores

```ruby
# Calculate trust score for user
trust_score = TrustScore.calculate_for(user)

# Access results
trust_score.score # => 75
trust_score.trust_level # => "trusted"
trust_score.badge # => { name: "Trusted", color: "green", icon: "⭐⭐" }
trust_score.factors_array # => [{ description: "...", points: 10 }]

# Get current trust score
current_score = TrustScore.current_for(user)
```

### Detecting Behavioral Patterns

```ruby
# Detect all patterns for user
patterns = BehavioralPatternDetector.new(user).detect_all

# Check for anomalies
anomalous_patterns = patterns.select(&:anomalous?)

# Get pattern details
pattern = patterns.first
pattern.pattern_type # => "login_pattern"
pattern.anomalous? # => true
pattern.anomaly_score # => 45
pattern.description # => "Unusual login timing..."
```

### Managing Device Fingerprints

```ruby
# Create/update device fingerprint
fingerprint = DeviceFingerprint.find_or_create_by!(
  fingerprint_hash: device_hash
) do |fp|
  fp.user = current_user
  fp.device_info = {
    browser: 'Chrome',
    os: 'macOS',
    screen_resolution: '1920x1080'
  }
  fp.last_ip_address = request.remote_ip
  fp.last_seen_at = Time.current
end

# Update last seen
fingerprint.touch_last_seen!

# Check device status
fingerprint.new_device? # => false
fingerprint.shared_device? # => true
fingerprint.calculate_risk_score # => 35

# Mark as suspicious
fingerprint.mark_suspicious!("Multiple failed logins")

# Block device
fingerprint.block!("Confirmed fraud")
```

### Managing IP Blacklist

```ruby
# Add IP to blacklist
IpBlacklist.add(
  '192.0.2.1',
  'Known bot network',
  severity: 3,
  duration: 30.days
)

# Check if IP is blacklisted
IpBlacklist.blacklisted?('192.0.2.1') # => true

# Remove from blacklist
IpBlacklist.remove('192.0.2.1')
```

### Creating Fraud Rules

```ruby
# Create velocity rule
FraudRule.create!(
  name: "High Login Velocity",
  description: "Detect rapid login attempts",
  rule_type: :velocity_check,
  conditions: { threshold: 10, timeframe: 3600 },
  risk_weight: 25,
  priority: 10
)

# Evaluate rule
rule = FraudRule.first
context = {
  user: current_user,
  ip_address: request.remote_ip,
  amount: 10000
}
rule.evaluate(context) # => true/false
```

### Managing Fraud Alerts

```ruby
# Create alert
alert = FraudAlert.create!(
  fraud_check: fraud_check,
  user: user,
  alert_type: :high_risk_transaction,
  severity: :high,
  title: "High Risk Transaction Detected",
  message: "Transaction flagged for manual review"
)

# Acknowledge alert
alert.acknowledge!(admin_user)

# Resolve alert
alert.resolve!(admin_user, "Verified as legitimate")

# Query alerts
unresolved = FraudAlert.unresolved
critical = FraudAlert.critical
recent = FraudAlert.recent
```

---

## Integration

### Controller Integration

```ruby
class SessionsController < ApplicationController
  def create
    user = User.find_by(email: params[:email])
    
    if user&.authenticate(params[:password])
      # Perform fraud check
      fraud_check = FraudDetectionService.new(
        user,
        user,
        :login_attempt,
        {
          ip_address: request.remote_ip,
          user_agent: request.user_agent,
          device_fingerprint: params[:device_fingerprint]
        }
      ).check
      
      if fraud_check.high_risk?
        # Require additional verification
        redirect_to verification_path, alert: "Additional verification required"
      else
        # Normal login
        session[:user_id] = user.id
        redirect_to root_path
      end
    else
      render :new, alert: "Invalid credentials"
    end
  end
end
```

### Order Processing Integration

```ruby
class OrdersController < ApplicationController
  def create
    @order = current_user.orders.build(order_params)
    
    if @order.save
      # Perform fraud check
      fraud_check = FraudDetectionService.new(
        current_user,
        @order,
        :order_placement,
        {
          ip_address: request.remote_ip,
          user_agent: request.user_agent,
          amount: @order.total_cents
        }
      ).check
      
      # Store fraud score
      @order.update!(
        fraud_check_score: fraud_check.risk_score,
        fraud_checked_at: Time.current,
        requires_manual_review: fraud_check.high_risk?
      )
      
      if fraud_check.risk_level == 'critical'
        # Cancel order
        @order.update!(status: 'cancelled')
        redirect_to orders_path, alert: "Order cancelled due to security concerns"
      elsif fraud_check.high_risk?
        # Hold for review
        redirect_to order_path(@order), notice: "Order is being reviewed"
      else
        # Process normally
        redirect_to order_path(@order), notice: "Order placed successfully"
      end
    else
      render :new
    end
  end
end
```

### JavaScript Device Fingerprinting

```javascript
// app/javascript/controllers/device_fingerprint_controller.js
import { Controller } from "@hotwired/stimulus"
import FingerprintJS from '@fingerprintjs/fingerprintjs'

export default class extends Controller {
  connect() {
    this.generateFingerprint()
  }
  
  async generateFingerprint() {
    const fp = await FingerprintJS.load()
    const result = await fp.get()
    
    // Store fingerprint in hidden field
    const field = document.getElementById('device_fingerprint')
    if (field) {
      field.value = result.visitorId
    }
    
    // Send to server
    this.sendFingerprint(result.visitorId, result.components)
  }
  
  sendFingerprint(hash, components) {
    fetch('/api/device_fingerprint', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({
        fingerprint_hash: hash,
        device_info: {
          browser: components.vendor?.value,
          os: components.platform?.value,
          screen_resolution: `${components.screenResolution?.value[0]}x${components.screenResolution?.value[1]}`,
          timezone: components.timezone?.value,
          language: components.languages?.value
        }
      })
    })
  }
}
```

---

## Background Jobs

### Trust Score Updates

```ruby
# Update all users (daily)
TrustScoreUpdateJob.perform_later

# Update specific user
TrustScoreUpdateJob.perform_later(user.id)
```

### Behavioral Analysis

```ruby
# Analyze all users (every 6 hours)
BehavioralAnalysisJob.perform_later

# Analyze specific user
BehavioralAnalysisJob.perform_later(user.id)
```

### Fraud Cleanup

```ruby
# Clean up old data (weekly)
FraudCleanupJob.perform_later
```

---

## Configuration

### Scheduled Jobs

Jobs are configured in `config/schedule.yml`:

```yaml
trust_score_update:
  cron: "0 2 * * *"  # Daily at 2:00 AM
  class: "TrustScoreUpdateJob"

behavioral_analysis:
  cron: "0 */6 * * *"  # Every 6 hours
  class: "BehavioralAnalysisJob"

fraud_cleanup:
  cron: "0 3 * * 0"  # Every Sunday at 3:00 AM
  class: "FraudCleanupJob"
```

### Risk Thresholds

Customize in `config/initializers/fraud_detection.rb`:

```ruby
FraudDetection.configure do |config|
  config.low_risk_threshold = 40
  config.high_risk_threshold = 70
  config.critical_risk_threshold = 80
  
  config.auto_block_threshold = 90
  config.require_verification_threshold = 70
  
  config.trust_score_update_frequency = 1.day
  config.behavioral_analysis_frequency = 6.hours
end
```

---

## Best Practices

### For Developers

1. **Always perform fraud checks** on sensitive actions
2. **Store fraud scores** with transactions
3. **Log all fraud events** for analysis
4. **Handle high-risk cases** gracefully
5. **Test fraud detection** thoroughly
6. **Monitor false positives** and adjust rules
7. **Keep device fingerprints** up to date

### For Operations

1. **Review fraud alerts** daily
2. **Update fraud rules** based on patterns
3. **Monitor trust score** distributions
4. **Investigate anomalies** promptly
5. **Maintain IP blacklist** regularly
6. **Train staff** on fraud indicators
7. **Document fraud cases** for learning

### For Security

1. **Use HTTPS** for all communications
2. **Encrypt sensitive data** at rest
3. **Rotate API keys** regularly
4. **Limit access** to fraud data
5. **Audit fraud actions** regularly
6. **Keep dependencies** updated
7. **Follow GDPR/privacy** regulations

---

## Monitoring & Alerts

### Key Metrics

- Fraud check volume
- Average risk scores
- High-risk transaction rate
- False positive rate
- Trust score distribution
- Anomaly detection rate
- Alert resolution time

### Dashboards

Create dashboards to monitor:
- Real-time fraud checks
- Risk score trends
- Trust score distribution
- Top fraud patterns
- Alert queue status
- Rule effectiveness

---

## Troubleshooting

### High False Positive Rate

**Problem:** Too many legitimate users flagged

**Solutions:**
1. Review and adjust fraud rules
2. Lower risk weights
3. Increase thresholds
4. Whitelist trusted IPs
5. Improve behavioral baselines

### Low Detection Rate

**Problem:** Fraud slipping through

**Solutions:**
1. Add more fraud rules
2. Increase risk weights
3. Lower thresholds
4. Enable more checks
5. Review missed cases

### Performance Issues

**Problem:** Fraud checks slowing down requests

**Solutions:**
1. Move checks to background jobs
2. Cache fraud scores
3. Optimize database queries
4. Use Redis for counters
5. Implement rate limiting

---

## Future Enhancements

- [ ] Machine learning model training
- [ ] Advanced graph analysis
- [ ] Biometric authentication
- [ ] Blockchain verification
- [ ] Real-time collaboration with other platforms
- [ ] Advanced device intelligence
- [ ] Behavioral biometrics
- [ ] Network analysis
- [ ] Predictive fraud scoring
- [ ] Automated rule generation

---

**Advanced Fraud Detection System v1.0**
Developed for The Final Market
Built with Ruby on Rails 8.0

