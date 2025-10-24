# frozen_string_literal: true

# Read Model: Optimized leaderboard for reputation rankings
# Pre-calculated rankings for fast leaderboard queries with caching
class ReputationLeaderboard < ApplicationRecord
  # Table configuration
  self.table_name = 'reputation_leaderboards'
  self.primary_key = 'id'

  # Attributes
  attribute :leaderboard_type, :string # 'daily', 'weekly', 'monthly', 'all_time'
  attribute :period_start, :date
  attribute :period_end, :date
  attribute :rankings, :jsonb # Array of user rankings
  attribute :total_participants, :integer
  attribute :last_calculated_at, :datetime

  # Validations
  validates :leaderboard_type, presence: true, inclusion: { in: %w[daily weekly monthly all_time] }
  validates :period_start, :period_end, presence: true
  validates :total_participants, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :by_type, ->(type) { where(leaderboard_type: type) }
  scope :current_period, -> { where('period_end >= ?', Date.current) }
  scope :recent, ->(days = 7) { where('period_end >= ?', days.days.ago.to_date) }
  scope :active, -> { where('last_calculated_at >= ?', 1.hour.ago) }

  # Optimized indexes
  # add_index :reputation_leaderboards, [:leaderboard_type, :period_end]
  # add_index :reputation_leaderboards, :total_participants
  # add_index :reputation_leaderboards, :last_calculated_at

  # Instance methods
  def rankings_data
    return [] unless rankings

    rankings.map do |ranking|
      {
        rank: ranking['rank'],
        user_id: ranking['user_id'],
        username: ranking['username'],
        score: ranking['score'],
        level: ranking['level'],
        change_from_previous: ranking['change_from_previous']
      }
    end
  end

  def top_user
    return nil if rankings.blank?

    top_ranking = rankings.first
    {
      user_id: top_ranking['user_id'],
      username: top_ranking['username'],
      score: top_ranking['score'],
      level: top_ranking['level']
    }
  end

  def user_rank(user_id)
    ranking = rankings.find { |r| r['user_id'] == user_id }
    ranking ? ranking['rank'] : nil
  end

  def user_score(user_id)
    ranking = rankings.find { |r| r['user_id'] == user_id }
    ranking ? ranking['score'] : nil
  end

  def percentile_rank(user_id)
    user_ranking = rankings.find { |r| r['user_id'] == user_id }
    return nil unless user_ranking

    (1 - (user_ranking['rank'].to_f / total_participants)) * 100
  end

  def rank_change_from_previous(user_id)
    ranking = rankings.find { |r| r['user_id'] == user_id }
    ranking ? ranking['change_from_previous'] : nil
  end

  def is_stale?
    last_calculated_at < 15.minutes.ago
  end

  def refresh_if_needed
    return unless is_stale?

    refresh!
  end

  def refresh!
    update!(last_calculated_at: Time.current)
    # Trigger recalculation would happen here
  end

  # Class methods for leaderboard management
  def self.get_leaderboard(type, date = Date.current)
    # Get or create leaderboard for the specified type and period
    period = calculate_period_for_type(type, date)

    leaderboard = find_or_initialize_by(
      leaderboard_type: type,
      period_start: period[:start],
      period_end: period[:end]
    )

    if leaderboard.new_record? || leaderboard.is_stale?
      leaderboard.calculate_rankings!
    end

    leaderboard
  end

  def self.refresh_all_leaderboards
    types = %w[daily weekly monthly all_time]
    updated_count = 0

    types.each do |type|
      begin
        get_leaderboard(type).refresh_if_needed
        updated_count += 1
      rescue StandardError => e
        Rails.logger.error("Failed to refresh #{type} leaderboard: #{e.message}")
      end
    end

    updated_count
  end

  def self.user_position_across_leaderboards(user_id)
    # Get user's position in all leaderboard types
    positions = {}

    %w[daily weekly monthly all_time].each do |type|
      leaderboard = get_leaderboard(type)
      positions[type] = {
        rank: leaderboard.user_rank(user_id),
        score: leaderboard.user_score(user_id),
        percentile: leaderboard.percentile_rank(user_id)
      }
    end

    positions
  end

  def self.calculate_rankings!(type, start_date, end_date)
    # Calculate rankings for the specified period
    events = UserReputationEvent.where(created_at: start_date..end_date)
    user_scores = events.group(:user_id).sum(:points_change)

    # Filter out users with zero or negative scores for most leaderboards
    if type != 'all_time'
      user_scores = user_scores.select { |_, score| score > 0 }
    end

    # Sort by score and assign ranks
    rankings = user_scores.sort_by { |_, score| -score }
                         .each_with_index
                         .map do |(user_id, score), index|
                           user = User.find_by(id: user_id)
                           next unless user

                           previous_rank = get_previous_rank(user_id, type, start_date)

                           {
                             rank: index + 1,
                             user_id: user_id,
                             username: user.username,
                             score: score,
                             level: ReputationLevel.from_score(score).to_s,
                             change_from_previous: calculate_rank_change(previous_rank, index + 1)
                           }
                         end.compact

    {
      rankings: rankings,
      total_participants: rankings.size,
      period_start: start_date.to_date,
      period_end: end_date.to_date,
      calculated_at: Time.current
    }
  end

  private

  def calculate_rankings!
    # Calculate rankings for this leaderboard
    start_time = Time.current

    result = self.class.calculate_rankings!(
      leaderboard_type,
      period_start,
      period_end
    )

    update!(
      rankings: result[:rankings],
      total_participants: result[:total_participants],
      last_calculated_at: result[:calculated_at]
    )

    Rails.logger.info("Calculated #{leaderboard_type} leaderboard in #{Time.current - start_time} seconds")
  end

  def self.calculate_period_for_type(type, date)
    case type
    when 'daily'
      { start: date.beginning_of_day, end: date.end_of_day }
    when 'weekly'
      start_date = date.beginning_of_week
      { start: start_date, end: start_date.end_of_week }
    when 'monthly'
      start_date = date.beginning_of_month
      { start: start_date, end: start_date.end_of_month }
    when 'all_time'
      { start: 1.year.ago, end: Time.current }
    else
      { start: date.beginning_of_day, end: date.end_of_day }
    end
  end

  def self.get_previous_rank(user_id, type, current_period_start)
    # Get user's rank in the previous period
    previous_period = calculate_previous_period(type, current_period_start)

    return nil if previous_period.nil?

    previous_leaderboard = find_by(
      leaderboard_type: type,
      period_start: previous_period[:start].to_date,
      period_end: previous_period[:end].to_date
    )

    return nil unless previous_leaderboard

    previous_leaderboard.user_rank(user_id)
  end

  def self.calculate_previous_period(type, current_start)
    case type
    when 'daily'
      previous_date = current_start.to_date.yesterday
      { start: previous_date.beginning_of_day, end: previous_date.end_of_day }
    when 'weekly'
      previous_date = current_start.to_date - 1.week
      start_date = previous_date.beginning_of_week
      { start: start_date, end: start_date.end_of_week }
    when 'monthly'
      previous_date = current_start.to_date - 1.month
      start_date = previous_date.beginning_of_month
      { start: start_date, end: start_date.end_of_month }
    else
      nil
    end
  end

  def self.calculate_rank_change(previous_rank, current_rank)
    return 0 unless previous_rank && current_rank

    previous_rank - current_rank # Positive means moved up
  end
end