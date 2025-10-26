import React from 'react';

// Type definitions for TypeScript
interface Activity {
  type?: string;
  title?: string;
  meta?: string;
  icon?: string;
  timestamp?: string;
}

interface ActivityItemProps {
  activity: Activity;
}

// Helper functions for calculations
const calculateRecencyScore = (timestamp: string): number => {
  const now = new Date();
  const time = new Date(timestamp);
  const diff = now.getTime() - time.getTime();
  const hours = diff / (1000 * 60 * 60);
  return hours < 1 ? 10 : hours < 24 ? 7 : 5;
};

const determineUrgency = (activity: Activity): number => {
  return activity.type === 'order' ? 5 : 3;
};

const assessRelevance = (activity: Activity): number => {
  return 5; // Simple implementation
};

const analyzePattern = (activity: Activity): string => {
  return 'normal';
};

const computePriorityClass = (recencyScore: number, urgency: number, relevance: number): string => {
  if (recencyScore >= 7) return 'high';
  return 'normal';
};

const computeAnimationDelay = (activity: Activity): number => {
  return 0; // Simple implementation
};

// Presentation component
const ActivityItem: React.FC<ActivityItemProps> = React.memo(({ activity }) => {
  const {
    type = 'default',
    title = 'Activity Event',
    meta = 'Unknown time',
    icon,
    timestamp = new Date().toISOString(),
  } = activity;

  const recencyScore = calculateRecencyScore(timestamp);
  const urgencyLevel = determineUrgency(activity);
  const relevanceScore = assessRelevance(activity);
  const behavioralPattern = analyzePattern(activity);
  const priorityClass = computePriorityClass(recencyScore, urgencyLevel, relevanceScore);
  const animationDelay = computeAnimationDelay(activity);

  // Icon based on type
  const getIcon = () => {
    if (icon) return <img src={icon} alt={title} className="w-8 h-8" />;
    const iconMap: Record<string, React.ReactNode> = {
      default: (
        <svg className="w-8 h-8 text-gray-600" fill="currentColor" viewBox="0 0 20 20">
          <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
        </svg>
      ),
      order: (
        <svg className="w-8 h-8 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
          <path d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z" />
        </svg>
      ),
      review: (
        <svg className="w-8 h-8 text-green-600" fill="currentColor" viewBox="0 0 20 20">
          <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
        </svg>
      ),
    };
    return iconMap[type] || iconMap.default;
  };

  const getPriorityColor = () => {
    const colors: Record<string, string> = {
      high: 'border-red-300 bg-red-100',
      normal: 'border-gray-300 bg-gray-100',
    };
    return colors[priorityClass] || colors.normal;
  };

  return (
    <div
      className={`flex items-start space-x-3 p-3 rounded-lg border-2 ${getPriorityColor()} transition-all duration-300 hover:shadow-lg focus-within:ring-2 focus-within:ring-blue-500`}
      style={{ animationDelay: `${animationDelay}ms` }}
      role="listitem"
      aria-label={`Activity: ${title}, type ${type}, recency ${recencyScore}`}
    >
      {/* Icon */}
      <div className="flex-shrink-0 w-8 h-8 flex items-center justify-center rounded-full bg-white">
        {getIcon()}
      </div>

      {/* Content */}
      <div className="flex-1 min-w-0">
        <h3 className="text-sm font-medium text-gray-900">{title}</h3>
        <p className="text-sm text-gray-500">{meta}</p>
        <p className="text-xs text-gray-400 mt-1">{new Date(timestamp).toLocaleString()}</p>
      </div>

      {/* Screen reader only */}
      <div className="sr-only">
        Activity {title} of type {type} with recency score {recencyScore}, urgency {urgencyLevel}, relevance {relevanceScore}.
      </div>
    </div>
  );
});

export default ActivityItem;