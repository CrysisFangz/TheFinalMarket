import { Controller } from '@hotwired/stimulus';
import React from 'react';
import ReactDOM from 'react-dom/client';
import QuickActionItem from '../components/QuickActionItem';

export default class extends Controller {
  connect() {
    const { link, icon, text, badge } = this.element.dataset;
    const iconElement = icon ? this.parseIcon(icon) : null;

    const root = ReactDOM.createRoot(this.element);
    root.render(
      React.createElement(QuickActionItem, {
        link,
        icon: iconElement,
        text,
        badge: badge ? parseInt(badge, 10) : undefined
      })
    );
  }

  disconnect() {
    if (this.element) {
      const root = ReactDOM.createRoot(this.element);
      root.unmount();
    }
  }

  parseIcon(iconHtml) {
    // Create a temporary div to parse HTML
    const tempDiv = document.createElement('div');
    tempDiv.innerHTML = iconHtml;
    return tempDiv.firstChild;
  }
}