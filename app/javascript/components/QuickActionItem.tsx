import React from 'react';

// Type definitions for TypeScript
interface QuickActionItemProps {
  link: string;
  icon?: React.ReactNode;
  text: string;
  badge?: number;
}

// Presentation component
const QuickActionItem: React.FC<QuickActionItemProps> = React.memo(({ link, icon, text, badge }) => {
  return (
    <a
      href={link}
      className="flex items-center space-x-3 p-3 rounded-lg border border-gray-200 bg-white shadow-sm transition-all duration-200 hover:shadow-md hover:border-gray-300 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
      aria-label={text}
    >
      {icon && (
        <div className="flex-shrink-0 w-8 h-8 flex items-center justify-center rounded-full bg-blue-100 text-blue-600">
          {icon}
        </div>
      )}
      <span className="flex-1 text-sm font-medium text-gray-900">{text}</span>
      {badge && badge > 0 && (
        <span
          className="inline-flex items-center justify-center px-2 py-1 text-xs font-bold leading-none text-red-100 bg-red-600 rounded-full"
          aria-label={`${badge} unread items`}
        >
          {badge}
        </span>
      )}
    </a>
  );
});

export default QuickActionItem;