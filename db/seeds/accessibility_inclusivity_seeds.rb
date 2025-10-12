puts "🌍 Seeding Accessibility & Inclusivity data..."

# Get users
users = User.limit(30)

if users.empty?
  puts "⚠️  No users found. Please seed users first."
  return
end

# Create Accessibility Settings
puts "  Creating accessibility settings..."
accessibility_count = 0

users.each do |user|
  next if AccessibilitySetting.exists?(user: user)
  
  # Random accessibility preferences
  setting = AccessibilitySetting.create!(
    user: user,
    font_size: [:small, :medium, :large, :extra_large].sample,
    contrast_mode: [:normal, :high_contrast, :dark_mode, :high_contrast_dark].sample,
    font_family: [:default, :dyslexia_friendly, :sans_serif, :serif].sample,
    line_height_value: [1.5, 1.6, 1.8, 2.0].sample,
    letter_spacing_value: [0.0, 0.05, 0.1, 0.12].sample,
    text_spacing_value: [1.0, 1.2, 1.5].sample,
    reduce_motion: [true, false].sample,
    screen_reader_optimized: [true, false].sample,
    keyboard_navigation_enabled: true,
    high_contrast_enabled: [true, false].sample,
    skip_to_content_enabled: true,
    aria_labels_enabled: true,
    descriptive_links: true,
    text_alternatives_enabled: true
  )
  
  accessibility_count += 1
end

puts "    ✅ Created #{accessibility_count} accessibility settings"

# Create specific accessibility profiles
puts "  Creating specialized accessibility profiles..."

# Screen reader user
if users[0]
  users[0].accessibility_setting&.enable_screen_reader_mode!
  users[0].update!(
    assistive_technologies: ['screen_reader', 'keyboard_only'],
    accessibility_verified: true
  )
end

# Dyslexia-friendly user
if users[1]
  users[1].accessibility_setting&.enable_dyslexia_mode!
  users[1].update!(
    accessibility_needs: { dyslexia: true, reading_difficulty: true }
  )
end

# High contrast user
if users[2]
  users[2].accessibility_setting&.enable_high_contrast_mode!
  users[2].update!(
    accessibility_needs: { low_vision: true, contrast_sensitivity: true }
  )
end

# Reduced motion user
if users[3]
  users[3].accessibility_setting&.enable_reduced_motion!
  users[3].update!(
    accessibility_needs: { motion_sensitivity: true, vestibular_disorder: true }
  )
end

puts "    ✅ Created specialized profiles"

# Create Language Preferences
puts "  Creating language preferences..."
language_count = 0

languages = ['en', 'es', 'fr', 'de', 'it', 'pt', 'ru', 'zh', 'ja', 'ko', 'ar', 'hi']

users.each do |user|
  next if LanguagePreference.exists?(user: user)
  
  primary = languages.sample
  secondary = (languages - [primary]).sample
  
  LanguagePreference.create!(
    user: user,
    primary_language: primary,
    secondary_language: secondary,
    currency_code: ['USD', 'EUR', 'GBP', 'JPY', 'CNY'].sample,
    timezone: ['UTC', 'America/New_York', 'Europe/London', 'Asia/Tokyo'].sample,
    auto_translate: [true, false].sample,
    show_original_text: [true, false].sample
  )
  
  language_count += 1
end

puts "    ✅ Created #{language_count} language preferences"

# Create Keyboard Shortcuts
puts "  Creating keyboard shortcuts..."
shortcut_count = 0

users.first(10).each do |user|
  KeyboardShortcut.create_defaults_for_user(user)
  shortcut_count += KeyboardShortcut::DEFAULT_SHORTCUTS.count
end

puts "    ✅ Created #{shortcut_count} keyboard shortcuts"

# Create Accessibility Audits
puts "  Creating accessibility audits..."
audit_count = 0

pages = [
  '/products',
  '/products/1',
  '/cart',
  '/checkout',
  '/account',
  '/search',
  '/categories/electronics',
  '/orders',
  '/wishlist',
  '/help'
]

pages.each do |page|
  audit = AccessibilityAudit.run_automated_audit(page, user: users.first)
  audit_count += 1
end

puts "    ✅ Created #{audit_count} accessibility audits"

# Create Screen Reader Content
puts "  Creating screen reader content..."
screen_reader_count = 0

# Sample products for screen reader content
products = Product.limit(20)

products.each do |product|
  # Product image description
  ScreenReaderContent.create_for_image(
    product,
    "#{product.name} - #{product.description&.truncate(100)}"
  )
  
  screen_reader_count += 1
end

