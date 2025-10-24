class OfflineSync < ApplicationRecord
  belongs_to :user
  belongs_to :mobile_device
  
  validates :user, presence: true
  validates :mobile_device, presence: true
  validates :sync_type, presence: true
  
  enum sync_type: {
    cart: 0,
    wishlist: 1,
    product_view: 2,
    search: 3,
    order: 4,
    review: 5,
    settings: 6
  }
  
  enum sync_status: {
    pending: 0,
    syncing: 1,
    completed: 2,
    failed: 3,
    conflict: 4
  }
  
  # Scopes
  scope :pending_syncs, -> { where(sync_status: :pending) }
  scope :by_user, ->(user) { where(user: user) }
  scope :by_device, ->(device) { where(mobile_device: device) }
  
  # Queue offline action for sync
  def self.queue_action(user, device, sync_type, action_data)
    OfflineSyncManagementService.queue_action(user, device, sync_type, action_data)
  end

  # Process sync
  def process!
    update!(sync_status: :syncing, sync_started_at: Time.current)

    begin
      result = action_service.execute_sync_action

      if result[:success]
        update!(
          sync_status: :completed,
          sync_completed_at: Time.current,
          sync_result: result[:data]
        )
      else
        failure_service.handle_sync_failure(result[:error])
      end
    rescue => e
      failure_service.handle_sync_failure(e.message)
    end
  end

  # Process all pending syncs for user
  def self.process_pending_for_user(user, device)
    OfflineSyncManagementService.process_pending_for_user(user, device)
  end

  # Get sync statistics
  def self.statistics(user)
    OfflineSyncManagementService.statistics(user)
  end
  
  private

  def action_service
    @action_service ||= OfflineSyncActionService.new(self)
  end

  def failure_service
    @failure_service ||= OfflineSyncFailureService.new(self)
  end
end

