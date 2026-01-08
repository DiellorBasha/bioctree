import * as THREE from "three";
import { PinMarker } from "./geometry/pinMarker.js";
import { PickingSystem } from "./interaction/picking.js";
import { SelectionFX } from "./interaction/selectionFX.js";
import { ViewerCore } from './core/viewerCore.js';
import { createLightingRig } from './core/lighting.js';
import { createVisualizationControls } from './ui/visualizationControls.js';
import { MeshManager } from './runtime/meshManager.js';
import { VisualizationManager } from './runtime/visualizationManager.js';
import { ScalarMapper } from './visualization/scalarMapper.js';
import { Colorbar } from './ui/colorbar.js';
import { StateManager, StateEvent, AppState } from './core/stateManager.js';

// Application state manager
let stateManager = null;

// Core rendering system
let viewerCore = null;

// Convenience accessors (populated by viewerCore)
let renderer, scene, camera, controls;
let canvas;

// Core subsystems
let lightRig = null;

// Runtime managers
let meshManager = null;
let vizManager = null;
let scalarMapper = null;
let colorbar = null;

// Scalar data cache (for re-applying when colormap changes)
let currentScalarData = null;

// Debug visuals
let targetMarker = null; // follows controls.target (rotation anchor)

// Interaction systems
let pickingSystem = null;
let selectionFX = null;
let pin = null;

/* -------------------- Defaults -------------------- */

// Pivot mode: recommended "MeshCenter" for FreeSurfer surfaces
const PIVOT_MODE = "MeshCenter";

// Debug toggles (initial state)
const SHOW_TARGET = false; // hide pivot marker

// Visualization state (lil-gui contract)
const vizState = {
  surface: {
    material: 'default'  // 'default' or 'wireframe'
  },
  edges: {
    color: '#ffffff'
  },
  helpers: {
    vertexNormals: false,
    tangents: false
  },
  scalar: {
    colormap: 'inferno',
    autoRange: true,
    colorbar: false
  }
};

// GUI instance
let vizGUI = null;

/* -------------------- Viewer Initialization -------------------- */

