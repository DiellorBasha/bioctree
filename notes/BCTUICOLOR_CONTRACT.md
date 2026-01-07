# bct.ui.color — Contract and Design (v1)
**Minimal scope:** Convert scalar numeric data to RGB using a named colormap (MATLAB built-in or BCT custom).  
**Updated implementation:** Custom colormaps live in `bct.ui.color.maps.*` (no separate `bct.colormap` package).

---

## 1. Purpose

`bct.ui.color` is the **UI-layer color-mapping module** for BCT. Its v1 responsibility is:

> Map a scalar numeric array (`values`) to an RGB array using a **named colormap**.

This module supports:
- MATLAB built-in colormaps (e.g., `"parula"`, `"turbo"`)
- Custom BCT colormaps (e.g., `"redblue"`) implemented as pure functions in `bct.ui.color.maps.*`

It is designed to integrate cleanly with:
- **`bct.registry`**: authoritative description of which colormaps exist
- **`bct.runtime`**: fast dictionary lookups mapping colormap IDs → generator function handles

---

## 2. Scope and Non-goals

### 2.1 In scope (v1)
- Resolve colormap ID → `N×3` colormap matrix using runtime dictionaries.
- Compute a default `CLim` from finite values when not provided.
- Map values → RGB deterministically using linear scaling into the colormap.
- Handle non-finite values (`NaN`, `Inf`) via a configurable `NaNColor`.
- Provide discovery for UI controls (list available colormaps).

### 2.2 Out of scope (v1)
- CLim policy families (robust percentiles, symmetric around center, fixed policies beyond explicit `CLim`).
- Alpha/transparency policies.
- Indexed/categorical mapping modes.
- Applying to MATLAB graphics objects (patch/axes). (May be added as `applyToPatch/applyToAxes` later.)

---

## 3. Architecture Overview

### 3.1 Separation of Concerns

| Layer | Responsibility | Examples |
|------:|----------------|----------|
| `bct.registry` | **What exists** (metadata) | `bct.registry.colormaps()` returns supported colormap IDs, providers, defaults |
| `bct.runtime` | **How to execute** (dispatch dictionaries) | `bct.runtime.colormap()` returns mapping `Id → @(n)colormap` |
| `bct.ui.color` | **UI-facing mapping pipeline** | `bct.ui.color.rgb(values,"Colormap","turbo")` returns RGB |

**Key rule:**  
`bct.ui.color` does not define the authoritative list of colormaps. It consumes `bct.registry` and `bct.runtime`.

---

## 4. Namespaces and File Layout

### 4.1 Package layout

```

+bct/+ui/+color/
rgb.m              % primary entry point: scalar -> RGB
resolve.m          % resolve colormap ID -> Nx3 array via runtime dictionary
clim.m             % compute default CLim from finite values
list.m             % discovery: return registered colormap IDs (from registry)
schema.m           % default ColorSpec struct for v1
validate.m         % validate/normalize spec and inputs

+maps/
redblue.m        % custom colormap generator(s): @(n)->Nx3
...              % additional custom maps

```

### 4.2 Related dependencies

