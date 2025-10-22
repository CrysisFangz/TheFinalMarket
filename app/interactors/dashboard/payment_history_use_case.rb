# frozen_string_literal: true

require 'interactor'

module Dashboard
  # Use case for retrieving payment history with financial analytics
  class PaymentHistoryUseCase
    include Interactor

    def call
      # Retrieve payment history
      payments = retrieve_payment_history(context.user, context.filters, context.pagination)

      # Decorate financial data
      decorated_payments = decorate_financial_data(payments)

      # Generate insights
      insights = generate_financial_insights(decorated_payments)

      context.payment_result = PaymentResult.success(decorated_payments, insights)
    rescue StandardError => e
      context.fail!(error: e.message)
    end

    private

    def retrieve_payment_history(user, filters, pagination)
      # Query payment models with filters and pagination
      # Placeholder
      []
    end

    def decorate_financial_data(payments)
      FinancialDecorator.new.decorate(payments)
    end

    def generate_financial_insights(decorated_payments)
      FinancialInsightGenerator.new.generate(decorated_payments)
    end
  end

  class PaymentResult
    attr_reader :transactions, :insights, :error

    def self.success(transactions, insights)
      new(transactions: transactions, insights: insights, success: true)
    end

    def self.failure(error)
      new(error: error, success: false)
    end

    def initialize(transactions: nil, insights: nil, error: nil, success: false)
      @transactions = transactions
      @insights = insights
      @error = error
      @success = success
    end

    def success?
      @success
    end
  end
end