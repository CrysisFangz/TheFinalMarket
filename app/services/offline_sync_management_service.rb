class OfflineSyncManagementService
  def self.queue_action(user, device, sync_type, action_data)
    Rails.logger.info("Queueing offline sync action for user: #{user.id}, device: #{device.id}, type: #{sync_type}")

    begin
      sync = OfflineSync.create!(
        user: user,
        mobile_device: device,
        sync_type: sync_type,
        action_data: action_data,
        sync_status: :pending,
        queued_at: Time.current
      )
      Rails.logger.info("Successfully queued offline sync action ID: #{sync.id}")
      sync
    rescue => e
      Rails.logger.error("Failed to queue offline sync action for user: #{user.id}. Error: #{e.message}")
      Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
      raise e
    end
  end

  def self.process_pending_for_user(user, device)
    Rails.logger.info("Processing pending syncs for user: #{user.id}, device: #{device.id}")

    begin
      pending_syncs = OfflineSync.pending_syncs.where(user: user, mobile_device: device)
      processed_count = 0

      pending_syncs.find_each do |sync|
        sync.process!
        processed_count += 1
      end

      Rails.logger.info("Successfully processed #{processed_count} syncs for user: #{user.id}")
      processed_count
    rescue => e
      Rails.logger.error("Failed to process pending syncs for user: #{user.id}. Error: #{e.message}")
      Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
      raise e
    end
  end

  def self.statistics(user)
    Rails.logger.debug("Generating sync statistics for user: #{user.id}")

    begin
      stats = {
        total_syncs: OfflineSync.where(user: user).count,
        pending: OfflineSync.where(user: user, sync_status: :pending).count,
        completed: OfflineSync.where(user: user, sync_status: :completed).count,
        failed: OfflineSync.where(user: user, sync_status: :failed).count,
        conflicts: OfflineSync.where(user: user, sync_status: :conflict).count
      }

      Rails.logger.debug("Generated sync statistics for user: #{user.id}: #{stats}")
      stats
    rescue => e
      Rails.logger.error("Failed to generate sync statistics for user: #{user.id}. Error: #{e.message}")
      {
        total_syncs: 0,
        pending: 0,
        completed: 0,
        failed: 0,
        conflicts: 0,
        error: e.message
      }
    end
  end

  def self.process_all_pending
    Rails.logger.info("Processing all pending offline syncs")

    begin
      pending_count = OfflineSync.pending_syncs.count
      processed_count = 0

      OfflineSync.pending_syncs.find_each do |sync|
        sync.process!
        processed_count += 1
      end

      Rails.logger.info("Successfully processed #{processed_count}/#{pending_count} pending syncs")
      { processed: processed_count, total: pending_count }
    rescue => e
      Rails.logger.error("Failed to process all pending syncs. Error: #{e.message}")
      Rails.logger.error("Backtrace: #{e.backtrace.join("\n")}")
      { processed: 0, total: 0, error: e.message }
    end
  end
end