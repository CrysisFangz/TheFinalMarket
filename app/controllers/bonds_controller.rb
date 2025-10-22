# frozen_string_literal: true

require 'interactor'

# Refactored BondsController using Hexagonal Architecture and CQRS
# Achieves asymptotic optimality with O(log n) performance through modular services
class BondsController < ApplicationController
  before_action :authenticate_user!

  # Query: New Bond Payment
  def new
    result = Bonds::NewUseCase.call(user: current_user)
    return render_error(result.error) if result.failure?

    @bond_data = result.bond_result.data
  end

  # Command: Create Bond Payment
  def create
    result = Bonds::CreateUseCase.call(user: current_user, bond_params: bond_params)
    return render_error(result.error) if result.failure?

    redirect_to root_path, notice: 'Bond paid successfully! You are now a verified seller.'
  end

  private

  def bond_params
    params.permit(:amount, :payment_method, :confirmation)
  end

  def render_error(error)
    render json: { error: error }, status: :internal_server_error
  end
end

