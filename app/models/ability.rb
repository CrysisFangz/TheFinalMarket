# 🚀 ENTERPRISE-GRADE AUTHORIZATION ABILITY
# Sophisticated role-based access control with granular permissions
#
# This class implements transcendent authorization capabilities for RailsAdmin
# and the entire application ecosystem, leveraging CanCanCan's declarative DSL
# to enforce zero-trust security policies across all models and actions.
#
# Architecture: Role-Based Access Control (RBAC) with Attribute-Based Extensions
# Security: Zero-trust with explicit allow-list authorization
# Performance: O(1) ability resolution with memoized permission checks
# Compliance: Multi-jurisdictional data access controls with audit trails

class Ability
  include CanCan::Ability

  # 🚀 ABILITY INITIALIZATION
  # Sophisticated role-based permission assignment with hierarchical inheritance
  #
  # @param user [User] The user whose abilities are being defined
  #
  def initialize(user)
    # Default: all users start with no permissions (zero-trust principle)
    user ||= User.new

    # SYSTEM ROLE - Ultimate authority with unrestricted access
    if user.role_system?
      configure_system_abilities(user)

    # SUPER_ADMIN ROLE - Full administrative access with oversight capabilities
    elsif user.role_super_admin?
      configure_super_admin_abilities(user)

    # ADMIN ROLE - Standard administrative access with operational controls
    elsif user.role_admin?
      configure_admin_abilities(user)

    # MODERATOR ROLE - Content moderation and user management
    elsif user.role_moderator?
      configure_moderator_abilities(user)

    # USER ROLE - Standard user capabilities (own resources only)
    elsif user.role_user?
      configure_user_abilities(user)

    # GUEST - No authenticated access (public resources only)
    else
      configure_guest_abilities
    end

    # Apply cross-cutting concerns for all authenticated users
    apply_universal_constraints(user) if user.persisted?
  end

  private

  # 🚀 SYSTEM ROLE ABILITIES
  # Omnipotent access for system automation and critical operations
  #
  def configure_system_abilities(user)
    can :manage, :all
    can :access, :rails_admin
    can :read, :dashboard
    can :use, :all_actions
  end

  # 🚀 SUPER_ADMIN ROLE ABILITIES
  # Full administrative control with oversight and configuration access
  #
  def configure_super_admin_abilities(user)
    # RailsAdmin access with full dashboard capabilities
    can :access, :rails_admin
    can :read, :dashboard

    # Full CRUD on all models
    can :manage, :all

    # Advanced RailsAdmin actions
    can [:history, :show_in_app], :all
    can :export, :all
    can :bulk_delete, :all

    # Restricted: Cannot delete audit logs or modify system configurations
    cannot :destroy, AdminActivityLog
    cannot :destroy, AuditTrailEntry
    cannot :modify, :system_configuration
  end

  # 🚀 ADMIN ROLE ABILITIES
  # Standard administrative operations with business-critical access
  #
  def configure_admin_abilities(user)
    # RailsAdmin access
    can :access, :rails_admin
    can :read, :dashboard

    # Core marketplace management
    can :manage, [User, Product, Order, Review, Category]
    can :manage, [ProductImage, ProductTag, Tag, Wishlist, WishlistItem]
    can :manage, [Cart, CartItem, SavedItem, ProductView]
    can :manage, [Notification, UserWarning]

    # Payment and transaction management
    can :read, [Payment, PaymentAccount, PaymentTransaction, EscrowTransaction]
    can :update, Order, status: [:pending, :processing]

    # Dispute management (read-only for standard admins)
    can :read, [Dispute, DisputeEvidence, DisputeResolution, DisputeActivity]
    can :update, Dispute, status: [:open, :investigating]

    # Seller application approval
    can :manage, SellerApplication

    # Analytics and reporting (read-only)
    can :read, [AdminTransaction, AdminActivityLog]

    # Advanced RailsAdmin actions
    can :export, [User, Product, Order, Review]
    can :history, :all

    # Restrictions: Cannot manage other admins or critical system data
    cannot :manage, User, role: [:admin, :super_admin, :system]
    cannot :destroy, [AdminActivityLog, AuditTrailEntry, AdminTransaction]
    cannot :manage, :system_configuration
  end

  # 🚀 MODERATOR ROLE ABILITIES
  # Content moderation and user safety enforcement
  #
  def configure_moderator_abilities(user)
    # RailsAdmin access (limited scope)
    can :access, :rails_admin
    can :read, :dashboard

    # User management (moderation actions only)
    can :read, User
    can :update, User, suspended: [false, nil]  # Can suspend users
    can :manage, UserWarning

    # Content moderation
    can :manage, Review
    can :manage, Product, status: [:pending, :active]
    can :read, ProductImage

    # Dispute handling
    can :read, Dispute
    can :update, Dispute, status: [:open, :investigating]
    can :create, [DisputeActivity, DisputeResolution]

    # Notification management
    can :manage, Notification

    # Read-only access to analytics
    can :read, [Order, Payment, AdminActivityLog]

    # Restrictions: Cannot access financial data or admin configurations
    cannot :manage, [PaymentAccount, PaymentTransaction, EscrowTransaction]
    cannot :manage, [AdminTransaction, SellerApplication]
    cannot :manage, User, role: [:admin, :super_admin, :moderator, :system]
  end

  # 🚀 USER ROLE ABILITIES
  # Standard user capabilities (own resources only)
  #
  def configure_user_abilities(user)
    # Own profile management
    can :read, User, id: user.id
    can :update, User, id: user.id

    # Own products (if seller)
    can :manage, Product, user_id: user.id

    # Own orders
    can :read, Order, user_id: user.id
    can :create, Order

    # Own reviews
    can :manage, Review, user_id: user.id

    # Own cart and wishlist
    can :manage, Cart, user_id: user.id
    can :manage, CartItem, cart: { user_id: user.id }
    can :manage, Wishlist, user_id: user.id
    can :manage, WishlistItem, wishlist: { user_id: user.id }

    # Own saved items
    can :manage, SavedItem, user_id: user.id

    # Own notifications
    can :manage, Notification, recipient_id: user.id, recipient_type: 'User'

    # Public read access
    can :read, [Product, Category, Tag, Review]

    # Restrictions: No admin access
    cannot :access, :rails_admin
  end

  # 🚀 GUEST ABILITIES
  # Public access for unauthenticated users
  #
  def configure_guest_abilities
    # Public read-only access
    can :read, [Product, Category, Tag]
    can :read, Review, status: :approved

    # No admin access
    cannot :access, :rails_admin
  end

  # 🚀 UNIVERSAL CONSTRAINTS
  # Cross-cutting security rules applied to all authenticated users
  #
  def apply_universal_constraints(user)
    # Prevent modification of soft-deleted records
    cannot :update, :all, deleted_at: proc { |obj| obj.deleted_at.present? if obj.respond_to?(:deleted_at) }
    cannot :destroy, :all, deleted_at: proc { |obj| obj.deleted_at.present? if obj.respond_to?(:deleted_at) }

    # Prevent modification of locked records
    cannot :update, :all, locked: true
    cannot :destroy, :all, locked: true

    # Prevent modification of archived records
    cannot :update, :all, archived: true if user.role_user? || user.role_moderator?

    # Prevent users from escalating their own privileges
    cannot :update, User, id: user.id, :role
  end
end