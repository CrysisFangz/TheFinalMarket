class MobileDeviceCapabilityService
  attr_reader :mobile_device

  def initialize(mobile_device)
    @mobile_device = mobile_device
  end

  def supports_biometric?
    Rails.logger.debug("Checking biometric support for MobileDevice ID: #{mobile_device.id}")
    return false unless mobile_device.metadata.present?

    mobile_device.metadata['biometric_available'] == true
  end

  def supports_ar?
    Rails.logger.debug("Checking AR support for MobileDevice ID: #{mobile_device.id}")
    return false unless mobile_device.metadata.present?

    mobile_device.metadata['ar_available'] == true
  end
end