/**
 * Advanced Service Worker for Web Push Notifications
 * Enterprise-grade implementation with comprehensive error handling,
 * performance optimizations, and modular architecture
 *
 * @version 2.0.0
 * @author Kilo Code - Omnipotent Systems Architect
 */

// ==========================================
// CONSTANTS & CONFIGURATION
// ==========================================

/**
 * Service Worker Configuration
 * Centralized configuration management for optimal maintainability
 */
const SW_CONFIG = {
  VERSION: '2.0.0',
  CACHE_NAME: 'pwa-notifications-v1',
  MAX_RETRY_ATTEMPTS: 3,
  RETRY_DELAYS: [1000, 2000, 4000], // Progressive backoff in milliseconds
  NOTIFICATION_TIMEOUT: 5000,
  MAX_NOTIFICATION_LENGTH: 1000,
  SUPPORTED_ACTIONS: ['navigate', 'focus', 'open', 'dismiss'],
  LOG_LEVEL: 'info', // 'debug', 'info', 'warn', 'error'
  PERFORMANCE_MONITORING: true
};

/**
 * Notification Categories and Their Default Behaviors
 */
const NOTIFICATION_CATEGORIES = {
  ORDER: {
    icon: '/icons/order.png',
    badge: '/icons/badge.png',
    tag: 'order-update',
    requireInteraction: false,
    silent: false,
    actions: [
      { action: 'view', title: 'View Order', icon: '/icons/eye.png' },
      { action: 'track', title: 'Track Package', icon: '/icons/track.png' }
    ]
  },
  MESSAGE: {
    icon: '/icons/message.png',
    badge: '/icons/badge.png',
    tag: 'message',
    requireInteraction: true,
    silent: false,
    actions: [
      { action: 'reply', title: 'Reply', icon: '/icons/reply.png' },
      { action: 'view', title: 'View Chat', icon: '/icons/chat.png' }
    ]
  },
  PROMOTION: {
    icon: '/icons/promo.png',
    badge: '/icons/badge.png',
    tag: 'promotion',
    requireInteraction: false,
    silent: true,
    actions: [
      { action: 'view', title: 'View Deal', icon: '/icons/deal.png' }
    ]
  }
};

// ==========================================
// UTILITY CLASSES & FUNCTIONS
// ==========================================

/**
 * Advanced Logger with Performance Monitoring
 * Provides structured logging with different severity levels
 */
class ServiceWorkerLogger {
  constructor(config) {
    this.config = config;
    this.performanceMarks = new Map();
  }

  /**
   * Log message with timestamp and context
   * @param {string} level - Log level
   * @param {string} message - Log message
   * @param {Object} context - Additional context data
   */
  log(level, message, context = {}) {
    if (this.shouldLog(level)) {
      const timestamp = new Date().toISOString();
      const logEntry = {
        timestamp,
        level,
        message,
        context,
        version: SW_CONFIG.VERSION
      };

      console[level](`[SW:${level.toUpperCase()}]`, message, logEntry);

      // Store performance metrics if enabled
      if (SW_CONFIG.PERFORMANCE_MONITORING && context.duration) {
        this.recordPerformanceMetric(message, context.duration);
      }
    }
  }

  /**
   * Check if message should be logged based on configured level
   * @param {string} level - Log level to check
   * @returns {boolean} Whether to log the message
   */
  shouldLog(level) {
    const levels = ['debug', 'info', 'warn', 'error'];
    const configLevel = levels.indexOf(SW_CONFIG.LOG_LEVEL);
    const messageLevel = levels.indexOf(level);
    return messageLevel >= configLevel;
  }

  /**
   * Record performance metric for monitoring
   * @param {string} operation - Operation name
   * @param {number} duration - Duration in milliseconds
   */
  recordPerformanceMetric(operation, duration) {
    if (!this.performanceMarks.has(operation)) {
      this.performanceMarks.set(operation, []);
    }
    this.performanceMarks.get(operation).push(duration);
  }

