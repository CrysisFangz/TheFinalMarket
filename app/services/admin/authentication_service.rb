# frozen_string_literal: true

class Admin::AuthenticationService
  def authenticate(user)
    raise AuthenticationError, 'User not authenticated' unless user&.admin?
    true
  end
end

class AuthenticationError < StandardError; end