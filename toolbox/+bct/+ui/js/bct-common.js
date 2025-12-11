/**
 * BCT Common JavaScript Utilities
 * 
 * Provides shared functionality for all BCT UI components including:
 * - MATLAB communication helpers
 * - Event handling utilities
 * - DOM manipulation helpers
 * - State management
 */

// Namespace for BCT utilities
window.BCT = window.BCT || {};

/**
 * Send a command message to MATLAB
 * @param {string} componentId - ID of the component sending the message
 * @param {string} cmd - Command name
 * @param {Object} data - Additional data to send
 */
BCT.sendToMatlab = function(componentId, cmd, data = {}) {
    const message = {
        id: componentId,
        cmd: cmd,
        timestamp: Date.now(),
        ...data
    };
    
    try {
        window.MATLAB.postMessage(message);
    } catch (error) {
        console.error('Failed to send message to MATLAB:', error);
    }
};

/**
 * Set up a listener for messages from MATLAB
 * @param {Function} callback - Function to call when message received
 */
BCT.onMatlabMessage = function(callback) {
    if (typeof callback !== 'function') {
        console.error('Callback must be a function');
        return;
    }
    
    // Listen for MATLAB data updates
    window.addEventListener('message', function(event) {
        if (event.data && event.data.id) {
            callback(event.data);
        }
    });
};

/**
 * Debounce function to limit how often a function can fire
 * @param {Function} func - Function to debounce
 * @param {number} wait - Wait time in milliseconds
 * @returns {Function} Debounced function
 */
BCT.debounce = function(func, wait = 250) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
};

/**
 * Throttle function to ensure a function is called at most once per interval
 * @param {Function} func - Function to throttle
 * @param {number} limit - Time limit in milliseconds
 * @returns {Function} Throttled function
 */
BCT.throttle = function(func, limit = 250) {
    let inThrottle;
    return function(...args) {
        if (!inThrottle) {
            func.apply(this, args);
            inThrottle = true;
            setTimeout(() => inThrottle = false, limit);
        }
    };
};

/**
 * Create an element with classes and attributes
 * @param {string} tag - HTML tag name
 * @param {Object} options - Options object
 * @param {string|string[]} options.classes - CSS classes to add
 * @param {Object} options.attrs - Attributes to set
 * @param {string} options.text - Text content
 * @param {string} options.html - HTML content
 * @returns {HTMLElement} Created element
 */
BCT.createElement = function(tag, options = {}) {
    const element = document.createElement(tag);
    
    // Add classes
    if (options.classes) {
        const classes = Array.isArray(options.classes) ? options.classes : [options.classes];
        element.classList.add(...classes);
    }
    
    // Set attributes
    if (options.attrs) {
        Object.keys(options.attrs).forEach(key => {
            element.setAttribute(key, options.attrs[key]);
        });
    }
    
    // Set content
    if (options.text) {
        element.textContent = options.text;
    } else if (options.html) {
        element.innerHTML = options.html;
    }
    
    return element;
};

/**
 * Show a notification or toast message
 * @param {string} message - Message to display
 * @param {string} type - Type of message ('info', 'success', 'warning', 'error')
 * @param {number} duration - Duration in milliseconds (0 for permanent)
 */
BCT.notify = function(message, type = 'info', duration = 3000) {
    const container = document.getElementById('bct-notifications') || createNotificationContainer();
    
    const notification = BCT.createElement('div', {
        classes: ['bct-notification', `bct-notification-${type}`],
        html: `
            <span class="bct-notification-message">${message}</span>
            <button class="bct-notification-close">&times;</button>
        `
    });
    
    container.appendChild(notification);
    
    // Animate in
    setTimeout(() => notification.classList.add('show'), 10);
    
    // Close button
    notification.querySelector('.bct-notification-close').onclick = () => {
        closeNotification(notification);
    };
    
    // Auto-close
    if (duration > 0) {
        setTimeout(() => closeNotification(notification), duration);
    }
    
    function closeNotification(elem) {
        elem.classList.remove('show');
        setTimeout(() => elem.remove(), 300);
    }
    
    function createNotificationContainer() {
        const cont = BCT.createElement('div', {
            attrs: { id: 'bct-notifications' },
            classes: 'bct-notifications-container'
        });
        document.body.appendChild(cont);
        return cont;
    }
};

/**
 * Simple state management for components
 */
BCT.StateManager = class {
    constructor(initialState = {}) {
        this.state = { ...initialState };
        this.listeners = [];
    }
    
    get(key) {
        return key ? this.state[key] : this.state;
    }
    
    set(key, value) {
        if (typeof key === 'object') {
            // Batch update
            Object.assign(this.state, key);
        } else {
            this.state[key] = value;
        }
        this.notify();
    }
    
    update(changes) {
        Object.assign(this.state, changes);
        this.notify();
    }
    
    subscribe(listener) {
        this.listeners.push(listener);
        return () => {
            this.listeners = this.listeners.filter(l => l !== listener);
        };
    }
    
    notify() {
        this.listeners.forEach(listener => listener(this.state));
    }
};

/**
 * Format a number with appropriate precision
 * @param {number} value - Value to format
 * @param {number} precision - Decimal places
 * @returns {string} Formatted number
 */
BCT.formatNumber = function(value, precision = 2) {
    if (typeof value !== 'number' || isNaN(value)) {
        return 'N/A';
    }
    return value.toFixed(precision);
};

/**
 * Format a timestamp
 * @param {number} timestamp - Unix timestamp in milliseconds
 * @returns {string} Formatted time string
 */
BCT.formatTime = function(timestamp) {
    const date = new Date(timestamp);
    return date.toLocaleTimeString();
};

/**
 * Load a CSS file dynamically
 * @param {string} href - Path to CSS file
 */
BCT.loadCSS = function(href) {
    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = href;
    document.head.appendChild(link);
};

/**
 * Load a JavaScript file dynamically
 * @param {string} src - Path to JS file
 * @returns {Promise} Promise that resolves when script loads
 */
BCT.loadScript = function(src) {
    return new Promise((resolve, reject) => {
        const script = document.createElement('script');
        script.src = src;
        script.onload = resolve;
        script.onerror = reject;
        document.head.appendChild(script);
    });
};

console.log('BCT Common utilities loaded');
