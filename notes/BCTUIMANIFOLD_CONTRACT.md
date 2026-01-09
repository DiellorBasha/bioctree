```markdown
# bct.ui Design Contract
Version: 0.2 (Minimal UI release: Manifold + Kernel Plot Viewer + UI foundations)  
Scope: Establish a scalable UI architecture for `bct.ui` that integrates with `bct.registry` and `bct.runtime`, while implementing only:
- `bct.ui.Manifold` (interactive component container for viewing a `bct.Manifold` and overlaying fields)
- a kernel function plot viewer (“fplot viewer”) that dynamically updates based on kernel parameters

This document is a binding design contract for the current implementation and future extensibility.

---

## 1. Goals and Non-Goals

### 1.1 Goals
- Provide a **stable UI entrypoint**: `bct.ui.show(obj, ...)`
- Establish a **consistent vocabulary** and directory structure so future UI components can be added without architectural refactors
- Support **embedding** UI components in App Designer containers and **standalone** figure usage
- Integrate with `bct.registry` and `bct.runtime` where it adds value:
  - UI dispatch (resolve which inspector/viewer to instantiate)
  - runtime specs (KernelSpec / parameter metadata)
  - UI colormap selection through a single `bct.ui.color` API
- Provide a deliberate design for **data adapters** that translate BCT data shapes into MATLAB graphics-ready forms

### 1.2 Non-Goals (explicit exclusions for now)
- No full “UI theming framework” beyond local defaults with safe fallbacks
- No general-purpose, schema-driven form generator (may be added later)
- No operator/filter/brush UI integration yet
- No requirement that UI packages mirror kernel/colormap APIs exactly (avoid over-standardization)

---

## 2. Canonical UI Terms (Definitions)

### 2.1 View
A **View** is a UI component whose primary responsibility is to **display** a model and maintain **visual state**.
- Owns axes/graphics handles (patch, quiver, line plots)
- Exposes methods like `setScalars`, `setVectors`, `clearOverlays`
- Does not perform domain computation (no eigen solves, no DEC assembly)

### 2.2 Controller
A **Controller** is a UI component whose responsibility is to **edit parameters** and emit state changes.
- Sliders, dropdowns, toggles, etc.

### 2.3 Inspector (Composite Component)
An **Inspector** is a composite component that bundles Views + Controllers into a workflow. Inspectors are the *unit of UI dispatch*.

For the minimal release:
- `bct.ui.Manifold` is treated as an Inspector (workflow container for manifold viewing).

### 2.4 Renderer (Internal)
Low-level functions that draw/update MATLAB graphics objects.
- Lives under `bct.ui.render.*`
- Not user-facing and not registered

### 2.5 Data Adapter (Internal)
Functions that translate BCT “data shapes” into graphics-ready inputs (RGB arrays, face-vertex mapping, sampled vectors, etc.).
- Lives under `bct.ui.data.*`

---

## 3. Package and Namespace Layout

## 3.1 Primary decision: where component classes live

### Contract decision (committed)
Use **canonical domain subpackages** for each major UI model type.

**Do not** place all UI component classes directly under `bct.ui` long-term; it will not scale and will create namespace collisions (`Manifold`, `Kernel`, `Graph`, `FEM`, etc.).

Instead, use:
- `bct.ui.manifold.*` for manifold viewing components
- `bct.ui.kernel.*` for kernel exploration components

The top-level `bct.ui.*` remains a façade for user-facing entrypoints (`show`, `viewer`, `list.inspectors`).

### Naming policy for the minimal release
- The class currently named `bct.ui.Manifold` should be moved to:
  - `bct.ui.manifold.Inspector` (preferred)
- The kernel plot viewer should be:
  - `bct.ui.kernel.Inspector`

**Compatibility note:** If you already have `bct.ui.Manifold` widely referenced, keep a thin compatibility shim:
- `bct.ui.Manifold` becomes a wrapper that subclasses or delegates to `bct.ui.manifold.Inspector`
- Mark as legacy in docstring, but keep functional

This is the same pattern you will use when other UI components are introduced.

---

## 3.2 Required structure (minimal release)

Recommended directory layout:

```

+bct/+ui/
show.m
viewer.m                  % embed-friendly constructor
+list
  inspectors.m          % discoverability
