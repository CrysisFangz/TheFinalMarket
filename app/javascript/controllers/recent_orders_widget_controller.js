import { Controller } from '@hotwired/stimulus';
import React from 'react';
import ReactDOM from 'react-dom/client';
import RecentOrdersWidget from '../components/RecentOrdersWidget';

export default class extends Controller {
  connect() {
    const orders = JSON.parse(this.element.dataset.orders || '[]');
    const emptyMessage = this.element.dataset.emptyMessage;
    const emptyIcon = this.element.dataset.emptyIcon;
    const actionLink = this.element.dataset.actionLink;
    const actionText = this.element.dataset.actionText;

    const root = ReactDOM.createRoot(this.element);
    root.render(
      React.createElement(RecentOrdersWidget, {
        orders,
        emptyMessage,
        emptyIcon,
        actionLink,
        actionText
      })
    );
  }

  disconnect() {
    if (this.element) {
      const root = ReactDOM.createRoot(this.element);
      root.unmount();
    }
  }
}