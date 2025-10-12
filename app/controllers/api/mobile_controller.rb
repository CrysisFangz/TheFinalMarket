# app/controllers/api/mobile_controller.rb
module Api
  class MobileController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :authenticate_mobile_user!
    
    # Barcode scanning endpoints
    def scan_barcode
      barcode = params[:barcode]
      service = BarcodeScannerService.new
      
      result = service.lookup_product(barcode)
      
      # Save scan history
      if current_user && result[:id]
        service.save_scan_history(current_user, barcode, result)
      end
      
      render json: result
    end
    
    def compare_prices
      barcode = params[:barcode]
      service = BarcodeScannerService.new
      
      result = service.compare_prices(barcode)
      
      render json: result
    end
    
    # Visual search endpoints
    def visual_search
      image_data = params[:image]
      service = VisualSearchService.new
      
      result = service.search_by_image(image_data)
      
      render json: result
    end
    
    def extract_product_info
      image_data = params[:image]
      service = VisualSearchService.new
      
      result = service.extract_product_info(image_data)
      
      render json: result
    end
    
    # Geolocation endpoints
    def nearby_stores
      latitude = params[:latitude]
      longitude = params[:longitude]
      radius = params[:radius]&.to_i || 10
      
      service = GeolocationService.new(latitude: latitude, longitude: longitude)
      stores = service.nearby_stores(radius_km: radius)
      
      render json: {
        stores: stores.map { |store| format_store(store) }
      }
    end
    
    def nearby_listings
      latitude = params[:latitude]
      longitude = params[:longitude]
      radius = params[:radius]&.to_i || 25
      category = params[:category]
      
      service = GeolocationService.new(latitude: latitude, longitude: longitude)
      listings = service.nearby_listings(radius_km: radius, category: category)
      
      render json: {
        listings: listings.map { |listing| format_listing(listing) }
      }
    end
    
    def local_deals
      latitude = params[:latitude]
      longitude = params[:longitude]
      radius = params[:radius]&.to_i || 15
      
      service = GeolocationService.new(latitude: latitude, longitude: longitude)
      deals = service.local_deals(radius_km: radius)
      
      render json: {
        deals: deals.map { |deal| format_deal(deal) }
      }
    end
    
    def location_recommendations
      latitude = params[:latitude]
      longitude = params[:longitude]
      
      service = GeolocationService.new(latitude: latitude, longitude: longitude)
      recommendations = service.location_recommendations
      
      render json: recommendations
    end
    
    def geofence_alerts
      latitude = params[:latitude]
      longitude = params[:longitude]
      
      service = GeolocationService.new(latitude: latitude, longitude: longitude)
      alerts = service.geofence_alerts(current_user)
      
      render json: { alerts: alerts }
    end
    
    # Mobile wallet endpoints
    def apple_pay_payment
      order = Order.find(params[:order_id])
      payment_token = params[:payment_token]
      
      authorize order, :update?
      
      service = MobileWalletService.new(order)
      result = service.create_apple_pay_payment(payment_token)
      
      render json: result
    end
    
    def google_pay_payment
      order = Order.find(params[:order_id])
      payment_token = params[:payment_token]
      
      authorize order, :update?
      
      service = MobileWalletService.new(order)
      result = service.create_google_pay_payment(payment_token)
      
      render json: result
    end
    
    def apple_pay_merchant_validation
      validation_url = params[:validation_url]
      order = Order.find(params[:order_id])
      
      authorize order, :show?
      
      service = MobileWalletService.new(order)
      result = service.verify_apple_pay_merchant(validation_url)
      
      render json: result
    end
    
    def google_pay_config
      order = Order.find(params[:order_id])
      
      authorize order, :show?
      
      service = MobileWalletService.new(order)
      config = service.google_pay_config
      
      render json: config
    end
    
    # Biometric authentication endpoints
    def biometric_enroll_challenge
      challenge = SecureRandom.base64(32)
      
      session[:biometric_challenge] = challenge
      session[:biometric_challenge_expires] = 5.minutes.from_now
      
      render json: {
        challenge: challenge,
        rp_name: 'TheFinalMarket',
        rp_id: request.host,
        user_id: Base64.strict_encode64(current_user.id.to_s),
        user_name: current_user.email,
        user_display_name: current_user.name
      }
    end
    
    def biometric_enroll
      credential = params[:credential]
      
      # Verify challenge
      unless valid_biometric_challenge?
        render json: { success: false, error: 'Invalid or expired challenge' }, status: :unauthorized
        return
      end
      
      # Save credential
      current_user.update!(
        biometric_credential_id: credential[:id],
        biometric_public_key: credential[:response][:attestationObject]
      )
      
      clear_biometric_challenge
      
      render json: { success: true, message: 'Biometric authentication enrolled successfully' }
    end
    
    def biometric_auth_challenge
      challenge = SecureRandom.base64(32)
      
      session[:biometric_challenge] = challenge
      session[:biometric_challenge_expires] = 5.minutes.from_now
      
      credentials = [{
        id: current_user.biometric_credential_id
      }]
      
      render json: {
        challenge: challenge,
        rp_id: request.host,
        credentials: credentials
      }
    end
    
    def biometric_authenticate
      assertion = params[:assertion]
      
      # Verify challenge
      unless valid_biometric_challenge?
        render json: { success: false, error: 'Invalid or expired challenge' }, status: :unauthorized
        return
      end
      
      # Verify assertion (simplified - in production use webauthn gem)
      if assertion[:id] == current_user.biometric_credential_id
        clear_biometric_challenge
        
        # Update last authenticated
        current_user.update!(last_biometric_auth_at: Time.current)
        
        render json: {
          success: true,
          message: 'Authentication successful',
          redirect_url: params[:redirect_url]
        }
      else
        render json: { success: false, error: 'Authentication failed' }, status: :unauthorized
      end
    end
    
    def biometric_status
      enrolled = current_user.biometric_credential_id.present?
      
      render json: {
        enrolled: enrolled,
        last_used: current_user.last_biometric_auth_at
      }
    end
    
    # Push notification endpoints
    def register_push_subscription
      subscription_data = params[:subscription]
      
      current_user.push_subscriptions.create!(
        endpoint: subscription_data[:endpoint],
        p256dh_key: subscription_data[:keys][:p256dh],
        auth_key: subscription_data[:keys][:auth],
        device_type: params[:device_type] || 'unknown'
      )
      
      render json: { success: true }
    end
    
    def send_test_notification
      PushNotificationService.new.send_to_user(
        current_user,
        title: 'Test Notification',
        body: 'This is a test notification from TheFinalMarket',
        url: root_url
      )
      
      render json: { success: true }
    end
    
    private
    
    def authenticate_mobile_user!
      # Check for API token or session
      token = request.headers['Authorization']&.split(' ')&.last
      
      if token
        # Verify JWT token
        begin
          decoded = JWT.decode(token, Rails.application.credentials.secret_key_base, true, algorithm: 'HS256')
          @current_user = User.find(decoded[0]['user_id'])
        rescue JWT::DecodeError
          render json: { error: 'Invalid token' }, status: :unauthorized
        end
      elsif user_signed_in?
        @current_user = current_user
      else
        render json: { error: 'Authentication required' }, status: :unauthorized
      end
    end
    
    def valid_biometric_challenge?
      session[:biometric_challenge].present? &&
        session[:biometric_challenge_expires].present? &&
        session[:biometric_challenge_expires] > Time.current
    end
    
    def clear_biometric_challenge
      session.delete(:biometric_challenge)
      session.delete(:biometric_challenge_expires)
    end
    
    def format_store(store)
      {
        id: store.id,
        name: store.name,
        address: store.address,
        distance: store.distance&.round(2),
        rating: store.rating,
        image_url: store.image_url
      }
    end
    
    def format_listing(listing)
      {
        id: listing.id,
        product_name: listing.product.name,
        price: listing.price,
        distance: listing.distance&.round(2),
        seller_name: listing.user.name,
        image_url: listing.product.primary_image_url
      }
    end
    
    def format_deal(deal)
      {
        id: deal.id,
        title: deal.title,
        description: deal.description,
        discount: deal.discount_percentage,
        distance: deal.distance&.round(2),
        expires_at: deal.expires_at
      }
    end
  end
end

