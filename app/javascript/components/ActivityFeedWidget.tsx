import React, { useState } from 'react';

// Type definitions for TypeScript
interface Activity {
  id: number;
  type: string;
  title: string;
  description: string;
  timestamp: string;
  icon: string;
}

interface ActivityFeedWidgetProps {
  activities: Activity[];
  emptyMessage: string;
  emptyIcon: string;
}

// Filter button component
const FilterButton: React.FC<{ filter: string; label: string; active: boolean; onClick: () => void }> = React.memo(({ filter, label, active, onClick }) => {
  return (
    <button
      className={`px-4 py-2 rounded-lg font-medium transition-colors ${active ? 'bg-purple-600 text-white' : 'bg-gray-200 text-gray-700 hover:bg-gray-300'}`}
      onClick={onClick}
      aria-pressed={active}
    >
      {label}
    </button>
  );
});

// Activity item component
const ActivityItem: React.FC<{ activity: Activity }> = React.memo(({ activity }) => {
  return (
    <div className="flex items-start space-x-3 p-3 rounded-lg border border-gray-200 bg-white shadow-sm transition-all duration-200 hover:shadow-md">
      <div className="flex-shrink-0 w-8 h-8 flex items-center justify-center rounded-full bg-purple-100 text-purple-600">
        <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
          <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
        </svg>
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium text-gray-900">{activity.title}</p>
        <p className="text-sm text-gray-500">{activity.description}</p>
        <p className="text-xs text-gray-400 mt-1">{activity.timestamp}</p>
      </div>
    </div>
  );
});

// Main component
const ActivityFeedWidget: React.FC<ActivityFeedWidgetProps> = React.memo(({ activities, emptyMessage, emptyIcon }) => {
  const [activeFilter, setActiveFilter] = useState('all');

  const filteredActivities = activities.filter(activity => activeFilter === 'all' || activity.type === activeFilter);

  return (
    <div className="bg-gray-50 p-6 rounded-xl shadow-lg border border-gray-200">
      {/* Header */}
      <div className="mb-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-semibold text-gray-900 flex items-center space-x-2">
            <svg className="w-5 h-5 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
              <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z" clipRule="evenodd" />
            </svg>
            <span>Recent Activity</span>
          </h2>
        </div>

        {/* Filters */}
        <div className="flex space-x-2">
          <FilterButton filter="all" label="All" active={activeFilter === 'all'} onClick={() => setActiveFilter('all')} />
          <FilterButton filter="order" label="Orders" active={activeFilter === 'order'} onClick={() => setActiveFilter('order')} />
          <FilterButton filter="review" label="Reviews" active={activeFilter === 'review'} onClick={() => setActiveFilter('review')} />
        </div>
      </div>

      {/* Content */}
      <div className="space-y-3">
        {filteredActivities.length > 0 ? (
          filteredActivities.map(activity => (
            <ActivityItem key={activity.id} activity={activity} />
          ))
        ) : (
          <div className="text-center py-8">
            <svg className="w-12 h-12 text-gray-400 mx-auto mb-4" fill="currentColor" viewBox="0 0 20 20">
              <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z" clipRule="evenodd" />
            </svg>
            <p className="text-gray-500">{emptyMessage}</p>
          </div>
        )}
      </div>
    </div>
  );
});

export default ActivityFeedWidget;