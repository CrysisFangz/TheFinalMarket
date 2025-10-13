# frozen_string_literal: true

# IconHelper - Centralized icon management system for consistent UI
# Provides semantic icon mapping and accessibility features
module IconHelper
  # Icon mapping for semantic consistency across the application
  ICON_MAP = {
    # Commerce & Shopping
    'shopping-cart' => 'M3 1a1 1 0 000 2h1.22l.305 1.222a.997.997 0 00.01.042l1.358 5.43-.893.892C3.74 11.846 4.632 14 6.414 14H15a1 1 0 000-2H6.414l1-1H14a1 1 0 00.894-.553l3-6A1 1 0 0017 3H6.28l-.31-1.243A1 1 0 005 1H3zM16 16.5a1.5 1.5 0 11-3 0 1.5 1.5 0 013 0zM6.5 18a1.5 1.5 0 100-3 1.5 1.5 0 000 3z',
    'shopping-bag' => 'M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z',
    'clipboard-list' => 'M9 2a1 1 0 000 2h2a1 1 0 100-2H9zM4 5a2 2 0 012-2 3 3 0 003 3h2a3 3 0 003-3 2 2 0 012 2v11a2 2 0 01-2 2H6a2 2 0 01-2-2V5zm3 4a1 1 0 000 2h.01a1 1 0 100-2H7zm3 0a1 1 0 000 2h3a1 1 0 100-2h-3zm-3 4a1 1 0 100 2h.01a1 1 0 100-2H7zm3 0a1 1 0 100 2h3a1 1 0 100-2h-3z',

    # User & Profile
    'user' => 'M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z M15 12a3 3 0 11-6 0 3 3 0 016 0z',
    'cog-6-tooth' => 'M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z M15 12a3 3 0 11-6 0 3 3 0 016 0z',

    # Communication
    'chat-bubble-left-right' => 'M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z',
    'bell' => 'M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9',

    # Status & Feedback
    'star' => 'M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z',
    'heart' => 'M3.172 5.172a4 4 0 015.656 0L10 6.343l1.172-1.171a4 4 0 115.656 5.656L10 17.657l-6.828-6.829a4 4 0 010-5.656z',
    'check-circle' => 'M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z',
    'x-circle' => 'M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z',
    'exclamation-triangle' => 'M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z',

    # Navigation & Actions
    'arrow-right' => 'M9 5l7 7-7 7',
    'arrow-left' => 'M15 19l-7-7 7-7',
    'chevron-down' => 'M19 9l-7 7-7-7',
    'chevron-up' => 'M5 15l7-7 7 7',
    'plus' => 'M12 4v16m8-8H4',
    'minus' => 'M20 12H4',
    'x-mark' => 'M6 18L18 6M6 6l12 12',

    # Interface
    'eye' => 'M15 12a3 3 0 11-6 0 3 3 0 016 0z M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z',
    'eye-slash' => 'M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242',
    'magnifying-glass' => 'M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z',
    'bars-3' => 'M3.75 6.75h16.5M3.75 12h16.5M3.75 17.25h16.5',

    # Status indicators
    'check' => 'M5 13l4 4L19 7',
    'x' => 'M6 18L18 6M6 6l12 12',
    'information-circle' => 'M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z'
  }.freeze

  # Generate SVG icon with proper accessibility attributes
  def icon(name, size: 'w-5 h-5', **options)
    return '' unless ICON_MAP.key?(name)

    icon_class = options[:class] || ''
    icon_class = "#{icon_class} #{size}".strip

    aria_label = options[:aria_label] || infer_aria_label(name)
    role = options[:role] || 'img'

    content_tag :svg,
      class: icon_class,
      fill: options[:fill] || 'none',
      stroke: options[:stroke] || 'currentColor',
      viewBox: options[:viewBox] || '0 0 24 24',
      aria: { label: aria_label, hidden: options[:aria_hidden] == true } do
      content_tag :path,
        nil,
        d: ICON_MAP[name],
        stroke_cap: options[:stroke_cap] || 'round',
        stroke_join: options[:stroke_join] || 'round',
        stroke_width: options[:stroke_width] || '2'
    end
  end

  # Generate icon with different variants (solid, outline, mini)
  def icon_variant(name, variant: :outline, size: 'w-5 h-5', **options)
    variant_sizes = {
      mini: 'w-4 h-4',
      outline: 'w-5 h-5',
      solid: 'w-5 h-5'
    }

    size = variant_sizes[variant] || size

    case variant
    when :solid
      options[:fill] = 'currentColor'
      options[:stroke] = 'none'
    when :outline
      options[:fill] = 'none'
      options[:stroke] = 'currentColor'
    end

    icon(name, size: size, **options)
  end

  # Generate status icon with semantic color
  def status_icon(status, **options)
    status_config = {
      success: { name: 'check-circle', color: 'text-green-500' },
      error: { name: 'x-circle', color: 'text-red-500' },
      warning: { name: 'exclamation-triangle', color: 'text-yellow-500' },
      info: { name: 'information-circle', color: 'text-blue-500' }
    }

    config = status_config[status.to_sym] || status_config[:info]
    options[:class] = "#{options[:class]} #{config[:color]}".strip

    icon(config[:name], **options)
  end

  private

  def infer_aria_label(icon_name)
    # Convert kebab-case to readable label
    icon_name.tr('-', ' ').gsub(/\b\w/) { |word| word.capitalize }
  end
end