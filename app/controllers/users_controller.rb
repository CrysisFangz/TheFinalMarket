class UsersController < ApplicationController
  before_action :authenticate_user!, only: [:show]

  def show
    @user = User.find(params[:id])
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    
    if @user.save
      # Initialize security fields
      @user.update_columns(
        failed_login_attempts: 0,
        locked_until: nil,
        last_login_at: Time.current
      ) if @user.respond_to?(:failed_login_attempts)
      
      session[:user_id] = @user.id
      session[:session_created_at] = Time.current
      redirect_to root_path, notice: 'Welcome! You have signed up successfully.'
    else
      # Provide helpful password feedback
      if @user.errors[:password].any?
        flash.now[:alert] = "Password #{@user.errors[:password].join(', ')}"
      end
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end
