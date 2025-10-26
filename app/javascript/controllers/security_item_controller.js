import { Controller } from '@hotwired/stimulus';
import React from 'react';
import ReactDOM from 'react-dom/client';
import SecurityItem from '../components/SecurityItem';

export default class extends Controller {
  connect() {
    const { type, user, icon, text, context, showTooltip, interactive } = this.element.dataset;

    const iconElement = icon ? this.parseIcon(icon) : undefined;

    const root = ReactDOM.createRoot(this.element);
    root.render(
      React.createElement(SecurityItem, {
        type,
        user: user ? JSON.parse(user) : undefined,
        icon: iconElement,
        text,
        context: context ? JSON.parse(context) : {},
        showTooltip: showTooltip !== 'false',
        interactive: interactive !== 'false'
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
    if (!iconHtml) return undefined;

    // Create a temporary div to parse HTML
    const tempDiv = document.createElement('div');
    tempDiv.innerHTML = iconHtml;
    return tempDiv.firstChild;
  }
}