  /**
   * Get performance statistics
   * @returns {Object} Performance metrics
   */
  getPerformanceStats() {
    const stats = {};
    for (const [operation, durations] of this.performanceMarks) {
      stats[operation] = {
        count: durations.length,
        average: durations.reduce((a, b) => a + b, 0) / durations.length,
        min: Math.min(...durations),
        max: Math.max(...durations)
      };
    }
    return stats;
  }

  debug(message, context) { this.log('debug', message, context); }
  info(message, context) { this.log('info', message, context); }
  warn(message, context) { this.log('warn', message, context); }
  error(message, context) { this.log('error', message, context); }
}

/**
 * Retry Mechanism with Exponential Backoff
 * Handles transient failures gracefully
 */
class RetryHandler {
  constructor(config) {
    this.config = config;
  }

  /**
   * Execute operation with retry logic
   * @param {Function} operation - Operation to retry
   * @param {string} operationName - Name for logging
   * @returns {Promise} Operation result
   */
  async executeWithRetry(operation, operationName) {
    let lastError;

    for (let attempt = 0; attempt <= SW_CONFIG.MAX_RETRY_ATTEMPTS; attempt++) {
      try {
        const startTime = performance.now();
        const result = await operation();
        const duration = performance.now() - startTime;

        logger.info(`${operationName} succeeded on attempt ${attempt + 1}`, {
          duration,
          attempt: attempt + 1
        });

        return result;
      } catch (error) {
        lastError = error;

        logger.warn(`${operationName} failed on attempt ${attempt + 1}`, {
          error: error.message,
          attempt: attempt + 1
        });

        if (attempt < SW_CONFIG.MAX_RETRY_ATTEMPTS) {
          const delay = SW_CONFIG.RETRY_DELAYS[attempt] || SW_CONFIG.RETRY_DELAYS[SW_CONFIG.RETRY_DELAYS.length - 1];
          await this.delay(delay * (attempt + 1)); // Progressive delay
        }
      }
    }

    logger.error(`${operationName} failed after ${SW_CONFIG.MAX_RETRY_ATTEMPTS + 1} attempts`, {
      error: lastError.message
    });
    throw lastError;
  }

  /**
   * Delay execution for specified milliseconds
   * @param {number} ms - Milliseconds to delay
   * @returns {Promise} Promise that resolves after delay
   */
  delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

/**
 * Notification Data Validator and Sanitizer
 * Ensures notification data integrity and security
 */
class NotificationValidator {
  /**
   * Validate and sanitize notification data
   * @param {Object} data - Raw notification data
   * @returns {Object} Validated and sanitized data
   */
  validateAndSanitize(data) {
    try {
      if (!data || typeof data !== 'object') {
        throw new Error('Invalid notification data: must be an object');
      }

      const sanitized = {};

      // Validate and sanitize title
      if (data.title) {
        sanitized.title = this.sanitizeString(data.title, SW_CONFIG.MAX_NOTIFICATION_LENGTH);
      } else {
        throw new Error('Notification title is required');
      }

      // Validate and sanitize body
      if (data.body) {
        sanitized.body = this.sanitizeString(data.body, SW_CONFIG.MAX_NOTIFICATION_LENGTH);
      }

      // Validate and sanitize icon
      if (data.icon) {
        sanitized.icon = this.validateUrl(data.icon);
      }

      // Validate and sanitize badge
      if (data.badge) {
        sanitized.badge = this.validateUrl(data.badge);
      }

      // Validate and sanitize data
      if (data.data) {
        sanitized.data = this.validateNotificationData(data.data);
      }

      // Validate actions
      if (data.actions && Array.isArray(data.actions)) {
        sanitized.actions = this.validateActions(data.actions);
      }

      // Set defaults
      sanitized.requireInteraction = data.requireInteraction !== false;
      sanitized.silent = data.silent === true;
      sanitized.tag = data.tag || `notification-${Date.now()}`;

      return sanitized;
    } catch (error) {
      logger.error('Notification validation failed', { error: error.message, data });
      throw error;
    }
  }

