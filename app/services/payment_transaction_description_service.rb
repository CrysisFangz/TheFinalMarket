class PaymentTransactionDescriptionService
  attr_reader :transaction

  def initialize(transaction)
    @transaction = transaction
  end

  def generate_description
    Rails.logger.debug("Generating description for payment transaction ID: #{transaction.id}, type: #{transaction.transaction_type}")

    begin
      description = case transaction.transaction_type.to_sym
      when :purchase
        generate_purchase_description
      when :refund
        generate_refund_description
      when :payout
        generate_payout_description
      when :fee
        generate_fee_description
      when :bond
        generate_bond_description
      when :bond_refund
        generate_bond_refund_description
      else
        generate_default_description
      end

      Rails.logger.debug("Generated description for payment transaction ID: #{transaction.id}: #{description}")
      description
    rescue => e
      Rails.logger.error("Failed to generate description for payment transaction ID: #{transaction.id}. Error: #{e.message}")
      "Payment Transaction ##{transaction.id}"
    end
  end

  private

  def generate_purchase_description
    if transaction.order
      "Payment for Order ##{transaction.order.id}"
    else
      "Payment Transaction ##{transaction.id}"
    end
  end

  def generate_refund_description
    if transaction.order
      "Refund for Order ##{transaction.order.id}"
    else
      "Refund Transaction ##{transaction.id}"
    end
  end

  def generate_payout_description
    if transaction.target_account&.user
      "Payout to #{transaction.target_account.user.name}"
    else
      "Payout to connected account"
    end
  end

  def generate_fee_description
    if transaction.order
      "Platform fee for Order ##{transaction.order.id}"
    else
      "Platform fee"
    end
  end

  def generate_bond_description
    if transaction.target_account&.user
      "Security bond for #{transaction.target_account.user.name}"
    else
      "Seller security bond"
    end
  end

  def generate_bond_refund_description
    if transaction.source_account&.user
      "Security bond refund for #{transaction.source_account.user.name}"
    else
      "Seller bond refund"
    end
  end

  def generate_default_description
    "#{transaction.transaction_type.titleize} Transaction ##{transaction.id}"
  end
end