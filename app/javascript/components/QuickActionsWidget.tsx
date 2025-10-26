import React from 'react';
import QuickActionItem from './QuickActionItem';

// Type definitions for TypeScript
interface QuickAction {
  link: string;
  icon: string;
  text: string;
  badge?: number;
}

interface QuickActionsWidgetProps {
  actions: QuickAction[];
}

// Presentation component
const QuickActionsWidget: React.FC<QuickActionsWidgetProps> = React.memo(({ actions }) => {
  return (
    <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
      {actions.map((action, index) => (
        <QuickActionItem
          key={index}
          link={action.link}
          icon={<div dangerouslySetInnerHTML={{ __html: action.icon }} />}
          text={action.text}
          badge={action.badge}
        />
      ))}
    </div>
  );
});

export default QuickActionsWidget;