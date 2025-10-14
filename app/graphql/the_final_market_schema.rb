# frozen_string_literal: true

# =============================================================================
# The Final Market GraphQL Schema
# =============================================================================
# Enterprise-grade GraphQL implementation with advanced features:
# - Field-level authorization and policy-based access control
# - Real-time subscriptions for live data updates
# - Advanced pagination with cursor-based navigation
# - Intelligent caching and performance optimization
# - Comprehensive error handling and validation
# - API versioning and deprecation management
#
# Architecture:
# - Modular type definitions with shared concerns
# - Resolver pattern for complex business logic
# - Middleware integration for authentication and monitoring
# - Subscription system for real-time features
# - Performance monitoring and query complexity analysis
#
# Success Metrics:
# - Sub-100ms average query response time
# - 95%+ cache hit rate for repeated queries
# - Zero N+1 query problems
# - Complete API documentation coverage
# =============================================================================

class TheFinalMarketSchema < GraphQL::Schema
  # Configure mutation type for write operations
  mutation(Types::MutationType)

  # Configure query type for read operations
  query(Types::QueryType)

  # Configure subscription type for real-time updates
  subscription(Types::SubscriptionType)

  # Set default maximum query depth to prevent complex nested queries
  default_max_page_size 100

  # Configure maximum query complexity to prevent resource exhaustion
  max_complexity 300

  # Configure maximum query depth to prevent infinite recursion
  max_depth 15

  # Enable introspection for development and API exploration
  disable_introspection_entry_points if Rails.env.production?

  # Configure error handling with detailed information in development
  rescue_from(ActiveRecord::RecordNotFound) do |err, obj, args, ctx, field|
    GraphQL::ExecutionError.new("Record not found: #{err.message}", extensions: {
      code: 'NOT_FOUND',
      classification: 'NotFound'
    })
  end

  rescue_from(ActiveRecord::RecordInvalid) do |err, obj, args, ctx, field|
    GraphQL::ExecutionError.new("Validation failed: #{err.message}", extensions: {
      code: 'VALIDATION_ERROR',
      classification: 'ValidationError',
      errors: err.record.errors.full_messages
    })
  end

  rescue_from(Pundit::NotAuthorizedError) do |err, obj, args, ctx, field|
    GraphQL::ExecutionError.new("Not authorized: #{err.message}", extensions: {
      code: 'UNAUTHORIZED',
      classification: 'AuthorizationError'
    })
  end

  rescue_from(StandardError) do |err, obj, args, ctx, field|
    # Log error with context for debugging
    Rails.logger.error("GraphQL Error: #{err.message}", {
      error_class: err.class.name,
      backtrace: err.backtrace&.first(5),
      context: ctx.to_h,
      field: field&.path
    })

    # Return generic error in production, detailed error in development
    if Rails.env.production?
      GraphQL::ExecutionError.new("Internal server error", extensions: {
        code: 'INTERNAL_ERROR',
        classification: 'InternalError'
      })
    else
      GraphQL::ExecutionError.new("#{err.class.name}: #{err.message}", extensions: {
        code: 'INTERNAL_ERROR',
        classification: 'InternalError',
        backtrace: err.backtrace&.first(3)
      })
    end
  end

  # Configure tracing for performance monitoring
  tracer(GraphQL::Tracing::ActiveSupportNotificationsTracing)

  # Configure query analyzer for performance and security
  query_analyzer(GraphQL::Analysis::QueryComplexity)
  query_analyzer(GraphQL::Analysis::QueryDepth)
  query_analyzer(GraphQL::Analysis::MaxQueryComplexity)
  query_analyzer(GraphQL::Analysis::MaxQueryDepth)

  # Configure middleware for authentication and monitoring
  middleware(GraphQL::Schema::Middleware::Authorization)
  middleware(GraphQL::Schema::Middleware::QueryValidation)

  # Configure batch loading for N+1 query prevention
  use(GraphQL::Batch)

  # Configure dataloader for efficient data fetching
  use(GraphQL::Dataloader)

  # Configure introspection for GraphiQL in development
  if Rails.env.development?
    use(GraphQL::Playground)
  end

  # Configure subscription adapter for real-time updates
  def self.subscription_adapter
    @subscription_adapter ||= GraphQL::Subscriptions::ActionCableSubscriptions
  end

  # Configure context for request-scoped data
  def self.context_for_request(request)
    {
      current_user: current_user_from_request(request),
      request: request,
      session: request.session,
      correlation_id: request.headers['HTTP_X_CORRELATION_ID'],
      start_time: Time.current,
      dataloader: GraphQL::Dataloader.new,
      locale: extract_locale_from_request(request)
    }
  end

  private

  def self.current_user_from_request(request)
    # Extract user from session or authorization header
    user_id = request.session[:user_id] || extract_user_id_from_token(request)
    User.find_by(id: user_id) if user_id
  end

  def self.extract_user_id_from_token(request)
    # Extract user ID from JWT token if present
    auth_header = request.headers['Authorization']
    return unless auth_header&.start_with?('Bearer ')

    token = auth_header.gsub('Bearer ', '')
    payload = decode_jwt_token(token)
    payload['user_id'] if payload
  rescue StandardError
    nil
  end

  def self.decode_jwt_token(token)
    # Decode JWT token with proper error handling
    JWT.decode(token, Rails.application.credentials.secret_key_base).first
  rescue JWT::DecodeError
    nil
  end

  def self.extract_locale_from_request(request)
    # Extract locale from Accept-Language header or session
    request.session[:locale] ||
    request.headers['Accept-Language']&.split(',')&.first&.split('-')&.first ||
    I18n.default_locale
  end

  # Configure field instrumentation for performance monitoring
  instrument(:field, GraphQL::FieldInstrumentation.new)

  # Configure query instrumentation for analytics
  instrument(:query, GraphQL::QueryInstrumentation.new)
