puts "🔒 Seeding Security & Privacy System..."

# Create privacy settings for existing users
puts "Creating privacy settings..."

User.find_each do |user|
  next if user.privacy_setting.present?
  
  PrivacySetting.create!(
    user: user,
    data_processing_consent: true,
    marketing_consent: [true, false].sample,
    data_retention_period: [:standard, :extended].sample,
    data_sharing_preferences: {
      'analytics' => true,
      'personalization' => true,
      'third_party_marketing' => false,
      'research' => [true, false].sample
    },
    marketing_preferences: {
      'email' => true,
      'sms' => [true, false].sample,
      'push' => true,
      'phone' => false
    },
    visibility_preferences: {
      'profile' => ['public', 'friends', 'private'].sample,
      'orders' => 'private',
      'reviews' => 'public',
      'wishlists' => ['public', 'friends'].sample
    },
    consent_given_at: user.created_at
  )
end

puts "✅ Created privacy settings for #{PrivacySetting.count} users"

# Create sample identity verifications
puts "Creating sample identity verifications..."

verified_users = User.limit(10)

verified_users.each do |user|
  verification = IdentityVerification.create!(
    user: user,
    verification_type: [:basic, :standard, :enhanced].sample,
    status: :approved,
    document_type: [:passport, :drivers_license, :national_id].sample,
    submitted_at: rand(30..90).days.ago,
    verified_at: rand(1..29).days.ago,
    expires_at: 2.years.from_now,
    verification_results: {
      document_valid: { passed: true, confidence: 0.95 },
      face_match: { passed: true, confidence: 0.92 },
      liveness_check: { passed: true, confidence: 0.88 }
    }
  )
  
  user.update!(
    identity_verified: true,
    verification_level: verification.verification_type
  )
end

puts "✅ Created #{IdentityVerification.count} identity verifications"

# Create sample 2FA setups
puts "Creating sample 2FA setups..."

User.limit(15).each do |user|
  TwoFactorAuthentication.create!(
    user: user,
    auth_method: [:totp, :sms, :email].sample,
    secret_key: TwoFactorAuthentication.generate_secret,
    backup_codes: TwoFactorAuthentication.generate_backup_codes.to_json,
    enabled: true,
    last_used_at: rand(1..7).days.ago
  )
  
  user.update!(two_factor_enabled: true)
end

puts "✅ Created #{TwoFactorAuthentication.count} 2FA setups"

# Create sample purchase protections
puts "Creating purchase protections..."

Order.where(status: 'completed').limit(20).each do |order|
  PurchaseProtection.create_for_order(
    order,
    [:fraud_protection, :buyer_protection, :shipping_protection].sample
  )
end

puts "✅ Created #{PurchaseProtection.count} purchase protections"

# Create sample security audits
puts "Creating security audit logs..."

User.limit(20).each do |user|
  # Login success events
  rand(5..15).times do
    SecurityAudit.log_event(
      :login_success,
      user: user,
      ip_address: Faker::Internet.ip_v4_address,
      user_agent: Faker::Internet.user_agent,
      details: { location: Faker::Address.city }
    )
  end
  
  # Some failed login attempts
  if rand < 0.3
    rand(1..3).times do
      SecurityAudit.log_event(
        :login_failure,
        user: user,
        ip_address: Faker::Internet.ip_v4_address,
        user_agent: Faker::Internet.user_agent,
        details: { reason: 'Invalid password' }
      )
    end
  end
  
  # Password changes
  if rand < 0.2
    SecurityAudit.log_event(
      :password_change,
      user: user,
      ip_address: Faker::Internet.ip_v4_address,
      details: { method: 'User initiated' }
    )
  end
end

puts "✅ Created #{SecurityAudit.count} security audit logs"

# Update security scores
puts "Calculating security scores..."

User.find_each do |user|
  score = SecurityAudit.security_score(user)
  user.update_column(:security_score, score)
end

puts "✅ Updated security scores"

# Create sample encrypted messages
puts "Creating encrypted messages..."

users = User.limit(10).to_a

20.times do
  sender = users.sample
  recipient = (users - [sender]).sample
  
  EncryptedMessage.send_encrypted(
    sender: sender,
    recipient: recipient,
    content: Faker::Lorem.paragraph,
    subject: Faker::Lorem.sentence,
    message_type: [:direct, :order_related, :support].sample
  )
end

puts "✅ Created #{EncryptedMessage.count} encrypted messages"

puts "🎉 Security & Privacy System seeded successfully!"
puts ""
puts "Summary:"
puts "  - #{PrivacySetting.count} privacy settings"
puts "  - #{IdentityVerification.count} identity verifications"
puts "  - #{TwoFactorAuthentication.count} 2FA setups"
puts "  - #{PurchaseProtection.count} purchase protections"
puts "  - #{SecurityAudit.count} security audit logs"
puts "  - #{EncryptedMessage.count} encrypted messages"
puts ""
puts "Security Features:"
puts "  ✅ Two-Factor Authentication (TOTP, SMS, Email)"
puts "  ✅ Identity Verification (Basic, Standard, Enhanced)"
puts "  ✅ Privacy Dashboard (GDPR compliant)"
puts "  ✅ Encrypted Messaging (End-to-end encryption)"
puts "  ✅ Purchase Protection (Fraud, Buyer, Shipping)"
puts "  ✅ Security Auditing (Comprehensive logging)"
puts "  ✅ Biometric Login (Ready for integration)"

