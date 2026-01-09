Below is a refactoring design document tailored to your current `ViewerCore` implementation. It assumes you want to evolve toward a **modular “core primitives” layout** (`scene.js`, `camera.js`, `renderer.js`, `frameTransform.js`) while preserving the strengths of your current class (clear responsibilities, clean lifecycle, and no geometry/picking awareness). 

---

## Refactoring objectives

### Why refactor at all

Your current `ViewerCore` is already well-structured and disciplined (scene/camera/renderer/controls, render loop, resize observer, lifecycle). The pressure to refactor comes from imminent growth in responsibilities that are *adjacent* to core runtime but should not live inside a single file:

* Multiple coordinate frames (MATLAB RAS vs three.js Y-up; future RAS/LAS, neurological/radiological)
* Multiple render backends (WebGL now, WebGPU later)
* Alternate cameras (perspective/orthographic; multiple views)
* Postprocessing pipelines (selection FX, SSAO/SSR, etc.)
* View-locked lighting patterns (you already add camera to the scene for this)
* Standardized defaults/config validation for camera/renderer/controls

Right now, those concerns would naturally accrete into `viewerCore.js`. The goal is to **prevent “core runtime” from becoming a catch-all**, by extracting “construction” logic into small factories and keeping `ViewerCore` as the orchestrator.

### What must remain true

Your file header rules are correct and should remain invariant: **ViewerCore should not become aware of geometry, picking, or materials**. 

---

## Current state analysis

`ViewerCore` currently combines these concerns in `init()`:

1. **Scene creation + scene background**
2. **Camera creation + up vector + position**
3. **Camera added to scene** (to support view-locked lighting)
4. **Renderer creation + tone mapping + output colorspace**
5. **OrbitControls creation + config + event bridging**
6. **Initial camera position/target logic**
7. Lifecycle logging

And it owns:

* Render loop (`start/stop/_renderFrame`)
* Resize (`resize/setupResizeObserver`)
* Callback registries (`onRender/onControlsChange`)
* Disposal (`dispose`)

This is a good baseline; the refactor is about **extraction**, not conceptual change. 

---

## Target architecture

### Proposed `core/` decomposition

**Keep `viewerCore.js`** as the runtime orchestrator, but extract construction into dedicated modules:

```
core/
  scene.js           # createScene + root nodes registration
  camera.js          # createCamera + updateCameraForResize
  renderer.js        # createRenderer + configureColorSpace
  controls.js        # createOrbitControls (optional but recommended)
  frameTransform.js  # createCoordinateFrameRoot + apply frame selection
  viewerCore.js      # orchestration + render loop + resize + lifecycle
```

You asked specifically about `scene/camera/renderer/frameTransform`. You can do that minimum set first, and add `controls.js` later. In practice, `controls.js` pays off quickly because OrbitControls setup tends to diversify.

---

## Separation of responsibilities

### `scene.js`

**Purpose:** construct the scene and register stable root nodes.

Recommended exports:

* `createScene({ backgroundColor }) -> { scene, roots }`

Where `roots` includes named groups you will attach content to later:

* `roots.world` (or `roots.matlabFrame`) for MATLAB-derived geometry
* `roots.overlay` for helpers/gizmos that should not inherit coordinate transforms (optional)
* `roots.debug` for axes helpers, bounding boxes (optional)

Why:

* Coordinate-frame transforms should never be “sprinkled” across geometry objects.
* Named roots make it obvious where objects belong (e.g., mesh goes under `matlabFrame`, UI helpers under `overlay`).

### `frameTransform.js`

**Purpose:** define and apply coordinate-frame mappings.

Recommended exports:

* `createFrameRoot(frameId) -> THREE.Group`
* `setFrame(frameRoot, frameId)` (updates transform without reconstructing)

Why:

* This is the single place you encode MATLAB↔three.js conventions.
* Later you can expose a “Frame” control in lil-gui without touching geometry or loaders.

This is also the correct place to encode the mapping you discovered (MATLAB viewer conventions vs three.js Y-up). Do not bake this into vertex buffers or loader logic.

### `camera.js`

**Purpose:** create camera and handle camera resize updates.

Recommended exports:

* `createCamera(cameraConfig, aspect) -> THREE.PerspectiveCamera | OrthographicCamera`
* `resizeCamera(camera, aspect)`

Why:

* Right now `init()` sets aspect to `1` and relies on a later `resize()`. That’s fine, but factoring it makes it explicit and testable.
* Later you can add orthographic without contaminating `ViewerCore`.

### `renderer.js`

**Purpose:** create/configure renderer and centralize output pipeline defaults.

Recommended exports:

* `createRenderer({ canvas, antialias, pixelRatio, toneMapping, exposure, outputColorSpace }) -> WebGLRenderer`
* `resizeRenderer(renderer, w, h)`

Why:

* Renderer settings are “policy.” You will likely experiment with tone mapping, output color space, and later postprocessing.
* Centralizing prevents drift across different viewer entry points.

### `viewerCore.js` (after refactor)

**Purpose:** orchestration and lifecycle only.

It should:

* call factory functions
* store references
* run render loop
* handle callbacks
* handle resize (delegating camera/renderer resize to helpers)
* dispose resources