puts "    ✅ Created #{screen_reader_count} screen reader contents"

# Create Translation Cache
puts "  Creating translation cache..."
translation_count = 0

common_phrases = {
  'welcome' => 'Welcome to The Final Market',
  'add_to_cart' => 'Add to Cart',
  'checkout' => 'Proceed to Checkout',
  'search' => 'Search for products',
  'account' => 'My Account',
  'orders' => 'My Orders',
  'wishlist' => 'My Wishlist',
  'help' => 'Help & Support',
  'contact' => 'Contact Us',
  'about' => 'About Us',
  'privacy' => 'Privacy Policy',
  'terms' => 'Terms of Service',
  'shipping' => 'Shipping Information',
  'returns' => 'Returns & Refunds',
  'faq' => 'Frequently Asked Questions'
}

target_languages = ['es', 'fr', 'de', 'zh', 'ja']

common_phrases.each do |key, text|
  target_languages.each do |lang|
    TranslationCache.get_translation('en', lang, key, text)
    translation_count += 1
  end
end

puts "    ✅ Created #{translation_count} translations"

# Create Accessibility Feedback
puts "  Creating accessibility feedback..."
feedback_count = 0

feedback_examples = [
  {
    page_url: '/products',
    feedback_type: :issue,
    description: 'Product images are missing alt text',
    wcag_criterion: '1.1.1 Non-text Content',
    severity: :high,
    assistive_technology: :screen_reader
  },
  {
    page_url: '/checkout',
    feedback_type: :issue,
    description: 'Form labels are not properly associated with inputs',
    wcag_criterion: '3.3.2 Labels or Instructions',
    severity: :critical,
    assistive_technology: :screen_reader
  },
  {
    page_url: '/search',
    feedback_type: :suggestion,
    description: 'Add keyboard shortcut for quick search access',
    severity: :medium,
    assistive_technology: :keyboard_only
  },
  {
    page_url: '/cart',
    feedback_type: :issue,
    description: 'Color contrast is too low for price text',
    wcag_criterion: '1.4.3 Contrast (Minimum)',
    severity: :high,
    assistive_technology: :screen_magnifier
  },
  {
    page_url: '/products/1',
    feedback_type: :praise,
    description: 'Excellent keyboard navigation on product page',
    severity: :low,
    assistive_technology: :keyboard_only
  },
  {
    page_url: '/account',
    feedback_type: :issue,
    description: 'Skip to content link is not working',
    wcag_criterion: '2.4.1 Bypass Blocks',
    severity: :medium,
    assistive_technology: :screen_reader
  },
  {
    page_url: '/help',
    feedback_type: :suggestion,
    description: 'Add text-to-speech option for help articles',
    severity: :low,
    assistive_technology: :screen_reader
  },
  {
    page_url: '/categories/electronics',
    feedback_type: :issue,
    description: 'Filter buttons are not keyboard accessible',
    wcag_criterion: '2.1.1 Keyboard',
    severity: :high,
    assistive_technology: :keyboard_only
  }
]

feedback_examples.each do |feedback_data|
  AccessibilityFeedback.create_from_user(users.sample, feedback_data)
  feedback_count += 1
end

# Resolve some feedback
AccessibilityFeedback.limit(3).each do |feedback|
  feedback.resolve!('Issue has been fixed and deployed to production')
end

puts "    ✅ Created #{feedback_count} accessibility feedback items"

# Summary
puts ""
puts "✅ Accessibility & Inclusivity seeding complete!"
puts ""
puts "Summary:"
puts "  - Accessibility Settings: #{AccessibilitySetting.count}"
puts "  - Language Preferences: #{LanguagePreference.count}"
puts "  - Keyboard Shortcuts: #{KeyboardShortcut.count}"
puts "  - Accessibility Audits: #{AccessibilityAudit.count}"
puts "  - Screen Reader Contents: #{ScreenReaderContent.count}"
puts "  - Translation Cache: #{TranslationCache.count}"
puts "  - Accessibility Feedback: #{AccessibilityFeedback.count}"
puts ""
puts "Accessibility Features:"
puts "  ✅ WCAG 2.1 AAA compliance tracking"
puts "  ✅ Screen reader optimization"
puts "  ✅ Keyboard navigation support"
puts "  ✅ High contrast & dark mode"
puts "  ✅ Dyslexia-friendly fonts"
puts "  ✅ 50+ language support"
puts "  ✅ RTL language support"
puts "  ✅ Reduced motion support"
puts "  ✅ Customizable font sizes"
puts "  ✅ Accessibility auditing"
puts ""

