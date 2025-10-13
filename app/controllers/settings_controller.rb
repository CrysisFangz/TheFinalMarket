# app/controllers/settings_controller.rb
class SettingsController < ApplicationController
  before_action :authenticate_user!

  def index
    @user = current_user
    @available_currencies = Currency.all
    @available_locales = I18n.available_locales
    @available_timezones = ActiveSupport::TimeZone.all.map { |tz| [tz.name, tz.name] }
  end

  def update_profile
    if current_user.update(profile_params)
      redirect_to settings_path, notice: 'Profile updated successfully.'
    else
      @user = current_user
      render :index
    end
  end

  def update_password
    if current_user.authenticate(params[:user][:current_password])
      if current_user.update(password_params)
        redirect_to settings_path, notice: 'Password updated successfully.'
      else
        @user = current_user
        flash.now[:alert] = 'Password update failed.'
        render :index
      end
    else
      @user = current_user
      flash.now[:alert] = 'Current password is incorrect.'
      render :index
    end
  end

  def update_notifications
    if current_user.update(notification_params)
      redirect_to settings_path, notice: 'Notification preferences updated.'
    else
      @user = current_user
      render :index
    end
  end

  def update_privacy
    if current_user.update(privacy_params)
      redirect_to settings_path, notice: 'Privacy settings updated.'
    else
      @user = current_user
      render :index
    end
  end
  
  def update_preferences
    if current_user.update(preference_params)
      # Update currency preference if provided
      if params[:user][:currency_id].present?
        currency = Currency.find(params[:user][:currency_id])
        current_user.user_currency_preference&.update(currency: currency) ||
          current_user.create_user_currency_preference(currency: currency)
      end
      
      redirect_to settings_path, notice: 'Preferences updated successfully.'
    else
      @user = current_user
      render :index
    end
  end

  private

  def profile_params
    params.require(:user).permit(:name, :email, :phone, :bio, :avatar)
  end

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end

  def notification_params
    params.require(:user).permit(
      :email_notifications,
      :push_notifications,
      :sms_notifications,
      :order_notifications,
      :promotion_notifications
    )
  end

  def privacy_params
    params.require(:user).permit(
      :profile_visibility,
      :show_email,
      :show_phone,
      :allow_messages
    )
  end
  
  def preference_params
    params.require(:user).permit(
      :locale,
      :timezone,
      :theme
    )
  end
end