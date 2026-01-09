Below is a **design / refactoring contract** that you can treat as an internal engineering guide for reorganizing the current `web/` runtime.
It is intentionally **agnostic to MATLAB integration** and focuses purely on making the JavaScript / three.js side *manageable, testable, and extensible*.

You can follow this incrementally without breaking functionality.

---

# Web Runtime Refactoring Contract

## three.js Manifold Viewer (`web/`)

---

## 1. Objective

Refactor the current monolithic `render.js` into a **modular, layered rendering runtime** that:

* Preserves existing behavior
* Avoids circular dependencies
* Keeps state ownership explicit
* Scales to additional visualization layers (fields, glyphs, streamlines)
* Remains compatible with static ES-module loading (no bundler)

This refactoring is **structural**, not functional.

---

## 2. Non-Goals (Important)

This refactoring explicitly does **not**:

* Change external behavior
* Introduce new features
* Modify UI layout or styles
* Introduce build tooling
* Change event semantics

All logic must remain ES-module compatible and browser-native.

---

## 3. Core Architectural Rules (Non-Negotiable)

### Rule 1 — One Composition Root

There must be **exactly one file** that:

* Owns global runtime state
* Initializes subsystems
* Exposes the public rendering API

This file remains `render.js`.

---

### Rule 2 — No Cross-Layer Imports

Modules may only depend on:

* Lower layers
* Explicit arguments passed at construction time

No module may “reach into” another module’s internals.

---

### Rule 3 — No Implicit Globals

All dependencies (scene, camera, renderer, geometry, state flags) must be:

* Passed explicitly
* Or owned by the composition root

No hidden coupling.

---

### Rule 4 — Modules Do Not Talk to the DOM

Except for:

* `index.html` (static)
* `main.js` (orchestration)

Rendering modules operate on three.js objects only.

---

## 4. Layered Runtime Model

The refactored runtime is divided into **five conceptual layers**:

```
┌───────────────────────────┐
│ Public Rendering Facade   │  ← render.js
├───────────────────────────┤
│ Interaction Layer         │  picking, selection FX
├───────────────────────────┤
│ Visualization Layer       │  helpers, overlays, glyphs
├───────────────────────────┤
│ Geometry & Attributes     │  mesh, buffers, fields
├───────────────────────────┤
│ Core Rendering Runtime    │  scene, camera, renderer
└───────────────────────────┘
```

Each layer has strict responsibilities.

---

## 5. Target Folder Structure

The following structure must be created under `web/`:

```
web/
├── render.js                 # composition root (stays)
│
├── core/
│   ├── viewerCore.js         # scene, camera, renderer, loop
│   ├── lighting.js           # view-locked lighting
│   ├── gizmo.js              # axes / orientation helpers
│
├── geometry/
│   ├── meshBuilder.js        # BufferGeometry creation
│   ├── attributes.js         # vertex/edge/face attributes
│   ├── pinMarker.js          # PinMarker class
│
├── interaction/
│   ├── picking.js            # raycasting + index resolution
│   ├── selectionFX.js        # highlight meshes, pulses
│
├── loaders/
│   └── spinning/             # unchanged
│
├── io/
│   ├── dataAdapter.js        # array normalization, indexing
│
├── utils/
│   ├── math.js               # small reusable math helpers
│   ├── dispose.js            # safe disposal helpers
```

No module may import upward (e.g., `geometry` importing `interaction`).

---

## 6. Responsibilities by Module

### 6.1 `render.js` — Composition Root

**Responsibilities**

* Own global viewer state
* Instantiate subsystems
* Wire subsystems together
* Expose a minimal public API

**Must contain**

* High-level lifecycle (`init`, `dispose`)
* State flags (show surface, wireframe, pick mode)
* Delegation logic only

**Must NOT**

* Contain geometry math
* Contain picking math
* Contain helper construction logic

---

### 6.2 `core/viewerCore.js`

**Responsibilities**

* Create and own:

  * `THREE.Scene`
  * `THREE.Camera`
  * `THREE.Renderer`
  * Render loop
