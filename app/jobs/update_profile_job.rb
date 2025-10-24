# frozen_string_literal: true

class UpdateProfileJob < ApplicationJob
  queue_as :default

  def perform(profile_id)
    profile = PersonalizationProfile.find(profile_id)
    calculator = ScoringCalculator.new(profile)
    manager = SegmentManager.new(profile)

    scores = calculator.recalculate_scores
    profile.update!(scores)
    manager.update_segments
  rescue ActiveRecord::RecordNotFound
    # Handle if profile is deleted
  end
end