class FraudAlertManagementService
  def self.acknowledge!(alert, by_user)
    alert.update!(
      acknowledged: true,
      acknowledged_at: Time.current,
      acknowledged_by: by_user
    )
  end

  def self.resolve!(alert, by_user, notes = nil)
    alert.update!(
      resolved: true,
      resolved_at: Time.current,
      resolved_by: by_user,
      resolution_notes: notes
    )
  end

  def self.get_badge_color(alert)
    Rails.cache.fetch("fraud_alert:#{alert.id}:badge_color", expires_in: 1.hour) do
      case alert.severity.to_sym
      when :high
        'red'
      when :medium
        'orange'
      when :low
        'yellow'
      end
    end
  end

  def self.critical?(alert)
    Rails.cache.fetch("fraud_alert:#{alert.id}:critical", expires_in: 1.hour) do
      alert.severity == 'high'
    end
  end
end