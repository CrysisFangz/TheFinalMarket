# Security & Privacy System - Complete Guide

## Overview

The Final Market's Security & Privacy System provides enterprise-grade security features and GDPR-compliant privacy controls.

---

## Features

### 1. Two-Factor Authentication (2FA)

**Supported Methods:**
- **TOTP** - Google Authenticator, Authy, 1Password
- **SMS** - Text message verification codes
- **Email** - Email verification codes
- **Biometric** - Face ID, Touch ID, fingerprint
- **Hardware Keys** - YubiKey, security keys

**Features:**
- Backup codes for account recovery
- QR code setup for TOTP
- 30-second code validity window
- Rate limiting on verification attempts

**Usage:**
```ruby
# Enable 2FA
auth = TwoFactorAuthentication.create!(
  user: current_user,
  auth_method: :totp,
  secret_key: TwoFactorAuthentication.generate_secret,
  backup_codes: TwoFactorAuthentication.generate_backup_codes.to_json,
  enabled: true
)

# Get QR code for setup
qr_code = auth.qr_code_svg

# Verify code
auth.verify_totp(params[:code]) # => true/false

# Use backup code
auth.verify_backup_code(params[:backup_code])
```

---

### 2. Privacy Dashboard

**GDPR Compliance:**
- Right to access data
- Right to rectification
- Right to erasure
- Right to data portability
- Right to restrict processing
- Right to object
- Right to withdraw consent

**Features:**
- Data sharing preferences
- Marketing consent management
- Visibility controls
- Data retention settings
- Privacy report generation
- Data export (JSON format)
- Account deletion

**Usage:**
```ruby
# Create privacy settings
privacy = PrivacySetting.create!(
  user: current_user,
  data_processing_consent: true,
  marketing_consent: true,
  data_retention_period: :standard
)

# Export user data
data = privacy.export_user_data
# => { personal_info: {...}, orders: [...], reviews: [...] }

# Delete user data
privacy.delete_user_data(:all) # or :personal, :activity, :marketing

# Check permissions
privacy.can_share_data?(:analytics) # => true/false
privacy.marketing_allowed?(:email) # => true/false

# Generate privacy report
report = privacy.privacy_report
```

---

### 3. Identity Verification

**Verification Levels:**
- **Basic** - Email + phone verification
- **Standard** - Government ID verification
- **Enhanced** - ID + selfie + liveness check
- **Business** - Business documents verification

**Features:**
- Automated AI verification
- Manual review fallback
- Document authenticity checks
- Face matching
- Liveness detection
- OCR data extraction
- 2-year validity period

**Usage:**
```ruby
# Create verification
verification = IdentityVerification.create!(
  user: current_user,
  verification_type: :enhanced,
  document_type: :passport
)

# Attach documents
verification.id_document_front.attach(params[:front_image])
verification.selfie_photo.attach(params[:selfie])

# Submit for verification
verification.submit!

# Check status
verification.valid_verification? # => true/false
verification.badge # => { icon: '✓✓✓', color: 'gold', text: 'Enhanced Verified' }
```

---

### 4. Encrypted Messaging

**Features:**
- End-to-end encryption (AES-256-GCM)
- Encrypted subject lines
- Encrypted attachments
- Read receipts
- Message deletion
- Conversation threading
- Message reporting

**Usage:**
```ruby
# Send encrypted message
message = EncryptedMessage.send_encrypted(
  sender: current_user,
  recipient: other_user,
  content: "Sensitive information",
  subject: "Order #12345",
  message_type: :order_related
)

# Mark as read
message.mark_as_read!(current_user)

# Get conversation thread
thread = message.conversation_thread

# Delete message
message.delete_for_user!(current_user)

# Report message
message.report!(current_user, "Spam")
```

---

### 5. Purchase Protection

**Protection Types:**
- **Fraud Protection** - Unauthorized transactions
- **Buyer Protection** - Item not received/as described
- **Shipping Protection** - Lost or damaged items
- **Warranty Extension** - Extended warranty coverage
- **Price Protection** - Price drop refunds

**Features:**
- Automatic coverage for eligible orders
- Claims management
- Evidence upload
- Automated payouts
- Coverage up to order amount

**Usage:**
```ruby
# Create protection
protection = PurchaseProtection.create_for_order(
  order,
  :buyer_protection
)

# File claim
claim = protection.file_claim(
  :item_not_received,
  "Package never arrived",
  { tracking_number: "123456" }
)

# Check coverage
details = protection.coverage_details
# => { type: 'buyer_protection', coverage_amount: 100.00, ... }
```

---

### 6. Security Auditing

**Tracked Events:**
- Login success/failure
- Password changes
- Email changes
- 2FA enable/disable
- Suspicious activity
- Account locks
- Permission changes
- Data exports
- API access
- Security breaches

