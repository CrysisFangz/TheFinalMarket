import { Controller } from '@hotwired/stimulus';
import React from 'react';
import ReactDOM from 'react-dom/client';
import ActivityFeedWidget from '../components/ActivityFeedWidget';

export default class extends Controller {
  connect() {
    const activitiesData = JSON.parse(this.element.dataset.activities || '[]');
    const emptyMessage = this.element.dataset.emptyMessage;
    const emptyIcon = this.element.dataset.emptyIcon;

    const root = ReactDOM.createRoot(this.element);
    root.render(React.createElement(ActivityFeedWidget, {
      activities: activitiesData,
      emptyMessage: emptyMessage,
      emptyIcon: emptyIcon
    }));
  }

  disconnect() {
    const root = ReactDOM.createRoot(this.element);
    root.unmount();
  }
}