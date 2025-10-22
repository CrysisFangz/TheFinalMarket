# frozen_string_literal: true

# Enhanced Category model with enterprise-grade domain-driven architecture
class Category < ApplicationRecord
  # Include domain value objects and entities
  include Categories::ValueObjects
  include Categories::Entities

  # Associations for hierarchical structure (maintained for backward compatibility)
  belongs_to :parent, class_name: 'Category', optional: true
  has_many :subcategories, class_name: 'Category', foreign_key: 'parent_id', dependent: :destroy

  # Item associations (maintained for backward compatibility)
  has_many :items, dependent: :restrict_with_error
  has_many :all_items, through: :descendants, source: :items

  # Enhanced validations with materialized path support
  validates :name, presence: true, uniqueness: { scope: :parent_id, case_sensitive: false }
  validates :name, length: { minimum: 2, maximum: 50 }
  validates :description, length: { maximum: 500 }
  validates :materialized_path, presence: true, format: { with: %r{\A/[a-zA-Z0-9\s\-']+(/\z|\z)} }
  validate :prevent_circular_dependency
  validate :validate_materialized_path_consistency

  # Enhanced scopes with materialized path optimization
  scope :main_categories, -> { where(parent_id: nil) }
  scope :active, -> { where(active: true) }
  scope :with_items, -> { joins(:items).distinct }
  scope :by_path_prefix, ->(prefix) { where('materialized_path LIKE ?', "#{sanitize_sql_like(prefix)}%") }
  scope :children_of, ->(parent_path) { where('materialized_path LIKE ? AND materialized_path != ?',
                                             "#{sanitize_sql_like(parent_path)}%",
                                             parent_path) }
  scope :ancestors_of, ->(category_path) {
    where('materialized_path <@ ?', category_path).where.not(materialized_path: category_path)
  }

  # Enhanced callbacks
  before_save :normalize_name
  before_save :update_materialized_path
  after_save :invalidate_path_cache
  after_destroy :invalidate_path_cache

  # ===== DOMAIN INTEGRATION METHODS =====

  # Creates a domain entity from the ActiveRecord model
  # @return [Categories::Entities::Category] domain entity
  def to_domain_entity
    @domain_entity ||= create_domain_entity
  end

  # Gets the domain repository instance
  # @return [Categories::Repositories::CategoryRepository] repository instance
  def self.domain_repository
    @domain_repository ||= Categories::Repositories::ActiveRecordCategoryRepository.new
  end

  # Gets the domain query service instance
  # @return [Categories::Services::Queries::CategoryQueries] query service instance
  def self.domain_queries
    @domain_queries ||= Categories::Services::Queries::CategoryQueries.new(domain_repository)
  end

  # Gets the domain command service instance
  # @return [Categories::Services::Commands::CreateCategoryCommand] command service instance
  def self.create_command
    @create_command ||= Categories::Services::Commands::CreateCategoryCommand.new(domain_repository)
  end

  # Gets the domain service instance
  # @return [Categories::Services::CategoryDomainService] domain service instance
  def self.domain_service
    @domain_service ||= Categories::Services::CategoryDomainService.new(domain_repository)
  end

  # ===== ENHANCED TREE OPERATIONS =====

  # Optimized ancestors using materialized path
  # @return [Array<Category>] array of ancestor categories
  def ancestors
    return [] if root?

    path_segments = materialized_path.split('/').reject(&:empty?)
    return [] if path_segments.empty?

    # Get ancestors using optimized path queries
    ancestor_paths = []
    current_path = '/'

    path_segments[0..-2].each do |segment|
      current_path += segment + '/'
      ancestor_paths << current_path
    end

    self.class.where(materialized_path: ancestor_paths).order(:materialized_path)
  end

  # Optimized descendants using materialized path
  # @return [Array<Category>] array of descendant categories
  def descendants
    self.class.children_of(materialized_path).order(:materialized_path)
  end

  # Enhanced full name with path support
  # @return [String] full category name with hierarchy
  def full_name
    path_segments = materialized_path.split('/').reject(&:empty!)
    return name if path_segments.empty?

    path_segments.join(' > ')
  end

  # Enhanced root check
  # @return [Boolean] true if category is root
  def root?
    parent_id.nil? || materialized_path == "/#{name}/"
  end

  # Enhanced leaf check
  # @return [Boolean] true if category has no children
  def leaf?
    descendants.empty?
  end

  # Optimized siblings query
  # @return [Array<Category>] array of sibling categories
  def siblings
    if parent_id
      parent.subcategories.where.not(id: id)
    else
      self.class.main_categories.where.not(id: id)
    end
  end

  # Enhanced tree method with domain integration
  # @return [Array<Hash>] tree structure with domain entities
  def self.tree
    domain_queries.get_tree.map do |node|
      {
        category: node[:category],
        children: node[:children],
        has_children: node[:has_children],
        item_count: node[:item_count]
      }
    end
  end

  # ===== PERFORMANCE OPTIMIZATIONS =====

  # Gets category with cached domain entity
  # @param force_reload [Boolean] force reload from database
  # @return [Categories::Entities::Category] domain entity
  def cached_domain_entity(force_reload: false)
    @domain_entity = nil if force_reload
    to_domain_entity
  end

  # Batch loads domain entities for multiple categories
  # @param category_ids [Array<Integer>] category IDs to load
  # @return [Hash<Integer, Categories::Entities::Category>] hash of ID to domain entity
  def self.batch_to_domain_entities(category_ids)
    categories = where(id: category_ids)
    categories.each_with_object({}) do |category, hash|
      hash[category.id] = category.to_domain_entity
    end
  end

  private

  # Creates domain entity from ActiveRecord model
  # @return [Categories::Entities::Category] domain entity
  def create_domain_entity
    path = Categories::ValueObjects::CategoryPath.new(materialized_path)
    name = Categories::ValueObjects::CategoryName.new(self.name)
    status = Categories::ValueObjects::CategoryStatus.new(active? ? :active : :inactive)

    Categories::Entities::Category.new(
      name: name,
      description: description,
      path: path,
      status: status,
      id: id
    )
  end

  # Normalizes category name using value object
  # @return [void]
  def normalize_name
    normalized = Categories::ValueObjects::CategoryName.new(name)
    self.name = normalized.to_s
  rescue ArgumentError => e
    errors.add(:name, e.message)
  end

  # Updates materialized path based on parent relationship
  # @return [void]
  def update_materialized_path
    if parent_id.nil?
      self.materialized_path = "/#{name}/"
    else
      parent_category = Category.find_by(id: parent_id)
      if parent_category&.materialized_path
        self.materialized_path = parent_category.materialized_path + name + '/'
      else
        self.materialized_path = "/#{name}/"
      end
    end
  end

  # Validates materialized path consistency
  # @return [void]
  def validate_materialized_path_consistency
    return unless materialized_path_changed? || name_changed? || parent_id_changed?

    expected_path = calculate_expected_path
    if materialized_path != expected_path
      errors.add(:materialized_path, 'is inconsistent with name or parent relationship')
    end
  end

  # Calculates expected materialized path
  # @return [String] expected path
  def calculate_expected_path
    if parent_id.nil?
      "/#{name}/"
    else
      parent = Category.find_by(id: parent_id)
      parent&.materialized_path ? parent.materialized_path + name + '/' : "/#{name}/"
    end
  end

  # Enhanced circular dependency prevention with materialized path
  # @return [void]
  def prevent_circular_dependency
    return unless parent_id_changed?

    # Use domain service for validation if available
    if self.class.respond_to?(:domain_service)
      begin
        domain_entity = to_domain_entity
        parent_path = parent.materialized_path
        if domain_service.would_create_circular_reference?(id, parent_path)
          errors.add(:parent_id, 'would create a circular dependency')
        end
      rescue => e
        # Fallback to original validation if domain service fails
        if descendants.include?(self)
          errors.add(:parent_id, 'would create a circular dependency')
        end
      end
    else
      # Original validation as fallback
      if parent_id_changed? && descendants.include?(self)
        errors.add(:parent_id, 'would create a circular dependency')
      end
    end
  end

  # Invalidates cached paths when category is modified
  # @return [void]
  def invalidate_path_cache
    # Clear Rails cache for category paths
    Rails.cache.delete_matched('category:*') if defined?(Rails.cache)

    # Clear domain entity cache
    @domain_entity = nil
  end

  # Gets domain service instance
  # @return [Categories::Services::CategoryDomainService] domain service
  def domain_service
    self.class.domain_service
  end

  # Custom validation error class
  class ValidationError < StandardError; end
end
