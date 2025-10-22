# frozen_string_literal: true

require 'interactor'

module Bonds
  # Use case for creating bond payment
  class CreateUseCase
    include Interactor

    def call
      # Process bond payment
      payment_result = process_bond_payment(context.user, context.bond_params)

      if payment_result.success?
        context.bond_result = BondResult.success(payment_result.bond)
      else
        context.fail!(error: payment_result.error)
      end
    rescue StandardError => e
      context.fail!(error: e.message)
    end

    private

    def process_bond_payment(user, bond_params)
      # Integrate with payment gateway
      # Placeholder for actual payment processing
      BondResult.success(user.bonds.create(amount: bond_params[:amount]))
    end
  end

  class BondResult
    attr_reader :bond, :error

    def self.success(bond)
      new(bond: bond, success: true)
    end

    def self.failure(error)
      new(error: error, success: false)
    end

    def initialize(bond: nil, error: nil, success: false)
      @bond = bond
      @error = error
      @success = success
    end

    def success?
      @success
    end
  end
end