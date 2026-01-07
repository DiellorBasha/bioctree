/**
 * gizmo.js
 * 
 * Axes helper and orientation overlay for viewport navigation.
 * 
 * Responsibilities:
 * - Create axes helper with separate scene/camera
 * - Render orientation overlay in corner
 * - Sync gizmo rotation with main camera
 * 
 * Rules:
 * - No dependency on mesh or picking
 * - Independent rendering system (secondary scene)
 * - View-locked orientation indicator
 */

import * as THREE from 'three';

/**
 * AxesGizmo - Orientation indicator overlay
 */
export class AxesGizmo {
  constructor() {
    this.scene = null;
    this.camera = null;
    this.axes = null;
    this.enabled = true;
  }

  /**
   * Initialize the axes gizmo system
   * @param {Object} options - Configuration options
   */
  init(options = {}) {
    const {
      backgroundColor = 0x000000,
      axesSize = 1,
      cameraDistance = 3
    } = options;

    // Create secondary scene for gizmo
    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(backgroundColor);

    // Create axes helper
    this.axes = new THREE.AxesHelper(axesSize);
    this.scene.add(this.axes);

    // Create camera for gizmo view
    this.camera = new THREE.PerspectiveCamera(50, 1, 0.1, 10);
    this.camera.position.set(0, 0, cameraDistance);
    this.camera.up.set(0, 1, 0);
    this.camera.lookAt(0, 0, 0);

    console.log('[AxesGizmo] Initialized');
  }

  /**
   * Update gizmo orientation to match main camera
   * @param {THREE.Camera} mainCamera - Main camera to sync with
   */
  update(mainCamera) {
    if (!this.axes || !mainCamera || !this.enabled) return;

    // Invert camera rotation so gizmo shows world axes relative to current view
    this.axes.quaternion.copy(mainCamera.quaternion).invert();
  }

  /**
   * Render the gizmo overlay
   * @param {THREE.WebGLRenderer} renderer - Renderer to use
   * @param {HTMLCanvasElement} canvas - Canvas element for viewport sizing
   */
  render(renderer, canvas) {
    if (!this.scene || !this.camera || !renderer || !this.enabled) return;

    const minDim = Math.min(canvas.clientWidth, canvas.clientHeight);
    const vp = Math.max(90, Math.floor(minDim * 0.18)); // ~18% of smaller dimension

    const margin = 12;
    const x = margin;
    const y = margin;

    // Clear depth buffer so overlay draws on top
    renderer.clearDepth();
    
    // Set scissor and viewport for overlay region (bottom-left)
    renderer.setScissorTest(true);
    renderer.setScissor(x, y, vp, vp);
    renderer.setViewport(x, y, vp, vp);

    // Update camera aspect for square viewport
    this.camera.aspect = 1;
    this.camera.updateProjectionMatrix();

    // Render gizmo scene
    renderer.render(this.scene, this.camera);

    // Restore scissor test state
    renderer.setScissorTest(false);

    // Restore viewport to full canvas for subsequent renders
    renderer.setViewport(0, 0, canvas.clientWidth, canvas.clientHeight);
  }

  /**
   * Enable or disable gizmo rendering
   * @param {boolean} enabled - Whether gizmo should be rendered
   */
  setEnabled(enabled) {
    this.enabled = !!enabled;
  }

  /**
   * Dispose of gizmo resources
   */
  dispose() {
    if (this.axes) {
      this.axes.dispose?.();
      this.axes = null;
    }
    
    this.scene = null;
    this.camera = null;
    
    console.log('[AxesGizmo] Disposed');
  }
}