export async function initViewer({ canvasEl, hudEl, glbUrl = null }) {
  canvas = canvasEl;

  // Initialize state manager
  stateManager = new StateManager();
  
  // Subscribe to state changes for debugging
  stateManager.on('*', (event, currentState, previousState) => {
    // Can be enabled for debugging
    // console.log('[State]', event, ':', previousState.state, '→', currentState.state);
  });

  // Initialize core rendering system
  viewerCore = new ViewerCore(canvas);
  viewerCore.init({
    backgroundColor: 0x000000,
    cameraConfig: {
      fov: 45,
      near: 0.01,
      far: 1e7,
      position: [0, 0, 300],
      up: [0, 1, 0]
    },
    controlsConfig: {
      enableDamping: true,
      dampingFactor: 0.08,
      target: [0, 0, 0],
      cameraPosition: [-300, 0, 0]  // Default: +Z (blue) points right
    }
  });

  // Extract convenience accessors
  scene = viewerCore.scene;
  camera = viewerCore.camera;
  renderer = viewerCore.renderer;
  controls = viewerCore.controls;

  // Initialize lighting rig
  lightRig = createLightingRig(camera);

  // Initialize runtime managers
  meshManager = new MeshManager(viewerCore);
  vizManager = new VisualizationManager(viewerCore, meshManager, lightRig);
  scalarMapper = new ScalarMapper();
  
  // Initialize colorbar UI overlay
  colorbar = new Colorbar(canvas.parentElement);

  // Pivot marker (optional)
  if (SHOW_TARGET) installTargetMarker();
  updateTargetMarker();

  // Setup resize observation
  viewerCore.setupResizeObserver();

  // Wire up controls change callbacks
  viewerCore.onControlsChange(() => {
    updateTargetMarker();
  });
  
  // Initialize picking system
  pickingSystem = new PickingSystem(camera, renderer);
  
  // Start with picking disabled (tools must be explicitly activated)
  pickingSystem.setEnabled(false);
  
  // Initialize selection FX
  selectionFX = new SelectionFX();
  
  // Initialize pin marker for vertex selection
  pin = new PinMarker(scene, renderer, {
    color: 0xffcc00,
    length: 18,
    headRadius: 2.0,
    lineWidthPx: 2.5
  });
  
  // Wire up picking callbacks
  pickingSystem.onTrianglePick = (hit, tri) => {
    selectionFX.showTriangle(hit.object, tri);
  };
  
  pickingSystem.onEdgePick = (hit, edge, tri) => {
    selectionFX.showEdge(hit.object, hit.point, tri);
  };
  
  pickingSystem.onVertexPick = (hit, vertexIdx, tri) => {
    pin.setFromVertexIndex(hit.object, vertexIdx, camera);
  };
  
  // Picking: pointer event handler
  viewerCore.getRendererElement().addEventListener("pointerdown", (evt) => {
    pickingSystem.handlePointerDown(evt);
  });

  // Register render callbacks
  viewerCore.onRender(() => {
    updateTargetMarker();
    
    // Update selection pulse animation
    const t = performance.now() / 1000;
    selectionFX?.updatePulse(t);
    pin?.updatePulse(t);
    
    // Resize pin on viewport changes
    pin?.onResize();

    // Update normals/tangents helpers if active (via vizManager)
    vizManager?.updateNormalsHelpers();
    vizManager?.updateTangentsHelpers();
  });

  // Start render loop
  viewerCore.start();
  
  // Create visualization controls GUI
  try {
    vizGUI = createVisualizationControls({
      vizState,
      onChange: () => {
        try {
          vizManager?.applyState(vizState);
          // Update colorbar visibility
          colorbar?.setVisible(vizState.scalar.colorbar);
          // Re-apply scalar data if colormap changed
          if (currentScalarData) {
            setScalarData({ action: 'update', data: currentScalarData });
          }
        } catch (err) {
          console.error('[Viewer] onChange error:', err);
        }
      }
    });
  } catch (err) {
    console.error('[Viewer] GUI creation failed:', err);
    console.error('[Viewer] Stack:', err.stack);
  }
  
  // Initial visualization sync
  try {
    vizManager?.applyState(vizState);
  } catch (err) {
    console.error('[Viewer] Initial applyState failed:', err);
    console.error('[Viewer] Stack:', err.stack);
  }
  
  // Load default mesh only if glbUrl is provided
  if (glbUrl) {
    loadGLB(glbUrl).catch((err) => {
      console.error(err);
    });
  }
}

/**
 * Handle post-load setup (shared by all loaders)
 * @private
 */
function handlePostLoad() {
  const loadedScene = meshManager.getLoadedScene();
  const bounds = meshManager.getBounds();

  // Set orbit pivot
  setPivotMode(PIVOT_MODE);
  
  // Apply visualization state
  vizManager?.applyState(vizState);
  
  // Update debug visuals
  updateTargetMarker();
  
  // Setup picking
  pickingSystem?.collectPickables(loadedScene);
  
  // Scale pin to mesh size
  if (pin) {
    pin.setLength(bounds.radius * 0.1);
  }
}

export async function loadGLB(url) {
  return viewerUI.withLoadingUI(
    async () => {
      await meshManager.loadGLB(url);
      const scene = meshManager.getLoadedScene();
      return scene;
    },
    {
      loadingMessage: `Loading: ${url}`,
      successMessage: `Loaded: ${url}`,
      onComplete: handlePostLoad
    }
  );
}

/**
 * Load model from URL - detects file type and uses appropriate loader
 * @param {string} url - Path to model file (.glb or .json)
 */
export async function loadModel(url) {
  const ext = url.split('.').pop().toLowerCase();
  
  if (ext === 'glb' || ext === 'gltf') {
    return loadGLB(url);
  } else if (ext === 'json') {
    return loadJSON(url);
  } else {
    throw new Error(`Unsupported file format: ${ext}`);
  }
}

/**
 * Load JSON geometry file
 * @param {string} url - Path to JSON geometry file
 */
export async function loadJSON(url) {
  return viewerUI.withLoadingUI(
    async () => {
      await meshManager.loadJSON(url);
      const scene = meshManager.getLoadedScene();
      return scene;
    },
    {
      loadingMessage: `Loading: ${url}`,
      successMessage: `Loaded: ${url}`,
      onComplete: handlePostLoad
    }
  );
}

/* -------------------- Picking API -------------------- */

export function setPickMode(mode) {
  pickingSystem?.setMode(mode);
}