```

+bct/+registry/
colormaps.m        % authoritative metadata list

+bct/+runtime/
colormap.m            % executable dictionary: Id -> @(n)->Nx3

````

---

## 5. Colormap Registry Contract (`bct.registry.colormaps`)

### 5.1 Purpose
`bct.registry.colormaps()` is the authoritative list of supported colormaps.

### 5.2 Return type
Struct array `defs(1×K)` with minimally:

- `Id` (string scalar): canonical ID used everywhere (case-sensitive, recommend lower-case)
- `Provider` (string scalar): `"matlab"` or `"bct"`
- `Kind` (string scalar): `"sequential"|"diverging"|"cyclic"|"categorical"` (informational in v1)
- `DefaultN` (positive integer): recommended default number of colors (e.g., 256)
- Optional: `Tags` (string array), `Notes` (string)

### 5.3 Example
- `"turbo"`:
  - `Id="turbo"`, `Provider="matlab"`, `Kind="sequential"`, `DefaultN=256`
- `"redblue"`:
  - `Id="redblue"`, `Provider="bct"`, `Kind="diverging"`, `DefaultN=256`

### 5.4 Rules
- Registry must contain **no UI state**.
- Registry ordering is the default UI ordering (for dropdowns).
- IDs must be unique.

---

## 6. Runtime Dictionary Contract (`bct.runtime.colormap`)

### 6.1 Purpose
`bct.runtime.colormap()` provides the executable mapping:
> `colormapId` → `@(n) -> [n×3 double]`

### 6.2 Return type
A MATLAB `dictionary` with:
- keys: `string`
- values: `function_handle` of signature `(n)->Nx3`

### 6.3 Construction policy
The runtime dictionary is constructed using the registry:

- For `Provider="matlab"`:
  - generator should call MATLAB built-in by name:
    - `@(n) feval(id, n)` (where `id` is `"turbo"` etc.)
- For `Provider="bct"`:
  - generator should call the corresponding function in `bct.ui.color.maps`:
    - e.g., `"redblue"` → `@(n) bct.ui.color.maps.redblue(n)`

### 6.4 Caching
The runtime dictionary should be cached internally (e.g., `persistent`) for performance.

### 6.5 Validation
Runtime dictionary must guarantee:
- returned colormap is `n×3`
- values are in `[0, 1]` (small numerical drift tolerated and clamped by generators if necessary)

---

## 7. Custom Colormap Generator Contract (`bct.ui.color.maps.*`)

### 7.1 Purpose
Provide BCT-defined colormaps as **pure functions**.

### 7.2 Signature
Each custom colormap generator must have signature:

- `C = bct.ui.color.maps.<name>(n)`

Where:
- `n` is optional, defaulting to 256 (or `DefaultN` if you enforce that later)
- output `C` is `n×3 double` in `[0, 1]`

### 7.3 Purity requirement
- No global state
- No dependency on graphics handles
- Deterministic given `n`

---

## 8. `bct.ui.color` API Contract (v1)

### 8.1 ColorSpec (schema)
In v1, the ColorSpec is minimal.

#### `bct.ui.color.schema()`
Returns:
```matlab
spec = struct( ...
  "Colormap", "parula", ...
  "NColors", 256, ...
  "CLim", [], ...
  "NaNColor", [0.2 0.2 0.2] );
````

**Field definitions**

* `Colormap` (string): colormap ID
* `NColors` (positive integer): number of colors used for mapping
* `CLim` (`[]` or `[lo hi]`): color limits
* `NaNColor` (`1×3 double`): RGB used for non-finite values

### 8.2 Primary mapping function

#### `bct.ui.color.rgb(values, Name,Value,...)`

**Purpose:** Convert scalar values to RGB.

**Signature**

* `rgb = bct.ui.color.rgb(values, Name,Value,...)`
* `[rgb, out] = bct.ui.color.rgb(values, Name,Value,...)`

**Accepted Name-Value arguments (v1)**

* `"Colormap"` (string) default `"parula"`
* `"NColors"` (positive integer) default `256`
* `"CLim"` (1×2 double) default `[]`
* `"NaNColor"` (1×3 double) default `[0.2 0.2 0.2]`

**Behavior**

1. Parse inputs; merge with defaults from `schema()`.
2. Validate options using `validate()`.
3. Resolve colormap array:

   * `cmap = bct.ui.color.resolve(spec.Colormap, spec.NColors)`
4. Compute `CLim` if absent:

   * `CLim = bct.ui.color.clim(values)` using finite values only
5. Map scalar values to colormap rows:

   * For each finite `x`:

     * if `CLim(1) == CLim(2)`: map to midpoint color (index `ceil(NColors/2)`)
     * else compute normalized `t = (x - lo)/(hi - lo)` and clamp to `[0,1]`
     * index `i = 1 + floor(t*(NColors-1))`
     * `rgb = cmap(i,:)`
6. Non-finite values map to `NaNColor`.
7. Return `rgb` plus `out` if requested.

**Output**

* `rgb`: `[..., 3] double`, same shape as `values` with last dimension = 3.

**Optional `out`**

