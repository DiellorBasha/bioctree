/**
 * BCT Core Utilities
 * Reusable utilities for all BCT UI components
 */

// ============================================================================
// ID GENERATION
// ============================================================================

export function generateId() {
  return `bct-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}

// ============================================================================
// MATLAB COMMUNICATION
// ============================================================================

export function isMatlabEnvironment() {
  return typeof window !== 'undefined' && 
         typeof window.MATLAB !== 'undefined' && 
         typeof window.MATLAB.postMessage === 'function';
}

export function postToMatlab(cmd, payload = {}) {
  const message = {
    id: generateId(),
    cmd: cmd,
    timestamp: Date.now(),
    ...payload
  };

  if (isMatlabEnvironment()) {
    window.MATLAB.postMessage(message);
  } else {
    // Fallback for non-MATLAB environments
    console.log('[BCT → MATLAB]', message);
    window.dispatchEvent(new CustomEvent('bct:matlab-message', { 
      detail: message 
    }));
  }
}

export function onMatlabMessage(callback) {
  if (isMatlabEnvironment()) {
    window.bctMessageHandler = callback;
  } else {
    window.addEventListener('bct:matlab-response', (event) => {
      callback(event.detail);
    });
  }
}

// ============================================================================
// STATE MANAGEMENT
// ============================================================================

export class StateManager {
  constructor(initialState = {}) {
    this.state = { ...initialState };
    this.listeners = new Map();
    this.history = [];
    this.maxHistory = 50;
  }

  get(key) {
    return key ? this.state[key] : { ...this.state };
  }

  set(keyOrObject, value) {
    const oldState = { ...this.state };
    
    if (typeof keyOrObject === 'object') {
      Object.assign(this.state, keyOrObject);
    } else {
      this.state[keyOrObject] = value;
    }

    this.history.push(oldState);
    if (this.history.length > this.maxHistory) {
      this.history.shift();
    }

    this.notify(this.state, oldState);
  }

  subscribe(listener, keys = null) {
    const id = generateId();
    this.listeners.set(id, { listener, keys });
    return () => this.listeners.delete(id);
  }

  notify(newState, oldState) {
    this.listeners.forEach(({ listener, keys }) => {
      if (!keys) {
        listener(newState, oldState);
      } else {
        const changed = keys.some(key => newState[key] !== oldState[key]);
        if (changed) {
          listener(newState, oldState);
        }
      }
    });
  }

  undo() {
    if (this.history.length > 0) {
      this.state = this.history.pop();
      this.notify(this.state, {});
    }
  }

  clear() {
    this.state = {};
    this.history = [];
    this.notify(this.state, {});
  }
}

// ============================================================================
// DOM UTILITIES
// ============================================================================

export function $(selector, parent = document) {
  return parent.querySelector(selector);
}

export function $$(selector, parent = document) {
  return Array.from(parent.querySelectorAll(selector));
}

export function createElement(tag, attrs = {}, ...children) {
  const element = document.createElement(tag);
  
  Object.entries(attrs).forEach(([key, value]) => {
    if (key === 'className') {
      element.className = value;
    } else if (key === 'innerHTML') {
      element.innerHTML = value;
    } else if (key === 'style' && typeof value === 'object') {
      Object.assign(element.style, value);
    } else if (key.startsWith('on') && typeof value === 'function') {
      const eventName = key.substring(2).toLowerCase();
      element.addEventListener(eventName, value);
    } else if (key === 'onClick' && typeof value === 'function') {
      element.addEventListener('click', value);
    } else if (key === 'dataset' && typeof value === 'object') {
      Object.entries(value).forEach(([k, v]) => {
        element.dataset[k] = v;
      });
    } else if (key === 'disabled') {
      element.disabled = value;
    } else if (value !== null && value !== undefined) {
      element.setAttribute(key, value);
    }
  });
  
  children.flat().forEach(child => {
    if (child instanceof Node) {
      element.appendChild(child);
    } else if (child !== null && child !== undefined) {
      element.appendChild(document.createTextNode(String(child)));
    }
  });
  
  return element;
}

export function on(element, event, handler, options) {
  if (!element) return;
  element.addEventListener(event, handler, options);
}

export function off(element, event, handler) {
  if (!element) return;
  element.removeEventListener(event, handler);
}

// ============================================================================
// ICONS
// ============================================================================

const ICONS = {
  upload: `<svg fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/></svg>`,
  save: `<svg fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4"/></svg>`,
  play: `<svg fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>`,
  settings: `<svg fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/></svg>`,
  close: `<svg fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/></svg>`,
  check: `<svg fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>`,
  chevronDown: `<svg fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/></svg>`,
  chevronRight: `<svg fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg>`,
};

export function getIcon(name) {
  return ICONS[name] || ICONS.settings;
}
