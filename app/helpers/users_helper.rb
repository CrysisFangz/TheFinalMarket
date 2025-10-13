module UsersHelper
  # Maximum level constant for better maintainability
  MAX_LEVEL = 6

  # Renders the user level progress bar with proper accessibility and error handling
  def render_user_level_progress(user)
    return content_tag(:div, class: 'user-level-max') do
      content_tag(:span, 'Max Level Achieved!', class: 'badge badge-success')
    end if user.level >= MAX_LEVEL

    progress_value = calculate_progress_percentage(user)
    points_to_next = user.points_to_next_level || 0
    next_level_name = level_name(user.level + 1) rescue 'next level'

    content_tag(:div, class: 'level-progress-section mt-3') do
      concat(
        content_tag(:div, class: 'progress-container mb-2') do
          content_tag(:div, class: 'progress progress-custom') do
            content_tag(:div,
              class: "progress-bar progress-bar-animated #{progress_bar_color(progress_value)}",
              role: 'progressbar',
              style: "width: #{progress_value}%;",
              'aria-valuenow' => progress_value.to_i,
              'aria-valuemin' => '0',
              'aria-valuemax' => '100',
              'aria-label' => "Progress to #{next_level_name}: #{progress_value.round}%"
            ) do
              "#{progress_value.round}%"
            end
          end
        end
      )

      concat(
        content_tag(:div, class: 'progress-text text-muted small') do
          "#{points_to_next} points to #{next_level_name}"
        end
      )
    end
  end

  # Renders the seller application card for eligible users
  def render_seller_application_card
    return unless can_apply_as_seller?

    content_tag(:div, class: 'seller-application-card card mt-4 shadow-sm') do
      content_tag(:div, class: 'card-body text-center') do
        concat(content_tag(:div, class: 'application-icon mb-3') do
          content_tag(:i, '', class: 'fas fa-gem fa-2x text-primary')
        end)

        concat(content_tag(:h5, 'Ready to Start Selling?', class: 'card-title mb-3'))

        concat(content_tag(:p, 'Join our marketplace as a verified seller and showcase your unique products to thousands of potential customers.', class: 'card-text text-muted mb-4'))

        concat(link_to('Apply to Become a Seller',
          new_seller_application_path,
          class: 'btn btn-primary btn-lg px-4',
          role: 'button',
          'aria-label' => 'Apply for seller status'
        ))
      end
    end
  end

  # Renders the user's products section with proper error handling and empty states
  def render_user_products_section
    products = @user.products.includes(:image_attachment)

    content_tag(:section, class: 'user-products-section') do
      concat(
        content_tag(:div, class: 'products-header mb-4') do
          content_tag(:h2, "Products by #{@user.name}", class: 'h4 mb-0')
        end
      )

      if products.any?
        concat(render_products_grid(products))
      else
        concat(render_empty_products_state)
      end
    end
  end

  private

  # Helper method to check if current user can apply as seller
  def can_apply_as_seller?
    return false unless current_user
    return false if @user != current_user
    return false if @user.gem?
    true
  end

  # Calculates progress percentage with error handling
  def calculate_progress_percentage(user)
    return 0.0 if user.progress_to_next_level.blank?
    return 0.0 if user.progress_to_next_level <= 0
    return 100.0 if user.progress_to_next_level >= 100

    user.progress_to_next_level.to_f
  end

  # Determines progress bar color based on progress
  def progress_bar_color(progress)
    case progress
    when 0..25 then 'bg-danger'
    when 26..50 then 'bg-warning'
    when 51..75 then 'bg-info'
    else 'bg-success'
    end
  end

  # Renders the products grid with responsive design
  def render_products_grid(products)
    content_tag(:div, class: 'products-grid') do
      content_tag(:div, class: 'row g-3') do
        products.map do |product|
          concat(
            content_tag(:div, class: 'col-12 col-sm-6 col-lg-4') do
              render_product_card(product)
            end
          )
        end.join.html_safe
      end
    end
  end

  # Renders an individual product card with proper image handling
  def render_product_card(product)
    content_tag(:div, class: 'product-card card h-100 shadow-sm hover-lift') do
      concat(render_product_image(product))
      concat(render_product_info(product))
    end
  end

  # Renders product image with fallback and optimization
  def render_product_image(product)
    if product.image.attached?
      content_tag(:div, class: 'product-image-container') do
        image_tag(product.image.variant(resize_to_limit: [300, 300]),
          class: 'card-img-top product-image',
          alt: "Image of #{product.name}",
          loading: 'lazy'
        )
      end
    else
      content_tag(:div, class: 'product-image-placeholder card-img-top d-flex align-items-center justify-content-center bg-light') do
        content_tag(:i, '', class: 'fas fa-image fa-2x text-muted')
      end
    end
  end

  # Renders product information section
  def render_product_info(product)
    content_tag(:div, class: 'card-body d-flex flex-column') do
      concat(
        content_tag(:h5, class: 'card-title product-title mb-2') do
          link_to(product.name,
            product_path(product),
            class: 'text-decoration-none',
            'aria-label' => "View details for #{product.name}"
          )
        end
      )

      concat(
        content_tag(:div, class: 'product-price mt-auto') do
          content_tag(:span, number_to_currency(product.price), class: 'h6 text-primary mb-0')
        end
      )
    end
  end

  # Renders empty state when user has no products
  def render_empty_products_state
    content_tag(:div, class: 'empty-products-state text-center py-5') do
      concat(content_tag(:div, class: 'empty-state-icon mb-3') do
        content_tag(:i, '', class: 'fas fa-store-slash fa-3x text-muted')
      end)

      concat(content_tag(:h3, 'No Products Yet', class: 'h5 mb-2'))

      concat(content_tag(:p, 'This seller hasn\'t listed any products yet. Check back soon for new items!', class: 'text-muted mb-0'))
    end
  end
end
