class Settings::InternationalizationController < ApplicationController
  before_action :authenticate_user!
  
  # POST /settings/update_currency
  def update_currency
    currency = Currency.find_by(code: params[:currency_code])
    
    if currency
      # Update or create user currency preference
      preference = current_user.user_currency_preference || current_user.build_user_currency_preference
      preference.currency = currency
      
      if preference.save
        session[:currency_code] = currency.code
        
        respond_to do |format|
          format.html { redirect_back fallback_location: root_path, notice: "Currency updated to #{currency.name}" }
          format.json { render json: { success: true, currency: currency } }
        end
      else
        respond_to do |format|
          format.html { redirect_back fallback_location: root_path, alert: "Failed to update currency" }
          format.json { render json: { success: false, errors: preference.errors }, status: :unprocessable_entity }
        end
      end
    else
      respond_to do |format|
        format.html { redirect_back fallback_location: root_path, alert: "Invalid currency" }
        format.json { render json: { success: false, error: "Invalid currency" }, status: :not_found }
      end
    end
  end
  
  # POST /settings/update_locale
  def update_locale
    locale = params[:locale]
    
    if I18n.available_locales.include?(locale.to_sym)
      current_user.update(locale: locale)
      session[:locale] = locale
      I18n.locale = locale
      
      respond_to do |format|
        format.html { redirect_back fallback_location: root_path, notice: "Language updated" }
        format.json { render json: { success: true, locale: locale } }
      end
    else
      respond_to do |format|
        format.html { redirect_back fallback_location: root_path, alert: "Invalid language" }
        format.json { render json: { success: false, error: "Invalid locale" }, status: :not_found }
      end
    end
  end
  
  # POST /settings/update_timezone
  def update_timezone
    timezone = params[:timezone]
    
    if ActiveSupport::TimeZone[timezone]
      current_user.update(timezone: timezone)
      session[:timezone] = timezone
      
      respond_to do |format|
        format.html { redirect_back fallback_location: root_path, notice: "Timezone updated" }
        format.json { render json: { success: true, timezone: timezone } }
      end
    else
      respond_to do |format|
        format.html { redirect_back fallback_location: root_path, alert: "Invalid timezone" }
        format.json { render json: { success: false, error: "Invalid timezone" }, status: :not_found }
      end
    end
  end
end

