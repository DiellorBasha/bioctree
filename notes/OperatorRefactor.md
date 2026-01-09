Below are complete, implementation-ready refactoring instructions you can hand to a coding agent. They assume the decisions we made:

* `bct.Manifold` caches **DECLab** `DiscreteExteriorCalculus` directly (no `bct.DEC` wrapper for runtime use).
* `bct.registry.operators` becomes a **flat dictionary** keyed by hierarchical IDs like `"gradient.dec"`, `"gradient.fem"`.
* Operator catalog contains only **derived analysis operators** (gradient/divergence/curl/laplacian/HHD/…).
* Tier-1 DEC primitives (`d0`, `d1`, `star0`, …) are **removed from registry/runtime** and used only as `requires` capability tokens (and remain accessible via `M.DEC()` if needed).
* No new mirror wrapper packages (do **not** create `bct.ops.dec.*` or reintroduce `bct.dec.*` wrappers for DECLab-native methods).
* Registry specs include **dependency metadata** for toolbox availability (DECLab, gptoolbox, etc.), used by runtime to filter applicability and produce actionable errors.
* Keep runtime/registry structure consistent with kernels/colormaps/brushes; use `+operators` subfolders (recommended) while maintaining backward-compatible façade entrypoints.

---

# 0) Deliverables checklist

Agent must deliver:

1. `bct.Manifold.DEC()` returns cached `DiscreteExteriorCalculus` instance.
2. `bct.registry.operators.defs()` returns a `dictionary` keyed by operator ID strings (e.g., `"gradient.dec"`).
3. Operator registry contains only derived operators (remove tier-1 DEC primitives).
4. `bct.runtime.operators.dictionary(ctx)` returns a dictionary of **bound operator handles**.
5. `bct.runtime.bind(spec, ctx)` supports:

   * representation resolution (DEC/FEM…)
   * dependency checks
   * binding of unbound class method handles (`@DiscreteExteriorCalculus.gradient`) and procedural functions (FEM adapters).
6. Backward compatibility shims (temporary) for old operator IDs (`dec_gradient`, etc.) and `bct.DEC` (deprecated).
7. Minimal smoke tests demonstrating DEC and FEM operators work and runtime filtering behaves when dependencies are missing.

---

# 1) Restructure directories (consistency with kernels/colormaps/brushes)

## 1.1 Add `+operators` subfolders

### Create:

**Registry**

* `toolbox/+bct/+registry/+operators/defs.m`
* `toolbox/+bct/+registry/+operators/list.m`
* `toolbox/+bct/+registry/+operators/schema.m`
* `toolbox/+bct/+registry/+operators/validate.m`

**Runtime**

* `toolbox/+bct/+runtime/+operators/dictionary.m`
* `toolbox/+bct/+runtime/+operators/resolve.m` (optional; if you already have a root `resolve` pattern)
* `toolbox/+bct/+runtime/+operators/clearCache.m` (optional; only if you cache operator dict)
* `toolbox/+bct/+runtime/+operators/private/` (optional helpers)

### Keep existing façades (do not break call sites):

* `toolbox/+bct/+registry/operators.m` becomes a thin delegator to `bct.registry.operators.defs()` (or list/validate as appropriate).
* `toolbox/+bct/+runtime/operators.m` becomes a thin delegator to `bct.runtime.operators.dictionary(context)`.

---

# 2) Update `bct.Manifold` DEC port to cache the DECLab backend

## 2.1 Modify `bct.Manifold.DEC()`

**Goal:** cache a `DiscreteExteriorCalculus` instance in `obj.Cache("DEC")`.

Implementation notes:

* Convert `Faces` and `Vertices` to `double` before passing to DECLab.
* Handle missing DECLab gracefully with a clear error (dependency check can also happen at runtime; but Manifold should still error if user calls `M.DEC()` directly).

Pseudo-implementation:

```matlab
function dec = DEC(obj)
    if ~isKey(obj.Cache, "DEC")
        if exist("DiscreteExteriorCalculus","class") ~= 8
            error("bct:MissingDependency", ...
                  "DECLab not found on MATLAB path (DiscreteExteriorCalculus missing).");
        end
        F = double(obj.Faces);
        V = double(obj.Vertices);
        obj.Cache("DEC") = DiscreteExteriorCalculus(F, V);
    end
    dec = obj.Cache("DEC");
end
```

