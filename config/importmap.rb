# ============================================================================
# Rails Importmap Configuration
# ============================================================================
# Manages JavaScript package imports for TheFinalMarket application
# 
# Organization:
# - Core Rails functionality (Turbo, Stimulus)
# - UI Framework (Bootstrap ecosystem)
# - Utility libraries (Sorting, Charts)
# - Feature-specific packages (Image cropping)
# - Application controllers
#
# Performance Strategy:
# - Critical packages: preload for immediate availability
# - Non-critical packages: lazy load to reduce initial bundle size
# - Core functionality: eager load for immediate page interaction
#
# Last Updated: 2025-10-13
# ============================================================================

# Core Rails functionality - Essential for application operation
# ============================================================================
pin "application"  # Main application JavaScript entry point

# Hotwired ecosystem - Critical for Rails 7+ modern functionality
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true    # SPA navigation
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true    # JavaScript framework
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"      # Loading states

# Application controllers - Custom Stimulus controllers
pin_all_from "app/javascript/controllers", under: "controllers"

# UI Framework - Bootstrap ecosystem for styling and interactions
# ============================================================================
# Critical for immediate UI rendering and user interactions
pin "bootstrap", to: "bootstrap.min.js", preload: true
pin "@popperjs/core", to: "popper.js", preload: true

# Utility Libraries - General purpose JavaScript utilities
# ============================================================================
# Rails request.js for AJAX operations
pin "@rails/request.js", to: "@rails--request.js.js" # v0.0.12

# Sorting functionality for interactive lists
pin "sortablejs" # v1.15.6

# Data Visualization - Chart functionality (lazy loaded)
# ============================================================================
# Charts are typically used on specific pages, so lazy load to reduce initial bundle
pin "chart.js", preload: false # v4.5.0
pin "chartkick", preload: false # v5.0.1
pin "@kurkle/color", to: "@kurkle--color.js", preload: false # v0.3.4

# Image Processing - Cropper.js ecosystem for image manipulation
# ============================================================================
# Core cropper functionality - essential for image editing features
pin "cropperjs" # v2.0.1

# Cropper.js elements - modular components for advanced cropping features
# These are loaded on-demand to reduce initial bundle size
pin "@cropper/element", to: "@cropper--element.js" # v2.0.1
pin "@cropper/element-canvas", to: "@cropper--element-canvas.js" # v2.0.1
pin "@cropper/element-crosshair", to: "@cropper--element-crosshair.js" # v2.0.1
pin "@cropper/element-grid", to: "@cropper--element-grid.js" # v2.0.1
pin "@cropper/element-handle", to: "@cropper--element-handle.js" # v2.0.1
pin "@cropper/element-image", to: "@cropper--element-image.js" # v2.0.1
pin "@cropper/element-selection", to: "@cropper--element-selection.js" # v2.0.1
pin "@cropper/element-shade", to: "@cropper--element-shade.js" # v2.0.1
pin "@cropper/element-viewer", to: "@cropper--element-viewer.js" # v2.0.1
pin "@cropper/elements", to: "@cropper--elements.js" # v2.0.1
pin "@cropper/utils", to: "@cropper--utils.js" # v2.0.1

# ============================================================================
# Import Validation and Error Handling
# ============================================================================
# 
# To validate all imports are correctly configured:
#   ./bin/importmap audit
#
# To check for outdated packages:
#   ./bin/importmap outdated
#
# Error Handling Strategy:
# - Critical packages (Turbo, Stimulus, Bootstrap) use preload: true
# - Non-critical packages use lazy loading to prevent blocking page load
# - Core functionality is prioritized over feature-specific packages
#
# Bundle Size Optimization:
# - Minified versions used where available (.min.js)
# - Modular imports for cropper.js elements to enable tree-shaking
# - Lazy loading for visualization libraries used on specific pages only
# ============================================================================