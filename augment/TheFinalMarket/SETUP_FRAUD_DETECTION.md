# Advanced Fraud Detection System - Setup Guide

## Quick Start

Follow these steps to set up the fraud detection system:

### 1. Run Database Migrations

```bash
bin/rails db:migrate
```

This will create:
- `fraud_checks` table
- `trust_scores` table
- `device_fingerprints` table
- `behavioral_patterns` table
- `ip_blacklists` table
- `fraud_rules` table
- `fraud_alerts` table
- Add columns to `users` and `orders` tables

### 2. Load Seed Data

```bash
bin/rails runner "load Rails.root.join('db/seeds/fraud_detection_seeds.rb')"
```

This will create:
- 10 fraud rules
- 3 IP blacklist entries
- Sample trust scores
- Sample fraud checks
- Sample device fingerprints

### 3. Install JavaScript Dependencies (Optional)

For device fingerprinting:

```bash
npm install @fingerprintjs/fingerprintjs
# or
yarn add @fingerprintjs/fingerprintjs
```

### 4. Configure Environment Variables (Optional)

```bash
# .env

# IP Intelligence Services
IPQUALITYSCORE_API_KEY=your_key
MAXMIND_LICENSE_KEY=your_key

# Geocoding (already configured for internationalization)
GEOCODER_API_KEY=your_key

# Error Tracking
SENTRY_DSN=your_dsn
```

### 5. Set Up Scheduled Jobs

Jobs are already configured in `config/schedule.yml`:

```yaml
trust_score_update:
  cron: "0 2 * * *"  # Daily at 2:00 AM
  
behavioral_analysis:
  cron: "0 */6 * * *"  # Every 6 hours
  
fraud_cleanup:
  cron: "0 3 * * 0"  # Every Sunday at 3:00 AM
```

Load the schedule:

```bash
# If using Sidekiq Cron
Sidekiq::Cron::Job.load_from_hash YAML.load_file('config/schedule.yml')

# If using whenever
whenever --update-crontab
```

### 6. Test the System

```bash
# Start Rails console
bin/rails console

# Test fraud detection
user = User.first
fraud_check = FraudDetectionService.new(
  user,
  user,
  :login_attempt,
  { ip_address: '192.168.1.1', user_agent: 'Mozilla/5.0' }
).check

puts "Risk Score: #{fraud_check.risk_score}"
puts "Risk Level: #{fraud_check.risk_level}"
puts "Flagged: #{fraud_check.flagged?}"

# Test trust score
trust_score = TrustScore.calculate_for(user)
puts "Trust Score: #{trust_score.score}"
puts "Trust Level: #{trust_score.trust_level}"

# Test behavioral patterns
patterns = BehavioralPatternDetector.new(user).detect_all
puts "Patterns detected: #{patterns.count}"
puts "Anomalous patterns: #{patterns.count { |p| p&.anomalous? }}"
```

---

## Integration Steps

### Step 1: Add Fraud Checks to Controllers

#### Login Controller

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
        redirect_to verification_path, alert: "Additional verification required"
      else
        session[:user_id] = user.id
        redirect_to root_path
      end
    end
  end
end
```

#### Orders Controller

```ruby
class OrdersController < ApplicationController
  def create
    @order = current_user.orders.build(order_params)
    
    if @order.save
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
      
      @order.update!(
        fraud_check_score: fraud_check.risk_score,
        fraud_checked_at: Time.current,
        requires_manual_review: fraud_check.high_risk?
      )
      
      if fraud_check.risk_level == 'critical'
        @order.update!(status: 'cancelled')
        redirect_to orders_path, alert: "Order cancelled"
      else
        redirect_to order_path(@order)
      end
    end
  end
end
```

### Step 2: Add Device Fingerprinting

#### Add to Application Layout

```erb
<!-- app/views/layouts/application.html.erb -->
<%= hidden_field_tag :device_fingerprint, '', id: 'device_fingerprint' %>
<%= javascript_include_tag 'device_fingerprint', defer: true %>
```

#### Create JavaScript Controller

```javascript
// app/javascript/controllers/device_fingerprint_controller.js
import { Controller } from "@hotwired/stimulus"
import FingerprintJS from '@fingerprintjs/fingerprintjs'

export default class extends Controller {
  async connect() {
    const fp = await FingerprintJS.load()
    const result = await fp.get()
    
    document.getElementById('device_fingerprint').value = result.visitorId
  }
}
```

### Step 3: Add Trust Score Display

```erb
<!-- app/views/users/show.html.erb -->
<div class="trust-score">
  <% trust_score = TrustScore.current_for(@user) %>
  <% if trust_score %>
    <span class="badge badge-<%= trust_score.badge[:color] %>">
      <%= trust_score.badge[:icon] %> <%= trust_score.badge[:name] %>
    </span>
    <span class="score"><%= trust_score.score %>/100</span>
  <% end %>
</div>
```

### Step 4: Add Fraud Alert Dashboard

```erb
<!-- app/views/admin/fraud_alerts/index.html.erb -->
<h1>Fraud Alerts</h1>

<div class="alerts">
  <% @alerts.each do |alert| %>
    <div class="alert alert-<%= alert.badge_color %>">
      <h3><%= alert.title %></h3>
      <p><%= alert.message %></p>
      <p>
        <strong>User:</strong> <%= alert.user.email %><br>
        <strong>Severity:</strong> <%= alert.severity %><br>
        <strong>Created:</strong> <%= alert.created_at.strftime('%Y-%m-%d %H:%M') %>
      </p>
      
      <% unless alert.acknowledged? %>
        <%= button_to 'Acknowledge', acknowledge_admin_fraud_alert_path(alert), method: :post %>
      <% end %>
      
      <% unless alert.resolved? %>
        <%= button_to 'Resolve', resolve_admin_fraud_alert_path(alert), method: :post %>
      <% end %>
    </div>
  <% end %>
