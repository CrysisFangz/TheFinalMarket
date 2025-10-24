class NotifyEventStartJob < ApplicationJob
  queue_as :default

  def perform(event_id)
    event = SeasonalEvent.find(event_id)
    User.find_in_batches(batch_size: 1000) do |users|
      users.each do |user|
        Notification.create!(
          recipient: user,
          notifiable: event,
          notification_type: 'seasonal_event_started',
          title: "#{event.name} Has Started!",
          message: event.description,
          data: { event_type: event.event_type, ends_at: event.ends_at }
        )
      end
    end
  end
end