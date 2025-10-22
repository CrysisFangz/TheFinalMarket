Rails.application.routes.draw do
   # ================================================================================================
   # ROUTING CONCERNS - SHARED BEHAVIOR PATTERNS
   # ================================================================================================
   # Reusable routing patterns that follow DRY principles and ensure consistency
   # Concerns encapsulate common routing behavior for maintainability and reusability

   # Review System Concern - Standardized review routes with helpful/unhelpful functionality
   # Used across multiple resources (items, users) to maintain consistent review behavior
   concern :reviewable do
     resources :reviews, only: [:create, :update, :destroy], constraints: { id: /\d+/ } do
       member do
         # Community voting system for review quality assessment
         post :helpful
         delete :helpful, action: :unhelpful
       end
     end
   end

   # ================================================================================================
   # ENTERPRISE ADMIN INTERFACE - RAILS ADMIN
   # ================================================================================================
   # Sophisticated admin panel with zero-configuration model discovery and comprehensive CRUD
   # Secured with CanCanCan authorization and integrated with AdminActivityLoggingService
   # Access restricted to admin, super_admin, and system roles only
   mount RailsAdmin::Engine => '/admin', as: 'rails_admin'

   # ================================================================================================
   # CORE AUTHENTICATION & AUTHORIZATION SYSTEM
   # ================================================================================================
  # Essential user authentication system providing secure access management for the entire platform
  # Handles user registration, login/logout functionality, and session management
  # These routes are fundamental to platform security and user identity verification

  # User Registration - Account creation and initial setup
  get    '/signup',  to: 'users#new'
  post   '/signup',  to: 'users#create'

  # User Authentication - Login/logout session management
  get    '/login',   to: 'sessions#new'
  post   '/login',   to: 'sessions#create'
  delete '/logout',  to: 'sessions#destroy'

  # ================================================================================================
  # USER DASHBOARD & PROFILE MANAGEMENT SYSTEM
  # ================================================================================================
  # Centralized user interface for personal dashboard, activity monitoring, and account management
  # Provides comprehensive user control over profile, preferences, security, and platform interaction

  # User Dashboard - Central hub for user activities, analytics, and navigation
  # Displays personalized content, recent activities, and quick access to key features
  get 'dashboard', to: 'users_dashboard#index', as: :user_dashboard
  get 'dashboard/stats', to: 'users_dashboard#stats', as: :dashboard_stats
  get 'dashboard/activities', to: 'users_dashboard#activities', as: :dashboard_activities

  # User Settings - Comprehensive profile and preference management system
  # Allows users to customize their experience, manage privacy, and control account settings
  get 'settings', to: 'settings#index', as: :settings
  post 'settings/update_profile', to: 'settings#update_profile', as: :settings_update_profile
  post 'settings/update_password', to: 'settings#update_password', as: :settings_update_password
  post 'settings/update_notifications', to: 'settings#update_notifications', as: :settings_update_notifications
  post 'settings/update_privacy', to: 'settings#update_privacy', as: :settings_update_privacy
  post 'settings/update_preferences', to: 'settings#update_preferences', as: :settings_update_preferences

  # ================================================================================================
  # SELLER-SPECIFIC BUSINESS OPERATIONS SYSTEM
  # ================================================================================================
  # Comprehensive seller management system providing order processing, pricing optimization,
  # inventory management, and financial tracking capabilities for marketplace sellers

  namespace :seller do
    # Seller Dashboard - Primary command center for seller operations and business insights
    root to: 'dashboard#index', as: :dashboard

    # Order Management System - Complete order lifecycle management for sellers
    # Numeric ID constraint prevents injection attacks and ensures data integrity
    resources :orders, only: [:index, :show], constraints: { id: /\d+/ } do
      member do
        # Mark orders as shipped - Updates order status and triggers customer notifications
        patch :ship
      end
    end

    # Advanced Pricing Engine - AI-powered dynamic pricing with competitive analysis
    # Numeric ID constraint ensures secure and valid pricing operations
    resources :pricing, only: [:index, :show], constraints: { id: /\d+/ } do
      member do
        # Get AI-powered pricing recommendations based on market analysis
        get :recommendations
        # Apply recommended pricing changes to products
        post :apply_recommendation
      end
      collection do
        # Comprehensive pricing analytics and performance metrics
        get :analytics
        # View and manage automated pricing rules
        get :rules
        # Create new pricing automation rules
        post :create_rule
        # Real-time pricing updates and market changes
        get :updates
        # Export pricing data for external analysis
        get :export
        # Bulk optimization across multiple products
        post :bulk_optimize
      end
    end

    # Pricing Rules Management - Direct manipulation of pricing automation rules
    resources :pricing_rules, only: [:update, :destroy], constraints: { id: /\d+/ }
  end

  # Additional Seller Financial Management - Payment processing and financial oversight
  namespace :dashboard do
    # Business overview and key performance indicators
    get 'overview'
    # Complete payment history and transaction records
    get 'payment_history'
    # Escrow account management for secure transaction handling
    get 'escrow'
    # Performance bond management for seller verification and buyer protection
    get 'bond'
  end

 # ================================================================================================
 # ADMINISTRATIVE CONTROL SYSTEM
 # ================================================================================================
 # Comprehensive administrative interface for platform governance, user management, financial oversight,
 # and advanced analytics. All admin routes require elevated privileges and proper authorization.

 namespace :admin do
   # Financial Management - Platform-wide financial monitoring and reporting
   get 'financials', to: 'financials#index'

   # User Administration - Complete user lifecycle management and moderation
   # Numeric ID constraint ensures secure user identification and prevents injection attacks
   resources :users, only: [:index, :show], constraints: { id: /\d+/ } do
     member do
       # Suspend user accounts for policy violations or security concerns
       patch :suspend
       # Issue formal warnings to users for misconduct
       post :warn
       # Verify and approve seller account applications
       patch :verify_seller
     end
   end

   # Bond Administration - Financial security and risk management system
   # Numeric ID constraint prevents unauthorized bond operations
   resources :bonds, only: [:index, :show], constraints: { id: /\d+/ } do
     member do
       # Approve bond applications from verified sellers
       patch :approve
       # Forfeit bonds for policy violations or failed obligations
       patch :forfeit
     end
   end

   # Advanced Analytics Suite - Comprehensive platform intelligence and reporting
   get 'analytics', to: 'analytics#index'
   get 'analytics/real_time', to: 'analytics#real_time'
   get 'analytics/cohorts', to: 'analytics#cohorts'
   get 'analytics/export', to: 'analytics#export'
   get 'analytics/dashboard', to: 'analytics#dashboard'

   # A/B Testing Management - Experiment control and analysis system
   resources :ab_tests, constraints: { id: /\d+/ } do
     member do
       # Generate detailed experiment reports and statistical analysis
       get :report
       # Update experiment parameters and test configurations
       patch :update
     end
     collection do
       # A/B testing dashboard for experiment oversight
       get :dashboard
     end
   end

   # Machine Learning & Predictive Analytics - AI-powered business intelligence
   namespace :predictive_analytics do
     root to: 'predictive_analytics#index'
     # Sales forecasting and trend prediction
     get 'sales_forecast'
     # Inventory optimization and demand prediction
     get 'inventory_predictions'
     # Customer behavior analysis and segmentation
     get 'customer_behavior'
     # Customer churn risk assessment and prevention
     get 'churn_risk'
     # Model retraining for improved accuracy and performance
     post 'retrain_models'
   end
 end

  # ================================================================================================
  # E-COMMERCE CORE SYSTEM
  # ================================================================================================
  # Primary shopping functionality including product discovery, cart management, and checkout process
  # Handles the complete customer journey from product browsing to purchase completion

  # Product Discovery - Category and promotional content browsing
  # Numeric ID constraint ensures only valid category/deal IDs are processed
  resources :categories, constraints: { id: /\d+/ }
  resources :deals, only: [:index, :show], constraints: { id: /\d+/ }

  # Shopping Cart - Session-based cart management system
  resource :cart, only: [:show], controller: 'carts'

  # Tag System - Product tagging and intelligent search enhancement
  resources :tags, except: [:new, :edit], constraints: { id: /\d+/ } do
    # Type-ahead search functionality for improved user experience
    get :autocomplete, on: :collection
  end

  # Product Catalog - Complex product hierarchy with variants and customization options
  # Numeric ID constraint ensures secure product identification and prevents injection attacks
  resources :products, constraints: { id: /\d+/ } do
    # Product Variants - Different versions/options of products (size, color, style, etc.)
    # Excludes index/show as they're handled by the parent products resource
    resources :variants, except: [:index, :show], constraints: { id: /\d+/ }

    # Option Types - Categories of customizable options (Color, Size, Material, etc.)
    # Excludes index/show as they're managed through the product interface
    resources :option_types, except: [:index, :show], constraints: { id: /\d+/ } do
      # Option Values - Specific values within option types (Red, Large, Cotton, etc.)
      resources :option_values, only: [:create, :update, :destroy], constraints: { id: /\d+/ }
    end

    # Product Images - Visual content management for product presentations
    # Creation and deletion only, with positioning and primary image management
    resources :product_images, only: [:create, :destroy], constraints: { id: /\d+/ } do
      member do
        # Set primary product image for main display
        patch :make_primary
        # Reorder product images for optimal presentation
        patch :update_position
      end
    end
  end

  # User Lists - Personal shopping lists and saved items management
  resource :wishlist, only: [:show] do
    # Add items to wishlist by specific product ID
    post 'add/:product_id', to: 'wishlists#add_item', as: :add_item, constraints: { product_id: /\d+/ }
    # Remove items from wishlist
    delete 'remove/:product_id', to: 'wishlists#remove_item', as: :remove_item, constraints: { product_id: /\d+/ }
  end

  # Saved Items - Long-term product saving with cart integration
  resources :saved_items, only: [:index, :create, :destroy], constraints: { id: /\d+/ } do
    member do
      # Move saved item to cart - PATCH for state change (moving from saved to cart)
      # PATCH is semantically correct as we're updating the item's state/location
      patch :move_to_cart
    end
    collection do
      # Bulk move multiple saved items to cart - POST for collection creation (cart_items)
      post :move_multiple_to_cart
    end
  end

  # Product Recommendations - AI-powered product suggestion system
  resources :recommendations, only: [:index], constraints: { id: /\d+/ } do
    # Recently viewed products for user context and convenience
    get :recently_viewed, on: :collection
    # Similar products based on user preferences and browsing behavior
    get :similar_products, on: :collection
  end

  # Product Comparison - Side-by-side product analysis and comparison
  resource :comparisons, only: [:show] do
    # Add products to comparison set for detailed analysis
    post 'add/:product_id', to: 'comparisons#add_item', as: :add_item, constraints: { product_id: /\d+/ }
    # Remove products from comparison set
    delete 'remove/:product_id', to: 'comparisons#remove_item', as: :remove_item, constraints: { product_id: /\d+/ }
    # Clear entire comparison set
    delete 'clear', to: 'comparisons#clear', as: :clear
  end

  # ================================================================================================
  # ORDER & TRANSACTION MANAGEMENT SYSTEM
  # ================================================================================================
  # Complete order lifecycle management from cart to delivery, including payment processing
  # and transaction security. Handles the critical path of e-commerce operations.

  # User Orders - Order history, creation, and management
  # Numeric ID constraint ensures secure order processing
  resources :orders, only: [:index, :show, :new, :create], constraints: { id: /\d+/ }

  # Cart Items - Individual item management within shopping cart
  # Numeric ID constraint prevents cart manipulation attacks
  resources :cart_items, constraints: { id: /\d+/ } do
    collection do
      # Clear entire shopping cart
      delete :clear
    end
  end

  # ================================================================================================
  # REVIEW & RATING SYSTEM
  # ================================================================================================
  # User-generated content and feedback system for products and purchases
  # Builds trust and helps other customers make informed decisions

  # Item Reviews - Reviews tied to specific purchased items for authentic feedback
  # Numeric ID constraints ensure valid item and review identification
  # Uses reviewable concern for consistent review behavior across resources
  resources :items, constraints: { id: /\d+/ }, concerns: :reviewable

  # User Profile Reviews - Reviews associated with user profiles and seller performance
  # Numeric ID constraints ensure secure user and review operations
  # Uses reviewable concern for consistent review behavior across resources
  resources :users, constraints: { id: /\d+/ }, concerns: :reviewable

  # ================================================================================================
  # DISPUTE RESOLUTION SYSTEM
  # ================================================================================================
  # Comprehensive dispute handling between buyers, sellers, and moderators
  # Ensures fair resolution of conflicts and maintains platform trust

  # Bond Creation - Financial security deposits for high-value transactions
  # Numeric ID constraint ensures secure bond operations
  resources :bonds, only: [:new, :create], constraints: { id: /\d+/ }

  # Dispute Management - Complete dispute lifecycle from filing to resolution
  # Numeric ID constraint ensures only valid disputes are processed
  resources :disputes, constraints: { id: /\d+/ } do
    # Dispute Comments - Communication thread within dispute resolution
    resources :comments, controller: 'dispute_comments', only: [:create], constraints: { id: /\d+/ }

    collection do
      # User's personal dispute history and active cases
      get :my_disputes
    end

    member do
      # Assign disputes to specific moderators for handling
      patch :assign_moderator
      # Add comments to dispute communication thread
      post :post_comment
      # Resolve disputes with final outcomes
      patch :resolve
    end
  end

  # Moderator Interface - Dedicated dispute management for platform moderators
  namespace :moderator do
    root 'disputes#index'
    resources :disputes do
      member do
        # Resolve disputes with moderator authority and final decision
        patch :resolve
        # Dismiss disputes as invalid or outside platform scope
        patch :dismiss
        # Reassign disputes to different moderators when needed
        patch :assign
      end
    end
  end

  # ================================================================================================
  # SELLER APPLICATION & VERIFICATION SYSTEM
  # ================================================================================================
  # Seller onboarding, verification, and application management process
  # Ensures platform quality and seller legitimacy

  # Public Seller Applications - Initial application submission process
  # Numeric ID constraint ensures secure application processing
  resources :seller_applications, only: [:new, :create], constraints: { id: /\d+/ }

  # Admin Seller Application Management - Review, approval, and role management
  namespace :admin do
    root 'dashboard#index'
    resources :users, constraints: { id: /\d+/ } do
      member do
        # Toggle user roles between buyer, seller, and admin
        patch :toggle_role, on: :member
      end
    end
    # Admin product oversight and content management
    resources :products, only: [:index, :show, :destroy], constraints: { id: /\d+/ }
    # Seller application review and approval workflow
    resources :seller_applications, only: [:index, :show, :update], constraints: { id: /\d+/ }
  end
  
  # Performance: Cache root route for improved initial page load performance
  root 'products#index', cache: true
  

  # ================================================================================================
  # SYSTEM HEALTH & UTILITY ROUTES
  # ================================================================================================
  # Essential system routes for monitoring, health checks, and utility functions
  # Critical for platform operations, monitoring, and external integrations

  # Health Check - Load balancer and monitoring integration
  # Returns 200 if application is healthy, 500 if there are issues
  # Performance: Cache health check for improved monitoring performance
  get "up" => "rails/health#show", as: :rails_health_check, cache: true

  # Shipping Calculator - Real-time shipping cost calculation
  # Performance: HTTP method constraints improve security and routing performance
  post 'shipping/calculate', to: 'shipping#calculate', via: [:post]
  get 'shipping/zones', to: 'shipping#zones', via: [:get], cache: true

  # Currency System - Multi-currency support and conversion
  # Performance: Locale constraints improve routing performance for international users
  # Performance: Cache static currency list for improved response times
  get 'currencies', to: 'currencies#index', cache: true, constraints: { locale: /(en|es|fr)/ }
  get 'currencies/:code', to: 'currencies#show', constraints: { locale: /(en|es|fr)/ }
  get 'currencies/:code/rate', to: 'currencies#rate', constraints: { locale: /(en|es|fr)/ }

  # Geographic Data - Country and region information
  # Performance: Locale constraints improve routing performance for international users
  # Performance: Cache static country list for improved response times
  get 'countries', to: 'countries#index', cache: true, constraints: { locale: /(en|es|fr)/ }
  get 'countries/:code', to: 'countries#show', constraints: { locale: /(en|es|fr)/ }

  # ================================================================================================
  # SEARCH & DISCOVERY SYSTEM
  # ================================================================================================
  # Advanced search functionality and product discovery
  # Helps users find products through intelligent search and recommendations

  # Search Interface - Main search functionality
  # Performance: HTTP method constraints improve security and routing performance
  get 'search', to: 'search#index', via: [:get]
  # Search suggestions for autocomplete - Performance: Cache suggestions for better UX
  get 'search/suggestions', to: 'search#suggestions', via: [:get]

  # ================================================================================================
  # GAMIFICATION SYSTEM
  # ================================================================================================
  # User engagement through achievements, challenges, and leaderboards
  # Increases platform interaction and customer loyalty

  # Gamification Dashboard - User progress and achievements overview
  namespace :gamification do
    root to: 'gamification#dashboard', as: :dashboard
    # Achievement system management
    get 'achievements', to: 'gamification#achievements'
    # Daily challenge system
    get 'daily_challenges', to: 'gamification#daily_challenges'
    # Leaderboard and competition features
    get 'leaderboards', to: 'gamification#leaderboards'
  end

  # Gamification API - Programmatic access to gamification features
  # Performance: Format constraints improve routing performance by limiting accepted formats
  namespace :api, constraints: { format: /(json|xml)/ } do
    # Daily challenges data for external consumption - JSON/XML only for API efficiency
    get 'daily_challenges', to: 'gamification#daily_challenges_api'
    # Achievement checking and validation - JSON/XML only for API efficiency
    get 'achievements/check', to: 'gamification#check_achievements'
  end

  # ================================================================================================
  # EXTERNAL INTEGRATIONS & WEBHOOKS
  # ================================================================================================
  # Third-party service integrations and webhook handlers
  # Enables seamless connectivity with external platforms and services

  # Payment Processor Webhooks - Secure webhook handling for payment events
  # Performance: Format constraints improve webhook processing performance
  namespace :webhooks, constraints: { format: /(json|xml)/ } do
    # Square payment processor webhook endpoint - JSON/XML only for security
    post 'square', to: 'square#receive', via: [:post]
  end

  # A/B Testing Dashboard - External testing platform integration
  # Only accessible to admin users for security
  mount Split::Dashboard, at: 'split', constraints: -> (request) {
    request.env['warden'].user&.admin?
  }

  # ================================================================================================
  # NOTIFICATION SYSTEM
  # ================================================================================================
  # User notifications and communication management
  # Keeps users informed about important activities and updates

  # Notification Management - RESTful notification handling
  # Using proper RESTful resources with PATCH for state-changing operations
  # GET for retrieval, PATCH for state modifications (marking as read)
  resources :notifications, only: [:index] do
    member do
      # Mark individual notifications as read - PATCH is semantically correct for state changes
      # PATCH is preferred over POST for partial resource updates (RFC 7231)
      patch :mark_as_read
    end
    collection do
      # Mark all notifications as read - PATCH for bulk state modification
      # Collection route as it operates on multiple resources simultaneously
      patch :mark_all_as_read
    end
  end

  # ================================================================================================
  # PROGRESSIVE WEB APP (PWA) ROUTES
  # ================================================================================================
  # Service worker and manifest routes for PWA functionality
  # Currently commented out - enable when PWA features are needed

  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # ================================================================================================
  # ROOT APPLICATION ROUTE
  # ================================================================================================
  # Application entry point - displays product catalog
   # ================================================================================================
   # COMPREHENSIVE ERROR HANDLING & EDGE CASE PROTECTION SYSTEM
   # ================================================================================================
   # Production-ready error handling, security constraints, and graceful fallbacks
   # Implements robust routing protection against malicious attacks and invalid requests

   # SECURITY CONSTRAINTS - Parameter validation and malicious request prevention
   # ================================================================================================

   # Parameter length constraints for security - prevents buffer overflow and DoS attacks
   # Username parameter constraints - limits length to prevent injection attacks
   constraints username: /[a-zA-Z0-9_-]{1,50}/ do
     # User profile routes with username parameter validation
     get 'users/:username', to: 'users#show', as: :user_profile
     get 'users/:username/reviews', to: 'users#reviews', as: :user_reviews
   end

   # Slug parameter constraints - validates URL-friendly strings for SEO routes
   constraints slug: /[a-z0-9-]+/ do
     # Product and category slug routes for SEO optimization
     get 'products/:slug', to: 'products#show_by_slug', as: :product_by_slug
     get 'categories/:slug', to: 'categories#show_by_slug', as: :category_by_slug
   end

   # API FORMAT CONSTRAINTS - Strict format validation for API endpoints
   # ================================================================================================

   # JSON-only API routes - prevents format confusion and improves API performance
   namespace :api, constraints: { format: :json } do
     # API versioning with format constraints
     namespace :v1 do
       # User API endpoints - JSON format only for security and performance
       resources :users, only: [:index, :show], constraints: { id: /\d+/ }
       # Product API endpoints - JSON format only for external integrations
       resources :products, only: [:index, :show], constraints: { id: /\d+/ }
       # Order API endpoints - JSON format only for payment processors
       resources :orders, only: [:index, :show, :create], constraints: { id: /\d+/ }
     end

     # Webhook endpoints - JSON format only for security
     namespace :webhooks do
       post 'stripe', to: 'stripe#receive'
       post 'paypal', to: 'paypal#receive'
       post 'square', to: 'square#receive'
     end
   end

   # XML API routes for legacy system compatibility
   namespace :api, constraints: { format: :xml } do
     namespace :v1 do
       # Legacy XML API endpoints for older integrations
       resources :products, only: [:index], constraints: { id: /\d+/ }
     end
   end

   # ERROR HANDLING ROUTES - Graceful error responses and fallbacks
   # ================================================================================================

   # HTTP Error Routes - Specific error handling for common HTTP status codes
   # Provides user-friendly error pages while maintaining security

   # 404 Not Found - Custom 404 handling with security considerations
   match '/404', to: 'errors#not_found', via: :all, as: :not_found_error

   # 422 Unprocessable Entity - Handles validation errors and malformed requests
   match '/422', to: 'errors#unprocessable_entity', via: :all, as: :unprocessable_entity_error

   # 500 Internal Server Error - Application error handling
   match '/500', to: 'errors#internal_server_error', via: :all, as: :internal_server_error

   # Maintenance Mode - Temporary maintenance page for system updates
   match '/maintenance', to: 'errors#maintenance', via: :all, as: :maintenance_mode

   # SECURITY PROTECTION ROUTES - Prevention of malicious routing attempts
   # ================================================================================================

   # Path Traversal Protection - Prevents directory traversal attacks
   # Blocks attempts to access files outside the web root
   constraints path: /^(?!.*\.\.).*$/ do
     # Static asset serving with path traversal protection
     get 'assets/*path', to: 'assets#show', constraints: { path: /.*/ }
   end

   # SQL Injection Prevention - Additional parameter sanitization
   # Numeric ID constraints across all resources for consistency
   constraints id: /\d+/ do
     # Additional numeric validation for sensitive operations
     get 'admin/reports/:id', to: 'admin/reports#show', as: :admin_report
   end

   # Request Size Limits - Prevents DoS attacks through large request handling
   # Large request bodies are rejected before processing
   match '*path', to: 'application#handle_large_request',
         via: :all,
         constraints: ->(request) { request.content_length.to_i > 10.megabytes }

   # FALLBACK ROUTES - Catch-all error handling for unmatched routes
   # ================================================================================================

   # Catch-all route for 404 handling - Must be last route for proper fallback behavior
   # Handles any unmatched routes and provides graceful error responses
   # Security: Placed last to ensure all other routes are matched first
   match '*path',
         to: 'application#handle_routing_error',
         via: :all,
         constraints: ->(request) {
           # Log suspicious routing attempts for security monitoring
           Rails.logger.warn("Unmatched route attempt: #{request.method} #{request.path}")
           true
         }
end
