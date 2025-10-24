class WalletOperationsService
  def self.hold_funds(wallet, amount)
    wallet.with_lock do
      if wallet.balance >= amount
        wallet.balance -= amount
        wallet.held_balance += amount
        wallet.save!
        true
      else
        false
      end
    end
  end

  def self.release_funds(wallet, amount)
    wallet.with_lock do
      if wallet.held_balance >= amount
        wallet.held_balance -= amount
        wallet.save!
        true
      else
        false
      end
    end
  end

  def self.receive_funds(wallet, amount)
    wallet.with_lock do
      wallet.balance += amount
      wallet.save!
    end
  end

  def self.withdraw_funds(wallet, amount)
    wallet.with_lock do
      if wallet.balance >= amount
        wallet.balance -= amount
        wallet.save!
        true
      else
        false
      end
    end
  end
end