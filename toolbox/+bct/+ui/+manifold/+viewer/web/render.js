import * as THREE from "three";
import { PinMarker } from "./geometry/pinMarker.js";
import { PickingSystem } from "./interaction/picking.js";
import { SelectionFX } from "./interaction/selectionFX.js";
import { ViewerCore } from './core/viewerCore.js';
import { createLightingRig } from './core/lighting.js';
import { createVisualizationControls } from './ui/visualizationControls.js';
import { MeshManager } from './runtime/meshManager.js';
import { VisualizationManager } from './runtime/visualizationManager.js';
import { LayerManager } from './runtime/layerManager.js';
import { ScalarMapper } from './visualization/scalarMapper.js';
import { Colorbar } from './ui/colorbar.js';
import { StateManager, StateEvent, AppState } from './core/stateManager.js';
import { createVectorLineSegments } from './visualization/lineSegments.js';
import { createLineSegments3D } from './visualization/lineSegments3D.js';
import { createPointCloud } from './visualization/pointCloud.js';
import { ParticleAdvection } from './visualization/particleAdvection.js';

// Application state manager
let stateManager = null;

// Particle advection systems
let particleFlows = new Map();  // name -> ParticleAdvection instance

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
let layerManager = null;
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

/**
 * Get diagnostic information about the viewer state
 */
export function getDiagnostics() {
  const diagnostics = {
    viewerInitialized: viewerCore !== null,
    rendererExists: renderer !== null,
    sceneExists: scene !== null,
    cameraExists: camera !== null,
    meshManagerExists: meshManager !== null,
    hasMesh: meshManager !== null && meshManager.hasLoaded(),
    sceneChildCount: scene ? scene.children.length : 0,
    meshRootChildren: viewerCore ? {
      matlab: viewerCore.roots.matlab.children.length,
      threejs: viewerCore.roots.threejs.children.length
    } : null,
    cameraPosition: camera ? {
      x: camera.position.x,
      y: camera.position.y,
      z: camera.position.z
    } : null,
    renderingActive: viewerCore ? viewerCore.isRunning : false
  };
  
  console.log('[Diagnostics] Full viewer state:', diagnostics);
  
  // Try to find mesh in scene
  if (scene) {
    const meshes = [];
    scene.traverse((obj) => {
      if (obj instanceof THREE.Mesh) {
        meshes.push({
          name: obj.name,
          visible: obj.visible,
          vertexCount: obj.geometry.attributes.position ? 
            obj.geometry.attributes.position.count : 0,
          hasNormals: obj.geometry.attributes.normal !== undefined,
          hasMaterial: obj.material !== null
        });
      }
    });
    diagnostics.meshesInScene = meshes;
    console.log('[Diagnostics] Meshes in scene:', meshes);
  }
  
  return diagnostics;
}

/* -------------------- Defaults -------------------- */

// Pivot mode: recommended "MeshCenter" for FreeSurfer surfaces
const PIVOT_MODE = "MeshCenter";

// Debug toggles (initial state)
const SHOW_TARGET = false; // hide pivot marker

