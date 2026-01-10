
# BCT Registry + Runtime Contract
## Scope: Kernels and UI Colormaps Only

This document defines the authoritative architecture and implementation contracts for:

- `bct.registry` (declarative definitions + schema/validation)
- `bct.runtime` (executable dispatch + optional caching)
- Refactoring the user-facing APIs:
  - `bct.kernel` (math-facing façade)
  - `bct.ui.color` (UI-facing façade)

**Explicit non-scope (do not implement yet):** filters, brushes, operators, and any other domains.

---

## 1. Architectural Intent

### 1.1 Separation of concerns

**Registry (`bct.registry.*`)**
- Declares what exists (IDs, metadata, parameter schemas, providers).
- Contains no UI state, no caching, no persistent globals, and no axes/graphics handles.
- Must be deterministic: calling registry functions twice should return equivalent definitions.

**Runtime (`bct.runtime.*`)**
- Turns registry definitions into executable dispatch:
  - Dictionaries of function handles for fast lookup.
  - Resolvers that bind definitions to context (e.g., axis, size `n`).
- May cache computed dictionaries (persistent cache) for performance.
- Must remain free of UI state and graphics handles; runtime is “execution plumbing,” not “view logic.”

**User-facing façades**
- `bct.kernel.*` and `bct.ui.color.*` remain the ergonomic entrypoints.
- They delegate to registry/runtime and should not become alternative sources of truth.

---

## 2. Naming and File Layout (Required)

### 2.1 Registry layout

Implement domain registries under `+bct/+registry/<domain>/`:

```

+bct/+registry/
+kernels/
defs.m
schema.m
validate.m
list.m           (optional convenience)
+colormaps/
defs.m
schema.m
validate.m
list.m           (optional convenience)

```

**Rule:** `defs.m` is the authoritative list. All other helpers must ultimately consume `defs.m`.

### 2.2 Runtime layout

Implement runtime dispatch under `+bct/+runtime/<domain>/`:

```

+bct/+runtime/
+kernels/
dictionary.m
resolve.m
clearCache.m     (recommended)
+colormaps/
dictionary.m
resolve.m
clearCache.m     (recommended)

```

### 2.3 User-facing façades

Keep existing public namespaces but refactor to delegate:

```

+bct/+kernel/
registry.m         (wrapper -> bct.registry.kernels.defs)
dictionary.m       (wrapper -> bct.runtime.kernels.dictionary)
list.m
get.m              (wrapper -> bct.runtime.kernels.resolve)

+bct/+ui/+color/
list.m
resolve.m          (wrapper -> bct.runtime.colormaps.resolve)
apply.m            (UI mapping; uses runtime resolve)
+maps/             (custom colormap generators, e.g. redblue.m)

````

**Policy:** `bct.ui.color` is the UI layer, but it must not own the authoritative colormap list. That belongs to `bct.registry.colormaps.defs`.

---

## 3. Contract: `bct.registry.kernels`

### 3.1 `bct.registry.kernels.defs()`

**Signature**
```matlab
defs = bct.registry.kernels.defs()
````

**Output**

* `defs`: struct array (1×K) with canonical fields.

**Required fields for each entry**

* `Id` (string scalar): unique canonical identifier (case-sensitive policy is allowed; be consistent).
* `Kind` (string scalar): coarse classification (e.g., `"smoothing"`, `"wavelet"`, `"window"`, `"impulse"`).
* `AxisKinds` (string array): allowed axes (e.g., `["time","freq","lambda","distance"]`).
* `ParamNames` (string array): names of parameters used in evaluation struct `p`.
* `DefaultParams` (function_handle): `@(axis)->struct`
* `ParamRanges` (function_handle): `@(axis)->struct`
* `Evaluate` (function_handle): **canonical evaluator** `@(x,p)->y`

**Optional fields**

* `Name` (string scalar) display name (if different from Id)
* `Tags` (string array)
* `EquationLatex` (string scalar)
* `Notes` (string scalar)
* `IsComplex` (logical scalar)
* `Units` (string scalar or struct) if you choose to encode unit semantics later

**Non-negotiable policy**

* `Evaluate(x,p)` is the single canonical execution contract.
* Any alternate forms (`Function = @(p) @(x) ...`) are derived in runtime if needed and must not be required.

### 3.2 `bct.registry.kernels.schema()`

**Signature**

```matlab
S = bct.registry.kernels.schema()
```

**Purpose**
Returns a declarative description of expected fields and invariants. This enables centralized validation and future tooling.

**Output**

* `S`: struct describing:

  * required fields
  * allowed values (where applicable)
  * invariant checks (as function handles)