## 2.2 Remove any remaining reliance on `bct.DEC` inside Manifold

* Ensure no `obj.Cache("DEC") = bct.DEC(obj)` remains.
* If other code expects `M.DEC().Backend`, fix those call sites to use `M.DEC()` directly.

---

# 3) Refactor the operator registry to a flat dictionary with hierarchical IDs

## 3.1 Convert specs storage to `dictionary`

**Constraint:** MATLAB `struct` cannot have a field name like `gradient.dec`. Therefore, operator defs must be a `dictionary` (or `containers.Map`). Use `dictionary` as decided.

### `bct.registry.operators.defs()` contract

Return:

* `specs` as `dictionary(string -> struct)`

Each spec struct should include at minimum:

* `id` (string) — e.g., `"gradient.dec"`
* `name` (string) — human-friendly label
* `domain` (string) — `"dec"`, `"fem"`, `"graph"`, etc.
* `representation` (string) — `"DiscreteExteriorCalculus"`, `"FEM"`, …
* `inputType`, `outputType` (string) — keep your existing convention
* `formDegree` (numeric or []) — keep if used
* `parameters` (struct) — operator parameters schema/defaults
* `requires` (string array) — capability tokens, checked against representation instance
* `dependency` (struct) — described below
* `function` (function_handle) — unbound method handle for DEC; adapter function for FEM
* `purity` (string) — `"pure"` etc.
* `description` (string)

## 3.2 Add dependency metadata per operator

Add `dependency` field to each spec:

```matlab
dependency = struct( ...
    "provider", "DECLab", ...
    "kind", "matlabpath", ...
    "requiredSymbols", ["DiscreteExteriorCalculus"], ...
    "rootHint", "external/DECLab", ...
    "notes", "" );
```

For gptoolbox:

```matlab
dependency = struct( ...
    "provider", "gptoolbox", ...
    "kind", "matlabpath", ...
    "requiredSymbols", ["grad","div"], ...
    "rootHint", "external/gptoolbox/mesh", ...
    "notes", "" );
```

## 3.3 Define DEC derived operators only (remove tier-1 primitives from registry)

### Keep (DEC):

* `"gradient.dec"`        → `function = @DiscreteExteriorCalculus.gradient`
* `"divergence.dec"`      → `function = @DiscreteExteriorCalculus.divergence`
* `"curl.dec"`            → `function = @DiscreteExteriorCalculus.curl`
* `"laplacian.dec"`       → `function = @DiscreteExteriorCalculus.laplacian`
* `"hhd.dec"`             → `function = @DiscreteExteriorCalculus.helmholtzHodgeDecomposition`

### Remove entirely from registry:

* any operator specs like `dec_d0`, `dec_d1`, `dec_star0`, `dec_star1`, `dec_sharp`, `dec_flat`, etc.

These should no longer appear in `defs`, `list`, `schema`, or runtime dictionaries.

### `requires` tokens for DEC derived ops

Keep tokens as “capability checks” only, e.g.:

* gradient.dec: `requires=["d0"]`
* divergence.dec: `requires=["d0","hd1"]` (or whatever you were using)
* curl.dec: `requires=["d1"]`
* laplacian.dec: `requires=[]` or `["d0","d1"]` (optional)
* hhd.dec: `requires=[]` (optional)

Runtime will check `isprop(dec, req)` or `ismethod(dec, req)` depending on how DECLab exposes them.

---

# 4) Add FEM operator implementations (adapters) without polluting DEC design

DEC can call class methods directly; FEM cannot, because gptoolbox uses procedural functions returning matrices.

## 4.1 Define FEM representation in context (minimal viable)

You have two options—agent should pick one and implement consistently:

### Option A (recommended): `M.FEM()` port caches FEM matrices

* Add `bct.Manifold.FEM()` that returns a struct:

  * `V`, `F` (or use manifold)
  * cached `G = grad(V,F)`
  * cached `D = div(V,F)`
* This improves performance for repeated calls.

### Option B: runtime computes matrices lazily and caches by manifold id

* If you avoid adding `M.FEM()`, runtime can compute `G/D` when binding or executing and cache them in `ctx` or a persistent map keyed by `M` identity.

Given your DEC approach uses Manifold caching, Option A is preferred for symmetry.

## 4.2 Implement FEM “apply” adapters in runtime operators

Create:

* `toolbox/+bct/+runtime/+operators/femGradient.m`
* `toolbox/+bct/+runtime/+operators/femDivergence.m`

