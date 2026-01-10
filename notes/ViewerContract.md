Below is a **full, explicit design document** for the **MATLAB–three.js Manifold Viewer**, written as an engineering specification rather than a tutorial. It formalizes the architecture you have converged on and is consistent with:

* MATLAB `ComponentContainer` patterns
* `uihtml` constraints
* three.js / WebGL / future WebGPU evolution
* DEC-aware scientific visualization
* Long-term maintainability

This is intended to be something you could keep in the repository as `ARCHITECTURE.md`.

---

# Design Specification

## bct.ui.manifold.Viewer (MATLAB)

## bct.ui.manifold.viewer (JavaScript / three.js)

---

## 1. Purpose and Scope

The **Manifold Viewer** is a reusable, scientific visualization component designed to render and interact with triangulated manifolds (e.g., cortical surfaces) in MATLAB using a three.js–based web runtime embedded via `uihtml`.

The viewer is explicitly designed for:

* DEC-style representations (0-, 1-, 2-forms)
* Vertex-, edge-, and face-index–based interaction
* Separation of **geometry (coordinate space)** from **data (fields on the geometry)**
* MATLAB as the authoritative source of state
* High-performance rendering with minimal data transfer

This component is **not** a general-purpose web app. It is a **rendering runtime** controlled by MATLAB.

---

## 2. High-level Architectural Principles

### 2.1 MATLAB is the System of Record

* MATLAB owns:

  * Geometry
  * Data
  * Semantics
  * Application logic
* JavaScript owns:

  * Rendering
  * Interaction detection
  * Visual feedback
* JavaScript never invents meaning; it only visualizes.

---

### 2.2 Geometry is a Contract, Not a File

* Geometry defines the coordinate space of a Viewer instance.
* Geometry is:

  * Set once
  * Cached for the lifetime of the Viewer
  * Immutable in topology
* Data (vertex-wise, edge-wise, face-wise) is updated independently.

GLB is treated as an **optional transport / debugging format**, not a required mechanism.

---

### 2.3 Strict MATLAB ↔ JavaScript Boundary

There are exactly three communication channels:

1. **Initialization**

   * `uihtml` loads `index.html`
2. **MATLAB → JavaScript**

   * `HTMLComponent.Data`
3. **JavaScript → MATLAB**

   * `sendEventToHTMLSource`
   * `HTMLEventReceivedFcn`

Only one JavaScript file is allowed to be MATLAB-aware.

---

## 3. Namespace and Ownership

### MATLAB namespace

```
bct.ui.manifold.Viewer
```

* MATLAB `ComponentContainer`
* Public API exposed to users
* Owns geometry, data, and state
* Translates MATLAB actions into viewer commands

---

### JavaScript namespace (conceptual)

```
bct.ui.manifold.viewer
```

* Rendering runtime
* No MATLAB logic
* No application state
* Pure visualization engine

---

## 4. MATLAB Component: Viewer.m

### 4.1 Responsibilities

`Viewer.m` is responsible for:

1. Lifecycle

   * Creation
   * Destruction
   * Reset
2. Geometry ownership

   * Vertices
   * Faces
   * Optional edges
3. Data ownership

   * Vertex data
   * Edge data
   * Face data
4. Interaction handling

   * Receiving pick events
   * Translating them into MATLAB semantics
5. Command dispatch

   * Sending rendering commands to JavaScript

---

### 4.2 Viewer.m Conceptual API

#### Construction

```matlab
viewer = bct.ui.manifold.Viewer( ...
    'Vertices', V, ...
    'Faces', F, ...
    'Edges', E );   % optional
```

* Geometry is set **once**.
* Construction triggers `setGeometry` in JavaScript.

---

#### Data updates (after construction)

```matlab
viewer.setVertexData(values);
viewer.setEdgeData(values);
viewer.setFaceData(values);
```

* Values are numeric arrays indexed by geometry.
* Only data is transferred, never geometry.

---

#### Interaction configuration

```matlab
viewer.setPickMode("vertex");
viewer.setPickMode("edge");
viewer.setPickMode("triangle");
```

---

#### Event handling

```matlab
viewer.HTMLComponent.HTMLEventReceivedFcn = ...
    @(src, evt) viewer.handleViewerEvent(evt);
```

MATLAB interprets:

* Vertex indices
* Edge indices
* Face indices
* Selection modes
* Future brush / region semantics

---

## 5. Geometry Contract (MATLAB → JS)

### 5.1 Tier 1: Required (Coordinate Space)

```matlab
Geometry.Vertices   % Nx3 double/single
Geometry.Faces      % Mx3 int32
```

* Defines the embedding and topology.
* Immutable after initialization.

---

### 5.2 Tier 2: Optional Precomputed Attributes

