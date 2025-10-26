import React from 'react';
import OrderItemCompact from './OrderItemCompact';

// Type definitions for TypeScript
interface Order {
  id: number;
  status: string;
  created_at: string;
  items_count?: number;
}

interface RecentOrdersWidgetProps {
  orders: Order[];
  emptyMessage: string;
  emptyIcon: string;
  actionLink: string;
  actionText: string;
}

// Presentation component
const RecentOrdersWidget: React.FC<RecentOrdersWidgetProps> = React.memo(({
  orders,
  emptyMessage,
  emptyIcon,
  actionLink,
  actionText
}) => {
  return (
    <div className="space-y-3">
      {orders.length > 0 ? (
        orders.map((order) => (
          <OrderItemCompact key={order.id} order={order} />
        ))
      ) : (
        <div className="text-center py-8">
          <div className="w-16 h-16 mx-auto mb-4 rounded-full bg-gray-100 flex items-center justify-center">
            <div dangerouslySetInnerHTML={{ __html: emptyIcon }} />
          </div>
          <p className="text-gray-500 mb-4">{emptyMessage}</p>
          <a
            href={actionLink}
            className="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            {actionText}
          </a>
        </div>
      )}
    </div>
  );
});

export default RecentOrdersWidget;