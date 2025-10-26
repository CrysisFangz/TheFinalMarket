import { Controller } from '@hotwired/stimulus';
import React from 'react';
import ReactDOM from 'react-dom/client';
import AchievementBadge from '../components/AchievementBadge';

export default class extends Controller {
  connect() {
    const achievementData = JSON.parse(this.element.dataset.achievement);
    const root = ReactDOM.createRoot(this.element);
    root.render(React.createElement(AchievementBadge, { achievement: achievementData }));
  }

  disconnect() {
    const root = ReactDOM.createRoot(this.element);
    root.unmount();
  }
}