/**
 * visualizationControls.js
 * 
 * lil-gui-based visualization controls panel.
 * 
 * Responsibilities:
 * - Create GUI instance with folder hierarchy
 * - Bind controls to visualization state
 * - Trigger onChange callback on modifications
 * 
 * Rules:
 * - No direct three.js calls
 * - No scene/geometry access
 * - JSON-serializable state only
 * - No picker/interaction logic
 */

import GUI from '../vendor/three/examples/jsm/libs/lil-gui.module.min.js';

/**
 * Create visualization controls panel
 * 
 * @param {Object} config
 * @param {Object} config.vizState - Visualization state object
 * @param {Function} config.onChange - Callback invoked on any state change
 * @returns {GUI} GUI instance (for disposal)
 */
export function createVisualizationControls({ vizState, onChange }) {
  const gui = new GUI({ width: 280, title: 'Visualization' });
  
  // Position in top-right corner
  gui.domElement.style.position = 'absolute';
  gui.domElement.style.top = '10px';
  gui.domElement.style.right = '10px';
  gui.domElement.style.zIndex = '1000';
  
  // Field folder - scalar visualization controls (most commonly used, listed first)
  const fieldFolder = gui.addFolder('Field');
  fieldFolder.close(); // Collapsed by default
  fieldFolder.add(vizState.scalar, 'colormap', [
    'viridis', 'plasma', 'inferno', 'magma', 'turbo',
    'rainbow', 'hot', 'cool', 'cooltowarm'
  ]).name('Colormap').onChange(onChange);
  fieldFolder.add(vizState.scalar, 'autoRange').name('Auto Range').onChange(onChange);
  fieldFolder.add(vizState.scalar, 'colorbar').name('Show Colorbar').onChange(onChange);
  
  // Manifold folder - mesh rendering and helpers
  const manifoldFolder = gui.addFolder('Manifold');
  manifoldFolder.close(); // Closed by default to reduce clutter
  
  // Mesh color picker
  manifoldFolder.addColor(vizState.surface, 'color').name('Mesh Color').onChange(onChange);
  
  // Wireframe overlay toggle
  manifoldFolder.add(vizState.surface, 'wireframe').name('Show Wireframe').onChange(onChange);
  
  // Wireframe color
  manifoldFolder.addColor(vizState.edges, 'color').name('Wireframe Color').onChange(onChange);
  
  // Geometry helpers
  manifoldFolder.add(vizState.helpers, 'vertexNormals').name('Vertex Normals').onChange(onChange);
  manifoldFolder.add(vizState.helpers, 'tangents').name('Tangents').onChange(onChange);
  
  return gui;
}