These functions should accept the FEM representation instance as first argument (to match the runtime binding convention), then the signal.

Example behavior:

### `gradient.fem`

* Input: scalar field `f0` (#V×1)
* Compute (once): `G = grad(V,F)`  (#F*dim × #V)
* Apply: `g = G * f0`  (#F*dim × 1)
* Reshape: `U = reshape(g, [#F, dim])`

### `divergence.fem`

* Input: face vector field `U` (#F×3 or #F×dim)
* Ensure stacked: `u = U(:)` (#F*dim×1)
* Compute `D = div(V,F)` (#V × #F*dim)
* Apply: `div0 = D * u` (#V×1)

Add dependency checks for gptoolbox availability in applicability.

## 4.3 Add FEM derived operators to registry

Add:

* `"gradient.fem"` with `function=@bct.runtime.operators.femGradient`
* `"divergence.fem"` with `function=@bct.runtime.operators.femDivergence`

Use dependency metadata:

* `requiredSymbols=["grad"]` and `["div"]` respectively (or both in both specs; simplest).

---

# 5) Update runtime for operators (dictionary-driven, consistent with existing runtime style)

## 5.1 `bct.runtime.context.m` (ensure it supports Manifold + lazy reps)

Agent must ensure `bct.runtime.context(...)` can accept a `bct.Manifold` and produce a `ctx` struct with at least:

* `ctx.Manifold = M`

Optional but recommended:

* include placeholders: `ctx.DEC = []`, `ctx.FEM = []`
* do not eagerly compute unless requested

This preserves performance and avoids toolboxes being required unless operator is used.

## 5.2 Update `bct.runtime.isApplicable(spec, ctx)` to include dependency + representation checks

Rules:

1. Dependency available:

   * For each symbol in `spec.dependency.requiredSymbols`, check `exist(symbol, ...)`:

     * if symbol looks like a class: `exist(symbol,"class")==8`
     * otherwise: `exist(symbol,"file")==2`
   * If missing: return false
2. Representation resolvable:

   * If `spec.representation == "DiscreteExteriorCalculus"`:

     * true if `ctx.DEC` exists and is a DEC instance, OR `ctx.Manifold` exists and can construct DEC (`exist("DiscreteExteriorCalculus","class")==8`)
   * If `spec.representation == "FEM"`:

     * true if `ctx.FEM` exists OR `ctx.Manifold` can provide FEM OR gptoolbox exists and `ctx.Manifold` has `Vertices/Faces`
3. (Optional) `requires` check deferred to bind/resolve (recommended) to avoid constructing reps during filtering.

## 5.3 Update `bct.runtime.bind(spec, ctx)` to resolve representation and bind `spec.function`

Binding contract:

* Return `boundHandle = @(varargin) spec.function(rep, varargin{:});`
* `rep` is resolved from `ctx` based on `spec.representation`

Representation resolution:

* DEC:

  * if `ctx.DEC` is empty and `ctx.Manifold` exists → `rep = ctx.Manifold.DEC()`
  * else `rep = ctx.DEC`
* FEM:

  * if `ctx.FEM` empty and `ctx.Manifold` has `FEM()` → `rep = ctx.Manifold.FEM()`
  * else if compute-on-demand: build a FEM rep struct from `ctx.Manifold.Vertices/Faces` and cache `G/D` as needed
  * else `rep = ctx.FEM`

Validation inside `bind`:

* Ensure `isa(rep, spec.representationClass)` where appropriate:

  * DEC: `isa(rep, 'DiscreteExteriorCalculus')`
  * FEM: `isstruct(rep)` with required fields
* Validate `requires` tokens against rep:

  * for each req in `spec.requires`:

    * if `isprop(rep, req)` or `ismethod(rep, req)` or (struct) `isfield(rep, req)` must be true
  * If not, error with operator id + missing requirement

This yields consistent runtime behavior across toolboxes.

## 5.4 Implement `bct.runtime.operators.dictionary(ctx)` in the same pattern as kernels/colormaps

Algorithm:

1. Load defs: `specs = bct.registry.operators.defs();` (dictionary)
2. Filter keys where `bct.runtime.isApplicable(spec, ctx)` is true
3. Bind each via `bct.runtime.bind(spec, ctx)`
4. Return a dictionary: `ops(id) = boundHandle`

No tier-1 operators are included.

---

# 6) Backward compatibility and deprecation

## 6.1 Operator ID migration: support old IDs temporarily

Create an alias map in runtime (or registry) for one release cycle:

Old → New:

* `"dec_gradient"` → `"gradient.dec"`
* `"dec_divergence"` → `"divergence.dec"`
* `"dec_curl"` → `"curl.dec"`
* `"dec_laplacian"` → `"laplacian.dec"` (if it existed)
* `"dec_hhd"` → `"hhd.dec"`

Implementation options:

* In `bct.registry.operators.defs()`, include alias specs with `deprecated=true` and `aliasOf="gradient.dec"`, OR
* In `bct.runtime.operators.resolve(id, ctx)`, if id not found, look up alias map and warn.

Use `warning("bct:DeprecatedOperatorId", ...)` once per session per id if possible.

## 6.2 Deprecate `bct.DEC` class

* Keep the class file temporarily but:

  * mark it deprecated in header
  * modify so it simply stores `Backend = Manifold.DEC()` and forwards calls without caching matrices
  * warn on construction that it will be removed

Then update any internal call sites to use `M.DEC()` directly.

## 6.3 Deprecate `+bct/+dec` package functions

* Remove tier-1 accessor functions from registry/runtime usage immediately.
* Keep the files only as deprecated wrappers if existing code uses them, but they should:

  * warn
  * call the appropriate runtime operator or DEC backend directly
* Schedule removal after migration.

Do **not** create any replacement mirror package (`bct.ops.dec.*`).

---

# 7) Cleanup: remove tier-1 DEC operators from runtime + UI

Agent must search and remove any references to:

* `dec_d0`, `dec_d1`, `dec_star*`, `dec_sharp`, `dec_flat`, etc.
  in:
* `bct.registry.operators.*`
* `bct.runtime.operators.*`
* `bct.runtime.ui.resolveInspector` (if it enumerates operators)
* any UI panels/inspector definitions that list operators

If UI still needs to show “requirements,” show them as text derived from `spec.requires`, not as callable operators.

---

# 8) Tests / acceptance criteria

Agent must add a minimal test script (or unit tests if you already have a harness) that verifies:

1. **DEC derived operator binding/execution**

   * Build a simple manifold (small triangle mesh).
   * Build runtime context.
   * `ops = bct.runtime.operators.dictionary(ctx)`
   * Confirm `isKey(ops, "gradient.dec")` when DECLab is on path.
   * Execute `G = ops("gradient.dec")(f0)` and verify output size matches expected DEC behavior for your mesh.

2. **FEM operator binding/execution**

   * Ensure gptoolbox on path.
   * Confirm `gradient.fem` and `divergence.fem` present.
   * Execute and validate output sizes (#F×dim, #V×1).

3. **Dependency filtering**

   * Simulate missing dependency by temporarily removing path (or by mocking `exist` if feasible).
   * Confirm operator keys are omitted when dependency is missing.
   * Confirm `resolve` produces actionable error message including `dependency.provider` and `rootHint`.

4. **Tier-1 operators removed**

   * Ensure no keys like `"d0.dec"` or `"dec_d0"` appear in registry defs or runtime dictionary.

5. **Backward ID aliases (if implemented)**

   * Request old id (e.g., `"dec_gradient"`) resolves to `"gradient.dec"` with a warning.

---

# 9) Implementation notes and pitfalls

* **Dictionary keys**: use `string` scalars consistently (`"gradient.dec"`), not char vectors.
* **MATLAB method handles**: for unbound method handles (`@DiscreteExteriorCalculus.gradient`), runtime must call them as `spec.function(rep, args...)`. Do not attempt `@rep.gradient`.
* **Do not eagerly construct DEC/FEM reps** during registry listing; only construct when binding/executing.
* **Avoid breaking existing API**: keep façade entrypoints `bct.runtime.operators` and `bct.registry.operators` operational (delegate to new subfolder functions).

---

# 10) What the agent should NOT do

* Do not add `bct.Manifold.gradient` / `divergence` / etc. (operators remain non-scope for Manifold).
* Do not create a new DEC wrapper class (e.g., `DECFacade`) or a new mirror package like `bct.ops.dec`.
* Do not keep tier-1 DEC primitives as registry/runtime operators.
* Do not store huge operator matrices redundantly if they already exist in backend or representation cache. Cache FEM matrices only if needed (and do it in `M.FEM()` or a dedicated runtime cache).

