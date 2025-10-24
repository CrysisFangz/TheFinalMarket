module TreasureHunt
  class QRCodeService
    include ServiceResultHelper

    def initialize(clue)
      @clue = clue
    end

    def call
      return failure('QR code already generated') if @clue.qr_code_value.present?

      # Schedule async generation
      GenerateQRCodeJob.perform_later(@clue.id)
      success('QR code generation scheduled')
    rescue StandardError => e
      Rails.logger.error("QR code service error: #{e.message}")
      failure('Failed to schedule QR code generation')
    end

    private

    def generate_code
      SecureRandom.hex(16)
    end
  end

  class GenerateQRCodeJob < ApplicationJob
    queue_as :default
    retry_on StandardError, wait: :exponentially_longer, attempts: 3

    def perform(clue_id)
      clue = TreasureHuntClue.find(clue_id)
      code = SecureRandom.hex(16)

      ActiveRecord::Base.transaction do
        clue.update!(qr_code_value: code)
        Rails.logger.info("QR code generated for clue #{clue.id}")
      end
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error("Clue not found for QR generation: #{e.message}")
    rescue StandardError => e
      Rails.logger.error("QR code generation failed: #{e.message}")
      raise e
    end
  end
end