**Minimum content**

* `S.RequiredFields` (string array)
* `S.OptionalFields` (string array)
* `S.ValidateEntry` (function handle): `@(entry)->mustPassOrError`

### 3.3 `bct.registry.kernels.validate(defs)`

**Signature**

```matlab
bct.registry.kernels.validate(defs)
```

**Contract**
Must error (not warn) if:

* duplicate `Id`s
* missing required fields
* `ParamNames` is inconsistent with `DefaultParams/ParamRanges` output fields
* `DefaultParams` or `ParamRanges` does not return a struct
* `Evaluate` is not a function handle with arity 2 (x,p)
* optional: sanity evaluation on a short axis sample throws

**Validation invariants (required)**
For each entry `e`:

* `mustBeTextScalar(e.Id)`
* `e.ParamNames` is string array, unique, stable ordering
* `p0 = e.DefaultParams(axis)` returns struct containing all `ParamNames`
* `pr = e.ParamRanges(axis)` returns struct containing all `ParamNames`
* `y = e.Evaluate(axisSample, p0)` executes without error

**Axis sample policy**
Use a minimal axis sample to validate execution without expensive computations:

* `axisSample = linspace(-1,1,9).';` (or any small canonical sample)

### 3.4 Validation placement policy

You may validate in either of these ways:

* `defs.m` calls `validate(defs)` before returning (strict mode), OR
* `validate.m` is called by runtime and/or tests

**Required:** runtime must never silently accept invalid registry entries.

---

## 4. Contract: `bct.runtime.kernels`

### 4.1 `bct.runtime.kernels.dictionary()`

**Signature**

```matlab
D = bct.runtime.kernels.dictionary()
```

**Output**

* `D`: MATLAB `dictionary` mapping

  * keys: kernel `Id` (string)
  * values: evaluator function handles with signature:

    * `@(x,p)->y`

**Construction**

* Build from `bct.registry.kernels.defs()`
* Validate defs before building.

**Caching**

* Must use `persistent cachedDict` (optional but recommended).
* Cache invalidation should be explicit via `bct.runtime.kernels.clearCache()`.

**Failure behavior**

* If a kernel definition is invalid or missing required executable parts, runtime must error.
* Do not silently skip registered kernels (skipping makes UI and downstream behavior inconsistent).

### 4.2 `bct.runtime.kernels.resolve(id, axis, varargin)`

**Signature**

```matlab
spec = bct.runtime.kernels.resolve(id, axis, NameValueArgs...)
```

**Inputs**

* `id` (string/scalar char): kernel Id
* `axis` (numeric vector): axis values used to compute defaults and ranges
* optional Name-Value:

  * `"Params"`: struct overriding defaults
  * `"ValidateParams"`: logical (default true)
  * `"AllowOutOfRange"`: logical (default false)

**Output: KernelSpec struct**
Required fields:

* `Id` (string)
* `Axis` (numeric vector) — stored as provided (do not copy huge arrays unnecessarily if avoidable)
* `ParamNames` (string array)
* `Defaults` (struct) from `DefaultParams(axis)`
* `Ranges` (struct) from `ParamRanges(axis)`
* `Params` (struct) final params after overrides
* `Evaluate` (function_handle) `@(x,p)->y`
* `Factory` (function_handle) `@(p)->@(x)->y` (derived convenience)
* `Kind`, `AxisKinds`, `Tags`, `EquationLatex`, `Notes` (if present in defs)

**Parameter resolution policy**

* Start with `Defaults`
* Override with provided `"Params"` (fieldwise)
* If `"ValidateParams"`:

  * Ensure all `ParamNames` exist
  * Ensure values are numeric scalars/vectors as appropriate for your kernel conventions
  * Enforce ranges unless `"AllowOutOfRange"=true`

**Axis compatibility**

* If `AxisKinds` are declared and axis kind is knowable from context, enforce compatibility.
* In this scope, axis kind may not be inferable automatically. Therefore:

  * Do not attempt inference in v1
  * Optionally accept `"AxisKind"` as an NV input if you want enforcement now

### 4.3 `bct.runtime.kernels.clearCache()`

**Signature**

```matlab
bct.runtime.kernels.clearCache()
```

**Behavior**

* Clears persistent caches used by `dictionary` (and any future caches).

---

## 5. Contract: `bct.registry.colormaps`

### 5.1 `bct.registry.colormaps.defs()`

**Signature**

```matlab
defs = bct.registry.colormaps.defs()
```

**Output**
Struct array with fields (your current model is correct):