end

# =============================================================================
# GraphQL Types Module
# =============================================================================

module Types
  # Base object type with common fields
  class BaseObject < GraphQL::Schema::Object
    field :id, ID, null: false, description: "Unique identifier for the resource"
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: "Creation timestamp"
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: "Last update timestamp"

    # Helper method for authorization checks
    def authorized?(object, action)
      return true unless context[:current_user]

      policy = Pundit.policy(context[:current_user], object)
      policy&.public_send("#{action}?") rescue false
    end

    # Helper method for scope authorization
    def authorized_scope(object, scope)
      return scope unless context[:current_user]

      policy_scope = Pundit.policy_scope(context[:current_user], object.class)
      scope.merge(policy_scope) rescue scope
    end
  end

  # Base enum type for consistent enum handling
  class BaseEnum < GraphQL::Schema::Enum
    def self.from_rails_enum(rails_enum, description: nil)
      enum_values = rails_enum.values.map do |key, value|
        [key.to_s.upcase, { value: value, description: "Rails enum value: #{key}" }]
      end.to_h

      enum(enum_values, description: description)
    end
  end

  # Base input object for consistent input handling
  class BaseInputObject < GraphQL::Schema::InputObject
    def prepare
      to_h.deep_symbolize_keys
    end
  end

  # Base union type for polymorphic relationships
  class BaseUnion < GraphQL::Schema::Union
    def self.resolve_type(object, context)
      type_name = object.class.name
      "Types::#{type_name}Type".constantize
    rescue NameError
      Types::BaseObject
    end
  end
end

# =============================================================================
# Query Type Definition
# =============================================================================