  /**
   * Sanitize string input
   * @param {string} str - String to sanitize
   * @param {number} maxLength - Maximum allowed length
   * @returns {string} Sanitized string
   */
  sanitizeString(str, maxLength) {
    if (typeof str !== 'string') {
      throw new Error('Expected string value');
    }

    const sanitized = str.trim().substring(0, maxLength);

    // Basic XSS prevention
    return sanitized.replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '');
  }

  /**
   * Validate URL format
   * @param {string} url - URL to validate
   * @returns {string} Validated URL
   */
  validateUrl(url) {
    if (typeof url !== 'string') {
      throw new Error('URL must be a string');
    }

    try {
      const urlObj = new URL(url, self.location.origin);
      return urlObj.href;
    } catch (error) {
      throw new Error(`Invalid URL: ${url}`);
    }
  }

  /**
   * Validate notification-specific data
   * @param {Object} data - Notification data object
   * @returns {Object} Validated data
   */
  validateNotificationData(data) {
    const validated = {};

    if (data.path) {
      validated.path = this.sanitizeString(data.path, 500);
    }

    if (data.category && NOTIFICATION_CATEGORIES[data.category]) {
      validated.category = data.category;
    }

    if (data.priority) {
      validated.priority = Math.max(0, Math.min(2, parseInt(data.priority) || 0));
    }

    return validated;
  }

  /**
   * Validate notification actions
   * @param {Array} actions - Array of action objects
   * @returns {Array} Validated actions
   */
  validateActions(actions) {
    return actions
      .filter(action => action && typeof action === 'object')
      .map(action => ({
        action: this.sanitizeString(action.action, 50),
        title: this.sanitizeString(action.title, 100),
        icon: action.icon ? this.validateUrl(action.icon) : undefined
      }))
      .filter(action => SW_CONFIG.SUPPORTED_ACTIONS.includes(action.action))
      .slice(0, 2); // Max 2 actions per notification
  }
}

// ==========================================
// CORE SERVICE WORKER MODULES
// ==========================================

/**
 * Advanced Notification Manager
 * Handles all notification-related operations with enterprise-grade features
 */
class NotificationManager {
  constructor() {
    this.validator = new NotificationValidator();
    this.retryHandler = new RetryHandler(SW_CONFIG);
    this.activeNotifications = new Map();
  }

  /**
   * Handle incoming push events
   * @param {PushEvent} event - Push event object
   */
  async handlePushEvent(event) {
    const startTime = performance.now();

    try {
      logger.info('Processing push event', {
        dataSize: event.data ? event.data.size : 0
      });

      if (!event.data) {
        throw new Error('Push event contains no data');
      }

      // Parse and validate notification data
      const rawData = await event.data.json();
      const notificationData = this.validator.validateAndSanitize(rawData);

      // Apply category-specific configuration
      const enhancedData = this.enhanceNotificationWithCategory(notificationData);

      // Show notification with retry mechanism
      await this.retryHandler.executeWithRetry(
        () => this.showNotification(enhancedData),
        'showNotification'
      );

      const duration = performance.now() - startTime;
      logger.info('Push event processed successfully', { duration });

    } catch (error) {
      const duration = performance.now() - startTime;
      logger.error('Failed to process push event', {
        error: error.message,
        duration
      });

      // Show fallback notification for critical errors
      await this.showFallbackNotification(error);
    }
  }

