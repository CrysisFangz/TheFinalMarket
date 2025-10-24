class ShippingController < ApplicationController
  # POST /shipping/calculate
  def calculate
    country_code = params[:country_code]
    weight_grams = params[:weight_grams].to_i

    result = ShippingCalculationService.calculate_shipping(country_code, weight_grams)

    if result[:error]
      return render json: { error: result[:error] }, status: result[:status]
    end

    render json: result
  end

  # GET /shipping/zones
  def zones
    result = ShippingCalculationService.all_zones
    render json: result
  end
end