**Features:**
- Comprehensive event logging
- Severity classification
- Anomaly detection
- Security score calculation
- Automated alerts
- Security recommendations

**Usage:**
```ruby
# Log security event
SecurityAudit.log_event(
  :login_success,
  user: current_user,
  ip_address: request.remote_ip,
  user_agent: request.user_agent,
  details: { location: 'New York' }
)

# Get security score
score = SecurityAudit.security_score(current_user) # => 0-100

# Get recommendations
recommendations = SecurityAudit.security_recommendations(current_user)
# => [{ priority: 'high', title: 'Enable 2FA', ... }]

# Detect anomalies
anomalies = SecurityAudit.detect_anomalies(current_user)
# => [{ type: 'multiple_locations', severity: 'medium', ... }]
```

---

## Integration Examples

### Login with 2FA

```ruby
class SessionsController < ApplicationController
  def create
    user = User.find_by(email: params[:email])
    
    if user&.authenticate(params[:password])
      if user.two_factor_enabled?
        # Require 2FA verification
        session[:pending_2fa_user_id] = user.id
        redirect_to two_factor_verification_path
      else
        # Normal login
        sign_in(user)
        SecurityAudit.log_event(:login_success, user: user, ip_address: request.remote_ip)
        redirect_to root_path
      end
    else
      SecurityAudit.log_event(:login_failure, user: user, ip_address: request.remote_ip)
      render :new, alert: "Invalid credentials"
    end
  end
  
  def verify_two_factor
    user = User.find(session[:pending_2fa_user_id])
    auth = user.two_factor_authentications.active.first
    
    if auth.verify_totp(params[:code])
      sign_in(user)
      session.delete(:pending_2fa_user_id)
      SecurityAudit.log_event(:login_success, user: user, ip_address: request.remote_ip)
      redirect_to root_path
    else
      render :two_factor_form, alert: "Invalid code"
    end
  end
end
```

### Privacy Dashboard

```ruby
class PrivacyController < ApplicationController
  def dashboard
    @privacy_setting = current_user.privacy_setting || current_user.create_privacy_setting
    @security_score = SecurityAudit.security_score(current_user)
    @recommendations = SecurityAudit.security_recommendations(current_user)
  end
  
  def export_data
    data = current_user.privacy_setting.export_user_data
    
    send_data data.to_json,
              filename: "my_data_#{Date.current}.json",
              type: 'application/json'
    
    SecurityAudit.log_event(:data_export, user: current_user, ip_address: request.remote_ip)
  end
  
  def delete_account
    current_user.privacy_setting.delete_user_data(:all)
    
    SecurityAudit.log_event(:data_deletion, user: current_user, ip_address: request.remote_ip)
    
    sign_out
    redirect_to root_path, notice: "Your account has been deleted"
  end
end
```

---

## Best Practices

### For Users

1. **Enable 2FA** - Add extra security layer
2. **Verify Identity** - Unlock premium features
3. **Review Privacy Settings** - Control your data
4. **Use Strong Passwords** - 12+ characters, mixed case, numbers, symbols
5. **Monitor Security Activity** - Check audit logs regularly
6. **Update Password Regularly** - Every 90 days
7. **Review Connected Devices** - Remove unknown devices

### For Developers

1. **Log All Security Events** - Comprehensive auditing
2. **Encrypt Sensitive Data** - Use Rails encryption
3. **Validate Input** - Prevent injection attacks
4. **Rate Limit** - Prevent brute force
5. **Use HTTPS** - Always encrypt in transit
6. **Sanitize Output** - Prevent XSS
7. **Keep Dependencies Updated** - Security patches

### For Administrators

1. **Monitor Security Alerts** - Review daily
2. **Review Audit Logs** - Weekly analysis
3. **Run Security Scans** - Automated weekly scans
4. **Update Security Policies** - Quarterly review
5. **Train Staff** - Security awareness
6. **Incident Response Plan** - Be prepared
7. **Regular Penetration Testing** - Quarterly

---

## Compliance

### GDPR Compliance

✅ **Right to Access** - Users can export their data  
✅ **Right to Rectification** - Users can update their data  
✅ **Right to Erasure** - Users can delete their data  
✅ **Right to Data Portability** - JSON export format  
✅ **Right to Restrict Processing** - Privacy preferences  
✅ **Right to Object** - Opt-out options  
✅ **Consent Management** - Explicit consent tracking  

### Security Standards

✅ **Encryption at Rest** - AES-256 encryption  
✅ **Encryption in Transit** - TLS 1.3  
✅ **Password Hashing** - bcrypt with salt  
✅ **2FA Support** - Multiple methods  
✅ **Audit Logging** - Comprehensive tracking  
✅ **Access Controls** - Role-based permissions  
✅ **Data Retention** - Configurable policies  

---

**Security & Privacy System v1.0**
Developed for The Final Market
Built with Ruby on Rails 8.0