It should *not* contain detailed construction logic.

---

## Recommended refactoring roadmap

### Phase 0 — Baseline tests (before changing code)

Add 2–3 simple checks you can run manually to ensure behavior is preserved:

* Camera renders something; OrbitControls rotate; zoom; pan.
* ResizeObserver correctly updates aspect and viewport.
* `onControlsChange` fires.
* Render loop starts/stops cleanly.

No new features yet—just a baseline.

### Phase 1 — Extract `renderer.js`

1. Create `core/renderer.js` with `createRenderer()` and `resizeRenderer()`.
2. Move renderer construction and configuration out of `ViewerCore.init()`.
3. Keep the same defaults (SRGB, ACES, exposure) to avoid visual drift. 
4. `ViewerCore.resize()` calls `resizeRenderer()`.

Acceptance criteria:

* Rendering identical to before
* Resize still works

### Phase 2 — Extract `camera.js`

1. Create `core/camera.js` with `createCamera()` and `resizeCamera()`.
2. Move camera creation out of `init()`.
3. Keep the “camera added to scene” behavior in `ViewerCore` (or move it into `scene.js` later), but ensure it remains. 

Acceptance criteria:

* OrbitControls behavior identical
* Aspect updates identical

### Phase 3 — Extract `scene.js`

1. Create `core/scene.js` with `createScene()`.
2. Keep the background color logic there.
3. Return `{ scene }` initially. In a follow-up commit, add `roots` once stable.

Acceptance criteria:

* No behavior changes
* Scene background still correct

### Phase 4 — Introduce `frameTransform.js` and a `matlabFrame` root

This is where you solve your orientation mismatch cleanly.

1. In `frameTransform.js`, implement `createMATLABFrameRoot()` that returns `THREE.Group` with the required rotation (or matrix).
2. In `scene.js`, create the scene and add:

   * `matlabFrame` root (transformed)
   * optionally `overlayRoot` (identity transform)
3. Expose these roots via `scene.userData` or a returned `roots` struct.
4. Update your mesh insertion code elsewhere to attach geometry under `matlabFrame`, not directly under `scene`.

Acceptance criteria:

* Mesh appears with correct orientation using JSON loading
* Wireframe/points/surface all align
* Picking rays (if you already have them) still work after updating which root objects are under

### Phase 5 — Optional but recommended: extract `controls.js`

Your current controls config includes both a `position` in cameraConfig and `cameraPosition` in controlsConfig. This is a minor policy smell: camera placement should have one authority.

Refactor goals:

* camera initial position belongs to camera config
* controls target/damping belong to controls config

This extraction makes that separation explicit and avoids conflicting inputs.

---

## Design decisions to adopt during refactor

### 1. Single source of truth for camera position

Right now you set camera position twice (first from `cameraConfig.position`, then from `controlsConfig.cameraPosition`). 

Recommendation:

* Remove one of these pathways.
* Prefer `cameraConfig.position` for initial placement and keep `controlsConfig.target` for look-at.

This prevents subtle regressions when you later add camera modes.

### 2. Centralize “frame selection”

Even if you only support one frame today, build the interface so you can expand:

* `frameId = 'matlab-ras-zup'` (or similar)
* Future: `'three-yup'`, `'fs-r-as'`, `'las'`, etc.

Do not spread transforms across mesh objects.

### 3. Keep `ViewerCore` callback API stable

Your `onRender()` and `onControlsChange()` are good integration points. Keep them unchanged so geometry/picking/UI systems remain decoupled. 

### 4. Avoid over-abstracting early

Do not introduce dependency injection frameworks or “engine” patterns. Plain functions + clear file boundaries are sufficient.

---

## Proposed module interfaces (concrete contracts)

### `core/scene.js`

* `createScene({ backgroundColor }) -> { scene, roots }`
* `roots.matlabFrame: THREE.Group`
* `roots.overlay: THREE.Group` (optional)

### `core/frameTransform.js`

* `createFrameRoot(frameId) -> THREE.Group`
* `setFrame(frameRoot, frameId)` (optional, for later)

### `core/camera.js`

* `createCamera(cameraConfig, aspect) -> camera`
* `resizeCamera(camera, aspect)`

### `core/renderer.js`

* `createRenderer(rendererConfig) -> renderer`
* `resizeRenderer(renderer, w, h)`

### `core/viewerCore.js`

* owns lifecycle + loop
* imports and composes the above

---

## Implementation steps and sequencing

If you want minimal risk and clean commits, implement in this exact order:

1. `renderer.js` (lowest coupling)
2. `camera.js`
3. `scene.js`
4. `frameTransform.js` + `matlabFrame` root (the only behavior-changing step)
5. (optional) `controls.js`

Each step should be a separate commit with “no behavior change” except Step 4.

---

## Success criteria

You should be able to say the refactor succeeded if:

* `ViewerCore` is shorter and reads like orchestration (composition root)
* Scene/camera/renderer configuration is in one place each
* Frame transforms are centralized and applied via a root node
* Geometry loaders remain pure (data → BufferGeometry)
* Picking/selection code does not need to know about coordinate systems (it just raycasts against scene objects)

---

