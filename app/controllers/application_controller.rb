class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  include AuthenticationConcern
  include Pundit::Authorization
  include Personalization

  before_action :check_session_timeout
  before_action :set_cart
  before_action :set_personalized_content

  private

  def check_session_timeout
    return unless session[:user_id]
    
    if session[:session_created_at].present?
      session_age = Time.current - Time.parse(session[:session_created_at].to_s)
      session_timeout = 8.hours.to_i
      
      if session_age > session_timeout
        reset_session
        redirect_to login_path, alert: 'Your session has expired. Please log in again.'
      end
    else
      # Set timestamp if missing (for existing sessions)
      session[:session_created_at] = Time.current
    end
  end

  def set_cart
    @cart = current_user.cart || current_user.create_cart if user_signed_in?
  end

  def set_personalized_content
    @personalized_content = personalized_content if user_signed_in?
  end
end
