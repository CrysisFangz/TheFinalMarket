class QuestObjective < ApplicationRecord
  belongs_to :shopping_quest
  belongs_to :product, optional: true
  belongs_to :category, optional: true
  
  validates :shopping_quest, presence: true
  validates :objective_type, presence: true
  validates :description, presence: true
  validates :target_value, numericality: { greater_than: 0 }
  
  enum objective_type: {
    purchase_product: 0,
    purchase_from_category: 1,
    spend_amount: 2,
    purchase_count: 3,
    review_product: 4,
    share_product: 5,
    refer_friend: 6,
    visit_store: 7,
    add_to_wishlist: 8,
    complete_profile: 9
  }
  
  # Check if objective is completed by user
  def completed_by?(user)
    current_progress(user) >= target_value
  end
  
  # Get current progress for user
  def current_progress(user)
    case objective_type.to_sym
    when :purchase_product
      user.orders.completed.joins(:line_items)
          .where(line_items: { product_id: product_id })
          .count
    when :purchase_from_category
      user.orders.completed.joins(line_items: :product)
          .where(products: { category_id: category_id })
          .count
    when :spend_amount
      user.orders.completed
          .where('created_at >= ?', shopping_quest.starts_at)
          .sum(:total_cents) / 100.0
    when :purchase_count
      user.orders.completed
          .where('created_at >= ?', shopping_quest.starts_at)
          .count
    when :review_product
      user.reviews.where(product_id: product_id).count
    when :share_product
      # Implementation depends on your sharing system
      0
    when :refer_friend
      user.referrals.where('created_at >= ?', shopping_quest.starts_at).count
    when :visit_store
      # Implementation depends on your analytics system
      0
    when :add_to_wishlist
      user.wishlist_items.where(product_id: product_id).count
    when :complete_profile
      user.profile_completion_percentage
    else
      0
    end
  end
  
  # Get progress percentage
  def progress_percentage(user)
    ((current_progress(user).to_f / target_value) * 100).round(2).clamp(0, 100)
  end
  
  # Get display text
  def display_text
    case objective_type.to_sym
    when :purchase_product
      "Purchase #{product.name}"
    when :purchase_from_category
      "Purchase from #{category.name}"
    when :spend_amount
      "Spend $#{target_value}"
    when :purchase_count
      "Make #{target_value} purchases"
    when :review_product
      "Review #{product.name}"
    when :share_product
      "Share #{product.name}"
    when :refer_friend
      "Refer #{target_value} friends"
    when :visit_store
      "Visit the store #{target_value} times"
    when :add_to_wishlist
      "Add #{product.name} to wishlist"
    when :complete_profile
      "Complete your profile to #{target_value}%"
    else
      description
    end
  end
end

