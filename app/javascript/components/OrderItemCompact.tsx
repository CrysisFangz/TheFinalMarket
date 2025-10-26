import React from 'react';

// Type definitions for TypeScript
interface Order {
  id: number;
  status: string;
  created_at: string;
  items_count?: number;
}

interface OrderItemCompactProps {
  order: Order;
}

// Presentation component
const OrderItemCompact: React.FC<OrderItemCompactProps> = React.memo(({ order }) => {
  const { id, status, created_at, items_count = 1 } = order;

  const getStatusColor = () => {
    const colors: Record<string, string> = {
      pending: 'bg-yellow-100 text-yellow-800',
      processing: 'bg-blue-100 text-blue-800',
      shipped: 'bg-purple-100 text-purple-800',
      delivered: 'bg-green-100 text-green-800',
      cancelled: 'bg-red-100 text-red-800',
    };
    return colors[status] || 'bg-gray-100 text-gray-800';
  };

  return (
    <div className="flex items-center space-x-3 p-3 rounded-lg border border-gray-200 bg-white shadow-sm transition-all duration-200 hover:shadow-md">
      {/* Icon */}
      <div className="flex-shrink-0 w-8 h-8 flex items-center justify-center rounded-full bg-purple-100 text-purple-600">
        <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
          <path d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z" />
        </svg>
      </div>

      {/* Details */}
      <div className="flex-1 min-w-0">
        <h3 className="text-sm font-medium text-gray-900">Order #{id}</h3>
        <p className="text-sm text-gray-500">{new Date(created_at).toLocaleDateString()} • {items_count} items</p>
      </div>

      {/* Status */}
      <div className="flex-shrink-0">
        <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getStatusColor()}`} role="status" aria-label={status}>
          {status.charAt(0).toUpperCase() + status.slice(1)}
        </span>
      </div>
    </div>
  );
});

export default OrderItemCompact;