export function setPickingEnabled(enabled) {
  pickingSystem?.setEnabled(enabled);
}

/**
 * Set mesh from raw data (MATLAB pathway)
 * @param {Object} meshData - Mesh data object
 * @param {Array} meshData.vertices - Flat array [x1,y1,z1, x2,y2,z2, ...]
 * @param {Array} meshData.faces - Flat array of indices [i1,i2,i3, ...]
 * @param {number} meshData.indexBase - 0 for 0-based indexing, 1 for 1-based
 * @param {string} meshData.frame - 'matlab' or 'threejs' coordinate frame
 */
export function setMeshFromData(meshData) {
  const tTotal = performance.now();
  
  if (!meshManager || !stateManager) {
    console.error('[setMeshFromData] Viewer not initialized. Call initViewer first.');
    return;
  }

  // Check if loading is allowed
  if (!stateManager.canPerformAction(StateEvent.LOAD_MESH_REQUESTED)) {
    console.warn('[setMeshFromData] Cannot load mesh in current state:', stateManager.getState());
    return;
  }

  try {
    // Dispatch load requested event
    const requestId = stateManager.generateRequestId();
    stateManager.dispatch(StateEvent.LOAD_MESH_REQUESTED, { requestId });
    
    // Load mesh from buffers
    const t0 = performance.now();
    meshManager.setMeshFromBuffers(meshData);
    const t1 = performance.now();
    
    // Get mesh info for state update
    const loadedScene = meshManager.getLoadedScene();
    let vertexCount = 0;
    let faceCount = 0;
    if (loadedScene) {
      loadedScene.traverse(obj => {
        if (obj.isMesh && obj.geometry) {
          const pos = obj.geometry.attributes.position;
          if (pos) vertexCount += pos.count;
          const idx = obj.geometry.index;
          if (idx) faceCount += idx.count / 3;
        }
      });
    }
    
    // Run post-load setup
    const t2 = performance.now();
    handlePostLoad();
    const t3 = performance.now();
    
    // Dispatch load succeeded event
    const bounds = meshManager.getBounds();
    stateManager.dispatch(StateEvent.LOAD_MESH_SUCCEEDED, {
      requestId,
      vertexCount,
      faceCount,
      bounds
    });
    
    const tEnd = performance.now();
  } catch (err) {
    console.error('[setMeshFromData] Error loading mesh:', err);
    stateManager.dispatch(StateEvent.LOAD_MESH_FAILED, { error: err.message });
  }
}

/**
 * Clear the current mesh from the viewer
 * Called from MATLAB via HTMLComponent.Data = {clearMesh: true}
 */
export function clearMesh() {
  if (!meshManager || !stateManager) {
    console.error('[clearMesh] Viewer not initialized');
    return;
  }

  try {
    // Dispatch clear mesh event
    stateManager.dispatch(StateEvent.CLEAR_MESH_REQUESTED);
    
    // Clear scalar data first
    currentScalarData = null;
    if (colorbar) {
      colorbar.setVisible(false);
    }
    
    // Clear the mesh
    meshManager.clearModel();
  } catch (err) {
    console.error('[clearMesh] Error clearing mesh:', err);
  }
}

/**
 * Set scalar data for color mapping
 * Called from MATLAB via HTMLComponent.Data = {scalar: scalarData}
 * @param {Object} scalarData - Scalar field configuration
 * @param {string} scalarData.action - 'update' or 'clear'
 * @param {Array} [scalarData.data] - Flat array of scalar values
 */
