class BiometricAuthentication < ApplicationRecord
  belongs_to :user
  belongs_to :mobile_device
  
  validates :user, presence: true
  validates :mobile_device, presence: true
  validates :biometric_type, presence: true
  
  enum biometric_type: {
    fingerprint: 0,
    face_id: 1,
    iris_scan: 2,
    voice_recognition: 3
  }
  
  enum status: {
    active: 0,
    disabled: 1,
    revoked: 2
  }
  
  # Enroll biometric
  def self.enroll(user, device, biometric_type, biometric_data)
    authentication = find_or_initialize_by(
      user: user,
      mobile_device: device,
      biometric_type: biometric_type
    )
    
    authentication.assign_attributes(
      biometric_hash: hash_biometric_data(biometric_data),
      status: :active,
      enrolled_at: Time.current,
      last_verified_at: Time.current
    )
    
    authentication.save!
    authentication
  end
  
  # Verify biometric
  def verify(biometric_data)
    return false unless active?
    
    if hash_biometric_data(biometric_data) == biometric_hash
      update!(
        last_verified_at: Time.current,
        verification_count: verification_count + 1
      )
      true
    else
      increment!(:failed_attempts)
      false
    end
  end
  
  # Disable biometric
  def disable!
    update!(status: :disabled, disabled_at: Time.current)
  end
  
  private
  
  def self.hash_biometric_data(data)
    Digest::SHA256.hexdigest(data.to_s)
  end
end

