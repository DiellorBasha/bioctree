
### Objective

Refactor `web/render.js` by **extracting** existing stateful responsibilities into explicit subsystem modules while **fully complying** with the architectural constraints in `RenderRefactor.md`.

You will create two runtime ownership subsystems:

1. **MeshManager** — owns active model/mesh lifecycle (load/attach/clear/dispose), geometry attribute enforcement, and bounds computation.
2. **VisualizationManager** — owns application of `vizState` to the loaded model/scene (surface/edges/helpers/scene settings) and ownership/disposal of helper visuals currently created in `render.js` (e.g., normals/tangents helpers and material swap/hide logic).

**Critical requirement:** This is an **extraction refactor**, not a redesign. Do not re-implement logic in parallel. Move the existing code blocks out of `render.js` (verbatim as much as possible), and have `render.js` delegate to these subsystems.

---

## Hard Constraints from `RenderRefactor.md` (Must Follow)

### C1) One composition root: `render.js` only

* `render.js` must remain the **only** public facade/composition root and the single source of runtime wiring.
* **Do not** introduce a new facade runtime file (e.g., do **not** create a `viewerRuntime.js` that becomes the new entrypoint).
* `render.js` retains all existing exports used by `main.js` and/or MATLAB `uihtml`.

### C2) No cross-layer imports

Maintain the “downward dependency” rule:

* Subsystems may import from lower-level layers (`core/`, `geometry/`, `interaction/`, `io/`, `utils/`) but not vice versa.
* Lower layers must never import from the new runtime subsystems.
* Avoid circular dependencies: `MeshManager` and `VisualizationManager` must not import each other; any needed references are passed in via constructors by `render.js`.

### C3) No DOM access inside rendering subsystems

* No direct DOM calls (`document`, `window` listeners, HTML manipulation) inside MeshManager or VisualizationManager.
* UI wiring remains in `main.js` and `ui/visualizationControls.js`.
* Subsystems operate on Three.js objects and state only.

### C4) Optional extraction: `utils/dispose.js`

* If you see duplicated disposal logic (currently in `render.js`), optionally extract it into `web/utils/dispose.js` and reuse it across managers.
* This must follow dependency rules (utils is lower-level, safe).

---

## Non-goals (Do Not Implement)

* Do not add new features (no glyph layers, streamlines, scalar overlays beyond current behavior).
* Do not change coordinate conventions (GLB → `roots.threejs`, JSON → `roots.matlab`).
* Do not change public API (exports from `render.js`).
* Do not change `ViewerCore` responsibilities (ViewerCore remains unaware of geometry/material/picking).

---

## Target Repository Additions (Compliant Structure)

Add these files only (additive):

```
web/
  runtime/
    meshManager.js
    visualizationManager.js
```

Optional (recommended if disposal is currently duplicated or messy):

```
web/
  utils/
    dispose.js
```

> Note: `runtime/` is not a new facade layer. It is a subordinate directory containing subsystems instantiated only by `render.js`.

---

## Required Responsibilities & Contracts

### MeshManager (Subsystem)

**Owns (move from `render.js`):**

* Current model state: the equivalent of `modelRoot`, `loadedScene` (or whatever names are used in current `render.js`).
* Load logic for GLB and JSON:

  * GLB/GLTF attaches under `viewerCore.roots.threejs`.
  * JSON attaches under `viewerCore.roots.matlab`.
* Geometry attribute enforcement (existing calls to `ensureGeometryAttributes()`).
* Base + wire material initialization currently done on traverse:

  * Store on `obj.userData.baseMaterial` and `obj.userData.wireMaterial` (preserve keys).
* Clear/remove/dispose logic for old model (existing `clearModel()` and `disposeObject3D()` behavior).
* Bounds computation currently used for things like pin sizing.

**Does NOT own:**

* Picking/selection logic.
* Visualization toggles and helper visuals.

**Minimum public API:**

* `async loadModelFromUrl(url)` → loads, attaches, initializes materials/attributes; returns the loaded root/group.
* `clearModel()` → removes from scene roots and disposes.
* `getLoadedScene()` → returns loaded scene root/group for picking & visualization application.
* `getModelRoot()` → returns root group used for attachment (if separate).
* `getBounds()` → return radius/box/sphere as currently computed in `render.js`.

**Constructor dependencies (passed by `render.js` only):**

* `viewerCore` (for `scene`, `roots`, maybe `renderer` only if needed)
* loaders / IO helpers used today (import them inside MeshManager as needed)
* `ensureGeometryAttributes` imported from `geometry/meshBuilder.js`

### VisualizationManager (Subsystem)

**Owns (move from `render.js`):**

* The visualization application pipeline currently in `render.js`:

  * `updateVisualization()` and its sub-functions:

    * `updateSurface()`
    * `updateEdges()`
    * `updateHelpers()`
    * `updateScene()`
* Helper visuals created/owned in `render.js`:

  * normals helpers
  * tangents helpers
  * any helper object lifecycle currently managed there
* Any material swap/hide/restore logic used to display helpers or wireframe, etc.

**Does NOT own:**

* Render loop / ViewerCore lifecycle
* DOM/UI creation (lil-gui remains in `ui/visualizationControls.js`)
* Mesh loading/disposal

**Minimum public API:**

* `applyState(vizState)` → applies current vizState to the loaded model/scene (calls extracted update* logic).
* `onModelChanged()` → called after model load/clear to rebuild helpers if needed and/or reapply state safely.
* `onResize(w,h)` → update helper materials needing resolution (only if current behavior requires it).
* `dispose()` → disposes helper visuals it owns.

**Constructor dependencies (passed by `render.js` only):**

