/**
 * renderer.js
 * 
 * Factory functions for WebGL renderer creation and configuration.
 * 
 * Centralizes renderer construction and output pipeline defaults.
 * This is the single place to define tone mapping, color space,
 * and rendering policies.
 */

import * as THREE from 'three';

/**
 * Create and configure WebGL renderer
 * @param {Object} config - Renderer configuration
 * @param {HTMLCanvasElement} config.canvas - Canvas element
 * @param {boolean} [config.antialias=true] - Enable antialiasing
 * @param {number} [config.pixelRatio] - Device pixel ratio (defaults to window.devicePixelRatio)
 * @param {number} [config.toneMapping=THREE.ACESFilmicToneMapping] - Tone mapping mode
 * @param {number} [config.toneMappingExposure=1.0] - Tone mapping exposure
 * @param {string} [config.outputColorSpace=THREE.SRGBColorSpace] - Output color space
 * @returns {THREE.WebGLRenderer} Configured renderer
 */
export function createRenderer(config) {
  const {
    canvas,
    antialias = true,
    pixelRatio = window.devicePixelRatio ?? 1,
    toneMapping = THREE.ACESFilmicToneMapping,
    toneMappingExposure = 1.0,
    outputColorSpace = THREE.SRGBColorSpace
  } = config;

  const renderer = new THREE.WebGLRenderer({ 
    canvas, 
    antialias 
  });

  renderer.setPixelRatio(pixelRatio);

  // Conservative tone mapping and color space
  if ('outputColorSpace' in renderer) {
    renderer.outputColorSpace = outputColorSpace;
  }
  renderer.toneMapping = toneMapping;
  renderer.toneMappingExposure = toneMappingExposure;

  return renderer;
}

/**
 * Resize renderer to match container dimensions
 * @param {THREE.WebGLRenderer} renderer - Renderer to resize
 * @param {number} width - New width
 * @param {number} height - New height
 */
export function resizeRenderer(renderer, width, height) {
  renderer.setSize(width, height, false);
}
