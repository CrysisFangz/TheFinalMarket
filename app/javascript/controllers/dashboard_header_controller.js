import { Controller } from '@hotwired/stimulus';
import React from 'react';
import ReactDOM from 'react-dom/client';
import DashboardHeader from '../components/DashboardHeader';

export default class extends Controller {
  connect() {
    const userData = JSON.parse(this.element.dataset.currentUser || '{}');
    const root = ReactDOM.createRoot(this.element);
    root.render(React.createElement(DashboardHeader, { current_user: userData }));
  }

  disconnect() {
    const root = ReactDOM.createRoot(this.element);
    root.unmount();
  }
}