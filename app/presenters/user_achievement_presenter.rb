class UserAchievementPresenter
  def initialize(user_achievement)
    @user_achievement = user_achievement
  end

  def completed?
    @user_achievement.progress >= 100
  end

  def progress_percentage
    "#{@user_achievement.progress}%"
  end

  def as_json(options = {})
    {
      id: @user_achievement.id,
      progress: @user_achievement.progress,
      completed: completed?,
      progress_percentage: progress_percentage,
      earned_at: @user_achievement.earned_at,
      user: @user_achievement.user,
      achievement: @user_achievement.achievement
    }
  end
end