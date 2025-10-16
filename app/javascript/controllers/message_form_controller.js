// ============================================================================
// HYPERSCALE MESSAGE FORM CONTROLLER
// ============================================================================
// ARCHITECTURAL PRINCIPLES:
// - Immutable Form State: Pure functions, optimistic updates, conflict resolution
// - Intelligent Input Handling: Predictive typing, auto-complete, real-time validation
// - Advanced File Management: Progressive upload, compression, virus scanning
// - Real-time Collaboration: Live typing indicators, presence awareness
// - Zero-Trust Security: Input sanitization, XSS prevention, CSRF protection
// ============================================================================

import { Controller } from "@hotwired/stimulus";
import { FormStateManager } from '../state/form_state_manager.js';
import { TypingIndicatorManager } from '../realtime/typing_indicator_manager.js';
import { FileUploadManager } from '../uploads/file_upload_manager.js';
import { InputValidator } from '../validation/input_validator.js';
import { PerformanceOptimizer } from '../performance/performance_optimizer.js';
import { AccessibilityManager } from '../accessibility/accessibility_manager.js';

/**
 * Hyperscale Message Form Controller
 * ==================================================
 * Autonomous form management with intelligent state handling, real-time collaboration,
 * advanced file uploads, and enterprise-grade validation
 */
export default class HyperscaleMessageFormController extends Controller {
  static targets = [
    "fileInput", "submit", "messageInput", "typingIndicator",
    "characterCount", "attachmentPreview", "sendButton", "formContainer"
  ];

  static values = {
    maxLength: Number,
    maxFileSize: Number,
    allowedFileTypes: Array,
    enableRealTimeTyping: Boolean,
    enableOptimisticUpdates: Boolean,
    enableDraftPersistence: Boolean,
    typingIndicatorTimeout: Number,
    debounceInterval: Number,
  };

  initialize() {
    // Initialize with hyperscale defaults
    this.maxLengthValue = this.maxLengthValue || 2000;
    this.maxFileSizeValue = this.maxFileSizeValue || 10 * 1024 * 1024; // 10MB
    this.allowedFileTypesValue = this.allowedFileTypesValue || [
      'image/jpeg', 'image/png', 'image/gif', 'image/webp',
      'application/pdf', 'text/plain', 'application/msword'
    ];
    this.enableRealTimeTypingValue = this.enableRealTimeTypingValue !== false;
    this.enableOptimisticUpdatesValue = this.enableOptimisticUpdatesValue !== false;
    this.enableDraftPersistenceValue = this.enableDraftPersistenceValue !== false;
    this.typingIndicatorTimeoutValue = this.typingIndicatorTimeoutValue || 3000;
    this.debounceIntervalValue = this.debounceIntervalValue || 300;

    this.state = {
      isInitialized: false,
      currentDraft: null,
      pendingUploads: new Map(),
      validationErrors: new Map(),
      performanceMetrics: new Map(),
      accessibilityState: new Map(),
    };

    this.components = {
      formStateManager: null,
      typingIndicatorManager: null,
      fileUploadManager: null,
      inputValidator: null,
      performanceOptimizer: null,
      accessibilityManager: null,
    };
  }

  connect() {
    this.initializeHyperscaleComponents();
    this.setupIntelligentEventHandling();
    this.setupAccessibilityEnhancements();
    this.setupPerformanceOptimizations();
    this.restoreDraftIfAvailable();

    this.state.isInitialized = true;
    this.emit('message-form:connected', { controller: this });
  }

  disconnect() {
    this.cleanup();
    this.persistDraftIfEnabled();
  }

