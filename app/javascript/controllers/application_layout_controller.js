import { Controller } from '@hotwired/stimulus';
import React from 'react';
import ReactDOM from 'react-dom/client';
import ApplicationLayout from '../components/ApplicationLayout';

export default class extends Controller {
  connect() {
    const userData = JSON.parse(this.element.dataset.currentUser || '{}');
    const notice = this.element.dataset.notice;
    const alert = this.element.dataset.alert;
    const yieldContent = this.element.dataset.yield;

    const root = ReactDOM.createRoot(this.element);
    root.render(React.createElement(ApplicationLayout, {
      current_user: userData,
      notice: notice,
      alert: alert,
      yield: yieldContent ? React.createElement('div', { dangerouslySetInnerHTML: { __html: yieldContent } }) : null
    }));
  }

  disconnect() {
    const root = ReactDOM.createRoot(this.element);
    root.unmount();
  }
}