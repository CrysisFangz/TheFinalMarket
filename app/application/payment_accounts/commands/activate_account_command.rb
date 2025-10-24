# frozen_string_literal: true

# Command: Activate Payment Account
# Handles payment account activation with comprehensive validation and event sourcing
class PaymentAccountCommands::ActivateAccountCommand
  include CommandPattern

  attr_reader :payment_account_id, :activation_params, :request_id

  def initialize(payment_account_id:, activation_params:, request_id:)
    @payment_account_id = payment_account_id
    @activation_params = activation_params
    @request_id = request_id

    validate!
  end

  def execute
    validate_execution!

    ActiveRecord::Base.transaction(isolation: :serializable) do
      # Create domain event
      event = create_activation_event
      store_event(event)

      # Update read model
      update_account_status(event)

      # Publish to event bus
      publish_event(event)

      success_result(event, 'Payment account activated successfully')
    end
  rescue ActiveRecord::RecordInvalid => e
    failure_result("Invalid account activation: #{e.message}")
  rescue StandardError => e
    Rails.logger.error("Payment account activation failed for account #{payment_account_id}: #{e.message}")
    failure_result("Account activation failed: #{e.message}")
  end

  private

  def validate!
    raise ValidationError, 'Payment account ID is required' unless payment_account_id.present?
    raise ValidationError, 'Request ID is required' unless request_id.present?
    validate_activation_params
  end

  def validate_execution!
    @payment_account = PaymentAccount.find_by(id: payment_account_id)
    raise ValidationError, 'Payment account not found' unless @payment_account
    raise ValidationError, 'Account is already active' if @payment_account.active?
    raise ValidationError, 'Account is suspended' if @payment_account.suspended?
  end

  def validate_activation_params
    required_params = %i[activation_reason admin_user_id]
    missing_params = required_params.select { |param| activation_params[param].blank? }

    raise ValidationError, "Missing required activation parameters: #{missing_params.join(', ')}" if missing_params.any?
  end

  def create_activation_event
    aggregate_id = "payment_account_#{payment_account_id}"

    PaymentAccountActivatedEvent.new(
      aggregate_id,
      payment_account_id: payment_account_id,
      activation_reason: activation_params[:activation_reason],
      admin_user_id: activation_params[:admin_user_id],
      activation_metadata: activation_params[:metadata] || {},
      request_id: request_id
    )
  end

  def store_event(event)
    event_store = EventStore.new
    event_store.append_events(event.aggregate_id, [event])
  end

  def update_account_status(event)
    @payment_account.update!(
      status: :active,
      activated_at: Time.current,
      activation_metadata: event.activation_metadata
    )
  end

  def publish_event(event)
    EventPublisher.publish('payment_account.events', event)
  end
end