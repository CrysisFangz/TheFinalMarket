# frozen_string_literal: true

require 'interactor'

module Users
  # Use case for showing user profile
  class ShowUseCase
    include Interactor

    def call
      user = User.find_by(id: context.user_id)
      return context.fail!(error: 'User not found') unless user

      decorated_user = UserDecorator.new.decorate(user)
      context.user_result = UserResult.success(decorated_user)
    rescue StandardError => e
      context.fail!(error: e.message)
    end
  end

  class UserResult
    attr_reader :user, :error

    def self.success(user)
      new(user: user, success: true)
    end

    def self.failure(error)
      new(error: error, success: false)
    end

    def initialize(user: nil, error: nil, success: false)
      @user = user
      @error = error
      @success = success
    end

    def success?
      @success
    end
  end
end