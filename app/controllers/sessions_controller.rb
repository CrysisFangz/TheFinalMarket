class SessionsController < ApplicationController
  def new
  end

  def create
    user = User.find_by(email: params[:email]&.downcase)
    
    # Check if account is locked
    if user&.account_locked?
      flash.now[:alert] = "Account locked due to too many failed login attempts. Please try again in 30 minutes."
      render :new, status: :unprocessable_entity
      return
    end
    
    # Authenticate user
    if user&.authenticate(params[:password])
      # Successful login - reset failed attempts and record login
      user.record_successful_login!
      session[:user_id] = user.id
      session[:session_created_at] = Time.current
      redirect_to root_path, notice: 'Logged in successfully!'
    else
      # Failed login - track attempt
      user&.record_failed_login!
      
      # Customize message if locked after this attempt
      if user&.account_locked?
        flash.now[:alert] = 'Too many failed attempts. Your account has been locked for 30 minutes.'
      else
        flash.now[:alert] = 'Invalid email or password'
      end
      
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session[:user_id] = nil
    session[:session_created_at] = nil
    redirect_to root_path, notice: 'Logged out successfully!'
  end
end