```matlab
Geometry.Normals    % Nx3
Geometry.UV         % Nx2
Geometry.Tangents   % Nx4
Geometry.Meta       % struct with semantic labels
```

Rules:

* Optional
* Explicit
* Never assumed
* Viewer must function without them

---

### 5.3 Tier 3: Viewer-derived Attributes (Default)

If optional attributes are missing, the JavaScript runtime may:

* Compute vertex normals
* Synthesize spherical UVs
* Compute tangents if prerequisites exist

These are **visual aids**, not authoritative data.

---

## 6. JavaScript Runtime Architecture

### 6.1 Top-level Structure

```
web/
├── index.html
├── styles.css
├── main.js
├── render.js
│
├── core/
│   ├── viewerCore.js
│   ├── lighting.js
│   ├── gizmo.js
│
├── geometry/
│   ├── meshBuilder.js
│   ├── attributes.js
│   ├── pinMarker.js
│
├── interaction/
│   ├── picking.js
│   ├── selectionFX.js
│
├── io/
│   ├── dataAdapter.js
│   ├── events.js
│
├── loaders/
│   └── spinning/
│
├── assets/
└── vendor/
```

---

## 7. JavaScript File Roles

### 7.1 index.html (Passive Container)

Responsibilities:

* Canvas
* HUD
* Picker toolbar
* Import maps
* Static layout only

No logic.

---

### 7.2 main.js (MATLAB Bridge)

**The only MATLAB-aware JavaScript file.**

Responsibilities:

* Listen for `HTMLComponent.Data` updates
* Decode commands
* Dispatch to `render.js`
* Send interaction events back to MATLAB

It does **not**:

* Touch three.js directly
* Perform geometry math
* Maintain rendering state

---

### 7.3 render.js (Public Rendering Facade)

Responsibilities:

* Expose a **stable, minimal API**:

  * `setGeometry`
  * `setVertexData`
  * `setEdgeData`
  * `setFaceData`
  * `setPickMode`
* Own viewer-wide rendering state
* Delegate to internal modules

It is **not MATLAB-aware**.

---

### 7.4 core/

#### viewerCore.js

* Scene
* Camera
* Renderer
* Render loop
* Resize handling

#### lighting.js

* View-locked lighting rig
* Consistent illumination independent of orientation

#### gizmo.js

* Axes helper
* Orientation feedback

---

### 7.5 geometry/

#### meshBuilder.js

* Construct `THREE.BufferGeometry`
* Attach positions and indices
* One-time geometry creation

#### attributes.js

* Attach/update:

  * Vertex colors
  * Scalar fields
  * Custom attributes
* No topology changes

#### pinMarker.js

* Vertex selection glyph
* World-space marker
* Visual feedback only

---

### 7.6 interaction/

#### picking.js

* Raycasting
* Vertex/edge/triangle identification
* Index computation
* No visual effects
* No MATLAB communication

#### selectionFX.js

* Highlight geometry
* Pulses
* Transparency
* Visual emphasis only

---

### 7.7 io/

#### dataAdapter.js

* Convert MATLAB-style arrays to typed arrays
* Enforce index conventions (0-based vs 1-based)
* Validate payloads

#### events.js

* Single abstraction over `sendEventToHTMLSource`
* No direct MATLAB logic elsewhere

---

## 8. Data Flow Summary

### Geometry Initialization

```
Viewer.m → HTMLComponent.Data
        → main.js
        → render.setGeometry
        → meshBuilder.js
        → BufferGeometry
```

### Data Updates

```
Viewer.m → HTMLComponent.Data
        → main.js
        → render.setVertexData / setEdgeData / setFaceData
        → attributes.js
```

### Interaction Events

```
User click
→ picking.js
→ events.js
→ sendEventToHTMLSource
→ Viewer.m.handleViewerEvent
```

---

## 9. DEC Compatibility

* Geometry corresponds to:

  * 0-simplices (vertices)
  * 1-simplices (edges)
  * 2-simplices (faces)
* Viewer supports:

  * 0-form visualization (vertex data)
  * 1-form visualization (edge data, streamlines)
  * 2-form visualization (face data)
* Derived fields (normals, tangents) are treated as **auxiliary**, not structural.

---

## 10. Design Constraints (Non-negotiable)

* Geometry is immutable after initialization
* MATLAB never calls internal JS modules
* Only `main.js` communicates with MATLAB
* No npm resolution at runtime
* All imports are relative
* No three.js logic in MATLAB

---

## 11. Long-term Extensions (Designed-for)

This architecture cleanly supports:

* Streamlines (derived geometry)
* WebGPU compute kernels
* Multi-view synchronization
* Brushing and region selection
* DEC dual meshes
* Time-varying fields
* Performance-critical rendering

---

## 12. One-sentence summary

> **`Viewer.m` defines meaning; `viewer/web` renders meaning.
> Geometry defines space once; data flows forever.**

---
