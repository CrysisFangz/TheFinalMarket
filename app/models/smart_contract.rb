class SmartContract < ApplicationRecord
  belongs_to :order, optional: true
  belongs_to :creator, class_name: 'User'
  
  has_many :contract_executions, dependent: :destroy
  
  validates :contract_type, presence: true
  validates :contract_address, presence: true, uniqueness: true
  validates :contract_code, presence: true, if: :draft?
  
  scope :active, -> { where(status: :active) }
  scope :by_type, ->(type) { where(contract_type: type) }
  
  # Contract types
  enum contract_type: {
    escrow: 0,
    marketplace: 1,
    auction: 2,
    subscription: 3,
    royalty_distribution: 4,
    multi_signature: 5
  }
  
  # Contract status
  enum status: {
    draft: 0,
    deployed: 1,
    active: 2,
    completed: 3,
    cancelled: 4
  }
  
  # Deploy contract
  def deploy!
    service = SmartContractDeploymentService.new(self)
    result = service.call
    result.success?
  end

  def deploy_sync!
    service = SmartContractDeploymentService.new(self)
    result = service.call_sync
    result.success? ? result.value : false
  end

  # Activate contract
  def activate!
    service = SmartContractActivationService.new(self)
    result = service.call
    result.success?
  end

  # Execute contract function
  def execute_function(function_name, params = {})
    service = SmartContractExecutionService.new(self)
    result = service.call(function_name, params)
    result.success?
  end

  def execute_function_sync(function_name, params = {})
    service = SmartContractExecutionService.new(self)
    result = service.call_sync(function_name, params)
    result.success? ? result.value : false
  end

  # Escrow functions
  def deposit_to_escrow(amount_cents)
    execute_function('deposit', { amount: amount_cents })
  end

  def release_escrow(recipient_address)
    execute_function('release', { to: recipient_address })
  end

  def refund_escrow(sender_address)
    execute_function('refund', { to: sender_address })
  end

  # Get contract balance
  def balance
    SmartContractQueryService.balance(self)
  end

  # Get contract state
  def contract_state
    SmartContractQueryService.contract_state(self)
  end
  
  # Get blockchain explorer URL
  def blockchain_explorer_url
    return nil unless contract_address
    
    "https://polygonscan.com/address/#{contract_address}"
  end
  
  private

  # Clear cache after state changes
  after_update :clear_cache_if_needed

  def clear_cache_if_needed
    if saved_change_to_status? || saved_change_to_contract_address?
      SmartContractQueryService.clear_cache(self)
    end
  end
end


  # Log events for state changes
  def log_event(event_type, data = {})
    events.create!(
      event_type: event_type,
      data: data,
      occurred_at: Time.current
    )
  end
  # Indexes for scalability
  index :contract_address, unique: true
  index :status
  index :contract_type
  index :creator_id