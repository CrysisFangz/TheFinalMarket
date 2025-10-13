# frozen_string_literal: true

require 'money'

# DashboardDecorator provides presentation logic for user dashboard data.
# This decorator follows the decorator pattern to separate business logic
# from presentation concerns while maintaining clean, readable methods.
#
# @example
#   user = User.find(1)
#   decorated_user = DashboardDecorator.new(user)
#   decorated_user.formatted_total_earnings  # => "$1,234.56"
#   decorated_user.formatted_pending_payouts # => "$567.89"
#   decorated_user.recent_sales_count       # => 42
class DashboardDecorator < SimpleDelegator
  # Default time window for recent sales calculation
  RECENT_SALES_DAYS = 30
  
  # Transaction types for financial calculations
  PAYOUT_TRANSACTION_TYPE = :payout
  HELD_ESCROW_STATUS = :held
  
  # Fallback display values
  NOT_AVAILABLE = 'N/A'
  ZERO_MONEY = Money.new(0).format

  # Initialize the decorator with a user object
  #
  # @param user [User] The user object to decorate
  # @raise [ArgumentError] if user is nil
  def initialize(user)
    super
    raise ArgumentError, 'User cannot be nil' if user.nil?
  end

  # Financial Information Methods
  # ============================

  # Returns formatted total earnings from payout transactions
  #
  # @return [String] Formatted money string (e.g., "$1,234.56")
  # @return [String] "N/A" if no earnings or error occurs
  def formatted_total_earnings
    calculate_formatted_sum(
      payment_transactions.where(transaction_type: PAYOUT_TRANSACTION_TYPE),
      :amount_cents
    )
  rescue StandardError => e
    handle_financial_error('total_earnings', e)
  end

  # Returns formatted pending payouts from held escrow transactions
  #
  # @return [String] Formatted money string (e.g., "$567.89")
  # @return [String] "N/A" if no pending payouts or error occurs
  def formatted_pending_payouts
    calculate_formatted_sum(
      escrow_transactions.where(status: HELD_ESCROW_STATUS),
      :amount_cents
    )
  rescue StandardError => e
    handle_financial_error('pending_payouts', e)
  end

  # Sales Information Methods
  # ========================

  # Returns count of recent sales within the configured time window
  #
  # @return [Integer] Number of orders in the last RECENT_SALES_DAYS days
  # @return [Integer] 0 if no recent sales or error occurs
  def recent_sales_count
    recent_orders.count
  rescue StandardError => e
    handle_query_error('recent_sales_count', e)
  end

  # Bond Information Methods
  # =======================

  # Returns human-readable bond status
  #
  # @return [String] Humanized bond status (e.g., "active" becomes "Active")
  # @return [String] "N/A" if no bond status available
  def formatted_bond_status
    bond_status&.humanize || NOT_AVAILABLE
  rescue StandardError => e
    handle_display_error('bond_status', e)
  end

  # Returns formatted bond amount
  #
  # @return [String] Formatted money string if bond exists
  # @return [String] "N/A" if no bond or amount available
  def formatted_bond_amount
    return NOT_AVAILABLE unless bond&.amount
    
    bond.amount.format
  rescue StandardError => e
    handle_display_error('bond_amount', e)
  end

  private

  # Optimized query for recent orders
  #
  # @return [ActiveRecord::Relation] Orders from the last RECENT_SALES_DAYS days
  def recent_orders
    orders.where(created_at: RECENT_SALES_DAYS.days.ago..Time.current)
  end

  # Calculates and formats monetary sum from a collection
  #
  # @param collection [ActiveRecord::Relation] Collection to sum
  # @param amount_field [Symbol] Field containing amount in cents
  # @return [String] Formatted money string
  # @return [String] Zero money format if sum is zero or collection is empty
  def calculate_formatted_sum(collection, amount_field)
    total_cents = collection.sum(amount_field)
    return ZERO_MONEY if total_cents.zero?
    
    Money.new(total_cents).format
  end

  # Handles errors in financial calculations
  #
  # @param operation [String] Name of the operation that failed
  # @param error [StandardError] The error that occurred
  # @return [String] Safe fallback value
  def handle_financial_error(operation, error)
    Rails.logger.error(
      "DashboardDecorator financial error in #{operation}: #{error.message}",
      user_id: id,
      error_class: error.class.name
    )
    NOT_AVAILABLE
  end

  # Handles errors in display formatting
  #
  # @param field [String] Name of the field that failed
  # @param error [StandardError] The error that occurred
  # @return [String] Safe fallback value
  def handle_display_error(field, error)
    Rails.logger.error(
      "DashboardDecorator display error for #{field}: #{error.message}",
      user_id: id,
      error_class: error.class.name
    )
    NOT_AVAILABLE
  end

  # Handles errors in database queries
  #
  # @param operation [String] Name of the operation that failed
  # @param error [StandardError] The error that occurred
  # @return [Integer] Safe fallback value (0)
  def handle_query_error(operation, error)
    Rails.logger.error(
      "DashboardDecorator query error in #{operation}: #{error.message}",
      user_id: id,
      error_class: error.class.name
    )
    0
  end
end