# frozen_string_literal: true

# Cart Item State Definitions
# Defines all possible states for cart items with their semantic meanings
module CartItemStates
  # === State Constants ===
  ACTIVE = 'active'.freeze
  EXPIRED = 'expired'.freeze
  LOCKED = 'locked'.freeze
  CANCELLED = 'cancelled'.freeze
  PURCHASED = 'purchased'.freeze
  ABANDONED = 'abandoned'.freeze

  # === State Collections ===
  ALL_STATES = [
    ACTIVE,
    EXPIRED,
    LOCKED,
    CANCELLED,
    PURCHASED,
    ABANDONED
  ].freeze

  PURCHASABLE_STATES = [
    ACTIVE,
    LOCKED
  ].freeze

  MUTABLE_STATES = [
    ACTIVE,
    LOCKED
  ].freeze

  FINAL_STATES = [
    EXPIRED,
    CANCELLED,
    PURCHASED,
    ABANDONED
  ].freeze

  # === State Predicates ===
  def self.active?(state)
    state == ACTIVE
  end

  def self.expired?(state)
    state == EXPIRED
  end

  def self.locked?(state)
    state == LOCKED
  end

  def self.cancelled?(state)
    state == CANCELLED
  end

  def self.purchased?(state)
    state == PURCHASED
  end

  def self.abandoned?(state)
    state == ABANDONED
  end

  def self.purchasable?(state)
    PURCHASABLE_STATES.include?(state)
  end

  def self.mutable?(state)
    MUTABLE_STATES.include?(state)
  end

  def self.final?(state)
    FINAL_STATES.include?(state)
  end

  # === State Transition Rules ===
  def self.valid_transition?(from_state, to_state)
    transition_rules[from_state]&.include?(to_state) || false
  end

  def self.transition_rules
    @transition_rules ||= {
      ACTIVE => [LOCKED, EXPIRED, CANCELLED, PURCHASED, ABANDONED],
      LOCKED => [ACTIVE, EXPIRED, CANCELLED, PURCHASED],
      EXPIRED => [], # Final state
      CANCELLED => [], # Final state
      PURCHASED => [], # Final state
      ABANDONED => [] # Final state
    }.freeze
  end

  # === State Metadata ===
  def self.state_metadata
    @state_metadata ||= {
      ACTIVE => {
        description: 'Item is active in cart and available for purchase',
        color: 'green',
        icon: 'shopping_cart',
        timeout: nil
      },
      LOCKED => {
        description: 'Item is temporarily locked for purchase processing',
        color: 'yellow',
        icon: 'lock',
        timeout: 5.minutes
      },
      EXPIRED => {
        description: 'Item has expired from cart',
        color: 'red',
        icon: 'timer_off',
        timeout: nil
      },
      CANCELLED => {
        description: 'Item was cancelled from cart',
        color: 'grey',
        icon: 'cancel',
        timeout: nil
      },
      PURCHASED => {
        description: 'Item has been purchased',
        color: 'blue',
        icon: 'check_circle',
        timeout: nil
      },
      ABANDONED => {
        description: 'Item was abandoned in cart',
        color: 'orange',
        icon: 'remove_shopping_cart',
        timeout: nil
      }
    }.freeze
  end

  def self.state_info(state)
    state_metadata[state] || {}
  end
end