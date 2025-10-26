import { Controller } from '@hotwired/stimulus';
import React from 'react';
import ReactDOM from 'react-dom/client';
import EmptyWidget from '../components/EmptyWidget';

export default class extends Controller {
  connect() {
    const icon = this.element.dataset.icon;
    const message = this.element.dataset.message;
    const actionLink = this.element.dataset.actionLink;
    const actionText = this.element.dataset.actionText;
    const actionClass = this.element.dataset.actionClass;

    const root = ReactDOM.createRoot(this.element);
    root.render(React.createElement(EmptyWidget, {
      icon: icon ? React.createElement('div', { dangerouslySetInnerHTML: { __html: icon } }) : null,
      message: message,
      actionLink: actionLink,
      actionText: actionText,
      actionClass: actionClass
    }));
  }

  disconnect() {
    const root = ReactDOM.createRoot(this.element);
    root.unmount();
  }
}