+render/                  % graphics updates (internal)
+data/                    % data adapters (internal)
+manifold/
Inspector.m            % main manifold component container
defaults.m             % manifold UI defaults (optional; must have fallback)
+kernel/
Inspector.m            % kernel function plot inspector
defaults.m             % kernel inspector defaults (optional; must have fallback)
+color/
apply.m
resolve.m
list.m
+maps/                 % custom colormap generators
redblue.m           % example custom map

```

Registry/runtime dispatch:

```

+bct/+registry/+ui/
inspectors.m              % authoritative list of inspectors

+bct/+runtime/+ui/+resolve/Inspector.m        % chooses inspector factory for given object/spec

````

---

## 4. Integration with bct.registry and bct.runtime

### 4.1 What UI registers (and what it does not)
UI registry registers **Inspectors** only.

It does NOT register:
- render primitives (`bct.ui.render`)
- data adapters (`bct.ui.data`)
- internal component subparts
- MATLAB built-in components

Reason: the registry should remain a minimal dispatch catalog.

### 4.2 bct.registry.ui.inspectors (authoritative metadata)
**Function:** `defs = bct.registry.ui.inspectors()`

Returns ordered struct array with fields:

- `Id` (string)  
  E.g. `"ManifoldInspector"`, `"KernelInspector"`
- `Class` (string)  
  `"bct.ui.manifold.Inspector"`, `"bct.ui.kernel.Inspector"`
- `Supports` (string array)  
  Model classes supported, e.g. `["bct.Manifold"]` or `["struct","bct.KernelSpec"]`
- `Priority` (double)  
  Higher wins when multiple inspectors support an object
- `Tags` (string array) optional
- `Notes` (string) optional

Registry contains no UI state.

### 4.3 bct.runtime.ui.resolveInspector (runtime dispatch)
**Function:** `[factory, def] = bct.runtime.ui.resolveInspector(obj, varargin)`

- Select by `InspectorId` override or by class match
- `factory` must be callable as `factory(parent)` and return a UI component instance
- No caching required initially

---

## 5. User-Facing Entry Points