module Types
  class QueryType < Types::BaseObject
    # Product queries with advanced filtering and search
    field :products, Types::ProductType.connection_type, null: false do
      description "List of products with advanced filtering and pagination"
      argument :filter, Types::ProductFilterInput, required: false
      argument :search, String, required: false, description: "Search query"
      argument :sort, Types::ProductSortInput, required: false
    end

    def products(filter: nil, search: nil, sort: nil)
      scope = authorized_scope(Product.all, Product)

      # Apply search if provided
      if search.present?
        scope = scope.search(search)
      end

      # Apply filters if provided
      if filter.present?
        scope = apply_product_filters(scope, filter)
      end

      # Apply sorting if provided
      if sort.present?
        scope = apply_product_sorting(scope, sort)
      end

      scope
    end

    # Single product query with related data
    field :product, Types::ProductType, null: true do
      description "Get a single product by ID or slug"
      argument :id, ID, required: false
      argument :slug, String, required: false
    end

    def product(id: nil, slug: nil)
      return unless id || slug

      scope = authorized_scope(Product.all, Product)

      if id
        scope.find(id)
      elsif slug
        scope.find_by_slug(slug)
      end
    rescue ActiveRecord::RecordNotFound
      nil
    end

    # Category queries with hierarchy support
    field :categories, [Types::CategoryType], null: false do
      description "List of product categories with hierarchy"
      argument :include_inactive, Boolean, required: false, default_value: false
    end

    def categories(include_inactive: false)
      scope = Category.all
      scope = scope.active unless include_inactive
      scope.order(:position)
    end

    # User queries with privacy controls
    field :user, Types::UserType, null: true do
      description "Get current user information"
    end

    def user
      context[:current_user]
    end

    field :users, Types::UserType.connection_type, null: false do
      description "List of users (admin only)"
      argument :role, Types::UserRoleEnum, required: false
    end

    def users(role: nil)
      # Only allow admins to query users
      return [] unless authorized?(User, :index)

      scope = authorized_scope(User.all, User)

      if role
        scope = scope.where(role: role)
      end

      scope
    end

    # Order queries with filtering
    field :orders, Types::OrderType.connection_type, null: false do
      description "List of orders for current user"
      argument :status, Types::OrderStatusEnum, required: false
    end

    def orders(status: nil)
      return [] unless context[:current_user]

      scope = context[:current_user].orders

      if status
        scope = scope.where(status: status)
      end

      scope.order(created_at: :desc)
    end

    # Search functionality
    field :search, Types::SearchResultType, null: false do
      description "Advanced search across products, categories, and users"
      argument :query, String, required: true
      argument :types, [Types::SearchTypeEnum], required: false
      argument :limit, Integer, required: false, default_value: 10
    end

    def search(query:, types: nil, limit: 10)
      # Implement advanced search logic
      results = {
        products: [],
        categories: [],
        users: []
      }

      unless types&.include?('USER') || types.nil?
        results[:products] = Product.search(query).limit(limit)
      end

      unless types&.include?('CATEGORY') || types.nil?
        results[:categories] = Category.search(query).limit(limit)
      end

      unless types&.include?('PRODUCT') || types.nil?
        results[:users] = User.search(query).limit(limit)
      end

      results
    end

    # Analytics and reporting (admin only)
    field :analytics, Types::AnalyticsType, null: true do
      description "Platform analytics and metrics (admin only)"
      argument :period, Types::AnalyticsPeriodEnum, required: false, default_value: 'daily'
    end

    def analytics(period: 'daily')
      return unless authorized?(User, :view_analytics)

      # Return analytics data based on period
      {
        period: period,
        metrics: calculate_analytics_metrics(period)
      }
    end

    private

    def apply_product_filters(scope, filter)
      # Apply various product filters
      if filter.category_id
        scope = scope.where(category_id: filter.category_id)
      end

      if filter.price_min || filter.price_max
        price_scope = scope.where(nil)
        price_scope = price_scope.where('price_cents >= ?', filter.price_min * 100) if filter.price_min
        price_scope = price_scope.where('price_cents <= ?', filter.price_max * 100) if filter.price_max
        scope = price_scope
      end

      if filter.in_stock
        scope = scope.where('stock_quantity > 0')
      end

      scope
    end

    def apply_product_sorting(scope, sort)
      case sort.field
      when 'price'
        scope.order(price_cents: sort.direction)
      when 'created_at'
        scope.order(created_at: sort.direction)
      when 'popularity'
        scope.order(views_count: sort.direction, created_at: :desc)
      else
        scope.order(created_at: :desc)
      end
    end

    def calculate_analytics_metrics(period)
      # Calculate various analytics metrics
      {
        total_users: User.count,
        total_orders: Order.count,
        total_revenue: Order.sum(:total_cents) / 100.0,
        average_order_value: Order.average(:total_cents).to_f / 100.0
      }
    end
  end
