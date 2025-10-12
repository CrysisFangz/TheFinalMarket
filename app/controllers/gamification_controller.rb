class GamificationController < ApplicationController
  before_action :authenticate_user!
  
  def dashboard
    @gamification_service = GamificationService.new(current_user)
    @stats = @gamification_service.stats
    @achievements = current_user.user_achievements.includes(:achievement).recent.limit(10)
    @daily_challenges = DailyChallenge.today.active
    @leaderboards = Leaderboard.active.limit(5)
  end
  
  def achievements
    @achievements = current_user.user_achievements
                                .includes(:achievement)
                                .order(earned_at: :desc)
                                .page(params[:page])
                                .per(20)
    
    @available_achievements = Achievement.active
                                        .where.not(id: current_user.achievements.pluck(:id))
                                        .order(tier: :asc, points: :desc)
  end
  
  def daily_challenges
    @challenges = DailyChallenge.today.active
    @user_challenges = current_user.user_daily_challenges.today.includes(:daily_challenge)
    @completed_count = @user_challenges.completed.count
    @total_count = @challenges.count
  end
  
  def leaderboards
    @leaderboard_type = params[:type] || 'points'
    @period = params[:period] || 'all_time'
    
    @leaderboard = Leaderboard.find_or_create_by!(
      leaderboard_type: @leaderboard_type,
      period: @period,
      name: "#{@leaderboard_type.titleize} - #{@period.titleize}"
    )
    
    @top_users = @leaderboard.top_users(100)
    @user_rank = @leaderboard.user_rank(current_user)
    @user_score = @leaderboard.user_score(current_user)
  end
  
  def check_achievements
    gamification_service = GamificationService.new(current_user)
    gamification_service.check_achievements
    
    new_achievements = current_user.user_achievements
                                   .where('earned_at > ?', 1.minute.ago)
                                   .includes(:achievement)
    
    render json: {
      new_achievements: new_achievements.map { |ua|
        {
          id: ua.achievement.id,
          name: ua.achievement.name,
          description: ua.achievement.description,
          icon_url: ua.achievement.icon_url,
          tier: ua.achievement.tier,
          points: ua.achievement.points
        }
      }
    }
  end
end

