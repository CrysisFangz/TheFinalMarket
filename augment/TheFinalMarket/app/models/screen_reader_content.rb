class ScreenReaderContent < ApplicationRecord
  belongs_to :contentable, polymorphic: true
  
  validates :contentable, presence: true
  validates :content_type, presence: true
  
  enum content_type: {
    image_description: 0,
    button_label: 1,
    link_description: 2,
    form_instruction: 3,
    navigation_hint: 4,
    status_message: 5,
    error_message: 6,
    success_message: 7,
    warning_message: 8,
    info_message: 9
  }
  
  # Generate screen reader text for an image
  def self.create_for_image(image, description)
    create!(
      contentable: image,
      content_type: :image_description,
      screen_reader_text: description,
      aria_label: description,
      long_description: description
    )
  end
  
  # Generate screen reader text for a button
  def self.create_for_button(button, label, hint: nil)
    create!(
      contentable: button,
      content_type: :button_label,
      screen_reader_text: label,
      aria_label: label,
      aria_describedby: hint
    )
  end
  
  # Generate screen reader text for a link
  def self.create_for_link(link, description, context: nil)
    full_text = context ? "#{description} - #{context}" : description
    
    create!(
      contentable: link,
      content_type: :link_description,
      screen_reader_text: full_text,
      aria_label: description,
      title_text: context
    )
  end
  
  # Generate ARIA live region content
  def self.create_live_region(contentable, message, politeness: 'polite')
    create!(
      contentable: contentable,
      content_type: :status_message,
      screen_reader_text: message,
      aria_live: politeness,
      aria_atomic: true
    )
  end
  
  # Get ARIA attributes
  def aria_attributes
    attrs = {}
    
    attrs['aria-label'] = aria_label if aria_label.present?
    attrs['aria-describedby'] = aria_describedby if aria_describedby.present?
    attrs['aria-live'] = aria_live if aria_live.present?
    attrs['aria-atomic'] = aria_atomic if aria_atomic
    attrs['role'] = role if role.present?
    
    attrs
  end
  
  # Get full screen reader text
  def full_text
    parts = [screen_reader_text]
    parts << long_description if long_description.present?
    parts << aria_describedby if aria_describedby.present?
    parts.join('. ')
  end
  
  # Validate screen reader text quality
  def validate_quality
    issues = []
    
    # Check length
    if screen_reader_text.length < 3
      issues << 'Screen reader text is too short'
    end
    
    if screen_reader_text.length > 150
      issues << 'Screen reader text is too long (consider using long_description)'
    end
    
    # Check for generic text
    generic_phrases = ['click here', 'read more', 'learn more', 'image', 'button']
    if generic_phrases.any? { |phrase| screen_reader_text.downcase.include?(phrase) }
      issues << 'Avoid generic phrases in screen reader text'
    end
    
    # Check for special characters
    if screen_reader_text.match?(/[<>{}]/)
      issues << 'Remove HTML tags from screen reader text'
    end
    
    issues
  end
  
  # Generate contextual description
  def self.generate_contextual_description(element_type, context)
    case element_type
    when 'product_image'
      "Product image: #{context[:product_name]}"
    when 'category_link'
      "Browse #{context[:category_name]} category"
    when 'add_to_cart'
      "Add #{context[:product_name]} to shopping cart"
    when 'checkout_button'
      "Proceed to checkout with #{context[:item_count]} items"
    when 'search_button'
      "Search for products"
    when 'filter_button'
      "Filter products by #{context[:filter_type]}"
    when 'sort_button'
      "Sort products by #{context[:sort_type]}"
    else
      context[:default_text] || 'Interactive element'
    end
  end
end

