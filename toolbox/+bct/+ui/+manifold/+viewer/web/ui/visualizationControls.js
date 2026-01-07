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
  const gui = new GUI({ title: 'Visualization Controls', width: 280 });
  
  // Position in top-right corner
  gui.domElement.style.position = 'absolute';
  gui.domElement.style.top = '10px';
  gui.domElement.style.right = '10px';
  gui.domElement.style.zIndex = '1000';
  
  // Collapse by default
  gui.close();
  
  // Surface folder
  const surfaceFolder = gui.addFolder('Surface');
  surfaceFolder.add(vizState.surface, 'visible').name('Visible').onChange(onChange);
  surfaceFolder.add(vizState.surface, 'opacity', 0, 1, 0.01).name('Opacity').onChange(onChange);
  surfaceFolder.add(vizState.surface, 'shading', ['smooth', 'flat']).name('Shading').onChange(onChange);
  surfaceFolder.add(vizState.surface, 'colorMode', ['uniform', 'vertex', 'face']).name('Color Mode').onChange(onChange);
  
  // Edges folder
  const edgesFolder = gui.addFolder('Edges');
  edgesFolder.add(vizState.edges, 'wireframe').name('Wireframe').onChange(onChange);
  edgesFolder.addColor(vizState.edges, 'color').name('Color').onChange(onChange);
  
  // Geometry Helpers folder
  const helpersFolder = gui.addFolder('Geometry Helpers');
  helpersFolder.add(vizState.helpers, 'vertexNormals').name('Vertex Normals').onChange(onChange);
  helpersFolder.add(vizState.helpers, 'faceNormals').name('Face Normals').onChange(onChange);
  helpersFolder.add(vizState.helpers, 'tangents').name('Tangents').onChange(onChange);
  
  // Overlays folder
  const overlaysFolder = gui.addFolder('Overlays');
  overlaysFolder.add(vizState.overlays, 'scalarField', ['none', 'curvature', 'depth']).name('Scalar Field').onChange(onChange);
  overlaysFolder.add(vizState.overlays, 'colormap', ['viridis', 'plasma', 'inferno', 'magma', 'turbo']).name('Colormap').onChange(onChange);
  overlaysFolder.add(vizState.overlays, 'autoRange').name('Auto Range').onChange(onChange);
  
  // Scene folder
  const sceneFolder = gui.addFolder('Scene');
  sceneFolder.add(vizState.scene, 'lighting').name('Lighting').onChange(onChange);
  sceneFolder.add(vizState.scene, 'axes').name('Axes').onChange(onChange);
  sceneFolder.addColor(vizState.scene, 'background').name('Background').onChange(onChange);
  
  return gui;
}
