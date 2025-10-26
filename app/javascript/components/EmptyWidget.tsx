import React from 'react';

// Type definitions for TypeScript
interface EmptyWidgetProps {
  icon?: React.ReactNode;
  message: string;
  actionLink?: string;
  actionText?: string;
  actionClass?: string;
}

// Presentation component
const EmptyWidget: React.FC<EmptyWidgetProps> = React.memo(({ icon, message, actionLink, actionText, actionClass }) => {
  return (
    <div className="text-center py-8">
      {icon ? (
        <div className="mb-4">{icon}</div>
      ) : (
        <svg className="w-12 h-12 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
        </svg>
      )}
      <p className="text-gray-500 mb-4">{message}</p>
      {actionLink && actionText && (
        <a href={actionLink} className={`inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-purple-600 hover:bg-purple-700 transition-colors ${actionClass}`}>
          {actionText}
        </a>
      )}
    </div>
  );
});

export default EmptyWidget;