## 5.1 bct.ui.show (primary)
**Signature:**
```matlab
[comp, fig] = bct.ui.show(obj, NameValue...)
````

### Contract requirement: Always create a root uigridlayout

Because MATLAB component containers often rely on layout managers for correct initial sizing, **`bct.ui.show` must always create a uigridlayout root** and place the component inside it (unless caller provides `Parent`, in which case parent is assumed to already be layout-managed).

**Required standalone pattern:**

```matlab
fig = uifigure;
root = uigridlayout(fig);
root.RowHeight = {'1x'};
root.ColumnWidth = {'1x'};
comp = factory(root);
```

### Name-value arguments (minimal)

* `"Parent"`: UI parent container (uigridlayout/uipanel/uifigure)
* `"InspectorId"`: override inspector selection
* `"Title"`: figure title

### Behavior

1. Resolve inspector via runtime
2. If `Parent` not provided:

   * create `uifigure`
   * create root `uigridlayout` with 1×1 sizing
3. Instantiate inspector component with `Parent=root` (or given parent)
4. Bind model to the component (see §5.3)
5. Return `[comp, fig]`

## 5.2 bct.ui.viewer (embed-friendly)

Creates and binds the inspector into a given parent container. It does **not** create a figure or grid automatically; caller is responsible for correct parent layout.

## 5.3 Standard inspector binding contract

Every inspector must accept the model via one of:

* public property `Object`
* public property named for the model (e.g. `Manifold`)
* public method `setObject(obj)`

---

## 6. Minimal Inspectors to Implement Now

## 6.1 bct.ui.manifold.Inspector (Manifold inspector component)

### Role

Interactive viewer for `bct.Manifold`:

* render base mesh patch
* overlay scalar fields (vertex/face/edge)
* overlay vector fields as quivers (sampled)
* clear overlays and reset camera/lighting
* prepare for future picking and brushing tools

### Required public API

**Properties**

* `Manifold` (or `Object`) : `bct.Manifold`
* `Axes` handle (optional public)
* layer handles (private but internally managed):

  * `hPatch`, `hQuiver`, etc.

**Methods**

* `setScalars(data, NameValue...)`
* `setVectors(vec, NameValue...)`
* `clearOverlays()`
* `resetView()`

### Color integration

All scalar-to-color behavior must delegate to `bct.ui.color`:

* resolve colormap by ID (`parula`, `turbo`, `redblue`)
* handle CLim policy and mapping
* produce RGB in expected shape

### Defaults policy

* `bct.ui.manifold.defaults()` may exist and returns a defaults struct.
* The inspector must include **hardcoded fallback defaults** so it does not error if defaults function is missing or fails.

---

## 6.2 bct.ui.kernel.Inspector (Kernel function plot inspector)

### Role

Interactive kernel explorer:

* choose kernel ID (from kernel registry list)
* edit parameters
* update a function plot

### Kernel integration contract

The kernel inspector consumes kernel metadata via `bct.runtime`:

* `spec = bct.runtime.kernels.resolve(id, axis)`
* The spec provides:

  * `Evaluate(x,p)` or `Function(p)->@(x)` convention
  * defaults and ranges derived from axis

The UI does not duplicate kernel metadata.

### Plotting policy

Default to sampled plot (`plot`) rather than true `fplot`, because the same kernel system must support discrete axes (eigenvalues, time, graph frequencies). You can still call it an “fplot viewer” in UX terms, but implementation should prefer `plot(ax, x, y)`.

---

## 7. bct.ui.color Integration (mandatory)

### 7.1 bct.ui.color role

`bct.ui.color` is the sole UI-layer API responsible for:

* listing available colormaps (including custom)
* resolving a colormap ID to an executable generator `@(n)->[n×3]`
* applying a colormap to scalar data to produce RGB

### 7.2 Integration points

* `bct.ui.manifold.Inspector.setScalars` must call `bct.ui.color.apply`
* `bct.ui.kernel.Inspector` may optionally use `bct.ui.color` for plotting color styling, but it is not required

### 7.3 Registry/runtime relationship

`bct.ui.color` must rely on:

* `bct.registry.colormaps()` for authoritative available IDs and metadata
* `bct.runtime.colormap()` (dictionary) for executable colormap generators

`bct.ui.color` itself should not maintain a parallel registry. It is an adapter façade for UI usage.

---

## 8. Data Adapters (mandatory)

### 8.1 Purpose

The UI layer will accept many “data shapes” that represent BCT fields and operators:

* vertex scalar data: `N×1`
* face scalar data: `M×1`
* edge scalar data: `E×1`
* vector fields: `N×3` or `M×3`
* tensors / phase gradients / other derived objects (future)

MATLAB graphics expects specific forms:

* `patch` typically consumes `FaceVertexCData` (per-vertex colors) or `CData` (per-face)
* quivers need positions + vectors in matched shapes
* edge fields often require conversion to line segments or mapped to vertices/faces

**Contract:** All such translations must be handled by `bct.ui.data.*` functions so component classes remain lean.

### 8.2 bct.ui.data package contents (minimal)

```
+bct/+ui/+data/
  scalarToVertexCData.m
  scalarToFaceCData.m
  edgeScalarToVertexScalar.m       % optional (simple average of incident edges)
  sampleVectors.m                  % downsample vectors for quiver rendering
  validateDataShape.m