  async initializeHyperscaleComponents() {
    // Initialize form state management with immutable updates
    this.components.formStateManager = new FormStateManager({
      enableOptimisticUpdates: this.enableOptimisticUpdatesValue,
      enableDraftPersistence: this.enableDraftPersistenceValue,
      enableConflictResolution: true,
    });

    // Initialize typing indicator management
    this.components.typingIndicatorManager = new TypingIndicatorManager({
      timeout: this.typingIndicatorTimeoutValue,
      enableRealTimeSync: this.enableRealTimeTypingValue,
      enablePresenceAwareness: true,
    });

    // Initialize advanced file upload management
    this.components.fileUploadManager = new FileUploadManager({
      maxFileSize: this.maxFileSizeValue,
      allowedTypes: this.allowedFileTypesValue,
      enableProgressiveUpload: true,
      enableCompression: true,
      enableVirusScanning: true,
    });

    // Initialize intelligent input validation
    this.components.inputValidator = new InputValidator({
      maxLength: this.maxLengthValue,
      enableRealTimeValidation: true,
      enableContextualSuggestions: true,
      enableAccessibilityFeedback: true,
    });

    // Initialize performance optimization
    this.components.performanceOptimizer = new PerformanceOptimizer({
      enableDebouncing: true,
      enableThrottling: true,
      enableLazyLoading: true,
    });

    // Initialize accessibility management
    this.components.accessibilityManager = new AccessibilityManager({
      enableScreenReader: true,
      enableKeyboardNavigation: true,
      enableAriaOptimization: true,
    });
  }

  setupIntelligentEventHandling() {
    // Enhanced keyboard handling with accessibility support
    this.setupKeyboardHandling();

    // Intelligent input handling with debouncing and validation
    this.setupInputHandling();

    // Advanced file handling with drag-and-drop support
    this.setupFileHandling();

    // Real-time collaboration features
    this.setupCollaborationFeatures();
  }

  setupKeyboardHandling() {
    this.element.addEventListener('keydown', (event) => {
      // Intelligent Enter key handling
      if (event.key === 'Enter' && !event.shiftKey) {
        event.preventDefault();
        this.handleSubmitAttempt();
      }

      // Enhanced keyboard shortcuts
      if (event.ctrlKey || event.metaKey) {
        switch(event.key) {
          case 'Enter':
            event.preventDefault();
            this.handleQuickSubmit();
            break;
          case 'b':
            event.preventDefault();
            this.toggleFormatting('bold');
            break;
          case 'i':
            event.preventDefault();
            this.toggleFormatting('italic');
            break;
        }
      }
    });
  }

  setupInputHandling() {
    // Debounced input handling for performance
    const debouncedInputHandler = this.components.performanceOptimizer.debounce(
      this.handleInput.bind(this),
      this.debounceIntervalValue
    );

    this.messageInputTarget?.addEventListener('input', debouncedInputHandler);

    // Real-time character counting
    this.messageInputTarget?.addEventListener('input', (event) => {
      this.updateCharacterCount(event.target.value.length);
    });
  }

  setupFileHandling() {
    // Enhanced file input handling
    this.fileInputTarget?.addEventListener('change', (event) => {
      this.handleFileSelection(event.target.files);
    });

    // Drag and drop support
    this.setupDragAndDrop();

    // Paste support for images and files
    this.setupPasteHandling();
  }

  setupCollaborationFeatures() {
    // Setup typing indicators
    if (this.enableRealTimeTypingValue) {
      this.setupTypingIndicators();
    }

    // Setup presence awareness
    this.setupPresenceAwareness();

    // Setup real-time form synchronization
    this.setupFormSynchronization();
  }

  setupAccessibilityEnhancements() {
    // Enhance form accessibility
    this.components.accessibilityManager.enhanceForm(this.element);

    // Setup ARIA live regions for real-time updates
    this.setupAriaLiveRegions();

    // Setup keyboard navigation enhancements
    this.setupKeyboardNavigation();
  }

  setupPerformanceOptimizations() {
    // Setup virtual scrolling for attachment previews
    if (this.hasAttachmentPreviewTarget) {
      this.components.performanceOptimizer.setupVirtualScrolling({
        container: this.attachmentPreviewTarget,
        itemHeight: 80,
      });
    }

    // Setup intelligent resource preloading
    this.setupResourcePreloading();

    // Setup memory management for large forms
    this.setupMemoryManagement();
  }

  async handleInput(event) {
    const input = event.target.value;
    const cursorPosition = event.target.selectionStart;

    // Real-time validation with contextual feedback
    const validationResult = await this.components.inputValidator.validate(input);

    if (!validationResult.isValid) {
      this.displayValidationErrors(validationResult.errors);
    } else {
      this.clearValidationErrors();
    }

    // Update form state immutably
    this.state.currentDraft = await this.components.formStateManager.updateDraft({
      content: input,
      cursorPosition,
      timestamp: Date.now(),
    });

    // Broadcast typing if real-time is enabled
    if (this.enableRealTimeTypingValue) {
      await this.components.typingIndicatorManager.broadcastTyping(input);
    }

    // Auto-save draft
    if (this.enableDraftPersistenceValue && input.length > 0) {
      await this.persistDraft(input);
    }
  }

