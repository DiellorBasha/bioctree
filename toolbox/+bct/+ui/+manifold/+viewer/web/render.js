import * as THREE from "three";
import { PinMarker } from "./geometry/pinMarker.js";
import { PickingSystem } from "./interaction/picking.js";
import { SelectionFX } from "./interaction/selectionFX.js";
import { ViewerCore } from './core/viewerCore.js';
import { createLightingRig } from './core/lighting.js';
import { AxesGizmo } from './core/gizmo.js';
import { createVisualizationControls } from './ui/visualizationControls.js';
import { MeshManager } from './runtime/meshManager.js';
import { VisualizationManager } from './runtime/visualizationManager.js';
import { ScalarMapper } from './visualization/scalarMapper.js';
import { Colorbar } from './ui/colorbar.js';

// Core rendering system
let viewerCore = null;

// Convenience accessors (populated by viewerCore)
let renderer, scene, camera, controls;
let canvas, hud;

// Core subsystems
let lightRig = null;
let axesGizmo = null;

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
    visible: true,
    shading: 'smooth',
    colorMode: 'uniform'
  },
  edges: {
    wireframe: false,
    width: 1.0,
    color: '#ffffff'
  },
  helpers: {
    vertexNormals: false,
    faceNormals: false,
    tangents: false
  },
  scalar: {
    colormap: 'viridis',
    autoRange: true,
    colorbar: false
  },
  scene: {
    lighting: true,
    axes: true,
    background: '#000000'
  }
};

// GUI instance
let vizGUI = null;

/* -------------------- Viewer Initialization -------------------- */

export async function initViewer({ canvasEl, hudEl, glbUrl = null }) {
  canvas = canvasEl;
  hud = hudEl;

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

  // Initialize axes gizmo
  axesGizmo = new AxesGizmo();
  axesGizmo.init({ backgroundColor: 0x000000 });

  // Initialize runtime managers
  meshManager = new MeshManager(viewerCore);
  vizManager = new VisualizationManager(viewerCore, meshManager, lightRig, axesGizmo);
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
    axesGizmo.update(camera);
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
    axesGizmo.update(camera);
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

  // Register gizmo overlay render callback (after main render)
  viewerCore.onRender(() => {
    axesGizmo.render(renderer, canvas);
  });

  // Start render loop
  viewerCore.start();
  
  // Create visualization controls GUI
  vizGUI = createVisualizationControls({
    vizState,
    onChange: () => {
      vizManager?.applyState(vizState);
      // Update colorbar visibility
      colorbar?.setVisible(vizState.scalar.colorbar);
      // Re-apply scalar data if colormap changed
      if (currentScalarData) {
        setScalarData({ action: 'update', data: currentScalarData });
      }
    }
  });
  
  // Initial visualization sync
  vizManager?.applyState(vizState);
  
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
  const t0 = performance.now();
  const loadedScene = meshManager.getLoadedScene();
  const bounds = meshManager.getBounds();

  // Don't log entire scene object (too expensive for large meshes)
  console.log(`[handlePostLoad] Scene loaded, bounds radius: ${bounds.radius.toFixed(2)}`);

  // Set orbit pivot
  const t1 = performance.now();
  setPivotMode(PIVOT_MODE);
  const t2 = performance.now();
  console.log(`[handlePostLoad] setPivotMode: ${(t2-t1).toFixed(2)}ms`);
  
  // Apply visualization state
  const t3 = performance.now();
  vizManager?.applyState(vizState);
  const t4 = performance.now();
  console.log(`[handlePostLoad] applyState: ${(t4-t3).toFixed(2)}ms`);
  
  // Update debug visuals
  updateTargetMarker();
  
  // Setup picking
  const t5 = performance.now();
  pickingSystem?.collectPickables(loadedScene);
  const t6 = performance.now();
  console.log(`[handlePostLoad] collectPickables: ${(t6-t5).toFixed(2)}ms`);
  
  // Scale pin to mesh size
  if (pin) {
    pin.setLength(bounds.radius * 0.1);
  }

  const t7 = performance.now();
  console.log(`[handlePostLoad] ===== Complete: ${(t7-t0).toFixed(2)}ms =====`);
}

export async function loadGLB(url) {
  console.log('[loadGLB] Starting load:', url);
  return viewerUI.withLoadingUI(
    async () => {
      await meshManager.loadGLB(url);
      const scene = meshManager.getLoadedScene();
      console.log('[loadGLB] Scene loaded:', scene);
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
  console.log('[loadModel] Called with url:', url);
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
  console.log('[loadJSON] Starting load:', url);
  return viewerUI.withLoadingUI(
    async () => {
      await meshManager.loadJSON(url);
      const scene = meshManager.getLoadedScene();
      console.log('[loadJSON] Scene loaded:', scene);
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
  
  if (!meshManager) {
    console.error('[setMeshFromData] Viewer not initialized. Call initViewer first.');
    return;
  }

  try {
    console.log('[setMeshFromData] Starting mesh load from MATLAB data');
    
    // Load mesh from buffers
    const t0 = performance.now();
    meshManager.setMeshFromBuffers(meshData);
    const t1 = performance.now();
    console.log(`[setMeshFromData] setMeshFromBuffers: ${(t1-t0).toFixed(2)}ms`);
    
    // Run post-load setup
    const t2 = performance.now();
    handlePostLoad();
    const t3 = performance.now();
    console.log(`[setMeshFromData] handlePostLoad: ${(t3-t2).toFixed(2)}ms`);
    
    const tEnd = performance.now();
    console.log(`[setMeshFromData] ===== TOTAL JavaScript time: ${(tEnd-tTotal).toFixed(2)}ms =====`);
  } catch (err) {
    console.error('[setMeshFromData] Error loading mesh:', err);
    viewerUI?.showError(err);
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
  if (!scalarMapper || !meshManager) {
    console.error('[setScalarData] Viewer not initialized');
    return;
  }

  try {
    if (scalarData.action === 'clear') {
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
      // Hide colorbar
      if (colorbar) {
        colorbar.setVisible(false);
      }
      console.log('[setScalarData] Cleared scalar visualization');
    } else if (scalarData.action === 'update') {
      // Apply scalar data to mesh
      const loadedScene = meshManager.getLoadedScene();
      if (!loadedScene) {
        console.error('[setScalarData] No mesh loaded. Call setMesh first.');
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
      
      // Update colorbar with range and colormap
      if (colorbar && clim) {
        try {
          colorbar.update(colormap, clim[0], clim[1]);
        } catch (colorbarErr) {
          console.error('[setScalarData] Colorbar update failed:', colorbarErr);
        }
      }
    }
  } catch (err) {
    console.error('[setScalarData] Error setting scalar data:', err);
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
