import { Controller } from '@hotwired/stimulus';
import React from 'react';
import ReactDOM from 'react-dom/client';
import QuickActionsWidget from '../components/QuickActionsWidget';

export default class extends Controller {
  connect() {
    const actions = JSON.parse(this.element.dataset.actions || '[]');
    const root = ReactDOM.createRoot(this.element);
    root.render(React.createElement(QuickActionsWidget, { actions }));
  }

  disconnect() {
    if (this.element) {
      const root = ReactDOM.createRoot(this.element);
      root.unmount();
    }
  }
}