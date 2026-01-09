Below is a **formal design contract** for refactoring your current **HTML/CSS visualization buttons** (Surface, Wireframe, Normals, Tangents, etc.) into a **`lil-gui`–based Visualization Controls system**.

This document is **implementation-oriented**, but it deliberately avoids picker tools, MATLAB integration, or application logic. It is strictly about **visualization controls** inside the `web/` runtime.

You can treat this as an internal spec (e.g., `+bct\+ui\+manifold\+viewer\web\LILGUIRefactor.md`).

---

# Design Contract

## Visualization Controls using `lil-gui`

*(three.js web runtime)*

---

## 1. Purpose

The purpose of the Visualization Controls system is to:

* Replace ad-hoc HTML/CSS buttons (Surface, Wireframe, Normals, Tangents, etc.)
* Provide a **scalable, declarative, and grouped control panel**
* Control **visual appearance only**
* Remain **DOM-based**, not WebGL-based
* Align with official three.js example patterns

The Visualization Controls panel is a **HUD overlay**, not part of the rendering pipeline.

---

## 2. Scope (Strict)

### Included

* Surface visibility and appearance
* Wireframe / edge rendering
* Geometry helpers (normals, tangents, face normals)
* Overlays and colormaps
* Scene-level visual helpers (lighting, axes, background)

### Explicitly Excluded

* Vertex / edge / triangle picking
* Interaction modes
* Brushing
* Data loading
* Geometry mutation
* Application state

These belong to other UI layers.

---

## 3. Core Design Principles

### Principle 1 — Visualization State Is Declarative

Controls bind to a **plain JavaScript object** representing visualization state.

No control directly manipulates three.js objects.

---

### Principle 2 — Single Update Path

All rendering updates are routed through **central update functions**.

No control callback contains rendering logic.

---

### Principle 3 — Logical Grouping

Controls are grouped by **what they affect**, not by implementation details.

---

### Principle 4 — Zero Coupling to Picking or IO

The Visualization Controls panel must not import or depend on:

* Interaction modules
* IO modules
* Loaders
* Events

---

## 4. Folder Organization (Required)

Extend your existing `web/` structure as follows:

```
web/
├── ui/
│   └── visualizationControls.js
│
├── render.js
├── core/
├── geometry/
├── interaction/
├── io/
├── utils/
├── vendor/
│   └── three/
│       └── examples/
│           └── jsm/
│               └── libs/
│                   └── lil-gui.module.min.js
```

### Rules

* All `lil-gui` logic lives in `web/ui/`
* `render.js` **imports** the controls but does not define them
* No CSS is required unless you choose to override defaults

---

## 5. Dependency Management

### Source of `lil-gui`

You **must** use the officially vendored version shipped with three.js:

```
vendor/three/examples/jsm/libs/lil-gui.module.min.js
```

### Import pattern (ES Modules)

```js
import GUI from '../vendor/three/examples/jsm/libs/lil-gui.module.min.js';
```

No CDN usage. No bundlers.

---

## 6. Visualization State Schema (Contract)

The Visualization Controls system owns a **single state object**.

### Required schema

```js
const viz = {
  surface: {
    visible: true,
    opacity: 1.0,
    shading: 'smooth',      // 'smooth' | 'flat'
    colorMode: 'uniform'    // 'uniform' | 'vertex' | 'face'
  },

  edges: {
    wireframe: false,
    width: 1.0,
    color: '#000000'
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
    axes: false,
    background: '#202020'
  }
};
```

### Rules

* No functions in the state object
* JSON-serializable
* Flat primitives only (no three.js objects)

---

## 7. Folder Taxonomy (GUI Structure)

The following folder hierarchy is **mandatory**:

```
Visualization Controls
├── Surface
├── Edges
├── Geometry Helpers
├── Overlays
├── Scene
```

Each folder has **exclusive responsibility**.

---

## 8. Folder Responsibilities

### 8.1 Surface Folder

Controls the primary surface mesh.

**Controls**

* Visible (boolean)
* Opacity (0–1)
* Shading (flat / smooth)
* Color mode

**Effects**

* Mesh visibility
* Material opacity
* Normal interpretation
* Color source selection

---

### 8.2 Edges Folder

Controls edge and wireframe rendering.

**Controls**

* Wireframe toggle
* Edge width
* Edge color

**Effects**

* Wireframe mesh visibility
* Line material properties

---

### 8.3 Geometry Helpers Folder

Controls visual debugging helpers.

**Controls**

* Vertex normals
* Face normals
* Tangents

**Effects**

* Helper object visibility only

---

### 8.4 Overlays Folder

Controls scalar field visualization.

**Controls**

* Active field
* Colormap
* Auto/manual range

**Effects**

* Attribute binding
* Shader uniforms
* Color mapping

---

### 8.5 Scene Folder

Controls global scene appearance.

**Controls**

* Lighting on/off
* Axes helper
* Background color

**Effects**

* Light visibility
* Helper visibility
* Renderer clear color

---

## 9. API of `visualizationControls.js`

### Required exports

```js
export function createVisualizationControls({
  vizState,
  onChange
});
```

### Responsibilities

* Instantiate `GUI`
* Create folders
* Bind controls to `vizState`
* Invoke `onChange()` on any modification
* Return GUI instance (for disposal)

### Prohibited

* Direct three.js calls
* Scene access
* Geometry access

---

## 10. Update Strategy (Mandatory)

### Pattern

```js
function onVisualizationChanged() {
  updateSurface();
  updateEdges();
  updateHelpers();
  updateOverlays();
  updateScene();
}
```

Each updater:

* Reads from `vizState`
* Updates rendering objects
* Does not modify `vizState`

---

## 11. Integration Pattern (Render-side)

`render.js` must:

1. Create `vizState`
2. Create visualization controls
3. Register a single update callback

```js
const gui = createVisualizationControls({
  vizState,
  onChange: updateVisualization
});
```

No rendering logic inside the GUI module.

---

## 12. Styling & Placement Rules

* Default `lil-gui` styling is acceptable
* Panel should float in the **top-right**
* Panel must not overlap canvas interactions
* No hardcoded layout assumptions

Optional override:

```js
gui.domElement.style.position = 'absolute';
gui.domElement.style.top = '10px';
gui.domElement.style.right = '10px';
```

---

## 13. Migration Rules (from HTML/CSS buttons)

### Replace

* Surface button → `Surface → Visible`
* Wireframe button → `Edges → Wireframe`
* Normals button → `Geometry Helpers → Vertex Normals`
* Tangents button → `Geometry Helpers → Tangents`

### Remove

* Corresponding DOM buttons
* Button click handlers
* Button state logic

---

## 14. Disposal & Lifecycle

* GUI instance must be disposable
* On viewer reset or destroy:

  ```js
  gui.destroy();
  ```
* No lingering DOM nodes

---

## 15. Non-Negotiable Constraints

* No picker logic
* No events
* No IO
* No geometry mutation
* No MATLAB awareness

---

## 16. Success Criteria

This refactor is successful if:

* No visualization buttons remain in HTML/CSS
* All visualization toggles live in `lil-gui`
* Controls are grouped and collapsible
* Adding a new visual toggle requires:

  * One state field
  * One GUI line
  * One updater branch

---

## 17. One-Sentence Guiding Rule

> **`lil-gui` describes *what the user wants to see*, not *what the user wants to do*.**

---
