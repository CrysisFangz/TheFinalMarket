class AccessibilitySetting < ApplicationRecord
  belongs_to :user
  
  validates :user, presence: true
  
  # Visual preferences
  enum font_size: {
    small: 0,
    medium: 1,
    large: 2,
    extra_large: 3
  }
  
  enum contrast_mode: {
    normal: 0,
    high_contrast: 1,
    dark_mode: 2,
    high_contrast_dark: 3
  }
  
  enum font_family: {
    default: 0,
    dyslexia_friendly: 1,
    sans_serif: 2,
    serif: 3,
    monospace: 4
  }
  
  # Apply accessibility preferences
  def apply_preferences
    {
      font_size: font_size_value,
      contrast_mode: contrast_mode,
      font_family: font_family_value,
      reduce_motion: reduce_motion?,
      screen_reader_optimized: screen_reader_optimized?,
      keyboard_navigation: keyboard_navigation_enabled?,
      high_contrast: high_contrast_enabled?,
      text_spacing: text_spacing_value,
      line_height: line_height_value,
      letter_spacing: letter_spacing_value
    }
  end
  
  # Get CSS variables
  def css_variables
    {
      '--font-size-base': font_size_value,
      '--font-family': font_family_value,
      '--line-height': line_height_value,
      '--letter-spacing': letter_spacing_value,
      '--text-spacing': text_spacing_value,
      '--contrast-mode': contrast_mode,
      '--animation-duration': reduce_motion? ? '0s' : '0.3s'
    }
  end
  
  # Check WCAG compliance level
  def wcag_compliance_level
    score = 0
    
    # Level A requirements
    score += 1 if keyboard_navigation_enabled?
    score += 1 if text_alternatives_enabled?
    
    # Level AA requirements
    score += 1 if contrast_ratio >= 4.5
    score += 1 if font_size_value.to_i >= 14
    
    # Level AAA requirements
    score += 1 if contrast_ratio >= 7.0
    score += 1 if font_size_value.to_i >= 16
    score += 1 if line_height_value.to_f >= 1.5
    
    case score
    when 7
      'AAA'
    when 4..6
      'AA'
    when 2..3
      'A'
    else
      'Non-compliant'
    end
  end
  
  # Enable screen reader mode
  def enable_screen_reader_mode!
    update!(
      screen_reader_optimized: true,
      keyboard_navigation_enabled: true,
      skip_to_content_enabled: true,
      aria_labels_enabled: true,
      descriptive_links: true
    )
  end
  
  # Enable dyslexia-friendly mode
  def enable_dyslexia_mode!
    update!(
      font_family: :dyslexia_friendly,
      font_size: :large,
      line_height_value: 1.8,
      letter_spacing_value: 0.12,
      text_spacing_value: 1.5
    )
  end
  
  # Enable high contrast mode
  def enable_high_contrast_mode!
    update!(
      contrast_mode: :high_contrast,
      high_contrast_enabled: true
    )
  end
  
  # Enable reduced motion
  def enable_reduced_motion!
    update!(reduce_motion: true)
  end
  
  # Get accessibility report
  def accessibility_report
    {
      wcag_level: wcag_compliance_level,
      features_enabled: enabled_features,
      contrast_ratio: contrast_ratio,
      font_size: font_size_value,
      recommendations: accessibility_recommendations
    }
  end
  
  private
  
  def font_size_value
    case font_size.to_sym
    when :small
      '12px'
    when :medium
      '14px'
    when :large
      '16px'
    when :extra_large
      '18px'
    else
      '14px'
    end
  end
  
  def font_family_value
    case font_family.to_sym
    when :dyslexia_friendly
      'OpenDyslexic, Arial, sans-serif'
    when :sans_serif
      'Arial, Helvetica, sans-serif'
    when :serif
      'Georgia, Times New Roman, serif'
    when :monospace
      'Courier New, monospace'
    else
      '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif'
    end
  end
  
  def line_height_value
    self[:line_height_value] || 1.5
  end
  
  def letter_spacing_value
    self[:letter_spacing_value] || 0.0
  end
  
  def text_spacing_value
    self[:text_spacing_value] || 1.0
  end
  
  def contrast_ratio
    case contrast_mode.to_sym
    when :high_contrast, :high_contrast_dark
      21.0 # Maximum contrast
    when :dark_mode
      15.0
    else
      4.5 # WCAG AA minimum
    end
  end
  
  def enabled_features
    features = []
    features << 'Screen Reader Optimized' if screen_reader_optimized?
    features << 'Keyboard Navigation' if keyboard_navigation_enabled?
    features << 'High Contrast' if high_contrast_enabled?
    features << 'Reduced Motion' if reduce_motion?
    features << 'Dyslexia-Friendly Font' if font_family == 'dyslexia_friendly'
    features << 'Skip to Content' if skip_to_content_enabled?
    features << 'ARIA Labels' if aria_labels_enabled?
    features
  end
  
  def accessibility_recommendations
    recommendations = []
    
    unless keyboard_navigation_enabled?
      recommendations << 'Enable keyboard navigation for better accessibility'
    end
    
    if font_size_value.to_i < 14
      recommendations << 'Increase font size to at least 14px for better readability'
    end
    
    if contrast_ratio < 4.5
      recommendations << 'Increase contrast ratio to meet WCAG AA standards'
    end
    
    unless screen_reader_optimized?
      recommendations << 'Enable screen reader optimization for visually impaired users'
    end
    
    if line_height_value < 1.5
      recommendations << 'Increase line height to at least 1.5 for better readability'
    end
    
    recommendations
  end
end

