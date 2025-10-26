import React from 'react';

// Type definitions for TypeScript
interface Achievement {
  type?: string;
  locked?: boolean;
  progress?: number;
  rarity?: string;
  category?: string;
  title?: string;
  description?: string;
  icon?: string;
  unlock_date?: string;
  points?: number;
}

interface AchievementBadgeProps {
  achievement: Achievement;
}

// Helper functions for calculations
const calculateRarityScore = (rarity: string, category: string): number => {
  const rarityScores: Record<string, number> = {
    common: 1,
    uncommon: 3,
    rare: 5,
    epic: 7,
    legendary: 10,
  };
  return rarityScores[rarity] || 1;
};

const assessUnlockComplexity = (achievement: Achievement): number => {
  return achievement.points ? achievement.points / 10 : 1;
};

const calculateProgressVelocity = (achievement: Achievement): number => {
  return achievement.progress ? achievement.progress / 100 : 0;
};

const computeAchievementValue = (points: number, rarityScore: number, unlockComplexity: number): number => {
  return points * rarityScore * unlockComplexity;
};

const determinePresentationMode = (rarityScore: number, locked: boolean, progress: number): string => {
  if (locked) return 'locked';
  if (progress >= 100) return 'unlocked';
  return 'in-progress';
};

const selectAnimationType = (rarityScore: number, unlockComplexity: number): string => {
  if (rarityScore >= 7) return 'epic';
  return 'standard';
};

const computeInteractionLevel = (progress: number, locked: boolean): number => {
  if (locked) return 0;
  if (progress >= 100) return 3;
  return 1;
};

// Presentation component
const AchievementBadge: React.FC<AchievementBadgeProps> = React.memo(({ achievement }) => {
  const {
    type = 'default',
    locked = false,
    progress = 0,
    rarity = 'common',
    category = 'general',
    title = 'Achievement',
    description = 'Complete this achievement to earn rewards',
    icon,
    points = 0,
  } = achievement;

  const rarityScore = calculateRarityScore(rarity, category);
  const unlockComplexity = assessUnlockComplexity(achievement);
  const progressVelocity = calculateProgressVelocity(achievement);
  const achievementValue = computeAchievementValue(points, rarityScore, unlockComplexity);
  const presentationMode = determinePresentationMode(rarityScore, locked, progress);
  const animationType = selectAnimationType(rarityScore, unlockComplexity);
  const interactionLevel = computeInteractionLevel(progress, locked);

  // Icon based on type
  const getIcon = () => {
    if (icon) return <img src={icon} alt={title} className="w-8 h-8" />;
    const iconMap: Record<string, React.ReactNode> = {
      default: (
        <svg className="w-8 h-8 text-gray-600" fill="currentColor" viewBox="0 0 20 20">
          <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
        </svg>
      ),
      // Add more types as needed
    };
    return iconMap[type] || iconMap.default;
  };

  const getRarityColor = () => {
    const colors: Record<string, string> = {
      common: 'border-gray-300 bg-gray-100',
      uncommon: 'border-green-300 bg-green-100',
      rare: 'border-blue-300 bg-blue-100',
      epic: 'border-purple-300 bg-purple-100',
      legendary: 'border-yellow-300 bg-yellow-100',
    };
    return colors[rarity] || colors.common;
  };

  return (
    <div
      className={`relative p-4 rounded-lg border-2 ${getRarityColor()} transition-all duration-300 hover:shadow-lg focus-within:ring-2 focus-within:ring-blue-500 ${locked ? 'opacity-50' : ''}`}
      role="img"
      aria-label={`Achievement: ${title}, ${locked ? 'locked' : 'unlocked'}, progress ${progress}%`}
    >
      {/* Icon */}
      <div className="flex items-center justify-center mb-3">
        {getIcon()}
      </div>

      {/* Title */}
      <h3 className="text-sm font-semibold text-gray-900 mb-2">{title}</h3>

      {/* Progress */}
      {interactionLevel > 1 && (
        <div className="mb-2">
          <div className="w-full bg-gray-200 rounded-full h-2">
            <div
              className="bg-blue-600 h-2 rounded-full transition-all duration-500"
              style={{ width: `${progress}%` }}
            ></div>
          </div>
          <p className="text-xs text-gray-600 mt-1">{progress}% complete</p>
        </div>
      )}

      {/* Points */}
      <p className="text-xs text-gray-500">Points: {points}</p>

      {/* Unlock animation */}
      {!locked && progress >= 100 && (
        <div className="absolute inset-0 rounded-lg bg-yellow-200 opacity-20 animate-pulse"></div>
      )}

      {/* Screen reader only */}
      <div className="sr-only">
        Achievement {title} is {locked ? 'locked' : 'unlocked'} with {progress}% progress, rarity {rarity}, worth {points} points.
      </div>
    </div>
  );
});

export default AchievementBadge;