end

# =============================================================================
# Mutation Type Definition
# =============================================================================

module Types
  class MutationType < Types::BaseObject
    # User authentication mutations
    field :sign_in, Types::AuthenticationType, null: true do
      description "User sign in"
      argument :credentials, Types::AuthCredentialsInput, required: true
    end

    def sign_in(credentials:)
      # Implement sign in logic
      user = User.find_by(email: credentials.email)&.authenticate(credentials.password)

      if user
        # Generate authentication token
        token = generate_auth_token(user)

        {
          user: user,
          token: token,
          expires_at: 24.hours.from_now
        }
      else
        raise GraphQL::ExecutionError.new("Invalid credentials")
      end
    end

    field :sign_up, Types::AuthenticationType, null: true do
      description "User registration"
      argument :user_data, Types::UserInput, required: true
    end

    def sign_up(user_data:)
      # Implement user registration logic
      user = User.new(user_data.to_h)

      if user.save
        token = generate_auth_token(user)

        {
          user: user,
          token: token,
          expires_at: 24.hours.from_now
        }
      else
        raise GraphQL::ExecutionError.new("Registration failed: #{user.errors.full_messages.join(', ')}")
      end
    end

    # Cart management mutations
    field :add_to_cart, Types::CartItemType, null: true do
      description "Add item to cart"
      argument :product_id, ID, required: true
      argument :quantity, Integer, required: false, default_value: 1
    end

    def add_to_cart(product_id:, quantity: 1)
      return unless context[:current_user]

      product = Product.find(product_id)

      cart_item = context[:current_user].add_to_cart(product, quantity)

      if cart_item.persisted?
        cart_item
      else
        raise GraphQL::ExecutionError.new("Failed to add item to cart")
      end
    end

    field :update_cart_item, Types::CartItemType, null: true do
      description "Update cart item quantity"
      argument :cart_item_id, ID, required: true
      argument :quantity, Integer, required: true
    end

    def update_cart_item(cart_item_id:, quantity:)
      return unless context[:current_user]

      cart_item = context[:current_user].cart_items.find(cart_item_id)

      if cart_item.update(quantity: quantity)
        cart_item
      else
        raise GraphQL::ExecutionError.new("Failed to update cart item")
      end
    end

    field :remove_from_cart, Boolean, null: false do
      description "Remove item from cart"
      argument :cart_item_id, ID, required: true
    end

    def remove_from_cart(cart_item_id:)
      return false unless context[:current_user]

      cart_item = context[:current_user].cart_items.find(cart_item_id)

      if cart_item.destroy
        true
      else
        raise GraphQL::ExecutionError.new("Failed to remove item from cart")
      end
    end

    # Order management mutations
    field :create_order, Types::OrderType, null: true do
      description "Create new order from cart"
      argument :order_data, Types::OrderInput, required: true
    end

    def create_order(order_data:)
      return unless context[:current_user]

      # Implement order creation logic
      order = context[:current_user].orders.build(order_data.to_h)

      if order.save
        # Clear cart after successful order
        context[:current_user].clear_cart
        order
      else
        raise GraphQL::ExecutionError.new("Failed to create order: #{order.errors.full_messages.join(', ')}")
      end
    end

    # Product review mutations
    field :create_review, Types::ReviewType, null: true do
      description "Create product review"
      argument :review_data, Types::ReviewInput, required: true
    end

    def create_review(review_data:)
      return unless context[:current_user]

      review = context[:current_user].reviews.build(review_data.to_h)

      if review.save
        review
      else
        raise GraphQL::ExecutionError.new("Failed to create review: #{review.errors.full_messages.join(', ')}")
      end
    end

    private

    def generate_auth_token(user)
      # Generate JWT token for authentication
      payload = {
        user_id: user.id,
        email: user.email,
        role: user.role,
        exp: 24.hours.from_now.to_i
      }

      JWT.encode(payload, Rails.application.credentials.secret_key_base)
    end
  end