* Resize handling
* Camera controls

**API**

```js
createViewerCore(canvas)
update()
dispose()
```

No awareness of geometry or picking.

---

### 6.3 `core/lighting.js`

**Responsibilities**

* Create lighting rig
* Attach lights to camera or scene
* No geometry knowledge

Lighting is *view-relative*, not data-relative.

---

### 6.4 `core/gizmo.js`

**Responsibilities**

* Axes helper
* Orientation overlay
* Secondary scene + camera if needed

No dependency on mesh or picking.

---

### 6.5 `geometry/meshBuilder.js`

**Responsibilities**

* Build `THREE.BufferGeometry` from raw arrays
* Set:

  * positions
  * indices
* Compute defaults when required

**Rules**

* Geometry creation happens **once**
* No data updates
* No materials

---

### 6.6 `geometry/attributes.js`

**Responsibilities**

* Attach and update:

  * vertex colors
  * scalar fields
  * custom attributes

**Rules**

* Must never change topology
* Must never recreate geometry
* Must work with existing buffers

---

### 6.7 `geometry/pinMarker.js`

**Responsibilities**

* Encapsulated vertex selection marker
* World-space glyph
* Animation / pulse logic

**Rules**

* No picking logic
* No raycasting
* No state outside the marker

This class should be **entirely standalone**.

---

### 6.8 `interaction/picking.js`

**Responsibilities**

* Raycasting
* Hit classification
* Conversion from:

  * faceIndex → vertex indices
  * faceIndex → edge indices

**Rules**

* No visual effects
* No scene modification
* Pure computation + callbacks

This module answers: *“what was picked?”*

---

### 6.9 `interaction/selectionFX.js`

**Responsibilities**

* Highlight meshes
* Edge overlays
* Triangle overlays
* Pulse animation

**Rules**

* No picking math
* No raycasting
* Only visualization of a given selection

This module answers: *“how should a selection look?”*

---

### 6.10 `io/dataAdapter.js`

**Responsibilities**

* Normalize incoming numeric arrays
* Convert to typed arrays
* Enforce index conventions
* Validate payload shape

**Rules**

* No three.js imports except `BufferAttribute`
* No scene knowledge

---

### 6.11 `utils/*`

**Responsibilities**

* Small, stateless helpers only
* No viewer state
* No three.js scene objects

---

## 7. Refactoring Procedure (Step-by-Step)

### Step 1 — Extract `PinMarker`

* Move class verbatim to `geometry/pinMarker.js`
* Import and instantiate from `render.js`
* No logic changes

---

### Step 2 — Extract Picking Logic

Move:

* `onPointerDown`
* `pickVertex`
* `pickEdge`
* `pickTriangle`
* distance helpers

Into `interaction/picking.js`.

Replace with:

```js
picking.handlePointer(event)
```

---

### Step 3 — Extract Selection FX

Move:

* `triFX`
* `edgeFX`
* pulse logic
* highlight creation

Into `interaction/selectionFX.js`.

---

### Step 4 — Extract Geometry Construction

Move:

* BufferGeometry creation
* index handling
* default normal / UV logic

Into `geometry/meshBuilder.js`.

---

### Step 5 — Extract Core Runtime

Move:

* scene creation
* camera
* renderer
* render loop
* resize logic

Into `core/viewerCore.js`.

---

### Step 6 — Reduce `render.js`

After extraction, `render.js` should:

* Read like a coordinator
* Be <300–400 lines
* Contain no heavy math

---

## 8. Stability Contract

After refactoring:

* All public functions in `render.js` must retain names
* Internal module APIs may evolve
* File paths must remain static
* Import maps remain unchanged

---

## 9. Success Criteria

Refactoring is successful if:

* `render.js` is readable end-to-end
* Each module has a single responsibility
* You can locate logic intuitively
* Adding a new visualization layer does not touch picking
* Adding new picking modes does not touch geometry

---

## 10. One-Sentence Guiding Principle

> **State lives at the top, math lives at the bottom, visuals live in the middle.**

---

