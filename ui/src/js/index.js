/**
 * BCT UI Library
 * Main entry point for bundled JavaScript
 * Exports all components and utilities to window.BCT global namespace
 */

import * as d3 from 'd3';
import * as utils from './core/utils.js';
import { BaseScrubber } from './scrubber/BaseScrubber.js';

// Export everything to window.BCT for MATLAB compatibility
window.BCT = {
  // D3.js library
  d3,
  
  // Core utilities
  ...utils,
  
  // Components
  BaseScrubber,
  
  // Version
  version: '2.0.0'
};

// For debugging
console.log('[BCT UI] Loaded successfully', window.BCT.version);

// Export for ES modules (future use)
export {
  d3,
  utils,
  BaseScrubber
};
