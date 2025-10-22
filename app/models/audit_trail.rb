class AuditTrail < ApplicationRecord
  belongs_to :record, polymorphic: true
  belongs_to :user
end