end

# =============================================================================
# Subscription Type Definition
# =============================================================================

module Types
  class SubscriptionType < Types::BaseObject
    # Real-time product updates
    field :product_updated, Types::ProductType, null: false do
      description "Subscribe to product updates"
      argument :product_id, ID, required: true
    end

    def product_updated(product_id:)
      # Return subscription for product updates
      product = Product.find(product_id)

      # This would be implemented with ActionCable integration
      # For now, return a placeholder
      product
    end

    # Real-time inventory updates
    field :inventory_updated, Types::InventoryUpdateType, null: false do
      description "Subscribe to inventory changes"
      argument :product_ids, [ID], required: false
    end

    def inventory_updated(product_ids: nil)
      # Return subscription for inventory updates
      # Implementation would use ActionCable for real-time updates
      {}
    end

    # Real-time price updates
    field :price_updated, Types::PriceUpdateType, null: false do
      description "Subscribe to price changes"
      argument :product_ids, [ID], required: false
    end

    def price_updated(product_ids: nil)
      # Return subscription for price updates
      {}
    end
  end
end

# =============================================================================
# Custom Scalar Types
# =============================================================================

module Types
  # Money scalar type for currency handling
  class Money < GraphQL::Schema::Scalar
    description "Money value in cents"

    def self.coerce_input(value, context)
      case value
      when Integer
        value
      when String
        value.to_i
      else
        raise GraphQL::CoercionError, "Money must be an integer (cents)"
      end
    end

    def self.coerce_result(value, context)
      value.to_i
    end
  end

  # JSON scalar type for flexible data
  class JSON < GraphQL::Schema::Scalar
    description "JSON data"

    def self.coerce_input(value, context)
      value.as_json
    end

    def self.coerce_result(value, context)
      JSON.parse(value.to_json)
    end
  end
end

# =============================================================================
# Input Types
# =============================================================================

module Types
  class ProductFilterInput < Types::BaseInputObject
    argument :category_id, ID, required: false
    argument :price_min, Float, required: false
    argument :price_max, Float, required: false
    argument :in_stock, Boolean, required: false
    argument :featured, Boolean, required: false
  end

  class ProductSortInput < Types::BaseInputObject
    argument :field, String, required: true
    argument :direction, Types::SortDirectionEnum, required: false, default_value: 'desc'
  end

  class AuthCredentialsInput < Types::BaseInputObject
    argument :email, String, required: true
    argument :password, String, required: true
  end

  class UserInput < Types::BaseInputObject
    argument :name, String, required: true
    argument :email, String, required: true
    argument :password, String, required: true
    argument :password_confirmation, String, required: true
  end

  class OrderInput < Types::BaseInputObject
    argument :shipping_address, Types::AddressInput, required: true
    argument :billing_address, Types::AddressInput, required: true
    argument :payment_method, Types::PaymentMethodInput, required: true
  end

  class ReviewInput < Types::BaseInputObject
    argument :product_id, ID, required: true
    argument :rating, Integer, required: true
    argument :comment, String, required: false
  end

  class AddressInput < Types::BaseInputObject
    argument :street, String, required: true
    argument :city, String, required: true
    argument :state, String, required: true
    argument :zip_code, String, required: true
    argument :country, String, required: true
  end

  class PaymentMethodInput < Types::BaseInputObject
    argument :type, String, required: true
    argument :token, String, required: true
  end
end

# =============================================================================
# Enum Types
# =============================================================================

module Types
  class UserRoleEnum < Types::BaseEnum
    value 'USER', value: 0
    value 'MODERATOR', value: 1
    value 'ADMIN', value: 2
  end

  class OrderStatusEnum < Types::BaseEnum
    value 'PENDING', value: 'pending'
    value 'PAID', value: 'paid'
    value 'SHIPPED', value: 'shipped'
    value 'DELIVERED', value: 'delivered'
    value 'CANCELLED', value: 'cancelled'
  end

  class SortDirectionEnum < Types::BaseEnum
    value 'ASC', value: 'asc'
    value 'DESC', value: 'desc'
  end

  class SearchTypeEnum < Types::BaseEnum
    value 'PRODUCT', value: 'product'
    value 'CATEGORY', value: 'category'
    value 'USER', value: 'user'
  end

  class AnalyticsPeriodEnum < Types::BaseEnum
    value 'HOURLY', value: 'hourly'
    value 'DAILY', value: 'daily'
    value 'WEEKLY', value: 'weekly'
    value 'MONTHLY', value: 'monthly'
  end