* `Id` (string)
* `Provider` (string): `"matlab"` or `"bct"`
* `Kind` (string): `"sequential"|"diverging"|"cyclic"|"categorical"`
* `DefaultN` (positive integer)
* `Tags` (string array) optional
* `Notes` (string) optional

**Provider policy**

* `"matlab"` means `feval(Id, n)`
* `"bct"` means `bct.ui.color.maps.<Id>(n)` (custom generator in codebase)

### 5.2 `bct.registry.colormaps.schema()` and `.validate(defs)`

Implement analogous to kernels:

* Validate unique IDs
* Validate Provider/Kind in allowed sets
* Validate DefaultN
* Optional: validate that runtime can resolve providers (exists check) but do not call generators here (registry must remain declarative)

---

## 6. Contract: `bct.runtime.colormaps`

### 6.1 `bct.runtime.colormaps.dictionary()`

**Signature**

```matlab
D = bct.runtime.colormaps.dictionary()
```

**Output**

* `D`: dictionary mapping:

  * key: colormap `Id`
  * value: function_handle `@(n)->[n×3 double]`

**Construction**

* From `bct.registry.colormaps.defs()`
* Validate defs before building
* Provider dispatch rules:

  * `"matlab"`: `D(id) = @(n) feval(id, n)`
  * `"bct"`: `D(id) = @(n) bct.ui.color.maps.<id>(n)` via `str2func`

**Error behavior**

* If provider is unknown: error
* If provider is `"bct"` but generator is missing: error (do not silently skip)

**Caching**

* Use `persistent cachedDict` and implement `clearCache()`.

### 6.2 `bct.runtime.colormaps.resolve(id, n)`

**Signature**

```matlab
C = bct.runtime.colormaps.resolve(id, n)
```

**Behavior**

* Returns `[n×3]` double colormap matrix
* Uses runtime dictionary dispatch:

  * `D = bct.runtime.colormaps.dictionary();`
  * `C = D(id)(n);`
* Enforce `n` integer positive scalar; fall back to registry DefaultN only if `n` omitted via an overload:

  * `resolve(id)` uses registry DefaultN

### 6.3 `bct.runtime.colormaps.clearCache()`

Analogous to kernels.

---

## 7. Refactor Contract: `bct.kernel` (user-facing façade)

### 7.1 Design goals

* Preserve ergonomic API: `list`, `get`, `dictionary`, `registry`
* Ensure `bct.kernel` never becomes a second source of truth
* Keep backward compatibility where possible

### 7.2 Required functions

#### `bct.kernel.registry()`

* Must delegate:

  * `defs = bct.registry.kernels.defs();`

#### `bct.kernel.dictionary()`

* Must delegate:

  * `D = bct.runtime.kernels.dictionary();`

#### `bct.kernel.list(varargin)`

* Should provide a stable listing (strings).
* Implementation should read from `bct.registry.kernels.defs()` and return `string([defs.Id]).'`
* Optional tag filtering can be added later; do not invent new taxonomy in this scope.

#### `bct.kernel.get(id, axis, varargin)`

* Must delegate to `bct.runtime.kernels.resolve(id, axis, ...)`
* Returns KernelSpec struct
* If you need a lightweight getter for evaluator only, add:

  * `bct.kernel.evaluator(id)` later; do not overload `get` to return multiple types unless you define a strict rule.

### 7.3 Deprecation policy

* If legacy functions exist (`bct.kernel.registry` returning struct with named fields, etc.), keep them as wrappers for now.
* Any change that breaks user scripts should be behind a temporary compatibility layer and documented.

---

## 8. Refactor Contract: `bct.ui.color` (user-facing façade)

### 8.1 Design goals

* `bct.ui.color` stays UI-oriented: resolve colormap and apply it to scalar data.
* Registry and runtime remain the only source of truth for “what colormaps exist” and “how to dispatch.”

### 8.2 Required functions

#### `bct.ui.color.list()`

* Returns list of IDs from `bct.registry.colormaps.defs()`
* Optionally include metadata as a table later; for now, return string array.

#### `bct.ui.color.resolve(id, n)`

* Delegates to runtime:

  * `C = bct.runtime.colormaps.resolve(id, n);`

#### `bct.ui.color.apply(data, NameValue...)`

**Purpose**
Convert scalar array to RGB using a named colormap.

**Minimum supported Name-Value arguments**

* `"Colormap"` (string) default `"parula"`
* `"CLim"` (1×2 double) optional; if omitted use `[min(data), max(data)]` ignoring NaNs
* `"N"` (positive int) default 256 (or registry DefaultN for chosen colormap)
* `"NaNColor"` (1×3 double) default `[0 0 0]` or configurable
* `"Clip"` (logical) default true