* `viewerCore` (scene/camera/renderer/roots)
* `meshManager` reference (passed, not imported)
* Any existing helpers needed (e.g., lighting rig reference if currently used in updateScene)

---

## Required Outcome: `render.js` as Orchestrator (Coordinator)

After refactor, `render.js` must:

* Initialize `ViewerCore` and manage its lifecycle.
* Instantiate:

  * `meshManager`
  * `vizManager`
  * picking system (`PickingSystem`)
  * selection FX (`SelectionFX`)
  * pin marker (`PinMarker`)
  * visualization controls (`createVisualizationControls`) and maintain `vizState`
* Wire interactions:

  * After model load: repopulate pickables from `meshManager.getLoadedScene()`
  * Apply vizState via `vizManager.applyState(vizState)`
  * Ensure selection/pin behave as before
* Keep all existing exports and semantics.

`render.js` must **not** continue to own:

* `loadedScene`, `modelRoot`, disposal helpers (if moved)
* helper visuals (normals/tangents) that are moved into VisualizationManager
* direct visualization update logic (other than delegating)

---

## Implementation Plan (Extraction Steps)

### Step 0 — Baseline verification

* Run existing app and verify:

  * GLB load works
  * JSON load works
  * clearing/reloading doesn’t break
  * picking/selection outline works after reload
  * pin marker behaves as before
  * GUI toggles still affect surface/edges/helpers/scene
* Do not begin refactor until baseline is confirmed.

### Step 1 — Optional: Extract disposal utilities (if beneficial)

* If `render.js` contains non-trivial `disposeObject3D` / disposal recursion logic:

  * Create `web/utils/dispose.js` with `disposeObject3D(obj)` (and helper functions as needed).
  * Replace the old implementation in `render.js` with imports from `utils/dispose.js`.
* Ensure `utils/dispose.js` has no DOM usage and no upward imports.

### Step 2 — Implement MeshManager (standalone)

* Create `web/runtime/meshManager.js`.
* Move the following from `render.js` into MeshManager, keeping logic intact:

  * URL extension routing (GLB vs JSON)
  * GLTF loader usage and JSON loader usage
  * attachment to correct `viewerCore.roots.*`
  * traversal to initialize geometry attributes and `userData` materials
  * clear/dispose logic
  * bounds computation used elsewhere
* Ensure MeshManager:

  * does not touch DOM
  * does not import VisualizationManager or render.js

### Step 3 — Integrate MeshManager into `render.js`

* Instantiate MeshManager in `initViewer()` or equivalent init path.
* Replace the body of `loadModel(url)` export to call `await meshManager.loadModelFromUrl(url)`.
* Replace references to `loadedScene` / `modelRoot` with manager accessors.
* Ensure post-load hooks remain:

  * re-collect pickables for PickingSystem using `meshManager.getLoadedScene()`.

### Step 4 — Implement VisualizationManager (standalone)

* Create `web/runtime/visualizationManager.js`.
* Move the visualization update functions from `render.js` into this class:

  * `updateVisualization()` and its helper functions
  * normals/tangents helper creation/removal and material swap/hide logic
* Replace internal references:

  * replace `loadedScene` usage with `this.meshManager.getLoadedScene()`
  * replace viewerCore usage with constructor-passed viewerCore
* Provide `applyState(vizState)` that calls the extracted update pipeline.

### Step 5 — Integrate VisualizationManager into `render.js`

* Instantiate VisualizationManager after MeshManager is created.
* Wire GUI state changes:

  * wherever `render.js` currently calls `updateVisualization()`, replace with `vizManager.applyState(vizState)`.
* After model load/clear:

  * call `vizManager.onModelChanged()` then `vizManager.applyState(vizState)` (or combined behavior if you implement it that way).

### Step 6 — Ensure resize/update wiring remains correct

* If helper visuals depend on renderer size/resolution, ensure `render.js` calls:

  * `vizManager.onResize(width,height)` from the existing resize callback path.
* Do not add new resize observers in managers; `render.js` owns ViewerCore resize.

### Step 7 — Clean up `render.js`

* Remove moved functions and any duplicated state.
* Ensure `render.js` reads as coordinator/orchestrator code.
* Verify no circular imports were introduced and no DOM usage moved into subsystems.

---

## Acceptance Criteria (Must Pass)

1. **No behavior regressions** vs baseline:

   * load GLB/JSON, clear/reload
   * picking and selection FX work after reload
   * pin marker works as before
   * GUI controls still apply correctly
2. **render.js remains the only public facade**:

   * All prior exports remain and behave the same
   * No new entrypoint introduced
3. **No cross-layer import violations**:

   * runtime managers import only downward layers
   * no lower layer imports runtime managers
4. **No DOM usage in managers**:

   * no `document`, `window` event wiring, or GUI code in MeshManager/VisualizationManager
5. **No duplication/conflicting sources of truth**:

   * active model state exists only in MeshManager
   * visualization helpers exist only in VisualizationManager

---

## Implementation Notes / Pitfalls

* Preserve `obj.userData.baseMaterial` and `obj.userData.wireMaterial` keys exactly; existing visualization toggles depend on them.
* Keep root attachment policy exactly:

  * GLB/GLTF → `viewerCore.roots.threejs`
  * JSON → `viewerCore.roots.matlab`
* Ensure that when models change, old helper visuals are disposed and detached properly (VisualizationManager responsibility).
* Avoid making MeshManager “pure geometry” — it is a runtime owner; it may attach/remove from scene roots, but must not touch DOM.

---

### Deliverables

* `web/runtime/meshManager.js` implemented and integrated.
* `web/runtime/visualizationManager.js` implemented and integrated.
* Optional `web/utils/dispose.js` implemented and used (if extracted).
* `web/render.js` reduced to orchestrator while preserving exports and behavior.
