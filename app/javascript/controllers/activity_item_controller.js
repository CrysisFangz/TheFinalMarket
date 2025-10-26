import { Controller } from '@hotwired/stimulus';
import React from 'react';
import ReactDOM from 'react-dom/client';
import ActivityItem from '../components/ActivityItem';

export default class extends Controller {
  connect() {
    const activityData = JSON.parse(this.element.dataset.activity || '{}');
    const root = ReactDOM.createRoot(this.element);
    root.render(React.createElement(ActivityItem, { activity: activityData }));
  }

  disconnect() {
    const root = ReactDOM.createRoot(this.element);
    root.unmount();
  }
}