```

### 8.3 Mandatory adapter behaviors

#### (A) Vertex scalar → RGB for patch

* Inputs: `values [N×1]`, `Manifold`, color spec (CLim, colormap id)
* Output: `rgb [N×3]` or `cdata` compatible with patch

#### (B) Face scalar → patch CData

Two acceptable policies (choose one and be consistent):

1. Direct per-face coloring:

   * output `cface [M×1]` or `[M×3]`, set patch `FaceColor='flat'`
2. Lift to vertices:

   * convert face values to vertex values (area-weighted averaging)
   * output per-vertex `rgb [N×3]`

For the minimal release, adopt policy (2) only if you need smooth interpolation. Otherwise, policy (1) is simpler and correct.

#### (C) Edge scalar → renderable representation

Minimal acceptable policy:

* map edge scalar to vertex scalar by averaging incident edge values per vertex
* then reuse vertex-scalar pipeline

Later you can render edges explicitly, but do not block the release on it.

#### (D) Vector field → quiver

* Inputs: `vec [N×3]` or `[M×3]`, plus positions:

  * vertex positions: `V [N×3]`
  * face centroids: `C [M×3]`
* Adapter returns sampled positions/vectors for quiver:

  * optional decimation factor or max arrows count
  * consistent sampling strategy

### 8.4 Validation

All adapters must validate:

* size matches the manifold cardinality (`N`, `M`, `E`)
* numeric type and finite values where required
* orientation (column vs row) normalized internally

Adapters should throw `bct:ui:data:*` errors with clear messages.

---

## 9. bct.ui.render (Internal Rendering Primitives)

### 9.1 Purpose

Low-level graphics creation/update functions used by inspectors.

### 9.2 Minimal functions to implement

* `bct.ui.render.ensurePatch(ax, V, F, style)` → `hPatch`
* `bct.ui.render.updatePatchVertexRGB(hPatch, rgb)` (sets FaceVertexCData)
* `bct.ui.render.ensureQuiver(ax, P, U, style)` → `hQuiver`
* `bct.ui.render.updateQuiver(hQuiver, P, U)`
* `bct.ui.render.ensureLine(ax, x, y, style)` → `hLine`
* `bct.ui.render.updateLine(hLine, x, y)`

Render functions are internal and not registered.

---

## 10. Error Handling and Fallback Policy

### 10.1 UI must not fail due to missing optional infrastructure

* If `bct.registry.ui.inspectors` or `bct.runtime.ui.resolveInspector` fails, error message must include:

  * class of `obj`
  * output of `bct.ui.listInspectors()`
  * suggestion to pass `"InspectorId"`

### 10.2 Defaults fallback

`bct.ui.manifold.Inspector` and `bct.ui.kernel.Inspector` must:

* use local hardcoded defaults if defaults helper function missing or errors

---

## 11. Extensibility Rules

### 11.1 Adding a new inspector

1. Create class under `bct.ui.<domain>.Inspector`
2. Ensure it accepts model via `Object` / `setObject`
3. Register in `bct.registry.ui.inspectors`
4. `bct.ui.show` automatically supports it

### 11.2 Adding new data shapes

All new data shapes must be implemented first as adapters in `bct.ui.data.*`, then consumed by inspectors.

This prevents domain growth from bloating component classes.

---

## 12. Minimal Implementation Checklist (for the current release)

* [ ] Implement `bct.registry.ui.inspectors` with entries:

  * `"ManifoldInspector"` → `"bct.ui.manifold.Inspector"` supports `bct.Manifold`
  * `"KernelInspector"` → `"bct.ui.kernel.Inspector"` supports `struct`/KernelSpec
* [ ] Implement `bct.runtime.ui.resolveInspector`
* [ ] Implement `bct.ui.show`:

  * always create root `uigridlayout` for standalone
* [ ] Implement `bct.ui.viewer` and `bct.ui.listInspectors`
* [ ] Implement `bct.ui.manifold.Inspector`

  * base patch render + scalar overlay + vector overlay
  * delegates scalar mapping to `bct.ui.color.apply`
  * delegates shape conversion to `bct.ui.data.*`
* [ ] Implement `bct.ui.kernel.Inspector`

  * kernel selection + parameter controls + plot update
  * consumes runtime kernel spec, does not duplicate metadata
* [ ] Implement minimal `bct.ui.data.*` adapters
* [ ] Implement minimal `bct.ui.render.*` functions
* [ ] Ensure `bct.ui.color` is the sole scalar→RGB colormap interface, backed by `bct.registry.colormaps` + `bct.runtime.colormap`

---

## 13. Contract Guarantees (stable APIs)

Once implemented, these are stable and should not be renamed without a deprecation strategy:

* `bct.ui.show`
* `bct.ui.viewer`
* `bct.ui.listInspectors`
* `bct.registry.ui.inspectors`
* `bct.runtime.ui.resolveInspector`
* `bct.ui.color.apply`, `bct.ui.color.resolve`, `bct.ui.color.list`

---

## 14. Naming Commitments (binding)

* Component classes live under domain namespaces:

  * `bct.ui.manifold.Inspector`
  * `bct.ui.kernel.Inspector`
* `bct.ui` top-level is façade/entrypoints only
* `bct.ui.color` is the unified UI colormap system
* `bct.ui.data` owns all data-shape → graphics-shape conversion
* `bct.ui.render` owns low-level graphics object creation/update

---

End of contract.

```
::contentReference[oaicite:0]{index=0}
```