</div>
```

---

## Configuration

### Customize Risk Thresholds

Create `config/initializers/fraud_detection.rb`:

```ruby
# Fraud Detection Configuration
FRAUD_DETECTION_CONFIG = {
  # Risk score thresholds
  low_risk_threshold: 40,
  high_risk_threshold: 70,
  critical_risk_threshold: 80,
  
  # Automatic actions
  auto_block_threshold: 90,
  require_verification_threshold: 70,
  flag_for_review_threshold: 60,
  
  # Trust score settings
  trust_score_update_frequency: 1.day,
  min_trust_score_for_seller: 50,
  min_trust_score_for_withdrawal: 60,
  
  # Behavioral analysis
  behavioral_analysis_frequency: 6.hours,
  anomaly_detection_sensitivity: 0.7,
  
  # Device fingerprinting
  device_fingerprint_enabled: true,
  track_device_changes: true,
  
  # Cleanup settings
  fraud_check_retention_days: 90,
  trust_score_retention_count: 10,
  behavioral_pattern_retention_days: 60
}.freeze
```

### Add Fraud Rules

```ruby
# In Rails console or seed file
FraudRule.create!(
  name: "Custom Rule",
  description: "Your custom fraud rule",
  rule_type: :velocity_check,
  conditions: { threshold: 15, timeframe: 3600 },
  risk_weight: 20,
  priority: 15,
  active: true
)
```

---

## Testing

### Unit Tests

```ruby
# test/services/fraud_detection_service_test.rb
require 'test_helper'

class FraudDetectionServiceTest < ActiveSupport::TestCase
  test "detects high risk for new account with large order" do
    user = users(:new_user)
    order = orders(:large_order)
    
    service = FraudDetectionService.new(user, order, :order_placement, {})
    fraud_check = service.check
    
    assert fraud_check.high_risk?
    assert fraud_check.risk_score > 70
  end
  
  test "low risk for trusted user with normal order" do
    user = users(:trusted_user)
    order = orders(:normal_order)
    
    service = FraudDetectionService.new(user, order, :order_placement, {})
    fraud_check = service.check
    
    assert_not fraud_check.high_risk?
    assert fraud_check.risk_score < 40
  end
end
```

### Integration Tests

```ruby
# test/integration/fraud_detection_test.rb
require 'test_helper'

class FraudDetectionTest < ActionDispatch::IntegrationTest
  test "blocks high risk login" do
    user = users(:suspicious_user)
    
    post login_path, params: {
      email: user.email,
      password: 'password'
    }
    
    assert_redirected_to verification_path
    assert_equal "Additional verification required", flash[:alert]
  end
  
  test "allows low risk login" do
    user = users(:trusted_user)
    
    post login_path, params: {
      email: user.email,
      password: 'password'
    }
    
    assert_redirected_to root_path
    assert_equal user.id, session[:user_id]
  end
end
```

---

## Monitoring

### Key Metrics to Track

1. **Fraud Check Volume**
   - Total checks per day
   - Checks by type
   - Average processing time

2. **Risk Distribution**
   - Low risk percentage
   - Medium risk percentage
   - High risk percentage
   - Critical risk percentage

3. **Trust Scores**
   - Average trust score
   - Trust level distribution
   - Score change trends

4. **Alerts**
   - Unresolved alerts
   - Alert resolution time
   - False positive rate

5. **Actions Taken**
   - Accounts suspended
   - Transactions blocked
   - Verifications required

### Dashboard Queries

```ruby
# Fraud checks in last 24 hours
FraudCheck.where('created_at > ?', 24.hours.ago).count

# High risk checks
FraudCheck.high_risk.where('created_at > ?', 7.days.ago).count

# Average risk score
FraudCheck.where('created_at > ?', 7.days.ago).average(:risk_score)

# Trust score distribution
TrustScore.group(:trust_level).count

# Unresolved alerts
FraudAlert.unresolved.count

# Top fraud patterns
FraudCheck.flagged.group(:check_type).count
```

---

## Troubleshooting

### Issue: Fraud checks not running

**Check:**
1. Verify migrations ran successfully
2. Check for errors in logs
3. Ensure user and checkable objects exist
4. Verify IP address is being passed

### Issue: All users getting high risk scores

**Solutions:**
1. Review fraud rules and weights
2. Adjust risk thresholds
3. Check for data issues
4. Review calculation logic

### Issue: Trust scores not updating

**Solutions:**
1. Check scheduled jobs are running
2. Verify TrustScoreUpdateJob is working
3. Check for errors in job logs
4. Run manually: `TrustScoreUpdateJob.perform_now`

### Issue: Device fingerprints not working

**Solutions:**
1. Verify JavaScript is loaded
2. Check FingerprintJS installation
3. Verify hidden field exists
4. Check browser console for errors

---

## Next Steps

1. ✅ Run migrations
2. ✅ Load seed data
3. ✅ Configure environment variables
4. ✅ Set up scheduled jobs
5. ✅ Test the system
6. 📝 Integrate into controllers
7. 📝 Add device fingerprinting
8. 📝 Create admin dashboard
9. 📝 Set up monitoring
10. 📝 Train staff on fraud indicators

---

**Advanced Fraud Detection System v1.0**
Setup Guide for The Final Market