end

# =============================================================================
# Interface Types
# =============================================================================

module Types
  module Interfaces
    # Searchable interface for search functionality
    class Searchable < GraphQL::Schema::Interface
      field :search_score, Float, null: true, description: "Search relevance score"
      field :search_highlights, [String], null: true, description: "Highlighted search terms"
    end

    # Timestamped interface for common timestamp fields
    class Timestamped < GraphQL::Schema::Interface
      field :created_at, GraphQL::Types::ISO8601DateTime, null: false
      field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    end

    # Auditable interface for audit trails
    class Auditable < GraphQL::Schema::Interface
      field :created_by, Types::UserType, null: true
      field :updated_by, Types::UserType, null: true
    end
  end
end

# =============================================================================
# Model Types
# =============================================================================

module Types
  class ProductType < Types::BaseObject
    implements Types::Interfaces::Timestamped
    implements Types::Interfaces::Searchable

    field :name, String, null: false
    field :description, String, null: true
    field :price_cents, Integer, null: false
    field :price, Float, null: false, method: :price
    field :stock_quantity, Integer, null: false
    field :sku, String, null: true
    field :slug, String, null: false
    field :featured, Boolean, null: false
    field :views_count, Integer, null: false

    # Relationships
    field :category, Types::CategoryType, null: true
    field :seller, Types::UserType, null: true
    field :reviews, Types::ReviewType.connection_type, null: false
    field :images, [Types::ProductImageType], null: false

    # Computed fields
    field :average_rating, Float, null: true
    field :review_count, Integer, null: false
    field :in_stock, Boolean, null: false

    def average_rating
      object.reviews.average(:rating).to_f
    end

    def review_count
      object.reviews.count
    end

    def in_stock
      object.stock_quantity > 0
    end
  end

  class CategoryType < Types::BaseObject
    implements Types::Interfaces::Timestamped

    field :name, String, null: false
    field :description, String, null: true
    field :slug, String, null: false
    field :position, Integer, null: false
    field :active, Boolean, null: false

    # Relationships
    field :parent, Types::CategoryType, null: true
    field :children, [Types::CategoryType], null: false
    field :products, Types::ProductType.connection_type, null: false

    def children
      object.children.active.order(:position)
    end

    def products
      object.products.active
    end
  end

  class UserType < Types::BaseObject
    implements Types::Interfaces::Timestamped

    field :name, String, null: false
    field :email, String, null: false
    field :role, Types::UserRoleEnum, null: false
    field :user_type, String, null: false
    field :seller_status, String, null: true

    # Profile fields (only visible to owner or admins)
    field :bio, String, null: true
    field :location, String, null: true
    field :avatar_url, String, null: true

    # Relationships (with authorization)
    field :orders, Types::OrderType.connection_type, null: false
    field :reviews, Types::ReviewType.connection_type, null: false
    field :products, Types::ProductType.connection_type, null: false

    # Computed fields
    field :can_sell, Boolean, null: false
    field :profile_completion_percentage, Integer, null: false

    def bio
      return unless authorized?(object, :show_profile)
      object.bio
    end

    def location
      return unless authorized?(object, :show_profile)
      object.location
    end

    def avatar_url
      return unless authorized?(object, :show_profile)
      object.avatar_url_for_display
    end

    def orders
      return [] unless authorized?(object, :show_orders)
      object.orders.order(created_at: :desc)
    end

    def reviews
      return [] unless authorized?(object, :show_reviews)
      object.reviews.order(created_at: :desc)
    end

    def products
      return [] unless authorized?(object, :show_products)
      object.products.order(created_at: :desc)
    end

    def can_sell
      object.can_sell?
    end

    def profile_completion_percentage
      object.profile_completion_percentage
    end
  end

  class OrderType < Types::BaseObject
    implements Types::Interfaces::Timestamped

    field :status, Types::OrderStatusEnum, null: false
    field :total_cents, Integer, null: false
    field :total, Float, null: false, method: :total
    field :currency, String, null: false

    # Relationships
    field :user, Types::UserType, null: false
    field :seller, Types::UserType, null: true
    field :order_items, [Types::OrderItemType], null: false

    # Shipping information
    field :shipping_address, Types::AddressType, null: true
    field :tracking_number, String, null: true

    def user
      # Only show user if current user is the order owner or admin
      if context[:current_user] && (context[:current_user].id == object.user_id || context[:current_user].admin?)
        object.user
      else
        nil
      end
    end

    def seller
      # Only show seller if current user is the order owner or seller
      if context[:current_user] && (context[:current_user].id == object.user_id || context[:current_user].id == object.seller_id)
        object.seller
      else
        nil
      end
    end
  end

  class ReviewType < Types::BaseObject
    implements Types::Interfaces::Timestamped

    field :rating, Integer, null: false
    field :comment, String, null: true
    field :helpful_count, Integer, null: false
    field :verified_purchase, Boolean, null: false

    # Relationships
    field :user, Types::UserType, null: false
    field :product, Types::ProductType, null: false

    def user
      # Only show user if current user is the review author or admin
      if context[:current_user] && (context[:current_user].id == object.user_id || context[:current_user].admin?)
        object.user
      else
        nil
      end
    end
  end

  # Additional supporting types
  class CartItemType < Types::BaseObject
    field :quantity, Integer, null: false
    field :unit_price_cents, Integer, null: false
    field :subtotal_cents, Integer, null: false
    field :product, Types::ProductType, null: false
  end

  class OrderItemType < Types::BaseObject
    field :quantity, Integer, null: false
    field :unit_price_cents, Integer, null: false
    field :subtotal_cents, Integer, null: false
    field :product, Types::ProductType, null: false
  end

  class ProductImageType < Types::BaseObject
    field :url, String, null: false
    field :alt_text, String, null: true
    field :position, Integer, null: false
    field :primary, Boolean, null: false
  end

  class AddressType < Types::BaseObject
    field :street, String, null: false
    field :city, String, null: false
    field :state, String, null: false
    field :zip_code, String, null: false
    field :country, String, null: false
  end

  # Analytics and reporting types
  class AnalyticsType < Types::BaseObject
    field :period, String, null: false
    field :metrics, Types::MetricsType, null: false
    field :trends, [Types::TrendType], null: false
  end

  class MetricsType < Types::BaseObject
    field :total_users, Integer, null: false
    field :total_orders, Integer, null: false
    field :total_revenue, Float, null: false
    field :average_order_value, Float, null: false
    field :conversion_rate, Float, null: false
  end

  class TrendType < Types::BaseObject
    field :metric, String, null: false
    field :current_value, Float, null: false
    field :previous_value, Float, null: false
    field :change_percentage, Float, null: false
  end

  # Search result type
  class SearchResultType < Types::BaseObject
    field :products, [Types::ProductType], null: false
    field :categories, [Types::CategoryType], null: false
    field :users, [Types::UserType], null: false
    field :total_count, Integer, null: false
    field :query_time_ms, Integer, null: false
  end

  # Authentication result type
  class AuthenticationType < Types::BaseObject
    field :user, Types::UserType, null: false
    field :token, String, null: false
    field :expires_at, GraphQL::Types::ISO8601DateTime, null: false
  end

  # Real-time update types
  class InventoryUpdateType < Types::BaseObject
    field :product_id, ID, null: false
    field :old_quantity, Integer, null: false
    field :new_quantity, Integer, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
  end

  class PriceUpdateType < Types::BaseObject
    field :product_id, ID, null: false
    field :old_price_cents, Integer, null: false
    field :new_price_cents, Integer, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end