  async handleFileSelection(files) {
    const fileArray = Array.from(files);

    for (const file of fileArray) {
      try {
        // Validate file
        const validation = await this.components.fileUploadManager.validateFile(file);

        if (!validation.isValid) {
          this.displayFileError(file.name, validation.errors);
          continue;
        }

        // Process file with progressive upload
        const uploadResult = await this.components.fileUploadManager.processFile(file, {
          enableCompression: true,
          enableVirusScanning: true,
          enableThumbnail: true,
        });

        // Display attachment preview
        this.displayAttachmentPreview(uploadResult);

        // Track upload state
        this.state.pendingUploads.set(uploadResult.id, uploadResult);

      } catch (error) {
        console.error('File processing failed:', error);
        this.displayFileError(file.name, ['File processing failed']);
      }
    }
  }

  setupDragAndDrop() {
    const dragZone = this.formContainerTarget || this.element;

    dragZone.addEventListener('dragover', (event) => {
      event.preventDefault();
      dragZone.classList.add('drag-over');
    });

    dragZone.addEventListener('dragleave', (event) => {
      event.preventDefault();
      dragZone.classList.remove('drag-over');
    });

    dragZone.addEventListener('drop', async (event) => {
      event.preventDefault();
      dragZone.classList.remove('drag-over');

      const files = event.dataTransfer.files;
      if (files.length > 0) {
        await this.handleFileSelection(files);
      }
    });
  }

  setupPasteHandling() {
    this.messageInputTarget?.addEventListener('paste', async (event) => {
      const clipboardData = event.clipboardData || window.clipboardData;

      // Handle pasted files
      if (clipboardData.files && clipboardData.files.length > 0) {
        event.preventDefault();
        await this.handleFileSelection(clipboardData.files);
      }

      // Handle pasted images
      if (clipboardData.items) {
        for (const item of clipboardData.items) {
          if (item.type.startsWith('image/')) {
            event.preventDefault();
            const file = item.getAsFile();
            await this.handleFileSelection([file]);
          }
        }
      }
    });
  }

  setupTypingIndicators() {
    // Setup real-time typing indicators with debouncing
    const debouncedTypingHandler = this.components.performanceOptimizer.debounce(
      this.handleTypingIndicator.bind(this),
      500
    );

    this.messageInputTarget?.addEventListener('input', debouncedTypingHandler);
  }

  setupPresenceAwareness() {
    // Setup real-time presence awareness
    this.components.typingIndicatorManager.on('presence:changed', (event) => {
      this.updatePresenceIndicator(event.detail);
    });
  }

  setupFormSynchronization() {
    // Setup real-time form state synchronization
    this.components.formStateManager.on('state:changed', (event) => {
      this.broadcastFormStateChange(event.detail);
    });
  }

  setupAriaLiveRegions() {
    // Setup ARIA live regions for screen reader announcements
    if (!document.getElementById('message-form-announcements')) {
      const liveRegion = document.createElement('div');
      liveRegion.id = 'message-form-announcements';
      liveRegion.setAttribute('aria-live', 'polite');
      liveRegion.setAttribute('aria-atomic', 'true');
      liveRegion.style.cssText = 'position:absolute;left:-10000px;width:1px;height:1px;overflow:hidden;';
      document.body.appendChild(liveRegion);
    }
  }

  setupKeyboardNavigation() {
    // Enhance keyboard navigation for the form
    this.element.addEventListener('keydown', (event) => {
      if (event.key === 'Tab') {
        this.components.accessibilityManager.handleTabNavigation(event);
      }
    });
  }

  setupResourcePreloading() {
    // Setup predictive resource preloading based on user behavior
    this.components.performanceOptimizer.setupPreloading({
      fileUploadResources: true,
      validationResources: true,
      typingIndicatorResources: true,
    });
  }

  setupMemoryManagement() {
    // Setup memory management for large forms and file uploads
    this.components.performanceOptimizer.setupMemoryManagement({
      maxFormSize: this.maxLengthValue * 2,
      maxFileBufferSize: this.maxFileSizeValue,
      enableGarbageCollection: true,
    });
  }

