import { Controller } from '@hotwired/stimulus';
import React from 'react';
import ReactDOM from 'react-dom/client';
import GamificationWidget from '../components/GamificationWidget';

export default class extends Controller {
  connect() {
    const statsData = JSON.parse(this.element.dataset.stats || '{}');
    const root = ReactDOM.createRoot(this.element);
    root.render(React.createElement(GamificationWidget, { stats: statsData }));
  }

  disconnect() {
    const root = ReactDOM.createRoot(this.element);
    root.unmount();
  }
}