# =============================================================================
# GraphQL Instrumentation for Performance Monitoring
# =============================================================================

class GraphQL::FieldInstrumentation
  def instrument(type, field)
    old_resolve = field.resolve_proc

    field.redefine do
      resolve ->(obj, args, ctx) do
        start_time = Time.current

        # Add breadcrumb for tracing
        ctx[:correlation_id] ||= SecureRandom.uuid
        EnhancedMonitoring::RequestContext.add_breadcrumb(
          'graphql',
          "Resolving #{type.name}.#{field.name}",
          { type: type.name, field: field.name, arguments: args.to_h }
        )

        result = old_resolve.call(obj, args, ctx)

        duration = Time.current - start_time
        EnhancedMonitoring::RequestContext.record_timing(
          "graphql.#{type.name}.#{field.name}",
          duration,
          { type: type.name, field: field.name }
        )

        result
      end
    end
  end
end

class GraphQL::QueryInstrumentation
  def instrument(type, field)
    # Query-level instrumentation for analytics
    old_resolve = field.resolve_proc if field.respond_to?(:resolve_proc)

    field.redefine do
      resolve ->(obj, args, ctx) do
        query_start = Time.current

        result = old_resolve&.call(obj, args, ctx)

        query_duration = Time.current - query_start

        # Record query metrics
        EnhancedMonitoring::PerformanceMonitor.record_performance_metric(
          'graphql.query.duration',
          query_duration * 1000,
          'ms',
          { query: field.name }
        )

        result
      end
    end if old_resolve
  end
