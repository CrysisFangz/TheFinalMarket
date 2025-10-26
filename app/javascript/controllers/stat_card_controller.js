import { Controller } from '@hotwired/stimulus';
import React from 'react';
import ReactDOM from 'react-dom/client';
import StatCard from '../components/StatCard';

export default class extends Controller {
  connect() {
    const {
      statType,
      iconSvg,
      value,
      label,
      change,
      link,
      linkText,
      context,
      interactive
    } = this.element.dataset;

    const root = ReactDOM.createRoot(this.element);
    root.render(
      React.createElement(StatCard, {
        statType,
        iconSvg,
        value,
        label,
        change: change ? parseFloat(change) : undefined,
        link,
        linkText,
        context: context ? JSON.parse(context) : {},
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
}