# frozen_string_literal: true

# Session Store Configuration
# Configures secure session management with automatic timeout

Rails.application.config.session_store :cookie_store,
  key: '_thefinalmarket_session',
  
  # Security settings
  secure: Rails.env.production?, # Only send cookie over HTTPS in production
  httponly: true,                # Prevent JavaScript access to session cookie
  same_site: :lax,              # CSRF protection
  
  # Session timeout (8 hours)
  expire_after: ENV.fetch('SESSION_TIMEOUT', 8.hours.to_i).to_i.seconds

# Session timeout middleware
class SessionTimeout
  def initialize(app)
    @app = app
  end

  def call(env)
    session = env['rack.session']
    
    # Check if session has expired
    if session[:last_activity_at].present?
      last_activity = Time.at(session[:last_activity_at])
      timeout = ENV.fetch('SESSION_TIMEOUT', 8.hours.to_i).to_i.seconds
      
      if Time.current - last_activity > timeout
        # Session expired - clear it
        session.clear
        session[:flash] = { notice: 'Your session has expired. Please log in again.' }
      end
    end
    
    # Update last activity timestamp
    session[:last_activity_at] = Time.current.to_i if session[:user_id]
    
    @app.call(env)
  end
end

Rails.application.config.middleware.use SessionTimeout