  /**
   * Show notification with advanced features
   * @param {Object} data - Notification data
   * @returns {Promise<Notification>} Created notification
   */
  async showNotification(data) {
    const notification = await self.registration.showNotification(data.title, {
      body: data.body,
      icon: data.icon,
      badge: data.badge,
      tag: data.tag,
      data: data.data,
      requireInteraction: data.requireInteraction,
      silent: data.silent,
      actions: data.actions,
      timestamp: Date.now(),
      vibrate: this.getVibrationPattern(data.data?.priority),
      ...data
    });

    // Track active notification
    this.activeNotifications.set(data.tag, {
      notification,
      timestamp: Date.now(),
      data
    });

    // Auto-cleanup after timeout
    if (!data.requireInteraction) {
      setTimeout(() => {
        this.activeNotifications.delete(data.tag);
      }, SW_CONFIG.NOTIFICATION_TIMEOUT);
    }

    return notification;
  }

  /**
   * Enhance notification with category-specific settings
   * @param {Object} data - Base notification data
   * @returns {Object} Enhanced notification data
   */
  enhanceNotificationWithCategory(data) {
    const category = NOTIFICATION_CATEGORIES[data.data?.category];
    if (!category) return data;

    return {
      ...data,
      icon: data.icon || category.icon,
      badge: data.badge || category.badge,
      tag: data.tag || category.tag,
      requireInteraction: data.requireInteraction !== undefined ?
        data.requireInteraction : category.requireInteraction,
      silent: data.silent !== undefined ? data.silent : category.silent,
      actions: data.actions || category.actions
    };
  }

  /**
   * Get vibration pattern based on priority
   * @param {number} priority - Notification priority (0-2)
   * @returns {Array} Vibration pattern
   */
  getVibrationPattern(priority = 0) {
    const patterns = [
      [200, 100, 200],      // Low priority - gentle
      [300, 100, 300, 100, 300], // Medium priority - moderate
      [500, 200, 500, 200, 500]  // High priority - urgent
    ];
    return patterns[priority] || patterns[0];
  }

  /**
   * Show fallback notification for errors
   * @param {Error} error - Error that occurred
   */
  async showFallbackNotification(error) {
    try {
      await self.registration.showNotification('Notification Service', {
        body: 'Unable to display notification. Please check your connection.',
        icon: '/icons/warning.png',
        tag: 'notification-error',
        requireInteraction: false,
        silent: true
      });
    } catch (fallbackError) {
      logger.error('Failed to show fallback notification', {
        error: fallbackError.message
      });
    }
  }

  /**
   * Close notification by tag
   * @param {string} tag - Notification tag
   */
  async closeNotification(tag) {
    try {
      const notificationData = this.activeNotifications.get(tag);
      if (notificationData?.notification) {
        await notificationData.notification.close();
        this.activeNotifications.delete(tag);
        logger.debug('Notification closed', { tag });
      }
    } catch (error) {
      logger.error('Failed to close notification', { tag, error: error.message });
    }
  }
}

/**
 * Advanced Client Manager
 * Sophisticated client window and tab management
 */
class ClientManager {
  constructor() {
    this.retryHandler = new RetryHandler(SW_CONFIG);
  }

  /**
   * Handle notification click events
   * @param {NotificationEvent} event - Notification click event
   */
  async handleNotificationClick(event) {
    const startTime = performance.now();

    try {
      logger.info('Processing notification click', {
        action: event.action,
        notificationTag: event.notification.tag
      });

      // Close the notification
      event.notification.close();

      // Handle different click actions
      if (event.action) {
        await this.handleNotificationAction(event);
      } else {
        await this.handleDefaultNotificationClick(event);
      }

      const duration = performance.now() - startTime;
      logger.info('Notification click processed', { duration });

    } catch (error) {
      const duration = performance.now() - startTime;
      logger.error('Failed to process notification click', {
        error: error.message,
        duration
      });
    }
  }

  /**
   * Handle notification action clicks
   * @param {NotificationEvent} event - Notification click event
   */
  async handleNotificationAction(event) {
    const { action, notification } = event;

    switch (action) {
      case 'view':
      case 'focus':
        await this.focusOrOpenClient(notification.data?.path || '/');
        break;

      case 'reply':
        await this.focusOrOpenClient('/messages');
        break;

      case 'track':
        await this.focusOrOpenClient(`/orders/${notification.data?.orderId}/track`);
        break;

      case 'dismiss':
        // Just close the notification (already done)
        break;

      default:
        logger.warn('Unknown notification action', { action });
        await this.focusOrOpenClient('/');
    }
  }