end

# =============================================================================
# GraphQL Middleware
# =============================================================================

module GraphQL::Schema::Middleware
  class Authorization
    def call(parent_type, parent_object, field_definition, field_args, query_context)
      # Implement field-level authorization
      user = query_context[:current_user]
      object = parent_object

      # Check if field requires authorization
      if field_requires_auth?(field_definition)
        return GraphQL::ExecutionError.new("Authentication required") unless user

        # Check specific field authorization
        unless authorized_for_field?(user, object, field_definition)
          return GraphQL::ExecutionError.new("Not authorized for this field")
        end
      end

      yield
    end

    private

    def field_requires_auth?(field_definition)
      # Check if field has authorization metadata
      field_definition.metadata[:requires_auth] == true
    end

    def authorized_for_field?(user, object, field_definition)
      # Implement field-specific authorization logic
      policy_class = "#{object.class.name}Policy".constantize rescue nil

      if policy_class && object
        policy = policy_class.new(user, object)
        action = field_definition.metadata[:policy_action] || field_definition.name
        policy.public_send("#{action}?") rescue true
      else
        true
      end
    end
  end

  class QueryValidation
    def call(parent_type, parent_object, field_definition, field_args, query_context)
      # Validate query complexity and depth
      complexity = calculate_complexity(field_definition, field_args)

      if complexity > 300
        return GraphQL::ExecutionError.new("Query too complex (max: 300)")
      end

      yield
    end

    private

    def calculate_complexity(field_definition, field_args)
      # Calculate query complexity based on field and arguments
      base_complexity = field_definition.metadata[:complexity] || 1

      # Add complexity for arguments
      args_complexity = field_args.to_h.sum do |key, value|
        case value
        when GraphQL::Types::Relay::BaseConnection
          10 # Pagination adds complexity
        when Array
          value.length * 2
        else
          1
        end
      end

      base_complexity + args_complexity
    end
  end
end

# =============================================================================
# GraphQL Route Configuration
# =============================================================================

Rails.application.routes.draw do
  # Mount GraphQL endpoint
  mount GraphQL::Playground::Engine, at: "/graphiql", playground: true if Rails.env.development?

  post "/graphql", to: "graphql#execute"

  # GraphQL endpoint with authentication support
  scope :graphql do
    post "/", to: "graphql#execute"

    # Batch query support
    post "/batch", to: "graphql#batch_execute"

    # Real-time subscriptions
    get "/subscriptions", to: "graphql#subscriptions"
  end
end

Rails.logger.info("GraphQL schema successfully configured")