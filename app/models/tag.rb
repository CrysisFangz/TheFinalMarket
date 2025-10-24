class Tag < ApplicationRecord
  has_many :product_tags, dependent: :destroy
  has_many :products, through: :product_tags

  validates :name, presence: true
  validate :name_uniqueness_case_insensitive

  before_validation :normalize_name
  after_save :publish_tag_event
  after_destroy :publish_tag_destroyed_event

  private

  def normalize_name
    self.name = TagNameNormalizer.normalize(name)
  end

  def name_uniqueness_case_insensitive
    normalized_name = TagNameNormalizer.normalize(name)
    return if TagNameNormalizer.unique?(normalized_name, exclude_tag: self)

    errors.add(:name, :taken, value: name)
  end

  def publish_tag_event
    # Publish event for tag creation or update to enable event-driven architecture
    event_name = new_record? ? 'tag.created' : 'tag.updated'
    ActiveSupport::Notifications.instrument(event_name, tag: self, changes: saved_changes)
  end

  def publish_tag_destroyed_event
    # Publish event for tag destruction
    ActiveSupport::Notifications.instrument('tag.destroyed', tag: self)
  end
end