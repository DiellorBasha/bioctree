import * as THREE from "three";
import { PinMarker } from "./geometry/pinMarker.js";
import { PickingSystem } from "./interaction/picking.js";
import { SelectionFX } from "./interaction/selectionFX.js";
import { ViewerCore } from './core/viewerCore.js';
import { createLightingRig } from './core/lighting.js';
import { AxesGizmo } from './core/gizmo.js';
import { createVisualizationControls } from './ui/visualizationControls.js';
import { ViewerUI } from './ui/viewerUI.js';
import { MeshManager } from './runtime/meshManager.js';
import { VisualizationManager } from './runtime/visualizationManager.js';

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

// UI system
let viewerUI = null;

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
    opacity: 1.0,
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
  overlays: {
    scalarField: 'none',
    colormap: 'viridis',
    autoRange: true
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
  
  // Initialize UI system
  viewerUI = new ViewerUI({
    hudElement: hud,
    loaderElement: document.getElementById("loaderHost"),
    loadAnimationDuration: 1500
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
    onChange: () => vizManager?.applyState(vizState)
  });
  
  // Initial visualization sync
  vizManager?.applyState(vizState);

  // Initialize loader component
  await viewerUI.initLoader();
  
  // Load default mesh only if glbUrl is provided
  if (glbUrl) {
    loadGLB(glbUrl).catch((err) => {
      console.error(err);
      viewerUI.showError(err);
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

  console.log('[handlePostLoad] loadedScene:', loadedScene);
  console.log('[handlePostLoad] bounds:', bounds);

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
  
  console.log('[handlePostLoad] Complete');
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
