class OptionType < ApplicationRecord
  include CircuitBreaker

  # Associations
  belongs_to :product
  has_many :option_values, dependent: :destroy

  # Validations
  validates :name, presence: true, length: { maximum: 100 },
                   format: { with: /\A[a-zA-Z0-9\s\-'&.]+\z/, message: "only allows letters, numbers, spaces, hyphens, apostrophes, periods, and ampersands" }
  validates :name, uniqueness: { scope: :product_id }

  # Attributes (Note: position can be added via migration if needed)

  # Scopes for performance
  scope :ordered, -> { order(position: :asc, name: :asc) }
  scope :with_option_values, -> { includes(:option_values) }

  # Instance methods
  def option_values_count
    Rails.cache.fetch("option_type:#{id}:option_values_count", expires_in: 1.hour) do
      option_values.count
    end
  end

  def display_name
    name.titleize
  end

  private

  # Callbacks with event publishing
  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_destroyed_event

  def publish_created_event
    EventPublisher.publish('option_type.created', { option_type_id: id, product_id: product_id, name: name })
  end

  def publish_updated_event
    EventPublisher.publish('option_type.updated', { option_type_id: id, product_id: product_id, name: name })
  end

  def publish_destroyed_event
    EventPublisher.publish('option_type.destroyed', { option_type_id: id, product_id: product_id, name: name })
  end

  # Example: Size, Color, Material
end