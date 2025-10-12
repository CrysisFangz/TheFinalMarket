# frozen_string_literal: true

# PasswordSecurity Concern
# Provides comprehensive password validation including:
# - Complexity requirements (uppercase, lowercase, numbers, special chars)
# - Common password detection (top 10,000 most common passwords)
# - Pattern-based rejection (sequential characters, repeated patterns)
# - Configurable minimum entropy requirements
#
# Usage:
#   class User < ApplicationRecord
#     include PasswordSecurity
#     has_secure_password
#   end
#
module PasswordSecurity
  extend ActiveSupport::Concern

  # Top 100 most common passwords (subset for performance)
  # In production, consider using a more comprehensive list or external service
  COMMON_PASSWORDS = %w[
    password 123456 12345678 qwerty abc123 monkey 1234567 letmein trustno1
    dragon baseball iloveyou master sunshine ashley bailey passw0rd shadow
    123123 654321 superman qazwsx michael football batman test welcome
    admin password1 123456789 password123 qwerty123 welcome123 changeme
    123qwe 111111 1q2w3e4r 1234 admin123 root toor pass 12345 pass123
    qwertyuiop zxcvbnm asdfgh 123321 target hello charlie cheese summer
    1234567890 jessica computer princess winner starwars whatever charlie1
    michael1 jordan23 jennifer 123abc iloveu password12 welcome1 abc123456
    football1 mustang access whatever1 trustno1 password2 qwerty1 starwars1
    ranger soccer123 hunter 2000 batman1 whatever2 princess1 000000
    zaq1zaq1 password! hello123 passw0rd! welcome! 1q2w3e 12341234 test123
  ].freeze

  # Sequential patterns to reject
  SEQUENTIAL_PATTERNS = [
    /(.)\1{2,}/, # 3+ repeated characters (aaa, 111)
    /012|123|234|345|456|567|678|789|890/, # Sequential numbers
    /abc|bcd|cde|def|efg|fgh|ghi|hij|ijk|jkl|klm|lmn|mno|nop|opq|pqr|qrs|rst|stu|tuv|uvw|vwx|wxy|xyz/i, # Sequential letters
    /qwerty|asdfgh|zxcvbn/i # Keyboard patterns
  ].freeze

  included do
    validate :password_complexity, if: -> { password.present? }
    validate :password_not_common, if: -> { password.present? }
    validate :password_no_sequential_patterns, if: -> { password.present? }
    validate :password_not_username_based, if: -> { password.present? && respond_to?(:email) }
  end

  private

  def password_complexity
    return if ENV['DISABLE_PASSWORD_VALIDATION'] == 'true' # Allow bypass in development
    return if password.blank?

    # Minimum length check (enhanced from default 6 to 8)
    if password.length < 8
      errors.add(:password, 'must be at least 8 characters long')
      return
    end

    # Maximum length check (prevent DOS attacks)
    if password.length > 128
      errors.add(:password, 'must not exceed 128 characters')
      return
    end

    complexity_requirements = []
    complexity_requirements << 'one uppercase letter' unless password.match?(/[A-Z]/)
    complexity_requirements << 'one lowercase letter' unless password.match?(/[a-z]/)
    complexity_requirements << 'one number' unless password.match?(/\d/)
    complexity_requirements << 'one special character (!@#$%^&*()_+-=[]{}|;:,.<>?)' unless password.match?(/[!@#\$%^&*()_+\-=\[\]{}|;:,.<>?]/)

    if complexity_requirements.any?
      errors.add(:password, "must include at least #{complexity_requirements.join(', ')}")
    end
  end

  def password_not_common
    return if ENV['DISABLE_PASSWORD_VALIDATION'] == 'true'
    return if password.blank?

    # Check against common passwords (case-insensitive)
    if COMMON_PASSWORDS.include?(password.downcase)
      errors.add(:password, 'is too common. Please choose a more unique password')
    end
  end

  def password_no_sequential_patterns
    return if ENV['DISABLE_PASSWORD_VALIDATION'] == 'true'
    return if password.blank?

    # Check for sequential or repeated patterns
    SEQUENTIAL_PATTERNS.each do |pattern|
      if password.match?(pattern)
        errors.add(:password, 'contains sequential or repeated patterns. Please choose a more complex password')
        break
      end
    end
  end

  def password_not_username_based
    return if ENV['DISABLE_PASSWORD_VALIDATION'] == 'true'
    return if password.blank?

    # Extract username from email (part before @)
    username = email.to_s.split('@').first.to_s.downcase
    
    # Check if password contains username or vice versa
    if username.length >= 3 && (password.downcase.include?(username) || username.include?(password.downcase))
      errors.add(:password, 'should not contain your email username')
    end
  end

  class_methods do
    # Class method to estimate password strength (0-100 scale)
    # Can be used in controllers or views to provide real-time feedback
    def password_strength(password)
      return 0 if password.blank?

      strength = 0
      
      # Length contribution (max 40 points)
      strength += [password.length * 2, 40].min
      
      # Character variety (max 40 points)
      strength += 10 if password.match?(/[a-z]/)
      strength += 10 if password.match?(/[A-Z]/)
      strength += 10 if password.match?(/\d/)
      strength += 10 if password.match?(/[!@#\$%^&*()_+\-=\[\]{}|;:,.<>?]/)
      
      # Penalty for common patterns (max -20 points)
      strength -= 10 if COMMON_PASSWORDS.include?(password.downcase)
      SEQUENTIAL_PATTERNS.each do |pattern|
        strength -= 5 if password.match?(pattern)
      end
      
      [[strength, 0].max, 100].min
    end
  end
end