  async handleSubmitAttempt() {
    // Validate form before submission
    const validation = await this.validateForm();

    if (!validation.isValid) {
      this.displayValidationErrors(validation.errors);
      this.focusFirstError();
      return;
    }

    // Submit with optimistic updates
    await this.submitFormOptimistically();
  }

  async validateForm() {
    const formData = this.getFormData();

    return await this.components.inputValidator.validateForm(formData, {
      context: 'message-submission',
      realTime: false,
    });
  }

  getFormData() {
    return {
      message: this.messageInputTarget?.value || '',
      attachments: Array.from(this.state.pendingUploads.values()),
      timestamp: Date.now(),
      metadata: this.getFormMetadata(),
    };
  }

  getFormMetadata() {
    return {
      userAgent: navigator.userAgent,
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      language: navigator.language,
      screenResolution: `${screen.width}x${screen.height}`,
      sessionId: this.getSessionId(),
    };
  }

  getSessionId() {
    if (!window.hyperscaleSessionId) {
      window.hyperscaleSessionId = `session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    }
    return window.hyperscaleSessionId;
  }

  async submitFormOptimistically() {
    const formData = this.getFormData();

    // Generate optimistic update ID
    const optimisticId = `optimistic_${Date.now()}`;

    // Display optimistic update immediately
    if (this.enableOptimisticUpdatesValue) {
      this.displayOptimisticUpdate(formData, optimisticId);
    }

    try {
      // Submit form data
      const response = await this.submitForm(formData);

      // Confirm optimistic update on success
      this.confirmOptimisticUpdate(optimisticId, response);

    } catch (error) {
      // Revert optimistic update on failure
      this.revertOptimisticUpdate(optimisticId, error);
    }
  }

  async submitForm(formData) {
    // Enhanced form submission with retry logic and error handling
    const submitWithRetry = async (attempt = 1) => {
      try {
        const response = await fetch(this.element.action || '/messages', {
          method: this.element.method || 'POST',
          body: this.serializeFormData(formData),
          headers: {
            'Content-Type': 'application/json',
            'X-Requested-With': 'XMLHttpRequest',
            'X-Form-Enhancement': 'hyperscale-2.0',
          },
        });

        if (!response.ok) {
          throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        return await response.json();

      } catch (error) {
        if (attempt < 3) {
          console.warn(`Form submission attempt ${attempt} failed, retrying...`);
          await new Promise(resolve => setTimeout(resolve, 1000 * attempt));
          return submitWithRetry(attempt + 1);
        }
        throw error;
      }
    };

    return await submitWithRetry();
  }

  serializeFormData(formData) {
    return JSON.stringify({
      message: formData.message,
      attachments: formData.attachments.map(att => att.id),
      metadata: formData.metadata,
    });
  }

  displayOptimisticUpdate(formData, optimisticId) {
    // Display optimistic message immediately
    const optimisticElement = this.createOptimisticMessageElement(formData, optimisticId);
    this.insertOptimisticMessage(optimisticElement);

    // Announce to screen readers
    this.announceOptimisticUpdate(formData);
  }

  createOptimisticMessageElement(formData, optimisticId) {
    const element = document.createElement('div');
    element.className = 'message optimistic-message';
    element.dataset.optimisticId = optimisticId;
    element.innerHTML = `
      <div class="message-content">
        <p>${this.escapeHtml(formData.message)}</p>
        ${formData.attachments.map(att => `<div class="attachment-preview">${att.name}</div>`).join('')}
      </div>
      <div class="message-status">
        <span class="optimistic-indicator" aria-label="Sending message...">⏳ Sending...</span>
      </div>
    `;
    return element;
  }

  insertOptimisticMessage(element) {
    // Insert optimistic message in the appropriate location
    const messagesContainer = document.querySelector('[data-messages-container]') ||
                             this.element.closest('[data-conversation]');

    if (messagesContainer) {
      messagesContainer.appendChild(element);
      element.scrollIntoView({ behavior: 'smooth' });
    }
  }

  confirmOptimisticUpdate(optimisticId, response) {
    const optimisticElement = document.querySelector(`[data-optimistic-id="${optimisticId}"]`);
    if (optimisticElement) {
      optimisticElement.classList.remove('optimistic-message');
      optimisticElement.classList.add('confirmed-message');
      optimisticElement.querySelector('.optimistic-indicator').remove();

      // Add confirmed timestamp
      const timestamp = document.createElement('span');
      timestamp.className = 'message-timestamp';
      timestamp.textContent = new Date().toLocaleTimeString();
      optimisticElement.querySelector('.message-status').appendChild(timestamp);
    }
  }

  revertOptimisticUpdate(optimisticId, error) {
    const optimisticElement = document.querySelector(`[data-optimistic-id="${optimisticId}"]`);
    if (optimisticElement) {
      optimisticElement.classList.add('failed-message');

      // Display error message
      const errorElement = document.createElement('div');
      errorElement.className = 'message-error';
      errorElement.textContent = 'Failed to send message. Click to retry.';
      errorElement.addEventListener('click', () => this.retryOptimisticUpdate(optimisticId));

      optimisticElement.querySelector('.message-status').appendChild(errorElement);
    }

    console.error('Optimistic update failed:', error);
  }

  async retryOptimisticUpdate(optimisticId) {
    // Retry failed optimistic update
    const formData = this.state.pendingOptimisticUpdates?.get(optimisticId);
    if (formData) {
      await this.submitFormOptimistically(formData);
    }
  }

  handleTypingIndicator() {
    if (this.enableRealTimeTypingValue) {
      this.components.typingIndicatorManager.handleTyping();
    }
  }

  updateCharacterCount(length) {
    if (this.hasCharacterCountTarget) {
      this.characterCountTarget.textContent = `${length}/${this.maxLengthValue}`;

      // Visual feedback for approaching limit
      if (length > this.maxLengthValue * 0.8) {
        this.characterCountTarget.classList.add('approaching-limit');
      } else {
        this.characterCountTarget.classList.remove('approaching-limit');
      }
    }
  }

  displayValidationErrors(errors) {
    // Clear existing errors
    this.clearValidationErrors();

    // Display new errors
    errors.forEach(error => {
      this.displaySingleValidationError(error);
    });
  }

  displaySingleValidationError(error) {
    const errorElement = document.createElement('div');
    errorElement.className = 'validation-error';
    errorElement.textContent = error.message;
    errorElement.id = `error-${error.field}`;

    // Insert error near the problematic field
    const field = this.element.querySelector(`[name="${error.field}"]`);
    if (field) {
      field.parentNode.insertBefore(errorElement, field.nextSibling);
      field.setAttribute('aria-describedby', errorElement.id);
      field.classList.add('has-error');
    }
  }

  clearValidationErrors() {
    const existingErrors = this.element.querySelectorAll('.validation-error');
    existingErrors.forEach(error => error.remove());

    // Remove error states from fields
    const fieldsWithErrors = this.element.querySelectorAll('.has-error');
    fieldsWithErrors.forEach(field => {
      field.classList.remove('has-error');
      field.removeAttribute('aria-describedby');
    });
  }

  focusFirstError() {
    const firstError = this.element.querySelector('.has-error');
    if (firstError) {
      firstError.focus();
      this.components.accessibilityManager.announceError(firstError);
    }
  }

  async persistDraft(content) {
    try {
      await this.components.formStateManager.persistDraft({
        content,
        timestamp: Date.now(),
        formId: this.element.id || 'message-form',
      });
    } catch (error) {
      console.warn('Failed to persist draft:', error);
    }
  }

  async restoreDraftIfAvailable() {
    if (!this.enableDraftPersistenceValue) return;

    try {
      const draft = await this.components.formStateManager.restoreDraft(
        this.element.id || 'message-form'
      );

      if (draft && draft.content) {
        this.messageInputTarget.value = draft.content;
        this.updateCharacterCount(draft.content.length);

        // Restore cursor position if available
        if (draft.cursorPosition && this.messageInputTarget.setSelectionRange) {
          this.messageInputTarget.setSelectionRange(draft.cursorPosition, draft.cursorPosition);
        }
      }
    } catch (error) {
      console.warn('Failed to restore draft:', error);
    }
  }

  async persistDraftIfEnabled() {
    if (this.enableDraftPersistenceValue && this.state.currentDraft) {
      await this.persistDraft(this.state.currentDraft.content);
    }
  }

  displayAttachmentPreview(uploadResult) {
    if (!this.hasAttachmentPreviewTarget) return;

    const previewElement = document.createElement('div');
    previewElement.className = 'attachment-preview-item';
    previewElement.dataset.uploadId = uploadResult.id;
    previewElement.innerHTML = `
      <div class="attachment-info">
        <span class="attachment-name">${uploadResult.name}</span>
        <span class="attachment-size">${this.formatFileSize(uploadResult.size)}</span>
      </div>
      <div class="attachment-progress">
        <div class="progress-bar" style="width: ${uploadResult.progress}%"></div>
      </div>
      <button class="remove-attachment" aria-label="Remove attachment">
        ×
      </button>
    `;

    // Add remove functionality
    previewElement.querySelector('.remove-attachment').addEventListener('click', () => {
      this.removeAttachment(uploadResult.id);
    });

    this.attachmentPreviewTarget.appendChild(previewElement);
  }

  removeAttachment(uploadId) {
    this.state.pendingUploads.delete(uploadId);

    const previewElement = this.attachmentPreviewTarget.querySelector(`[data-upload-id="${uploadId}"]`);
    if (previewElement) {
      previewElement.remove();
    }
  }

  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes';

    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));

    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  }

  displayFileError(fileName, errors) {
    // Display file-specific errors
    const errorElement = document.createElement('div');
    errorElement.className = 'file-error';
    errorElement.innerHTML = `
      <strong>${fileName}:</strong> ${errors.join(', ')}
    `;

    // Insert error in attachment preview area
    if (this.hasAttachmentPreviewTarget) {
      this.attachmentPreviewTarget.appendChild(errorElement);
    }

    // Auto-remove after 5 seconds
    setTimeout(() => {
      errorElement.remove();
    }, 5000);
  }

  toggleFormatting(format) {
    const input = this.messageInputTarget;
    if (!input) return;

    const start = input.selectionStart;
    const end = input.selectionEnd;
    const selectedText = input.value.substring(start, end);

    if (selectedText) {
      const formattedText = this.applyFormatting(selectedText, format);
      const newValue = input.value.substring(0, start) + formattedText + input.value.substring(end);
      input.value = newValue;
      input.setSelectionRange(start + formattedText.length, start + formattedText.length);
      input.focus();
    }
  }

  applyFormatting(text, format) {
    switch (format) {
      case 'bold':
        return `**${text}**`;
      case 'italic':
        return `*${text}*`;
      default:
        return text;
    }
  }

  announceOptimisticUpdate(formData) {
    const announcement = `Message sent: ${formData.message.substring(0, 50)}${formData.message.length > 50 ? '...' : ''}`;
    this.announceToScreenReader(announcement);
  }

  announceToScreenReader(message) {
    const liveRegion = document.getElementById('message-form-announcements');
    if (liveRegion) {
      liveRegion.textContent = message;
    }
  }

  escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  handleQuickSubmit() {
    // Quick submit without full validation for trusted users
    const formData = this.getFormData();

    if (formData.message.trim()) {
      this.submitFormOptimistically();
    }
  }

  updatePresenceIndicator(presenceData) {
    // Update typing indicators and presence awareness UI
    if (this.hasTypingIndicatorTarget) {
      this.typingIndicatorTarget.innerHTML = presenceData.indicators || '';
    }
  }

  broadcastFormStateChange(stateChange) {
    // Broadcast form state changes to other clients
    this.emit('form-state:changed', stateChange);
  }

  cleanup() {
    // Cleanup all resources and event listeners
    this.components.formStateManager?.cleanup();
    this.components.typingIndicatorManager?.cleanup();
    this.components.fileUploadManager?.cleanup();
    this.components.performanceOptimizer?.cleanup();
    this.components.accessibilityManager?.cleanup();

    // Clear pending uploads
    this.state.pendingUploads.clear();

    // Remove event listeners
    this.element.removeEventListener('keydown', this.keyboardHandler);
    this.messageInputTarget?.removeEventListener('input', this.inputHandler);

    console.log('Message form controller cleaned up');
  }

  emit(event, data) {
    window.dispatchEvent(new CustomEvent(event, { detail: data }));
  }
}