**Output**

* `RGB`: array size `[size(data), 3]` (same shape plus trailing channel dim)
* Optional second output `idx` (uint16) of colormap indices may be provided if you need it for performance later.

**Implementation policy**

* Must call `bct.ui.color.resolve()` (not `feval` directly).
* Must not embed colormap lists or providers; those live in registry/runtime.

#### `bct.ui.color.maps.*`

* Contains only BCT-provided custom map generators, signature:

  * `C = bct.ui.color.maps.<id>(n)`
* Must return `double` in `[0,1]` with shape `[n×3]`.

---

## 9. Error Handling Policy (Global)

### 9.1 Registry

* `validate` must throw errors (not warnings) for schema violations.
* Registry functions must not “best-effort” partial results.

### 9.2 Runtime

* Runtime must error if:

  * registry validation fails
  * requested ID does not exist
  * provider cannot be resolved
* Runtime may cache dictionaries; caching must not mask errors. If a dictionary is cached and registry changes, the user must call `clearCache()` (or you can introduce a versioned cache later).

### 9.3 Façades

* Façades should surface runtime errors without swallowing them.
* Façades may add better user messaging (e.g., “available IDs: …”) but must not silently fall back to unrelated defaults (unless explicitly documented).

---

## 10. Refactoring Steps (Recommended Order)

### Step 1 — Introduce registry namespaces without breaking existing code

1. Create `bct.registry.kernels.defs` by moving your current kernel registry definitions into canonical struct-array entries.
2. Create `bct.registry.colormaps.defs` (rename/move from current `bct.registry.colormaps` if needed).
3. Implement `schema.m` and `validate.m` for both.

### Step 2 — Introduce runtime dispatch layers

1. Create `bct.runtime.kernels.dictionary/resolve/clearCache`.
2. Create `bct.runtime.colormaps.dictionary/resolve/clearCache`.
3. Update `bct.ui.color.resolve` to call runtime resolve.

### Step 3 — Refactor façades to delegate

1. Update `bct.kernel.registry/dictionary/list/get` to delegate to registry/runtime.
2. Ensure `bct.ui.color.list/resolve/apply` use registry/runtime and do not embed colormap dispatch logic.

### Step 4 — Compatibility wrappers

* If old functions exist (`bct.kernel.registry` returning a different shape), implement them as thin adapters:

  * Convert canonical `defs` into legacy struct-of-structs if needed.
* Mark legacy outputs in docstrings as deprecated (do not remove yet).

---

## 11. Acceptance Criteria (Must Pass)

### 11.1 Kernels

* `bct.registry.kernels.defs()` returns a validated struct array with unique `Id`s.
* `bct.runtime.kernels.dictionary()` returns a dictionary mapping each Id to `@(x,p)->y`.
* `bct.runtime.kernels.resolve("Gaussian", axis)` returns a KernelSpec with computed defaults/ranges and executable Evaluate/Factory.
* `bct.kernel.get("Gaussian", axis)` returns the same KernelSpec (delegation).

### 11.2 Colormaps

* `bct.registry.colormaps.defs()` returns a validated struct array with unique `Id`s.
* `bct.runtime.colormaps.dictionary()` returns dispatch `@(n)->[n×3]` for each Id.
* `bct.ui.color.resolve("redblue", 256)` returns the custom map (via `bct.ui.color.maps.redblue`).
* `bct.ui.color.apply(data,"Colormap","turbo")` maps scalars to RGB correctly.

---

## 12. Implementation Notes (Non-optional)

### 12.1 Prefer struct arrays over struct-with-dynamic-fields for registries

* Struct arrays are easier to validate, list, sort, and serialize.
* Dynamic-field registries are harder to validate and evolve.

### 12.2 Keep runtime dictionaries as the only dispatch mechanism

* Do not re-implement dispatch inside UI or kernel façades.
* This ensures a single performance/caching strategy.

### 12.3 Do not let UI packages own registries

* `bct.ui.color.maps.*` can exist (implementation), but the list of maps and their metadata is in `bct.registry.colormaps.defs`.

---

## 13. Minimal Example Usage (Target UX)

### Kernels

```matlab
axis = linspace(-5,5,501).';
spec = bct.kernel.get("Gaussian", axis);
y = spec.Evaluate(axis, spec.Params);      % defaults
y2 = spec.Evaluate(axis, struct("mu",0,"sigma",1)); % override
```

### Colormaps

```matlab
C = bct.ui.color.resolve("redblue", 256);
RGB = bct.ui.color.apply(signal, "Colormap","parula", "CLim",[-1 1], "N",256);
```

---

End of contract.


