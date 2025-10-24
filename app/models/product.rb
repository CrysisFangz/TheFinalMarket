class Product < ApplicationRecord
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  include CircuitBreaker

  # Associations
  belongs_to :user
  has_many :product_categories, dependent: :destroy
  has_many :categories, through: :product_categories
  has_many :product_tags, dependent: :destroy
  has_many :tags, through: :product_tags
  has_many :product_images, -> { order(position: :asc) }, dependent: :destroy
  has_many :line_items, dependent: :destroy
  has_many :reviews, dependent: :destroy
  has_many :reviewers, through: :reviews, source: :user

  has_many :product_recommendations, dependent: :destroy
  has_many :dynamic_pricing_events, dependent: :destroy
  has_many :product_performance_metrics, dependent: :destroy
  has_many :user_interaction_events, dependent: :destroy
  has_many :product_optimization_insights, dependent: :destroy

  has_many :global_inventory_records, dependent: :destroy
  has_many :regional_pricing_rules, dependent: :destroy
  has_many :international_shipping_rules, dependent: :destroy
  has_many :cross_border_compliance_records, dependent: :destroy

  has_many :blockchain_verification_records, dependent: :destroy
  has_many :supply_chain_events, dependent: :destroy
  has_many :authenticity_certificates, dependent: :destroy
  has_many :ownership_transfer_records, dependent: :destroy

  has_many :pricing_rules, dependent: :destroy
  has_many :price_changes, dependent: :destroy
  has_many :price_experiments, dependent: :destroy
  has_many :market_price_intelligence, dependent: :destroy

  has_many :content_translations, as: :translatable, dependent: :destroy
  belongs_to :origin_country, optional: true, class_name: 'Country', foreign_key: :origin_country_code, primary_key: :code

  has_many :option_types, dependent: :destroy
  has_many :option_values, through: :option_types
  has_many :variants, dependent: :destroy

  has_many :product_views, dependent: :destroy
  has_many :product_comparisons, dependent: :destroy
  has_many :product_wishlists, dependent: :destroy
  has_many :conversion_funnel_events, dependent: :destroy

  has_many :product_compliance_records, dependent: :destroy
  has_many :regulatory_reporting_events, dependent: :destroy
  has_many :product_audit_trails, dependent: :destroy
  has_many :data_retention_records, dependent: :destroy

  # Elasticsearch configuration
  settings index: {
    number_of_shards: 5,
    number_of_replicas: 2,
    refresh_interval: '30s',
    analysis: {
      analyzer: {
        custom_analyzer: {
          type: 'custom',
          tokenizer: 'standard',
          filter: ['lowercase', 'custom_stemmer', 'custom_synonym', 'edge_ngram']
        }
      },
      filter: {
        custom_stemmer: {
          type: 'stemmer',
          language: 'english'
        },
        custom_synonym: {
          type: 'synonym',
          synonyms: [
            'laptop, notebook, computer',
            'phone, smartphone, mobile, cellphone',
            'tv, television, display, screen',
            'headphone, headset, earphone',
            'tablet, ipad, slate'
          ]
        },
        edge_ngram: {
          type: 'edge_ngram',
          min_gram: 2,
          max_gram: 20
        }
      }
    }
  }

  mapping dynamic: 'false' do
    indexes :name, type: 'text', analyzer: 'custom_analyzer' do
      indexes :keyword, type: 'keyword'
      indexes :suggest, type: 'completion'
    end
    indexes :description, type: 'text', analyzer: 'custom_analyzer'
    indexes :short_description, type: 'text', analyzer: 'custom_analyzer'
    indexes :price, type: 'double'
    indexes :sale_price, type: 'double'
    indexes :currency, type: 'keyword'
    indexes :category, type: 'keyword'
    indexes :brand, type: 'keyword'
    indexes :tags, type: 'keyword'
    indexes :specifications, type: 'nested'
    indexes :average_rating, type: 'float'
    indexes :total_reviews, type: 'integer'
    indexes :review_score, type: 'float'
    indexes :created_at, type: 'date'
    indexes :updated_at, type: 'date'
    indexes :status, type: 'keyword'
    indexes :availability, type: 'keyword'
    indexes :condition, type: 'keyword'
    indexes :variants do
      indexes :sku, type: 'keyword'
      indexes :price, type: 'double'
      indexes :sale_price, type: 'double'
      indexes :stock_quantity, type: 'integer'
      indexes :specifications, type: 'nested'
    end
    indexes :global_inventory do
      indexes :region, type: 'keyword'
      indexes :available_quantity, type: 'integer'
      indexes :reserved_quantity, type: 'integer'
    end
    indexes :ai_insights do
      indexes :demand_score, type: 'float'
      indexes :optimization_potential, type: 'float'
      indexes :personalization_score, type: 'float'
    end
  end

  # Nested attributes
  accepts_nested_attributes_for :product_images, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :option_types, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :variants, allow_destroy: true, reject_if: :all_blank

  # Validations
  validates :name, presence: true, length: { maximum: 200 },
                   format: { with: /\A[a-zA-Z0-9\s\-'&.]+\z/, message: "only allows letters, numbers, spaces, hyphens, apostrophes, periods, and ampersands" }
  validates :description, presence: true, length: { maximum: 5000 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0.01, less_than_or_equal_to: 999999.99 }
  validates :sku, uniqueness: true, allow_blank: true, format: { with: /\A[A-Z0-9\-_]+\z/, message: "only allows uppercase letters, numbers, hyphens, and underscores" }

  validates :weight, numericality: { greater_than: 0, less_than: 10000 }, allow_nil: true
  validates :dimensions, format: { with: /\A\d+(\.\d+)?x\d+(\.\d+)?x\d+(\.\d+)?\z/, message: "must be in format LxWxH" }, allow_blank: true

  validates :origin_country_code, inclusion: { in: ISO3166::Country.codes }, allow_blank: true
  validates :warranty_period, numericality: { greater_than: 0, less_than_or_equal_to: 120 }, allow_nil: true

  # Attributes
  attribute :status, :string, default: 'draft'
  attribute :availability, :string, default: 'available'
  attribute :condition, :string, default: 'new'
  attribute :visibility, :string, default: 'public'

  attribute :specifications, :json, default: {}
  attribute :ai_insights, :json, default: {}
  attribute :global_distribution_data, :json, default: {}
  attribute :blockchain_metadata, :json, default: {}
  attribute :enterprise_metadata, :json, default: {}

  # Enhanced scopes for performance and optimization
  scope :active, -> { where(status: 'active') }
  scope :available, -> { where(availability: 'available') }
  scope :with_categories, -> { includes(:categories) }
  scope :with_tags, -> { includes(:tags) }
  scope :with_variants, -> { includes(:variants) }
  scope :with_all_associations, -> { includes(:categories, :tags, :variants, :product_images, :user) }
  scope :searchable, -> { where(status: 'active', availability: 'available') }
  scope :recent, -> { order(created_at: :desc) }

  # Simple instance methods with enhanced service integration
  def tag_list
    ProductTagService.get_tag_list(self)
  end

  def tag_list=(names)
    ProductTagService.update_tags(self, names)
  end

  def default_variant
    variants.first
  end

  def available_variants
    variants.where(available: true)
  end

  def has_variants?
    variants.count > 1
  end

  def min_price
    ProductPricingService.new(self).min_price
  end

  def max_price
    ProductPricingService.new(self).max_price
  end

  def total_stock
    Rails.cache.fetch("product:#{id}:total_stock", expires_in: 15.minutes) do
      InventoryService.new.total_stock(self)
    end
  end

  # Enhanced performance methods with better caching
  def cached_category_names
    Rails.cache.fetch("product:#{id}:category_names", expires_in: 2.hours) do
      categories.pluck(:name)
    end
  end

  def cached_variant_count
    Rails.cache.fetch("product:#{id}:variant_count", expires_in: 1.hour) do
      variants.count
    end
  end

  def cached_average_rating
    Rails.cache.fetch("product:#{id}:average_rating", expires_in: 30.minutes) do
      reviews.average(:rating).to_f.round(2)
    end
  end

  # Performance optimized search with enhanced caching
  def self.cached_search(query: nil, filters: {}, page: 1, per_page: 20)
    cache_key = "product_search:#{Digest::MD5.hexdigest([query, filters, page, per_page].to_s)}"

    Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
      search(query: query, filters: filters, page: page, per_page: per_page)
    end
  end

  # Elasticsearch indexing
  def as_indexed_json(options = {})
    {
      id: id,
      name: name,
      description: description,
      short_description: short_description,
      price: price,
      sale_price: sale_price,
      currency: currency,
      category: categories.pluck(:name),
      brand: brand,
      tags: tags.pluck(:name),
      specifications: specifications,
      average_rating: average_rating,
      total_reviews: total_reviews,
      review_score: review_score,
      created_at: created_at,
      updated_at: updated_at,
      status: status,
      availability: availability,
      condition: condition,
      variants: variants.map { |v| { sku: v.sku, price: v.price, sale_price: v.sale_price, stock_quantity: v.stock_quantity, specifications: v.specifications } },
      global_inventory: global_inventory_records.map { |gi| { region: gi.region, available_quantity: gi.available_quantity, reserved_quantity: gi.reserved_quantity } },
      ai_insights: ai_insights
    }
  end

  # Search method with caching
  def self.search(query: nil, filters: {}, page: 1, per_page: 20)
    ProductSearchService.search(query: query, filters: filters, page: page, per_page: per_page)
  end

  private

  # Callbacks with event publishing
  after_create :update_search_index, :publish_created_event
  after_update :update_search_index, :publish_updated_event
  after_destroy :publish_destroyed_event

  def update_search_index
    IndexProductJob.perform_later(id)
  end

  def publish_created_event
    EventPublisher.publish('product.created', { product_id: id, name: name })
  end

  def publish_updated_event
    EventPublisher.publish('product.updated', { product_id: id, name: name })
  end

  def publish_destroyed_event
    EventPublisher.publish('product.destroyed', { product_id: id, name: name })
  end

  private

  def with_retry(max_retries: 3, &block)
    retries = 0
    begin
      yield
    rescue StandardError => e
      retries += 1
      retry if retries < max_retries
      Rails.logger.error("Failed after #{retries} retries: #{e.message}")
      raise e
    end
  end
end
