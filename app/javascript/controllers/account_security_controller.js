import { Controller } from '@hotwired/stimulus';
import React from 'react';
import ReactDOM from 'react-dom/client';
import AccountSecurityWidget from '../components/AccountSecurityWidget';

export default class extends Controller {
  connect() {
    const userData = JSON.parse(this.element.dataset.user);
    const root = ReactDOM.createRoot(this.element);
    root.render(React.createElement(AccountSecurityWidget, { user: userData }));
  }

  disconnect() {
    const root = ReactDOM.createRoot(this.element);
    root.unmount();
  }
}