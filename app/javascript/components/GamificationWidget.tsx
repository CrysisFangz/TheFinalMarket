import React from 'react';
import AchievementBadge from './AchievementBadge';

// Type definitions for TypeScript
interface GamificationStats {
  user_level: number;
  reward_points: number;
  gamification_eligible: boolean;
}

interface GamificationWidgetProps {
  stats: GamificationStats;
}

// Presentation component
const GamificationWidget: React.FC<GamificationWidgetProps> = React.memo(({ stats }) => {
  const { user_level, reward_points, gamification_eligible } = stats;

  if (!gamification_eligible) return null;

  const maxPoints = user_level * 1000;
  const progressPercentage = (reward_points / maxPoints) * 100;

  return (
    <div className="bg-gray-50 p-6 rounded-xl shadow-lg border border-gray-200">
      {/* Header */}
      <div className="mb-6">
        <h2 className="text-lg font-semibold text-gray-900 flex items-center space-x-2">
          <svg className="w-5 h-5 text-purple-600" fill="currentColor" viewBox="0 0 20 20">
            <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
          </svg>
          <span>Your Progress</span>
        </h2>
      </div>

      {/* Content */}
      <div className="space-y-4">
        {/* Level Badge */}
        <div className="text-center">
          <div className="text-2xl font-bold text-purple-600">{user_level}</div>
          <div className="text-sm text-gray-500">Active Shopper</div>
        </div>

        {/* Points Progress */}
        <div>
          <div className="w-full bg-gray-200 rounded-full h-2 mb-2">
            <div
              className="bg-purple-600 h-2 rounded-full transition-all duration-500"
              style={{ width: `${progressPercentage}%` }}
              role="progressbar"
              aria-valuenow={reward_points}
              aria-valuemin={0}
              aria-valuemax={maxPoints}
              aria-label={`${reward_points} out of ${maxPoints} points to next level`}
            ></div>
          </div>
          <p className="text-sm text-gray-600">{reward_points} / {maxPoints} points to next level</p>
        </div>

        {/* Achievements Preview */}
        <div className="flex justify-center space-x-2">
          <AchievementBadge achievement={{ type: 'trophy', locked: false, progress: 100 }} />
          <AchievementBadge achievement={{ type: 'star', locked: false, progress: 100 }} />
          <AchievementBadge achievement={{ type: 'diamond', locked: false, progress: 100 }} />
          <AchievementBadge achievement={{ type: 'locked', locked: true, progress: 0 }} />
        </div>

        {/* View All Rewards Button */}
        <a href="/gamification" className="block w-full text-center bg-purple-600 text-white py-2 px-4 rounded-lg hover:bg-purple-700 transition-colors">
          View All Rewards →
        </a>
      </div>
    </div>
  );
});

export default GamificationWidget;