```matlab
out = struct( ...
  "ColormapId", spec.Colormap, ...
  "Colormap", cmap, ...
  "NColors", spec.NColors, ...
  "CLim", CLim, ...
  "NaNColor", spec.NaNColor, ...
  "ValidMask", isfinite(values) );
```

### 8.3 Colormap resolution

#### `bct.ui.color.resolve(colormapId, n)`

**Purpose:** Resolve ID to `n×3` colormap matrix.

**Behavior**

1. `D = bct.runtime.colormap()`
2. Verify `colormapId` exists in dictionary keys.
3. Call `cmap = D(colormapId)(n)`
4. Validate output shape and range.

### 8.4 CLim computation

#### `bct.ui.color.clim(values)`

**Purpose:** Compute default `CLim`.

**Rules**

* Use finite values only:

  * `lo = min(valuesFinite)`
  * `hi = max(valuesFinite)`
* If no finite values:

  * return `[0 1]`
* If constant (`lo == hi`):

  * return `[lo hi]` (caller uses midpoint mapping)

### 8.5 Discovery for UI dropdowns

#### `bct.ui.color.list()`

**Purpose:** Return available colormap IDs for UI selection.

**Behavior**

* Call `defs = bct.registry.colormaps()`
* Return `string({defs.Id})` in registry order

### 8.6 Validation

#### `bct.ui.color.validate(spec)`

**Purpose:** Ensure spec is well-formed.

**Validation rules (v1)**

* `spec.Colormap` is string scalar
* `spec.NColors` is positive integer scalar
* `spec.NaNColor` is `1×3 double` in `[0,1]`
* if `spec.CLim` non-empty:

  * size is `1×2`
  * `CLim(1) <= CLim(2)`
* Note: existence of colormap ID is validated in `resolve()` (execution layer).

---

## 9. Error Handling

Errors must be thrown with stable identifiers:

* Unknown colormap ID:

  * `bct:ui:color:UnknownColormap`
* Invalid `NColors`:

  * `bct:ui:color:InvalidNColors`
* Invalid `CLim`:

  * `bct:ui:color:InvalidCLim`
* Invalid `NaNColor`:

  * `bct:ui:color:InvalidNaNColor`
* Invalid colormap output from generator:

  * `bct:ui:color:InvalidColormapOutput`

No warnings in v1.

---

## 10. End-to-End Workflow (v1)

### 10.1 Author adds a new custom map

1. Implement generator:

   * `+bct/+ui/+color/+maps/<id>.m`
2. Add metadata entry:

   * `bct.registry.colormaps()` includes `Id=<id>, Provider="bct", ...`
3. Runtime dictionary automatically binds it:

   * `bct.runtime.colormap()` resolves `Provider="bct"` → `bct.ui.color.maps.<id>`

### 10.2 User maps values to RGB

```matlab
rgb = bct.ui.color.rgb(values, "Colormap","redblue", "NColors",256);
```

`bct.ui.color.rgb`:

* resolves `"redblue"` using runtime dictionary
* computes `CLim` (unless provided)
* returns deterministic `rgb`

---

## 11. Minimal Testing Requirements

1. `bct.ui.color.list()` includes `"parula"` and `"turbo"` (and `"redblue"` if registered).
2. `resolve("turbo",256)` returns `256×3`.
3. `rgb` output shape:

   * `size(rgb) == [size(values), 3]`
4. Constant field behavior is stable and does not error.
5. NaNs map to `NaNColor`.
6. Unknown colormap ID throws `bct:ui:color:UnknownColormap`.

---

## 12. Forward Compatibility Notes

This v1 contract is intentionally a spine for later additions:

* Add CLim policies later:

  * `"CLimPolicy"="robust"|"symmetric"|...`
  * implemented via `bct.runtime` policy dictionaries
* Add alpha policies:

  * `"AlphaPolicy"="mask"|"field"`
* Add graphics application helpers:

  * `applyToPatch(hPatch, values, ...)`
  * `applyToAxes(ax, ...)`

**Constraint:** These future extensions must not break the v1 `rgb()` signature or semantics.

---

