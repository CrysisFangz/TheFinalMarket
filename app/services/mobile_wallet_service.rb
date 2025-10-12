# app/services/mobile_wallet_service.rb
class MobileWalletService
  def initialize(order)
    @order = order
    @square_client = Square::Client.new(
      access_token: Rails.application.credentials.square[:access_token],
      environment: Rails.env.production? ? 'production' : 'sandbox'
    )
  end

  # Create Apple Pay payment
  def create_apple_pay_payment(payment_token)
    begin
      result = @square_client.payments.create_payment(
        body: {
          source_id: payment_token,
          idempotency_key: SecureRandom.uuid,
          amount_money: {
            amount: (@order.total * 100).to_i,
            currency: 'USD'
          },
          autocomplete: true,
          location_id: Rails.application.credentials.square[:location_id],
          reference_id: @order.id.to_s,
          note: "Order ##{@order.order_number}",
          buyer_email_address: @order.user.email
        }
      )

      if result.success?
        process_successful_payment(result.data.payment, 'apple_pay')
      else
        { success: false, errors: result.errors }
      end
    rescue => e
      Rails.logger.error("Apple Pay payment failed: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # Create Google Pay payment
  def create_google_pay_payment(payment_token)
    begin
      result = @square_client.payments.create_payment(
        body: {
          source_id: payment_token,
          idempotency_key: SecureRandom.uuid,
          amount_money: {
            amount: (@order.total * 100).to_i,
            currency: 'USD'
          },
          autocomplete: true,
          location_id: Rails.application.credentials.square[:location_id],
          reference_id: @order.id.to_s,
          note: "Order ##{@order.order_number}",
          buyer_email_address: @order.user.email
        }
      )

      if result.success?
        process_successful_payment(result.data.payment, 'google_pay')
      else
        { success: false, errors: result.errors }
      end
    rescue => e
      Rails.logger.error("Google Pay payment failed: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # Verify Apple Pay merchant
  def verify_apple_pay_merchant(validation_url)
    begin
      # This requires Apple Pay merchant certificate
      response = HTTP.post(validation_url, json: {
        merchantIdentifier: Rails.application.credentials.apple_pay[:merchant_id],
        displayName: 'TheFinalMarket',
        initiative: 'web',
        initiativeContext: Rails.application.credentials.apple_pay[:domain]
      })

      if response.status.success?
        JSON.parse(response.body)
      else
        { error: 'Merchant validation failed' }
      end
    rescue => e
      Rails.logger.error("Apple Pay merchant validation failed: #{e.message}")
      { error: e.message }
    end
  end

  # Get Google Pay configuration
  def google_pay_config
    {
      environment: Rails.env.production? ? 'PRODUCTION' : 'TEST',
      apiVersion: 2,
      apiVersionMinor: 0,
      merchantInfo: {
        merchantId: Rails.application.credentials.google_pay[:merchant_id],
        merchantName: 'TheFinalMarket'
      },
      allowedPaymentMethods: [
        {
          type: 'CARD',
          parameters: {
            allowedAuthMethods: ['PAN_ONLY', 'CRYPTOGRAM_3DS'],
            allowedCardNetworks: ['AMEX', 'DISCOVER', 'MASTERCARD', 'VISA']
          },
          tokenizationSpecification: {
            type: 'PAYMENT_GATEWAY',
            parameters: {
              gateway: 'square',
              gatewayMerchantId: Rails.application.credentials.square[:location_id]
            }
          }
        }
      ],
      transactionInfo: {
        totalPriceStatus: 'FINAL',
        totalPrice: @order.total.to_s,
        currencyCode: 'USD',
        countryCode: 'US'
      }
    }
  end

  # Save payment method for future use
  def save_payment_method(user, payment_token, wallet_type)
    user.payment_methods.create!(
      token: payment_token,
      wallet_type: wallet_type,
      last_four: extract_last_four(payment_token),
      is_default: user.payment_methods.empty?
    )
  end

  private

  def process_successful_payment(payment, payment_method)
    @order.update!(
      payment_status: 'paid',
      payment_method: payment_method,
      payment_id: payment.id,
      paid_at: Time.current
    )

    # Send confirmation
    OrderMailer.payment_confirmation(@order).deliver_later
    
    # Send push notification
    PushNotificationService.new.send_to_user(
      @order.user,
      title: 'Payment Successful! 🎉',
      body: "Your order ##{@order.order_number} has been confirmed",
      url: Rails.application.routes.url_helpers.order_url(@order)
    )

    { success: true, payment: payment, order: @order }
  end

  def extract_last_four(token)
    # Extract last 4 digits from token metadata
    # This is a placeholder - actual implementation depends on payment processor
    '****'
  end
end

