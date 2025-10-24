# frozen_string_literal: true

# Presenter for WalletTransaction to handle data representation and formatting, decoupling from the model.
class WalletTransactionPresenter
  def initialize(transaction)
    @transaction = transaction
  end

  def description
    case @transaction.transaction_type.to_sym
    when :credit
      "Added funds from #{@transaction.source}"
    when :debit
      "Payment for #{@transaction.purpose}"
    when :refund
      "Refund for #{@transaction.purpose}"
    when :adjustment
      "Balance adjustment"
    else
      "Unknown transaction"
    end
  end

  def formatted_amount
    Amount.new(@transaction.amount_cents).to_s
  end

  def formatted_balance_after
    Balance.new(@transaction.balance_after_cents).to_s
  end

  def status_badge
    case @transaction.status.to_sym
    when :completed
      '<span class="badge badge-success">Completed</span>'
    when :pending
      '<span class="badge badge-warning">Pending</span>'
    when :failed
      '<span class="badge badge-danger">Failed</span>'
    when :reversed
      '<span class="badge badge-secondary">Reversed</span>'
    else
      '<span class="badge badge-light">Unknown</span>'
    end
  end

  def as_json(options = {})
    {
      id: @transaction.id,
      type: @transaction.transaction_type,
      amount: formatted_amount,
      balance_after: formatted_balance_after,
      description: description,
      status: @transaction.status,
      processed_at: @transaction.processed_at
    }
  end
end