export function setScalarData(scalarData) {
  if (!scalarMapper || !meshManager || !stateManager) {
    console.error('[setScalarData] Viewer not initialized');
    return;
  }

  try {
    if (scalarData.action === 'clear') {
      // Dispatch clear data event
      stateManager.dispatch(StateEvent.CLEAR_DATA_REQUESTED);
      
      // Clear scalar visualization
      currentScalarData = null;
      const loadedScene = meshManager.getLoadedScene();
      if (loadedScene) {
        loadedScene.traverse(obj => {
          if (obj.isMesh) {
            scalarMapper.clearFromMesh(obj);
          }
        });
      }
      // Hide colorbar and update vizState
      if (colorbar) {
        colorbar.setVisible(false);
        vizState.scalar.colorbar = false;
        // Update GUI to reflect the state change
        if (vizGUI) {
          vizGUI.updateDisplay();
        }
      }
    } else if (scalarData.action === 'update') {
      // Dispatch load data requested event
      const requestId = stateManager.generateRequestId();
      stateManager.dispatch(StateEvent.LOAD_DATA_REQUESTED, { requestId });
      
      // Apply scalar data to mesh
      const loadedScene = meshManager.getLoadedScene();
      if (!loadedScene) {
        console.error('[setScalarData] No mesh loaded. Call setMesh first.');
        stateManager.dispatch(StateEvent.LOAD_DATA_FAILED, { error: 'No mesh loaded' });
        return;
      }

      const { data } = scalarData;
      
      if (!data || data.length === 0) {
        console.error('[setScalarData] No scalar data provided');
        return;
      }

      // Cache the data for colormap updates
      currentScalarData = data;
      
      // Use colormap from vizState
      const colormap = vizState.scalar.colormap;
      
      // Auto-compute clim if autoRange is enabled
      let clim = null;
      if (vizState.scalar.autoRange) {
        let min = Infinity;
        let max = -Infinity;
        for (let i = 0; i < data.length; i++) {
          if (data[i] < min) min = data[i];
          if (data[i] > max) max = data[i];
        }
        clim = [min, max];
      }

      // Apply to all meshes in scene
      loadedScene.traverse(obj => {
        if (obj.isMesh) {
          scalarMapper.applyToMesh(obj, data, { colormap, clim });
        }
      });
      
      // Update colorbar with range and colormap, and show it automatically
      if (colorbar && clim) {
        try {
          colorbar.update(colormap, clim[0], clim[1]);
          // Auto-show colorbar when scalar data is applied
          colorbar.setVisible(true);
          vizState.scalar.colorbar = true;
          // Update GUI to reflect the state change
          if (vizGUI) {
            vizGUI.updateDisplay();
          }
        } catch (colorbarErr) {
          console.error('[setScalarData] Colorbar update failed:', colorbarErr);
        }
      }
      
      // Dispatch load data succeeded event
      stateManager.dispatch(StateEvent.LOAD_DATA_SUCCEEDED, {
        requestId,
        type: 'scalar',
        count: data.length,
        range: clim
      });
    }
  } catch (err) {
    console.error('[setScalarData] Error setting scalar data:', err);
    stateManager.dispatch(StateEvent.LOAD_DATA_FAILED, { error: err.message });
    console.error('[setScalarData] Stack trace:', err.stack);
  }
}

/* -------------------- Pivot control -------------------- */

function setPivotMode(mode) {
  if (!controls) return;

  if (mode === "WorldOrigin") {
    controls.target.set(0, 0, 0);
  } else {
    const modelRoot = meshManager?.getModelRoot();
    if (modelRoot) {
      const center = new THREE.Box3().setFromObject(modelRoot).getCenter(new THREE.Vector3());
      controls.target.copy(center);
    } else {
      controls.target.set(0, 0, 0);
    }
  }

  // Keep your canonical view direction relative to pivot
  const t = controls.target;
  camera.position.set(t.x - 300, t.y, t.z);
  camera.lookAt(t);

  controls.update();
  updateTargetMarker();
}

/* -------------------- Pivot marker -------------------- */

function installTargetMarker() {
  if (targetMarker) scene.remove(targetMarker);

  const geom = new THREE.SphereGeometry(4.0, 16, 16);
  const mat = new THREE.MeshBasicMaterial({ color: 0xffcc00 });
  targetMarker = new THREE.Mesh(geom, mat);
  targetMarker.position.copy(controls?.target ?? new THREE.Vector3());
  scene.add(targetMarker);
}

function updateTargetMarker() {
  if (!targetMarker || !controls) return;
  targetMarker.position.copy(controls.target);
}

/* -------------------- State Manager Access -------------------- */

/**
 * Get current application state (for debugging)
 * @returns {string} Current app state
 */
export function getAppState() {
  return stateManager?.getState() || 'uninitialized';
}

/**
 * Get full state snapshot (for debugging)
 * @returns {Object} Complete state snapshot
 */
export function getStateSnapshot() {
  return stateManager?.getSnapshot() || null;
}

/**
 * Get state transition history (for debugging)
 * @returns {Array} State transition history
 */
export function getStateHistory() {
  return stateManager?.getHistory() || [];
}