  /**
   * Handle default notification clicks (no specific action)
   * @param {NotificationEvent} event - Notification click event
   */
  async handleDefaultNotificationClick(event) {
    const targetPath = event.notification.data?.path || '/';

    // Try to focus existing client first
    const focused = await this.focusExistingClient(targetPath);
    if (!focused) {
      // Open new window if no existing client found
      await this.openNewWindow(targetPath);
    }
  }

  /**
   * Focus existing client window/tab
   * @param {string} targetPath - Target path to focus
   * @returns {Promise<boolean>} Whether a client was focused
   */
  async focusExistingClient(targetPath) {
    try {
      const clients = await self.clients.matchAll({
        type: 'window',
        includeUncontrolled: true
      });

      logger.debug('Found existing clients', { count: clients.length, targetPath });

      // Sort clients by last focus time (most recent first)
      const sortedClients = clients.sort((a, b) => {
        const aTime = a.lastFocusTime || 0;
        const bTime = b.lastFocusTime || 0;
        return bTime - aTime;
      });

      for (const client of sortedClients) {
        try {
          const clientUrl = new URL(client.url);
          const clientPath = clientUrl.pathname;

          logger.debug('Checking client', {
            clientPath,
            targetPath,
            clientUrl: client.url
          });

          // Check for exact path match or relevant section match
          if (this.isPathMatch(clientPath, targetPath)) {
            await client.focus();
            logger.info('Focused existing client', { clientPath, targetPath });
            return true;
          }
        } catch (error) {
          logger.warn('Error checking client', {
            error: error.message,
            clientUrl: client.url
          });
          continue;
        }
      }

      logger.debug('No matching client found to focus');
      return false;
    } catch (error) {
      logger.error('Error focusing existing client', {
        error: error.message,
        targetPath
      });
      return false;
    }
  }

  /**
   * Check if client path matches target path
   * @param {string} clientPath - Client's current path
   * @param {string} targetPath - Target path
   * @returns {boolean} Whether paths match
   */
  isPathMatch(clientPath, targetPath) {
    // Exact match
    if (clientPath === targetPath) return true;

    // Section match (e.g., /orders/123 matches /orders)
    if (targetPath.startsWith('/') && clientPath.startsWith(targetPath)) {
      return true;
    }

    // Handle special cases
    if (targetPath.includes('/orders/') && clientPath.startsWith('/orders')) {
      return true;
    }

    if (targetPath.includes('/messages') && clientPath.startsWith('/conversations')) {
      return true;
    }

    return false;
  }

  /**
   * Open new window with target path
   * @param {string} targetPath - Path to open
   */
  async openNewWindow(targetPath) {
    try {
      const fullUrl = new URL(targetPath, self.location.origin).href;

      await this.retryHandler.executeWithRetry(
        () => self.clients.openWindow(fullUrl),
        'openWindow'
      );

      logger.info('Opened new window', { targetPath, fullUrl });
    } catch (error) {
      logger.error('Failed to open new window', {
        error: error.message,
        targetPath
      });

      // Fallback: try to open root path
      try {
        await self.clients.openWindow(self.location.origin);
      } catch (fallbackError) {
        logger.error('Fallback window open also failed', {
          error: fallbackError.message
        });
      }
    }
  }
}

/**
 * Performance Monitor
 * Tracks and reports service worker performance metrics
 */
class PerformanceMonitor {
  constructor() {
    this.metrics = new Map();
    this.startTime = performance.now();
  }

  /**
   * Record a performance metric
   * @param {string} name - Metric name
   * @param {number} value - Metric value
   * @param {string} unit - Metric unit
   */
  recordMetric(name, value, unit = 'ms') {
    if (!this.metrics.has(name)) {
      this.metrics.set(name, []);
    }
    this.metrics.get(name).push({
      value,
      unit,
      timestamp: Date.now()
    });
  }

