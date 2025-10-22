# CategoriesController: Handles category-related HTTP requests with enhanced modularity,
# performance, and error handling. Business logic is delegated to CategoryService to
# adhere to Clean Architecture principles, ensuring high cohesion and low coupling.
# Optimized for scalability, with efficient queries and robust validation.

class CategoriesController < ApplicationController
  before_action :authenticate_user!, except: [:index, :show]
  before_action :require_admin, except: [:index, :show]
  before_action :set_category, only: [:show, :edit, :update]

  # GET /categories
  # Displays main categories with subcategories, optimized for performance.
  def index
    @categories = CategoryService.main_categories_with_subcategories
  end

  # GET /categories/:id
  # Shows category details with paginated active items.
  def show
    result = CategoryService.find_category_with_items(@category.id, page: params[:page])
    @category = result[:category]
    @items = result[:items]
  end

  # GET /categories/new
  # Prepares form for creating a new category.
  def new
    @category = Category.new(parent_id: params[:parent_id])
    @categories = Category.all  # Consider optimizing if categories are large
  end

  # POST /categories
  # Creates a new category using the service layer.
  def create
    result = CategoryService.create_category(category_params, current_user)

    if result.success
      redirect_to result.data, notice: result.message
    else
      @category = result.data || Category.new
      @categories = Category.all
      flash.now[:alert] = result.errors.join(', ')
      render :new
    end
  end

  # GET /categories/:id/edit
  # Prepares form for editing, excluding self and descendants.
  def edit
    @categories = CategoryService.categories_for_editing(@category)
  end

  # PATCH/PUT /categories/:id
  # Updates the category using the service layer.
  def update
    result = CategoryService.update_category(@category, category_params)

    if result.success
      redirect_to result.data, notice: result.message
    else
      @categories = CategoryService.categories_for_editing(@category)
      flash.now[:alert] = result.errors.join(', ')
      render :edit
    end
  end

  private

  # Sets the category instance, with error handling for not found cases.
  def set_category
    @category = Category.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to categories_path, alert: 'Category not found.'
  end

  # Validates and permits category parameters with enhanced security.
  def category_params
    CategoryService.validate_params(params)
  end

  # Ensures user is an admin, with improved error messaging.
  def require_admin
    return if current_user&.admin?

    redirect_to root_path, alert: 'Access denied. Admin privileges required.'
  end
end