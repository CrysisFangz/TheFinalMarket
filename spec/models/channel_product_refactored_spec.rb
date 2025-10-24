# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ChannelProduct Refactored Architecture' do
  let(:sales_channel) { create(:sales_channel, status: :active) }
  let(:product) { create(:product, active: true, stock_quantity: 10, price: 29.99) }
  let(:channel_product) { create(:channel_product, sales_channel: sales_channel, product: product) }

  describe 'ChannelProduct Model' do
    it 'has proper associations' do
      expect(channel_product.sales_channel).to eq(sales_channel)
      expect(channel_product.product).to eq(product)
    end

    it 'has correct validations' do
      expect(channel_product).to validate_presence_of(:sales_channel)
      expect(channel_product).to validate_presence_of(:product)
      expect(channel_product).to validate_uniqueness_of(:product_id).scoped_to(:sales_channel_id)
    end

    it 'has working scopes' do
      expect(ChannelProduct.available).to include(channel_product)
      expect(ChannelProduct.active_channels).to include(channel_product)
    end

    it 'delegates business logic to value objects' do
      expect(channel_product.pricing).to be_a(ChannelProduct::ValueObjects::ChannelPricing)
      expect(channel_product.inventory).to be_a(ChannelProduct::ValueObjects::ChannelInventory)
      expect(channel_product.effective_price).to be_a(BigDecimal)
      expect(channel_product.effective_inventory).to be_an(Integer)
    end

    it 'delegates synchronization to service' do
      expect(channel_product.sync_from_product!).to eq(channel_product)
      expect(channel_product.last_synced_at).to be_present
    end

    it 'delegates performance analytics to service' do
      metrics = channel_product.performance_metrics
      expect(metrics).to be_present
    end

    it 'delegates channel data management to service' do
      result = channel_product.update_channel_data(title: 'New Title')
      expect(result['title']).to eq('New Title')
    end

    it 'delegates health checks to service' do
      health_check = channel_product.health_check
      expect(health_check).to be_a(ChannelProduct::Services::HealthCheckService::HealthCheckResult)
    end
  end

  describe 'ChannelDataService' do
    let(:service) { ChannelProduct::Services::ChannelDataService.new }

    it 'updates channel data successfully' do
      data = { title: 'Test Title', description: 'Test Description' }
      result = service.update_data(channel_product, data)

      expect(result['title']).to eq('Test Title')
      expect(result['description']).to eq('Test Description')
      expect(channel_product.channel_specific_data['title']).to eq('Test Title')
    end

    it 'validates data size' do
      large_data = 'x' * 60_000 # Exceeds 50KB limit
      expect do
        service.update_data(channel_product, title: large_data)
      end.to raise_error(ChannelProduct::Services::ChannelDataError, /too large/)
    end

    it 'validates content constraints' do
      expect do
        service.update_data(channel_product, title: 'x' * 300) # Too long
      end.to raise_error(ChannelProduct::Services::ChannelDataError, /too long/)
    end
  end

  describe 'BulkSynchronizationService' do
    let(:service) { ChannelProduct::Services::BulkSynchronizationService.new }
    let(:product_ids) { [product.id] }

    it 'performs bulk synchronization' do
      result = service.bulk_sync(product_ids, {})

      expect(result).to be_a(ChannelProduct::Services::BulkSynchronizationService::BulkSynchronizationResult)
      expect(result.total_processed).to be >= 1
      expect(result.success_rate).to be >= 0.0
    end
  end

  describe 'HealthCheckService' do
    let(:service) { ChannelProduct::Services::HealthCheckService.new }

    it 'performs health check' do
      result = service.check_health(channel_product)

      expect(result).to be_a(ChannelProduct::Services::HealthCheckService::HealthCheckResult)
      expect(result.healthy).to be_in([true, false])
      expect(result.issues).to be_an(Array)
      expect(result.last_checked).to be_present
    end

    context 'when product is inactive' do
      before { product.update!(active: false) }

      it 'reports product inactive issue' do
        result = service.check_health(channel_product)
        expect(result.issues).to include('Product inactive')
        expect(result.healthy).to be false
      end
    end
  end

  describe 'ChannelProductPresenter' do
    let(:presenter) { ChannelProduct::Presenters::ChannelProductPresenter.new(channel_product) }

    it 'serializes to JSON' do
      json = presenter.as_json
      expect(json[:id]).to eq(channel_product.id)
      expect(json[:product_id]).to eq(product.id)
      expect(json[:sales_channel_id]).to eq(sales_channel.id)
      expect(json[:effective_price]).to eq(channel_product.effective_price)
    end

    it 'provides API response format' do
      api_response = presenter.to_api_response
      expect(api_response[:_links]).to be_present
      expect(api_response[:_links][:self]).to include(channel_product.id.to_s)
    end

    it 'provides dashboard view format' do
      dashboard_view = presenter.to_dashboard_view
      expect(dashboard_view[:performance_metrics]).to be_present
      expect(dashboard_view[:business_insights]).to be_present
      expect(dashboard_view[:health_check]).to be_present
    end
  end

  describe 'ChannelProductQueries' do
    it 'finds available products' do
      results = ChannelProduct::Queries::ChannelProductQueries.find_available_products(sales_channel.id)
      expect(results).to include(channel_product)
    end

    it 'finds products by channel type' do
      results = ChannelProduct::Queries::ChannelProductQueries.find_products_by_channel_type([:web])
      expect(results).to be_an(ActiveRecord::Relation)
    end

    it 'finds recently updated products' do
      results = ChannelProduct::Queries::ChannelProductQueries.find_recently_updated(1.minute.ago)
      expect(results).to be_an(ActiveRecord::Relation)
    end

    it 'finds stale synchronizations' do
      results = ChannelProduct::Queries::ChannelProductQueries.find_stale_synchronizations(2.hours.ago)
      expect(results).to be_an(ActiveRecord::Relation)
    end

    it 'finds healthy products' do
      results = ChannelProduct::Queries::ChannelProductQueries.find_healthy_products
      expect(results).to be_an(ActiveRecord::Relation)
    end

    it 'provides performance summary' do
      summary = ChannelProduct::Queries::ChannelProductQueries.performance_summary
      expect(summary).to be_an(ActiveRecord::Relation)
    end
  end

  describe 'ChannelProductPolicies' do
    let(:user) { create(:user, role: :seller) }
    let(:policy) { ChannelProduct::Policies::ChannelProductPolicies.new(channel_product, user) }

    it 'allows purchase when conditions are met' do
      expect(policy.can_purchase?).to be true
    end

    it 'allows sync for authorized user' do
      expect(policy.can_sync?).to be true
    end

    it 'allows channel data updates for authorized user' do
      expect(policy.can_update_channel_data?).to be true
    end

    it 'allows viewing analytics for authorized user' do
      expect(policy.can_view_analytics?).to be true
    end

    it 'enforces field restrictions based on user role' do
      fields = policy.allowed_channel_data_fields
      expect(fields).to include('title', 'description')
      expect(fields).not_to include('internal_notes') # Not for sellers
    end

    context 'with admin user' do
      let(:admin_user) { create(:user, role: :admin) }
      let(:admin_policy) { ChannelProduct::Policies::ChannelProductPolicies.new(channel_product, admin_user) }

      it 'allows all operations for admin' do
        expect(admin_policy.can_purchase?).to be true
        expect(admin_policy.can_sync?).to be true
        expect(admin_policy.can_update_channel_data?).to be true
        expect(admin_policy.can_view_analytics?).to be true
      end

      it 'allows additional fields for admin' do
        fields = admin_policy.allowed_channel_data_fields
        expect(fields).to include('internal_notes')
      end
    end
  end

  describe 'AvailabilityPolicy' do
    let(:user) { create(:user, role: :seller) }
    let(:policy) { ChannelProduct::Policies::AvailabilityPolicy.new(channel_product, user) }

    it 'allows marking available when conditions are met' do
      expect(policy.can_modify_availability?).to be true
    end

    it 'checks product stock for availability' do
      expect(policy.product_in_stock?).to be true
    end
  end

  describe 'SynchronizationPolicy' do
    let(:user) { create(:user, role: :seller) }
    let(:policy) { ChannelProduct::Policies::SynchronizationPolicy.new(channel_product, user) }

    it 'allows sync when not recently synced' do
      expect(policy.can_sync_now?).to be true
    end

    it 'enforces sync frequency limits' do
      expect(policy.max_sync_frequency).to eq(15.minutes)
    end

    context 'with admin user' do
      let(:admin_user) { create(:user, role: :admin) }
      let(:admin_policy) { ChannelProduct::Policies::SynchronizationPolicy.new(channel_product, admin_user) }

      it 'allows more frequent syncs for admin' do
        expect(admin_policy.max_sync_frequency).to eq(5.minutes)
      end
    end
  end

  describe 'Integration between components' do
    it 'maintains data consistency across services' do
      # Update channel data
      channel_product.update_channel_data(title: 'Integration Test')

      # Check that presenter reflects changes
      presenter = ChannelProduct::Presenters::ChannelProductPresenter.new(channel_product)
      expect(presenter.as_json[:channel_title]).to eq('Integration Test')
    end

    it 'maintains referential integrity' do
      # Test that all components work together
      expect do
        channel_product.sync_from_product!
        channel_product.performance_metrics
        channel_product.health_check
        channel_product.update_channel_data(title: 'Test')
      end.not_to raise_error
    end

    it 'provides consistent API across different interfaces' do
      # Test that different ways of accessing data are consistent
      direct_price = channel_product.effective_price
      presenter_price = ChannelProduct::Presenters::ChannelProductPresenter.new(channel_product).as_json[:effective_price]

      expect(direct_price).to eq(presenter_price)
    end
  end

  describe 'Error handling' do
    it 'handles missing associations gracefully' do
      channel_product.product.destroy

      expect do
        channel_product.pricing
      end.not_to raise_error
    end

    it 'handles invalid data gracefully' do
      expect do
        channel_product.update_channel_data('invalid' => 'data')
      end.to raise_error(ChannelProduct::Services::ChannelDataError)
    end
  end

  describe 'Performance characteristics' do
    it 'caches value objects appropriately' do
      # First call should create the object
      pricing1 = channel_product.pricing
      pricing2 = channel_product.pricing

      # Should be the same cached instance
      expect(pricing1.object_id).to eq(pricing2.object_id)
    end

    it 'invalidates cache when needed' do
      pricing1 = channel_product.pricing
      channel_product.invalidate_instance_cache
      pricing2 = channel_product.pricing

      # Should be different instances after cache invalidation
      expect(pricing1.object_id).not_to eq(pricing2.object_id)
    end
  end
end