  /**
   * Get performance statistics
   * @returns {Object} Performance statistics
   */
  getStats() {
    const stats = {};
    const uptime = performance.now() - this.startTime;

    for (const [name, values] of this.metrics) {
      const numbers = values.map(v => v.value);
      stats[name] = {
        count: values.length,
        average: numbers.reduce((a, b) => a + b, 0) / numbers.length,
        min: Math.min(...numbers),
        max: Math.max(...numbers),
        latest: numbers[numbers.length - 1],
        unit: values[0]?.unit || 'ms'
      };
    }

    stats.uptime = {
      value: uptime,
      unit: 'ms'
    };

    return stats;
  }
}

// ==========================================
// SERVICE WORKER INITIALIZATION
// ==========================================

// Initialize core components
const logger = new ServiceWorkerLogger(SW_CONFIG);
const notificationManager = new NotificationManager();
const clientManager = new ClientManager();
const performanceMonitor = new PerformanceMonitor();

// Service Worker Install Event
self.addEventListener('install', (event) => {
  logger.info('Service Worker installing', { version: SW_CONFIG.VERSION });

  event.waitUntil(
    (async () => {
      try {
        // Skip waiting to activate immediately
        await self.skipWaiting();
        logger.info('Service Worker installed and activated');
      } catch (error) {
        logger.error('Service Worker installation failed', { error: error.message });
      }
    })()
  );
});

// Service Worker Activate Event
self.addEventListener('activate', (event) => {
  logger.info('Service Worker activating', { version: SW_CONFIG.VERSION });

  event.waitUntil(
    (async () => {
      try {
        // Claim all clients immediately
        await self.clients.claim();

        // Clean up old caches
        const cacheNames = await caches.keys();
        await Promise.all(
          cacheNames
            .filter(name => name !== SW_CONFIG.CACHE_NAME)
            .map(name => caches.delete(name))
        );

        logger.info('Service Worker activated successfully');
      } catch (error) {
        logger.error('Service Worker activation failed', { error: error.message });
      }
    })()
  );
});

// Push Event Handler
self.addEventListener('push', (event) => {
  logger.debug('Push event received');
  event.waitUntil(notificationManager.handlePushEvent(event));
});

// Notification Click Event Handler
self.addEventListener('notificationclick', (event) => {
  logger.debug('Notification click event received');
  event.waitUntil(clientManager.handleNotificationClick(event));
});

// Message Event Handler (for communication with main thread)
self.addEventListener('message', (event) => {
  const { type, data } = event.data || {};

  switch (type) {
    case 'GET_PERFORMANCE_STATS':
      event.ports[0].postMessage({
        type: 'PERFORMANCE_STATS',
        data: performanceMonitor.getStats()
      });
      break;

    case 'CLOSE_NOTIFICATION':
      if (data && data.tag) {
        notificationManager.closeNotification(data.tag);
      }
      break;

    case 'SKIP_WAITING':
      self.skipWaiting();
      break;

    default:
      logger.warn('Unknown message type received', { type });
  }
});

// Error Event Handler
self.addEventListener('error', (event) => {
  logger.error('Service Worker error', {
    message: event.message,
    filename: event.filename,
    lineno: event.lineno,
    colno: event.colno
  });
});

// Unhandled Promise Rejection Handler
self.addEventListener('unhandledrejection', (event) => {
  logger.error('Unhandled promise rejection in Service Worker', {
    reason: event.reason?.message || event.reason
  });
});

logger.info('Advanced Service Worker loaded', {
  version: SW_CONFIG.VERSION,
  features: [
    'Modular Architecture',
    'Comprehensive Error Handling',
    'Performance Monitoring',
    'Advanced Client Management',
    'Retry Mechanisms',
    'Security Validation',
    'Category-based Notifications'
  ]
});