// Visualization state (lil-gui contract)
const vizState = {
  surface: {
    material: 'default',  // 'default' or 'wireframe'
    color: '#ffffff',     // Base mesh color (white)
    wireframe: false      // Show wireframe overlay on top of mesh
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
    colorbar: false,
    clim: null  // null = auto, or [min, max] array
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
  layerManager = new LayerManager();
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

    // Update LineMaterial resolutions for LineSegments2 objects
    updateLineMaterialResolutions();

    // Update normals/tangents helpers if active (via vizManager)
    vizManager?.updateNormalsHelpers();
    vizManager?.updateTangentsHelpers();

    // Update particle advection systems
    particleFlows.forEach(flow => {
      if (flow.isAnimating) {
        flow.step(0.016);  // ~60 FPS timestep
      }
    });
  });

  // Start render loop
  viewerCore.start();
  
  // Create visualization controls GUI
  try {
    // Dispose old GUI if exists
    if (vizGUI) {
      vizGUI.destroy();
      vizGUI = null;
    }
    
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
 * Update LineMaterial resolution for all LineSegments2 objects
 * Called each frame to ensure line width renders correctly on viewport resize
 * @private
 */
function updateLineMaterialResolutions() {
  if (!scene || !renderer) return;
  
  const width = renderer.domElement.width;
  const height = renderer.domElement.height;
  
  scene.traverse((obj) => {
    // Check if object has LineMaterial (from LineSegments2)
    if (obj.material && obj.material.isLineMaterial) {
      obj.material.resolution.set(width, height);
    }
  });
}

/**
 * Handle post-load setup (shared by all loaders)
 * @private
 */
function handlePostLoad() {
  const loadedScene = meshManager.getLoadedScene();
  const bounds = meshManager.getBounds();
  
  console.log('[handlePostLoad] Post-load setup:', {
    hasScene: !!loadedScene,
    bounds: bounds,
    pivotMode: PIVOT_MODE
  });

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
  
  console.log('[handlePostLoad] Post-load complete');
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
  
  console.log('[setMeshFromData] Called with data:', {
    hasVertices: !!(meshData && meshData.vertices),
    hasFaces: !!(meshData && meshData.faces),
    vertexCount: meshData && meshData.vertices ? meshData.vertices.length / 3 : 0,
    faceCount: meshData && meshData.faces ? meshData.faces.length / 3 : 0,
    frame: meshData && meshData.frame,
    indexBase: meshData && meshData.indexBase
  });
  
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
    
    // Clear all layers (scalars, vectors, points)
    if (layerManager) {
      layerManager.clearAll();
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
 * @param {string} scalarData.action - 'add'|'set'|'clear'
 * @param {string} [scalarData.name='default'] - Layer name for add/clear operations
 * @param {string} [scalarData.mode='replace'] - Blending mode: 'add'|'replace'|'multiply'|'max'|'min'
 * @param {Array} [scalarData.data] - Flat array of scalar values
 */
export function setScalarData(scalarData) {
  if (!scalarMapper || !meshManager || !stateManager) {
    console.error('[setScalarData] Viewer not initialized');
    return;
  }

  try {
    const action = scalarData.action || 'set';
    const name = scalarData.name || 'default';
    const mode = scalarData.mode || 'replace';

    if (action === 'clear') {
      // Dispatch clear data event
      stateManager.dispatch(StateEvent.CLEAR_DATA_REQUESTED);
      
      // Clear specific layer or all
      if (scalarData.name) {
        console.log(`[setScalarData] Clearing scalar layer: ${name}`);
        // Note: Scalar layers currently don't support independent clearing
        // This would require layer-based color management
        // For now, clear all
      }
      
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
      
      // Clear all scalar layers
      if (layerManager) {
        layerManager.clearAllScalarLayers();
      }
      
      // Hide colorbar and update vizState
      if (colorbar) {
        colorbar.setVisible(false);
        vizState.scalar.colorbar = false;
        if (vizGUI) {
          vizGUI.updateDisplay();
        }
      }
    } else if (action === 'add' || action === 'set' || action === 'update') {
      // 'update' is legacy alias for 'set'
      if (action === 'update') {
        console.warn('[setScalarData] action="update" is deprecated, use "set" instead');
      }
      
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

      // Apply blending mode if currentScalarData exists and mode is not 'replace'
      let finalData = data;
      if (currentScalarData && mode !== 'replace') {
        if (currentScalarData.length !== data.length) {
          console.error('[setScalarData] Cannot blend: scalar data length mismatch');
          return;
        }
        
        finalData = new Array(data.length);
        
        switch (mode) {
          case 'add':
            for (let i = 0; i < data.length; i++) {
              finalData[i] = currentScalarData[i] + data[i];
            }
            console.log(`[setScalarData] Blending mode: ADD (existing + new)`);
            break;
          
          case 'multiply':
            for (let i = 0; i < data.length; i++) {
              finalData[i] = currentScalarData[i] * data[i];
            }
            console.log(`[setScalarData] Blending mode: MULTIPLY (existing * new)`);
            break;
          
          case 'max':
            for (let i = 0; i < data.length; i++) {
              finalData[i] = Math.max(currentScalarData[i], data[i]);
            }
            console.log(`[setScalarData] Blending mode: MAX`);
            break;
          
          case 'min':
            for (let i = 0; i < data.length; i++) {
              finalData[i] = Math.min(currentScalarData[i], data[i]);
            }
            console.log(`[setScalarData] Blending mode: MIN`);
            break;
          
          default:
            console.warn(`[setScalarData] Unknown blend mode: ${mode}, using replace`);
            finalData = data;
        }
      }

      // Cache the blended data for future updates
      currentScalarData = finalData;
      
      // Use colormap from vizState
      const colormap = vizState.scalar.colormap;
      
      // Determine clim: use custom if set, otherwise auto-compute
      let clim = null;
      if (vizState.scalar.clim !== null) {
        // Use custom color limits
        clim = vizState.scalar.clim;
      } else if (vizState.scalar.autoRange) {
        // Auto-compute clim from data
        let min = Infinity;
        let max = -Infinity;
        for (let i = 0; i < finalData.length; i++) {
          if (finalData[i] < min) min = finalData[i];
          if (finalData[i] > max) max = finalData[i];
        }
        clim = [min, max];
      }

      // Apply to all meshes in scene
      let meshObject = null;
      loadedScene.traverse(obj => {
        if (obj.isMesh) {
          scalarMapper.applyToMesh(obj, finalData, { colormap, clim });
          if (!meshObject) meshObject = obj;
        }
      });
      
      // Store layer in manager
      if (layerManager && meshObject) {
        layerManager.setScalarLayer(name, {
          data: finalData,
          meshObject: meshObject,
          metadata: { colormap, clim, action, mode }
        });
        console.log(`[setScalarData] ${action === 'add' ? 'Added' : 'Set'} scalar layer: ${name} (mode: ${mode})`);
      }
      
      // Update colorbar with range and colormap
      if (colorbar && clim) {
        try {
          colorbar.update(colormap, clim[0], clim[1]);
          colorbar.setVisible(true);
          vizState.scalar.colorbar = true;
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
        name: name,
        count: finalData.length,
        range: clim
      });
      
      console.log(`[setScalarData] Scalar layer '${name}' applied: ${finalData.length} values, range [${clim[0].toFixed(2)}, ${clim[1].toFixed(2)}]`);
    }
  } catch (err) {
    console.error('[setScalarData] Error setting scalar data:', err);
    stateManager.dispatch(StateEvent.LOAD_DATA_FAILED, { error: err.message });
    console.error('[setScalarData] Stack trace:', err.stack);
  }
}

/**
 * Set color limits for scalar visualization
 * Called from MATLAB via HTMLComponent.Data = {colorLimits: climData}
 * @param {Object} climData - Color limit configuration
 */
export function setColorLimits(climData) {
  try {
    if (!climData || !climData.action || climData.action !== 'setClim') {
      console.warn('[setColorLimits] Invalid color limits payload');
      return;
    }
    
    if (climData.clim === 'auto') {
      // Reset to auto range
      vizState.scalar.clim = null;
      vizState.scalar.autoRange = true;
      console.log('[setColorLimits] Color limits reset to auto');
    } else if (Array.isArray(climData.clim) && climData.clim.length === 2) {
      // Set custom limits
      vizState.scalar.clim = climData.clim;
      vizState.scalar.autoRange = false;
      console.log(`[setColorLimits] Color limits set to [${climData.clim[0]}, ${climData.clim[1]}]`);
    } else {
      console.warn('[setColorLimits] Invalid clim format:', climData.clim);
      return;
    }
    
    // Re-apply current scalar data with new limits
    if (layerManager) {
      const currentLayer = layerManager.getScalarLayer('default');
      if (currentLayer && currentLayer.data) {
        const colormap = vizState.scalar.colormap;
        let clim = vizState.scalar.clim;
        
        // If auto, recompute from data
        if (clim === null && vizState.scalar.autoRange) {
          let min = Infinity;
          let max = -Infinity;
          for (let i = 0; i < currentLayer.data.length; i++) {
            if (currentLayer.data[i] < min) min = currentLayer.data[i];
            if (currentLayer.data[i] > max) max = currentLayer.data[i];
          }
          clim = [min, max];
        }
        
        // Re-apply to mesh
        loadedScene.traverse(obj => {
          if (obj.isMesh) {
            scalarMapper.applyToMesh(obj, currentLayer.data, { colormap, clim });
          }
        });
        
        // Update colorbar
        if (colorbar && clim) {
          colorbar.update(colormap, clim[0], clim[1]);
        }
        
        console.log(`[setColorLimits] Scalar visualization updated with new limits`);
      }
    }
  } catch (err) {
    console.error('[setColorLimits] Error setting color limits:', err);
  }
}

/**
 * Set vector data for quiver visualization
 * Called from MATLAB via HTMLComponent.Data = {vector: vectorData}
 * @param {Object} vectorData - Vector field configuration
 * @param {string} vectorData.action - 'add'|'set'|'clear'
 * @param {string} [vectorData.name='default'] - Layer name for add/clear operations
 * @param {Array} [vectorData.data] - Flat array of vector components [vx,vy,vz,...]
 * @param {string} [vectorData.support] - 'face' or 'vertex'
 * @param {number} [vectorData.stride] - Draw every Nth vector
 * @param {number} [vectorData.lengthScale] - Arrow length scaling
 * @param {number} [vectorData.maxLength] - Maximum arrow length
 * @param {number} [vectorData.minMagnitude] - Minimum vector magnitude to display
 */
export function setVectorData(vectorData) {
  if (!meshManager || !scene || !stateManager) {
    console.error('[setVectorData] Viewer not initialized');
    return;
  }

  try {
    const action = vectorData.action || 'set';
    const name = vectorData.name || 'default';

    if (action === 'clear') {
      if (vectorData.name) {
        // Clear specific layer
        if (layerManager && layerManager.clearVectorLayer(name)) {
          console.log(`[setVectorData] Cleared vector layer: ${name}`);
        } else {
          console.warn(`[setVectorData] Vector layer not found: ${name}`);
        }
      } else {
        // Clear all vector layers
        if (layerManager) {
          layerManager.clearAllVectorLayers();
          console.log('[setVectorData] Cleared all vector layers');
        }
      }
    } else if (action === 'add' || action === 'set' || action === 'update') {
      // 'update' is legacy alias for 'set'
      if (action === 'update') {
        console.warn('[setVectorData] action="update" is deprecated, use "set" instead');
      }
      
      // For 'set', clear existing layer with this name
      if (action === 'set' && layerManager) {
        layerManager.clearVectorLayer(name);
      }
      
      // Get loaded mesh
      const loadedScene = meshManager.getLoadedScene();
      if (!loadedScene) {
        console.error('[setVectorData] No mesh loaded. Call setMesh first.');
        return;
      }

      const { 
        data, 
        positions: positionsRaw,
        normals: normalsRaw,
        support, 
        stride, 
        lengthScale, 
        maxLength, 
        minMagnitude,
        style = 'arrow',  // 'arrow' (default, 3D InstancedMesh) or 'line' (LineSegments)
        frame = 'matlab',  // 'matlab' (default, Z-up) or 'threejs' (Y-up)
        color = 0xff0000,  // Default red for line segments
        lineWidth = 2      // Default line width
      } = vectorData;
      
      if (!data || data.length === 0) {
        console.error('[setVectorData] No vector data provided');
        return;
      }

      // Find mesh in loaded scene
      let mesh = null;
      loadedScene.traverse(obj => {
        if (obj.isMesh && !mesh) {
          mesh = obj;
        }
      });

      if (!mesh) {
        console.error('[setVectorData] No mesh found in loaded scene');
        return;
      }

      // Get positions and normals from MATLAB payload
      const positions = positionsRaw ? new Float32Array(positionsRaw) : null;
      const normals = normalsRaw ? new Float32Array(normalsRaw) : null;
      
      if (!positions) {
        console.error('[setVectorData] No positions provided in payload');
        return;
      }
      
      const numPositions = positions.length / 3;
      const numVectors = data.length / 3;
      
      if (numPositions !== numVectors) {
        console.error(`[setVectorData] Position count (${numPositions}) does not match vector count (${numVectors})`);
        return;
      }
      
      console.log(`[setVectorData] Frame: ${frame}, Support: ${support}, Vectors: ${numVectors}` + 
                  (normals ? `, with normals` : `, no normals`));
      console.log(`[setVectorData] Style: ${style}, Stride: ${stride}, LengthScale: ${lengthScale}`);
      if (style === 'line') {
        console.log(`[setVectorData] Color: 0x${color.toString(16)}, LineWidth: ${lineWidth}`);
      }

      // Create vector visualization using LineSegments
      const vectorsFloat32 = new Float32Array(data);
      
      const vectorObject = createVectorLineSegments({
        positions: positions,
        vectors: vectorsFloat32,
        normals: normals,
        style: style || 'arrow',  // 'arrow' or 'line'
        stride: stride || 5,
        lengthScale: lengthScale || 1.0,
        maxLength: maxLength || 10.0,
        minMagnitude: minMagnitude || 1e-12,
        color: color,
        linewidth: lineWidth
      });
      console.log(`[setVectorData] Created LineSegments (${style}): ${vectorObject.userData.vectorCount} vectors`);

      // Store layer metadata in object
      vectorObject.userData.layerName = name;
      vectorObject.userData.layerType = 'vector';

      // Determine frame root
      let frameRoot = scene;
      if (frame === 'matlab') {
        frameRoot = viewerCore.roots.matlab;
        console.log('[setVectorData] ✓ Using MATLAB frame root (Z-up → Y-up transform)');
      } else if (frame === 'threejs') {
        frameRoot = viewerCore.roots.threejs;
        console.log('[setVectorData] ✓ Using three.js frame root (no transform)');
      } else {
        console.warn(`[setVectorData] ⚠ Unknown frame: ${frame}, defaulting to MATLAB frame`);
        frameRoot = viewerCore.roots.matlab;
      }
      
      // Verify mesh and vectors are in same frame
      const meshFrame = meshManager.modelRoot?.parent === viewerCore.roots.matlab ? 'matlab' : 'threejs';
      console.log(`[setVectorData] Mesh in: ${meshFrame}, Vectors in: ${frame}` + 
                  (meshFrame === frame ? ' ✓ MATCH' : ' ✗ MISMATCH!'));
      
      frameRoot.add(vectorObject);
      console.log(`[setVectorData] ✓ Added vectors to ${frame} frame root`);
      
      // Store in layer manager
      if (layerManager) {
        layerManager.setVectorLayer(name, {
          quiverObject: vectorObject,
          metadata: { style, stride, lengthScale, maxLength, support, frame, action }
        });
        console.log(`[setVectorData] ${action === 'add' ? 'Added' : 'Set'} vector layer: ${name}`);
      }
      
      console.log(`[setVectorData] Vector layer '${name}' added: ${vectorObject.userData.vectorCount} vectors (style: ${style})`);
    }
  } catch (err) {
    console.error('[setVectorData] Error setting vector data:', err);
    console.error('[setVectorData] Stack trace:', err.stack);
  }
}

/**
 * Set point cloud data for marker visualization
 * Called from MATLAB via HTMLComponent.Data = {point: pointData}
 * @param {Object} pointData - Point cloud configuration
 * @param {string} pointData.action - 'add'|'set'|'clear'
 * @param {string} [pointData.name='default'] - Layer name for add/clear operations
 * @param {Array} [pointData.positions] - Flat array of positions [x,y,z,...]
 * @param {Array<number>} [pointData.indices] - Vertex/face indices to mark
 * @param {number} [pointData.radius=1.0] - Sphere radius
 * @param {number|Array} [pointData.color=0xff0000] - Color (hex or array of hex values)
 * @param {number} [pointData.opacity=1.0] - Opacity (0-1)
 * @param {boolean} [pointData.transparent=false] - Enable transparency
 * @param {string} [pointData.frame='matlab'] - Coordinate frame ('matlab' or 'threejs')
 */
export function setPointData(pointData) {
  if (!meshManager || !scene || !stateManager) {
    console.error('[setPointData] Viewer not initialized');
    return;
  }

  try {
    const action = pointData.action || 'set';
    const name = pointData.name || 'default';

    if (action === 'clear') {
      if (pointData.name) {
        // Clear specific layer
        if (layerManager && layerManager.clearPointLayer(name)) {
          console.log(`[setPointData] Cleared point layer: ${name}`);
        } else {
          console.warn(`[setPointData] Point layer not found: ${name}`);
        }
      } else {
        // Clear all point layers
        if (layerManager) {
          layerManager.clearAllPointLayers();
          console.log('[setPointData] Cleared all point layers');
        }
      }
    } else if (action === 'add' || action === 'set') {
      // For 'set', clear existing layer with this name
      if (action === 'set' && layerManager) {
        layerManager.clearPointLayer(name);
      }
      
      const {
        positions: positionsRaw,
        indices,
        radius = 1.0,
        color = 0xff0000,
        opacity = 1.0,
        transparent = false,
        frame = 'matlab'
      } = pointData;
      
      if ((!positionsRaw || positionsRaw.length === 0) && (!indices || indices.length === 0)) {
        console.error('[setPointData] No positions or indices provided');
        return;
      }

      let positions = null;
      
      if (indices && indices.length > 0) {
        // Create positions from vertex indices
        const loadedScene = meshManager.getLoadedScene();
        if (!loadedScene) {
          console.error('[setPointData] No mesh loaded. Call setMesh first.');
          return;
        }
        
        // Find mesh in loaded scene
        let mesh = null;
        loadedScene.traverse(obj => {
          if (obj.isMesh && !mesh) {
            mesh = obj;
          }
        });
        
        if (!mesh || !mesh.geometry) {
          console.error('[setPointData] No mesh geometry found');
          return;
        }
        
        const vertexPositions = mesh.geometry.attributes.position.array;
        positions = new Float32Array(indices.length * 3);
        
        for (let i = 0; i < indices.length; i++) {
          const idx = indices[i];
          positions[i * 3] = vertexPositions[idx * 3];
          positions[i * 3 + 1] = vertexPositions[idx * 3 + 1];
          positions[i * 3 + 2] = vertexPositions[idx * 3 + 2];
        }
        
        console.log(`[setPointData] Created positions from ${indices.length} vertex indices`);
      } else {
        positions = new Float32Array(positionsRaw);
      }
      
      const numPoints = positions.length / 3;
      console.log(`[setPointData] Creating point cloud: ${numPoints} points, radius ${radius}`);
      
      // Create point cloud visualization
      const pointObject = createPointCloud({
        positions: positions,
        radius: radius,
        color: color,
        opacity: opacity,
        transparent: transparent,
        useInstancing: numPoints > 100 // Use instancing for large point clouds
      });
      
      // Store layer metadata in object
      pointObject.userData.layerName = name;
      pointObject.userData.layerType = 'point';
      
      // Determine frame root
      let frameRoot = scene;
      if (frame === 'matlab') {
        frameRoot = viewerCore.roots.matlab;
        console.log('[setPointData] ✓ Using MATLAB frame root (Z-up → Y-up transform)');
      } else if (frame === 'threejs') {
        frameRoot = viewerCore.roots.threejs;
        console.log('[setPointData] ✓ Using three.js frame root (no transform)');
      } else {
        console.warn(`[setPointData] ⚠ Unknown frame: ${frame}, defaulting to MATLAB frame`);
        frameRoot = viewerCore.roots.matlab;
      }
      
      frameRoot.add(pointObject);
      console.log(`[setPointData] ✓ Added point cloud to ${frame} frame root`);
      
      // Store in layer manager
      if (layerManager) {
        layerManager.setPointLayer(name, {
          pointObject: pointObject,
          metadata: { radius, color, opacity, transparent, frame, action }
        });
        console.log(`[setPointData] ${action === 'add' ? 'Added' : 'Set'} point layer: ${name}`);
      }
      
      console.log(`[setPointData] Point layer '${name}' added: ${numPoints} points`);
    }
  } catch (err) {
    console.error('[setPointData] Error setting point data:', err);
    console.error('[setPointData] Stack trace:', err.stack);
  }
}

/**
 * setLineData - Set arbitrary line segments
 * 
 * @param {Object} lineData - Line data configuration
 * @param {string} [lineData.name='default'] - Layer name for management
 * @param {string} [lineData.action='set'] - 'set', 'add', or 'clear'
 * @param {Float32Array} lineData.segments - Line segment endpoints [x1,y1,z1,x2,y2,z2,...]
 * @param {number|string} [lineData.color=0xff0000] - Line color (hex number or CSS string)
 * @param {number} [lineData.linewidth=2] - Line width in pixels
 * @param {string} [lineData.frame='matlab'] - Coordinate frame ('matlab' or 'threejs')
 */
export function setLineData(lineData) {
  if (!meshManager || !scene || !stateManager) {
    console.error('[setLineData] Viewer not initialized');
    return;
  }

  try {
    const action = lineData.action || 'set';
    const name = lineData.name || 'default';

    if (action === 'clear') {
      if (lineData.name) {
        // Clear specific layer
        if (layerManager && layerManager.clearLineLayer(name)) {
          console.log(`[setLineData] Cleared line layer: ${name}`);
        } else {
          console.warn(`[setLineData] Line layer not found: ${name}`);
        }
      } else {
        // Clear all line layers
        if (layerManager) {
          layerManager.clearAllLineLayers();
          console.log('[setLineData] Cleared all line layers');
        }
      }
    } else if (action === 'add' || action === 'set') {
      // For 'set', clear existing layer with this name
      if (action === 'set' && layerManager) {
        layerManager.clearLineLayer(name);
      }
      
      const {
        segments,
        color = 0xff0000,
        linewidth = 2,
        frame = 'matlab'
      } = lineData;
      
      if (!segments || segments.length === 0) {
        console.error('[setLineData] No segments provided');
        return;
      }

      const segmentCount = segments.length / 6;
      console.log(`[setLineData] Creating line segments: ${segmentCount} segments, linewidth ${linewidth}`);
      
      // Create line segment visualization
      const lineObject = createLineSegments3D({
        segments: new Float32Array(segments),
        color: color,
        linewidth: linewidth
      });
      
      // Store layer metadata in object
      lineObject.userData.layerName = name;
      lineObject.userData.layerType = 'line';
      lineObject.userData.segmentCount = segmentCount;
      
      // Determine frame root
      let frameRoot = scene;
      if (frame === 'matlab') {
        frameRoot = viewerCore.roots.matlab;
        console.log('[setLineData] ✓ Using MATLAB frame root (Z-up → Y-up transform)');
      } else if (frame === 'threejs') {
        frameRoot = viewerCore.roots.threejs;
        console.log('[setLineData] ✓ Using three.js frame root (no transform)');
      } else {
        console.warn(`[setLineData] ⚠ Unknown frame: ${frame}, defaulting to MATLAB frame`);
        frameRoot = viewerCore.roots.matlab;
      }
      
      frameRoot.add(lineObject);
      console.log(`[setLineData] ✓ Added line segments to ${frame} frame root`);
      
      // Store in layer manager
      if (layerManager) {
        layerManager.setLineLayer(name, {
          lineObject: lineObject,
          metadata: { segmentCount, color, linewidth, frame, action }
        });
        console.log(`[setLineData] ${action === 'add' ? 'Added' : 'Set'} line layer: ${name}`);
      }
      
      console.log(`[setLineData] Line layer '${name}' added: ${segmentCount} segments`);
    }
  } catch (err) {
    console.error('[setLineData] Error setting line data:', err);
    console.error('[setLineData] Stack trace:', err.stack);
  }
}

/* -------------------- Pivot control -------------------- */

/**
 * Set scene background color
 * Called from MATLAB via HTMLComponent.Data = {background: {color: ...}}
 * @param {Object} backgroundData - Background configuration
 * @param {number|string} backgroundData.color - Color (hex number, color name, or 'none')
 */
export function setBackground(backgroundData) {
  if (!scene) {
    console.error('[setBackground] Viewer not initialized');
    return;
  }

  try {
    const { color } = backgroundData;
    
    if (color === 'none' || color === null) {
      // Transparent background
      scene.background = null;
      console.log('[setBackground] Set background to transparent');
    } else if (typeof color === 'string') {
      // Named color
      scene.background = new THREE.Color(color);
      console.log(`[setBackground] Set background to '${color}'`);
    } else if (typeof color === 'number') {
      // Hex color
      scene.background = new THREE.Color(color);
      console.log(`[setBackground] Set background to 0x${color.toString(16).padStart(6, '0')}`);
    } else {
      console.error('[setBackground] Invalid color:', color);
    }
  } catch (err) {
    console.error('[setBackground] Error setting background:', err);
    console.error('[setBackground] Stack trace:', err.stack);
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

  // Position camera at distance proportional to mesh size
  const bounds = meshManager?.getBounds();
  const distance = bounds ? bounds.radius * 2.5 : 300;  // 2.5x radius or default 300
  
  const t = controls.target;
  camera.position.set(t.x - distance, t.y, t.z);
  camera.lookAt(t);

  controls.update();
  updateTargetMarker();
  
  console.log('[setPivotMode] Camera positioned:', {
    target: controls.target,
    cameraPosition: camera.position,
    distance: distance,
    meshRadius: bounds?.radius
  });
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

/**
 * Set up particle flow advection system
 * Called from MATLAB via HTMLComponent.Data = {particleFlow: flowData}
 * @param {Object} flowData - Particle flow configuration
 */
export function setParticleFlow(flowData) {
  try {
    if (!viewerCore) {
      console.error('[setParticleFlow] Viewer not initialized');
      return;
    }

    const name = flowData.name || 'default';
    const action = flowData.action || 'set';

    if (action === 'clear') {
      // Clear particle flow
      if (particleFlows.has(name)) {
        const flow = particleFlows.get(name);
        flow.stop();
        const particleSystem = flow.getParticleSystem();
        if (particleSystem && particleSystem.parent) {
          particleSystem.parent.remove(particleSystem);
        }
        particleFlows.delete(name);
        console.log(`[setParticleFlow] Cleared particle flow: ${name}`);
      }
      return;
    }

    // Get mesh
    const loadedScene = meshManager.getLoadedScene();
    if (!loadedScene) {
      console.error('[setParticleFlow] No mesh loaded');
      return;
    }

    let mesh = null;
    loadedScene.traverse(obj => {
      if (obj.isMesh && !mesh) {
        mesh = obj;
      }
    });

    if (!mesh) {
      console.error('[setParticleFlow] No mesh found in scene');
      return;
    }

    // Parse vector field
    const { vectorField, numParticles = 1000, stepSize = 0.1, particleSize = 2.0, 
            particleColor = 0x00ffff, fade = true, fadeTime = 2.0, respawn = true,
            autoStart = true } = flowData;

    if (!vectorField || !vectorField.data) {
      console.error('[setParticleFlow] No vector field provided');
      return;
    }

    // Create or update particle flow
    if (particleFlows.has(name) && action === 'add') {
      console.warn('[setParticleFlow] Particle flow already exists, replacing:', name);
    }

    // Clear old flow if exists
    if (particleFlows.has(name)) {
      const oldFlow = particleFlows.get(name);
      oldFlow.stop();
      const oldSystem = oldFlow.getParticleSystem();
      if (oldSystem && oldSystem.parent) {
        oldSystem.parent.remove(oldSystem);
      }
    }

    // Create new flow
    const flow = new ParticleAdvection({
      mesh: mesh,
      vectorField: {
        support: vectorField.support || 'face',
        data: new Float32Array(vectorField.data)
      },
      numParticles: numParticles,
      stepSize: stepSize,
      particleSize: particleSize,
      particleColor: particleColor,
      fade: fade,
      fadeTime: fadeTime,
      respawn: respawn
    });

    // Add particle system to scene
    const particleSystem = flow.getParticleSystem();
    if (particleSystem) {
      scene.add(particleSystem);
    }

    // Store flow
    particleFlows.set(name, flow);

    // Start animation if requested
    if (autoStart) {
      flow.start();
    }

    console.log(`[setParticleFlow] Created particle flow '${name}': ${numParticles} particles, support=${vectorField.support}`);

  } catch (err) {
    console.error('[setParticleFlow] Error:', err);
    console.error(err.stack);
  }
}

/**
 * Get particle flows (for animation loop integration)
 * @returns {Map} Map of particle advection systems
 */
export function getParticleFlows() {
  return particleFlows;
}
