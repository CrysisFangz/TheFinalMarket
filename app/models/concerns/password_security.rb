# frozen_string_literal: true

# Password Security Concern
# Provides enhanced password validation and security checks
module PasswordSecurity
  extend ActiveSupport::Concern

  included do
    # Password complexity validations
    validate :password_complexity, if: -> { password.present? }
    validate :password_not_common, if: -> { password.present? }
  end

  private

  # Ensure password meets complexity requirements
  def password_complexity
    return if password.blank?

    complexity_rules = {
      'at least one lowercase letter' => /[a-z]/,
      'at least one uppercase letter' => /[A-Z]/,
      'at least one digit' => /\d/,
      'at least one special character' => /[^A-Za-z0-9]/
    }

    violations = complexity_rules.select { |_rule, regex| password !~ regex }

    if violations.any? && password.length < 12
      # If password is shorter than 12 characters, require at least 3 out of 4 rules
      if violations.size > 1
        errors.add(:password, "must include #{violations.keys.join(', ')}")
      end
    elsif violations.size == 4
      # Password must meet at least one rule
      errors.add(:password, "is too simple. Include letters, numbers, or special characters")
    end
  end

  # Check against common password list
  def password_not_common
    return if password.blank?

    common_passwords = %w[
      password password123 123456 12345678 qwerty abc123 monkey letmein
      dragon 111111 baseball iloveyou trustno1 sunshine master 123123
      welcome shadow ashley football jesus michael ninja mustang password1
    ]

    if common_passwords.include?(password.downcase)
      errors.add(:password, "is too common. Please choose a more unique password")
    end

    # Check for simple patterns
    if password =~ /^(.)\1+$/ # All same character
      errors.add(:password, "cannot be all the same character")
    end

    if password =~ /^(012|123|234|345|456|567|678|789|890|abc|bcd|cde|def|efg|fgh|ghi|hij|ijk|jkl|klm|lmn|mno|nop|opq|pqr|qrs|rst|stu|tuv|uvw|vwx|wxy|xyz)+$/i
      errors.add(:password, "cannot be a simple sequence")
    end
  end

  # Class methods
  module ClassMethods
    # Check password strength score (0-5)
    def password_strength(password)
      return 0 if password.blank?

      score = 0
      score += 1 if password.length >= 8
      score += 1 if password.length >= 12
      score += 1 if password =~ /[a-z]/ && password =~ /[A-Z]/
      score += 1 if password =~ /\d/
      score += 1 if password =~ /[^A-Za-z0-9]/

      score
    end
  end
end