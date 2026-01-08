Below is the minimal wiring you need so that this MATLAB usage works:

```matlab
fig = uifigure('Position', [1458 61 1091 1339]);
gr = uigridlayout(fig, [1 1]);
gr.RowHeight = {'1x'};
gr.ColumnWidth = {'1x'};
v = bct.ui.manifold.Viewer(gr);  % Empty - no mesh loaded
v.setMesh(V, F);
```

---

## 1) JavaScript: extend `MeshManager` to accept raw buffers (MATLAB path)

### Change

Add a new method (name is up to you; recommended):

* `meshManager.setMeshFromBuffers({ vertices, faces, indexBase, frame })`

### What it must do

1. **Clear** the previous model (reuse `clearModel()`).
2. Build a `THREE.BufferGeometry` from the received arrays.
3. Call `ensureGeometryAttributes(geometry)` so the geometry has normals/UVs/tangents as needed. 
4. Create a `THREE.Mesh` and attach it under the correct root (`roots.matlab` when `frame === 'matlab'`).
5. Update MeshManager’s internal pointers (`modelRoot`, `loadedScene`) so existing downstream systems (bounds, picking collection, post-load setup) keep working.

This keeps MeshManager as the single owner of “is a mesh currently loaded?” and prevents GPU leaks on replacement.

---

## 2) JavaScript: expose a public “set mesh” API from your composition root (`render.js`)

Right now, the runtime objects (`meshManager`, `pickingSystem`, `vizManager`) live inside `render.js` module scope. 
So MATLAB-bridge code cannot access them directly without introducing coupling.

### Change

Add an exported function to `render.js`, e.g.:

* `export function setMeshFromData(meshData) { ... }`

### What it should do

Inside `setMeshFromData(meshData)`:

1. Validate runtime is initialized (`meshManager` exists; `initViewer()` has been called).
2. Call `meshManager.setMeshFromBuffers(meshData)`.
3. Call your existing `handlePostLoad()` to:

   * set orbit pivot
   * apply viz state
   * collect pickables
   * scale pin length, etc. 

This reuses the same “post-load” pipeline you already rely on for GLB/JSON loads.

---

## 3) JavaScript: add a MATLAB bridge in `index.html` via `setup(htmlComponent)` and `DataChanged`

Your current `index.html` is a plain web demo shell that loads `main.js` and uses DOM UI controls (buttons, file dropdown). 
MATLAB’s `uihtml` will call a global `setup(htmlComponent)` function when running in the MATLAB context. You must define it.

### Change

In `index.html`, add a small module script that defines `window.setup` and wires `DataChanged`.

Conceptually:

* `setup(htmlComponent)` should:

  1. call `initViewer({ canvasEl, hudEl })` (same as web demo, but without loading a default mesh)
  2. register `htmlComponent.addEventListener("DataChanged", ...)`
  3. when Data changes and contains `Data.mesh`, call `setMeshFromData(Data.mesh)` (the new export from `render.js`)

This is the key point: synchronization exists, but **the viewer will only update if you attach a DataChanged listener and call your mesh setter**.

---

## 4) MATLAB: extend `Viewer.m` with a Mesh API that sets `HTMLComponent.Data`

Your current `Viewer.m` only loads the HTML and sizes the component; it has no data channel. You need to add:

### Change A — properties (optional but recommended)

Add:

* `Vertices (:,3) double`
* `Faces (:,3) uint32`

so the component can hold the mesh state on the MATLAB side.

### Change B — public method: `setMesh(V,F)`

Add:

* `setMesh(comp, V, F)` validates, stores, then **updates `comp.HTMLComponent.Data`** with a struct payload.

### Payload contract (recommended)

Send a “mesh object” that JS can consume directly:

* `mesh.vertices`: flat row vector `[x1 y1 z1 x2 y2 z2 ...]`
* `mesh.faces`: flat row vector of indices `[i1 i2 i3 ...]`
* `mesh.indexBase`: `0` (convert MATLAB faces from 1-based to 0-based before sending)
* `mesh.frame`: `'matlab'` (so MeshManager attaches to `roots.matlab`)

MATLAB-side flattening should preserve XYZ interleaving per vertex (i.e., `reshape(V.',1,[])`, not `V(:)`).

---

## 5) What changes are *not* required right now

* You do **not** need `sendEventToHTMLSource` for mesh setting; `HTMLComponent.Data` is appropriate because the mesh is “shared component state” and changes relatively infrequently.
* You do **not** need loaders or URLs for MATLAB-driven mesh display; the loader pathway remains useful for demo/testing.  

---

## End-to-end flow once wired

1. MATLAB creates `Viewer` (JS loads, viewer initializes empty).
2. MATLAB calls `v.setMesh(V,F)` → MATLAB sets `HTMLComponent.Data.mesh = ...`.
3. JavaScript `DataChanged` fires in `setup(htmlComponent)`.
4. JS calls `render.js:setMeshFromData(mesh)` → `meshManager.setMeshFromBuffers(mesh)` → Three.js mesh is created and attached.
5. `handlePostLoad()` runs to frame pivot, enable picking collection, apply viz state.

---

## Quick sanity check against your current web files

* `index.html` currently boots `main.js` and includes UI DOM elements. 
* `main.js` is purely web-demo wiring (buttons, file loader) and calls `initViewer`. 
* `render.js` is the runtime composition root where MeshManager lives; it is the correct place to expose `setMeshFromData`. 
* `meshBuilder.ensureGeometryAttributes()` is the correct utility to run after you construct BufferGeometry from MATLAB arrays. 

If you want, paste your updated `meshManager.js` after you add state + `setMeshFromBuffers`, and I will provide a precise checklist for the two remaining edits: (1) the exact `render.js` export, and (2) the minimal `index.html` `setup(htmlComponent)` bridge that won’t interfere with your existing `main.js` demo mode.
