import { Controller } from '@hotwired/stimulus';
import React from 'react';
import ReactDOM from 'react-dom/client';
import OrderItemCompact from '../components/OrderItemCompact';

export default class extends Controller {
  connect() {
    const orderData = JSON.parse(this.element.dataset.order || '{}');
    const root = ReactDOM.createRoot(this.element);
    root.render(React.createElement(OrderItemCompact, { order: orderData }));
  }

  disconnect() {
    if (this.element) {
      const root = ReactDOM.createRoot(this.element);
      root.unmount();
    }
  }
}