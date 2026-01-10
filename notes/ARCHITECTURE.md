# Viewer Architecture - Separation of Concerns

## Overview
The viewer is now organized into clean layers with clear responsibilities:

```
┌─────────────────────────────────────────────────────┐
│              render.js (Application)                │
│  - Orchestration & initialization                   │
│  - Picking callbacks                                │
│  - Post-load coordination                           │
└──────────┬──────────────┬────────────┬──────────────┘
           │              │            │
    ┌──────▼──────┐  ┌───▼───────┐  ┌▼──────────┐
    │   ViewerUI  │  │MeshManager│  │ViewerCore │
    │     (UI)    │  │  (Data)   │  │   (Core)  │
    └─────────────┘  └───────────┘  └───────────┘
```

---

## Layer 1: Core Infrastructure (`core/`)
**Purpose:** Pure Three.js rendering system

### viewerCore.js
- Orchestrates scene/camera/renderer creation via factories
- Manages animation loop (`requestAnimationFrame`)
- Handles resize events
- Manages OrbitControls
- Provides callback registration (`onRender`, `onControlsChange`)

**Owns:**
- `scene` - THREE.Scene
- `camera` - THREE.PerspectiveCamera
- `renderer` - THREE.WebGLRenderer
- `controls` - OrbitControls
- `roots` - Scene structure groups

**Does NOT know about:**
- ❌ Meshes or geometry loading
- ❌ Materials
- ❌ Picking/interaction
- ❌ UI elements
- ❌ Application state

---

## Layer 2: Runtime Data Management (`runtime/`)
**Purpose:** Data lifecycle and state management

### meshManager.js
- Loads models from URLs (GLB, GLTF, JSON)
- Creates meshes and materials
- Manages model state (add/remove from scene)
- Disposes resources
- Computes bounding boxes

**Owns:**
- `modelRoot` - Container for loaded model
- `loadedScene` - Reference to loaded content

**Key Methods:**
- `loadModelFromUrl(url)` - Route by extension
- `loadGLB(url)` - Load binary model
- `loadJSON(url)` - Load JSON geometry
- `clearModel()` - Dispose resources
- `getBounds()` - Calculate bounding box

**Does NOT:**
- ❌ Update UI (loader, HUD)
- ❌ Manage camera/controls
- ❌ Handle picking
- ❌ Coordinate post-load setup

### visualizationManager.js
- Applies visualization state to meshes
- Manages material switching (base/wireframe)
- Creates debug helpers (normals, tangents, etc.)
- Owns light rig, axes gizmo

---

## Layer 3: UI System (`ui/`)
**Purpose:** User interface components and feedback

### viewerUI.js
- Loader overlay (show/hide/progress)
- HUD messages
- Animation timing and transitions
- Loading state management

**Key Methods:**
- `showLoader()` / `hideLoader()`
- `setLoaderProgress(percent)`
- `setHud(text)`
- `startLoading(message)`
- `completeLoading(message, onComplete)`
- `showError(error)`
- `withLoadingUI(operation, options)` - Execute async operation with UI

**Does NOT:**
- ❌ Load data
- ❌ Manipulate Three.js scene
- ❌ Handle picking
- ❌ Manage application state

---

## Layer 4: Application Orchestration (`render.js`)
**Purpose:** Wire up all systems and coordinate workflows

### Responsibilities:
1. **Initialization** - Create all systems (core, runtime, UI, interaction)
2. **Loading Coordination** - Use `viewerUI.withLoadingUI()` pattern
3. **Post-Load Setup** - Shared `handlePostLoad()` function
4. **Interaction Callbacks** - Wire picking events to visual effects

### Loading Pattern:
```javascript
// OLD (mixed concerns):
export async function loadGLB(url) {
  showLoader();
  await meshManager.loadGLB(url);
  vizManager?.applyState(vizState);
  pickingSystem?.collectPickables(loadedScene);
  hideLoader();
}

// NEW (clean separation):
export async function loadGLB(url) {
  return viewerUI.withLoadingUI(
    async () => {
      await meshManager.loadGLB(url);
      return meshManager.getLoadedScene();
    },
    {
      loadingMessage: `Loading: ${url}`,
      successMessage: `Loaded: ${url}`,
      onComplete: handlePostLoad  // Shared coordination
    }
  );
}
```

### Shared Post-Load Handler:
```javascript
function handlePostLoad() {
  const loadedScene = meshManager.getLoadedScene();
  const bounds = meshManager.getBounds();
  
  // Coordinate all systems:
  setPivotMode(PIVOT_MODE);
  vizManager?.applyState(vizState);
  updateTargetMarker();
  pickingSystem?.collectPickables(loadedScene);
  pin?.setLength(bounds.radius * 0.1);
}
```

---

## Benefits of This Architecture

### ✅ Separation of Concerns
- **ViewerCore** = Rendering engine (no awareness of data or UI)
- **MeshManager** = Data loader (no UI updates)
- **ViewerUI** = UI feedback (no data manipulation)
- **render.js** = Orchestrator (wires systems together)

### ✅ Testability
- Each layer can be tested independently
- Mock boundaries are clear
- UI can be tested without loading meshes
- Data loading can be tested without UI

### ✅ Maintainability
- Changes to UI don't affect data layer
- Changes to loading logic don't affect rendering
- Shared `handlePostLoad()` eliminates duplication
- Clear responsibilities = easier debugging

### ✅ Reusability
- ViewerUI can be used by other components
- MeshManager can load without UI
- ViewerCore is pure infrastructure

---

## Migration Guide

### Before (Monolithic):
```javascript
// UI mixed into data layer
async function loadGLB(url) {
  showLoader();              // UI concern
  await meshManager.loadGLB(url);  // Data concern
  vizManager?.applyState();  // Coordination concern
  hideLoader();              // UI concern
}
```

### After (Layered):
```javascript
// UI layer handles feedback
await viewerUI.withLoadingUI(
  async () => await meshManager.loadGLB(url),  // Pure data operation
  {
    loadingMessage: "Loading...",
    onComplete: handlePostLoad  // Coordination in application layer
  }
);
```

---

## File Organization

```
web/
├── core/               # Infrastructure layer
│   ├── viewerCore.js   # Rendering system orchestrator
│   ├── scene.js        # Scene factory
│   ├── camera.js       # Camera factory
│   ├── renderer.js     # Renderer factory
│   └── lighting.js     # Light rig
│
├── runtime/            # Data management layer
│   ├── meshManager.js          # Mesh loading & lifecycle
│   └── visualizationManager.js # Visualization state
│
├── ui/                 # UI layer
│   ├── viewerUI.js     # UI feedback & loading states
│   └── visualizationControls.js # lil-gui integration
│
├── interaction/        # Interaction systems
│   ├── picking.js      # Raycasting & hit detection
│   └── selectionFX.js  # Visual feedback
│
├── geometry/           # Geometry utilities
│   └── pinMarker.js    # Pin marker visual
│
└── render.js          # Application orchestration
```

---

## Next Steps

### Immediate Improvements:
1. ✅ Extract UI layer (ViewerUI) - **DONE**
2. ✅ Remove UI from data layer (MeshManager) - **DONE**
3. ✅ Shared post-load handler (handlePostLoad) - **DONE**
4. ✅ Fix broken `loadModel()` API - **NEXT STEP**

### Future Enhancements:
- [ ] Event system for state changes (optional)
- [ ] State management class (ViewerState)
- [ ] Progress tracking for large file loads
- [ ] Cancellable loading operations
- [ ] Unit tests for each layer
