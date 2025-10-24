# app/models/mobile_device.rb
class MobileDevice < ApplicationRecord
  belongs_to :user
  
  validates :device_id, presence: true, uniqueness: { scope: :user_id }
  validates :device_type, presence: true
  validates :os_version, presence: true
  
  enum device_type: {
    ios: 0,
    android: 1,
    other: 2
  }
  
  enum status: {
    active: 0,
    inactive: 1,
    blocked: 2
  }
  
  scope :active_devices, -> { where(status: :active) }
  scope :for_user, ->(user) { where(user: user) }
  scope :ios_devices, -> { where(device_type: :ios) }
  scope :android_devices, -> { where(device_type: :android) }
  
  # Delegated to MobileDeviceCapabilityService
  def touch_last_seen!
    update(last_seen_at: Time.current)
  end

  def supports_biometric?
    @capability_service ||= MobileDeviceCapabilityService.new(self)
    @capability_service.supports_biometric?
  end

  def supports_ar?
    @capability_service ||= MobileDeviceCapabilityService.new(self)
    @capability_service.supports_ar?
  end
end

