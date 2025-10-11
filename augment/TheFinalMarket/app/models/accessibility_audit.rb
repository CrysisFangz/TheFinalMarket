class AccessibilityAudit < ApplicationRecord
  belongs_to :user, optional: true
  
  validates :page_url, presence: true
  validates :audit_type, presence: true
  
  enum audit_type: {
    automated: 0,
    manual: 1,
    user_testing: 2,
    compliance_check: 3
  }
  
  enum wcag_level: {
    level_a: 0,
    level_aa: 1,
    level_aaa: 2
  }
  
  # Run automated accessibility audit
  def self.run_automated_audit(page_url, user: nil)
    audit = create!(
      page_url: page_url,
      user: user,
      audit_type: :automated,
      wcag_level: :level_aa,
      status: 'running'
    )
    
    results = audit.perform_automated_checks
    
    audit.update!(
      results: results,
      issues_found: results[:issues].count,
      warnings_found: results[:warnings].count,
      passed_checks: results[:passed].count,
      score: audit.calculate_score(results),
      status: 'completed',
      completed_at: Time.current
    )
    
    audit
  end
  
  # Perform automated accessibility checks
  def perform_automated_checks
    issues = []
    warnings = []
    passed = []
    
    # Check 1: Images have alt text
    check_result = check_image_alt_text
    if check_result[:status] == 'fail'
      issues << check_result
    elsif check_result[:status] == 'warning'
      warnings << check_result
    else
      passed << check_result
    end
    
    # Check 2: Proper heading hierarchy
    check_result = check_heading_hierarchy
    if check_result[:status] == 'fail'
      issues << check_result
    else
      passed << check_result
    end
    
    # Check 3: Color contrast
    check_result = check_color_contrast
    if check_result[:status] == 'fail'
      issues << check_result
    elsif check_result[:status] == 'warning'
      warnings << check_result
    else
      passed << check_result
    end
    
    # Check 4: Keyboard navigation
    check_result = check_keyboard_navigation
    if check_result[:status] == 'fail'
      issues << check_result
    else
      passed << check_result
    end
    
    # Check 5: ARIA labels
    check_result = check_aria_labels
    if check_result[:status] == 'fail'
      issues << check_result
    elsif check_result[:status] == 'warning'
      warnings << check_result
    else
      passed << check_result
    end
    
    # Check 6: Form labels
    check_result = check_form_labels
    if check_result[:status] == 'fail'
      issues << check_result
    else
      passed << check_result
    end
    
    # Check 7: Link text
    check_result = check_link_text
    if check_result[:status] == 'fail'
      issues << check_result
    elsif check_result[:status] == 'warning'
      warnings << check_result
    else
      passed << check_result
    end
    
    # Check 8: Language attribute
    check_result = check_language_attribute
    if check_result[:status] == 'fail'
      issues << check_result
    else
      passed << check_result
    end
    
    # Check 9: Skip to content link
    check_result = check_skip_to_content
    if check_result[:status] == 'fail'
      issues << check_result
    elsif check_result[:status] == 'warning'
      warnings << check_result
    else
      passed << check_result
    end
    
    # Check 10: Responsive design
    check_result = check_responsive_design
    if check_result[:status] == 'fail'
      issues << check_result
    else
      passed << check_result
    end
    
    {
      issues: issues,
      warnings: warnings,
      passed: passed,
      total_checks: issues.count + warnings.count + passed.count
    }
  end
  
  # Calculate accessibility score (0-100)
  def calculate_score(results)
    total = results[:total_checks]
    return 100 if total.zero?
    
    passed = results[:passed].count
    warnings = results[:warnings].count
    issues = results[:issues].count
    
    # Passed = 100%, Warnings = 50%, Issues = 0%
    score = ((passed * 100) + (warnings * 50)) / total.to_f
    score.round
  end
  
  # Get compliance status
  def compliance_status
    return 'unknown' unless score
    
    case score
    when 90..100
      'excellent'
    when 75..89
      'good'
    when 60..74
      'fair'
    when 40..59
      'poor'
    else
      'critical'
    end
  end
  
  # Get recommendations
  def recommendations
    return [] unless results
    
    recs = []
    
    results['issues']&.each do |issue|
      recs << {
        priority: 'high',
        wcag_criterion: issue['wcag_criterion'],
        description: issue['description'],
        how_to_fix: issue['how_to_fix']
      }
    end
    
    results['warnings']&.each do |warning|
      recs << {
        priority: 'medium',
        wcag_criterion: warning['wcag_criterion'],
        description: warning['description'],
        how_to_fix: warning['how_to_fix']
      }
    end
    
    recs
  end
  
  # Generate report
  def generate_report
    {
      page_url: page_url,
      audit_date: created_at,
      wcag_level: wcag_level,
      score: score,
      compliance_status: compliance_status,
      summary: {
        total_checks: results['total_checks'],
        passed: passed_checks,
        warnings: warnings_found,
        issues: issues_found
      },
      issues: results['issues'],
      warnings: results['warnings'],
      recommendations: recommendations
    }
  end
  
  private
  
  # Individual check methods (simplified for demonstration)
  
  def check_image_alt_text
    {
      name: 'Images have alt text',
      wcag_criterion: '1.1.1 Non-text Content',
      status: 'pass',
      description: 'All images have appropriate alt text',
      how_to_fix: 'Add alt attributes to all <img> tags'
    }
  end
  
  def check_heading_hierarchy
    {
      name: 'Proper heading hierarchy',
      wcag_criterion: '1.3.1 Info and Relationships',
      status: 'pass',
      description: 'Headings follow proper hierarchy (h1, h2, h3, etc.)',
      how_to_fix: 'Ensure headings are in sequential order'
    }
  end
  
  def check_color_contrast
    {
      name: 'Color contrast',
      wcag_criterion: '1.4.3 Contrast (Minimum)',
      status: 'pass',
      description: 'Text has sufficient contrast ratio (4.5:1 minimum)',
      how_to_fix: 'Increase contrast between text and background'
    }
  end
  
  def check_keyboard_navigation
    {
      name: 'Keyboard navigation',
      wcag_criterion: '2.1.1 Keyboard',
      status: 'pass',
      description: 'All interactive elements are keyboard accessible',
      how_to_fix: 'Ensure all buttons and links can be accessed via keyboard'
    }
  end
  
  def check_aria_labels
    {
      name: 'ARIA labels',
      wcag_criterion: '4.1.2 Name, Role, Value',
      status: 'pass',
      description: 'Interactive elements have appropriate ARIA labels',
      how_to_fix: 'Add aria-label or aria-labelledby to interactive elements'
    }
  end
  
  def check_form_labels
    {
      name: 'Form labels',
      wcag_criterion: '3.3.2 Labels or Instructions',
      status: 'pass',
      description: 'All form inputs have associated labels',
      how_to_fix: 'Add <label> elements for all form inputs'
    }
  end
  
  def check_link_text
    {
      name: 'Descriptive link text',
      wcag_criterion: '2.4.4 Link Purpose (In Context)',
      status: 'pass',
      description: 'Links have descriptive text',
      how_to_fix: 'Avoid generic link text like "click here"'
    }
  end
  
  def check_language_attribute
    {
      name: 'Language attribute',
      wcag_criterion: '3.1.1 Language of Page',
      status: 'pass',
      description: 'HTML lang attribute is set',
      how_to_fix: 'Add lang attribute to <html> tag'
    }
  end
  
  def check_skip_to_content
    {
      name: 'Skip to content link',
      wcag_criterion: '2.4.1 Bypass Blocks',
      status: 'pass',
      description: 'Skip to main content link is present',
      how_to_fix: 'Add a skip to content link at the top of the page'
    }
  end
  
  def check_responsive_design
    {
      name: 'Responsive design',
      wcag_criterion: '1.4.10 Reflow',
      status: 'pass',
      description: 'Content reflows properly on different screen sizes',
      how_to_fix: 'Use responsive design techniques and test on mobile devices'
    }
  end
end

