
# Design Document: Runtime Operator Artifacts and `bct.operators` Entrypoint

## 0. Objective

Upgrade the operator system so that:

1. **Registry** (`bct.registry.operators`) remains the **authoritative, static catalog** of operators (declarative specs).
2. **Runtime** (`bct.runtime.operators`) continues to **filter and bind** operators based on context and available dependencies.
3. The runtime system returns **Operator artifacts** (structs) rather than plain bound function handles.
4. Provide a user-friendly entrypoint **`bct.operators`** (not `bct.ops`) that returns:

   * a list of available operators for a context,
   * a way to resolve and retrieve an operator by ID,
   * a way to apply an operator uniformly.

The change must be implemented in a way that:

* does not break existing curated operator implementations,
* does not alter registry semantics or contents except where strictly necessary,
* supports incremental migration (backward compatibility where feasible).

---

## 1. Design Principles and Constraints

### 1.1 Registry remains declarative and deterministic

* Registry “specs” are **static data**, not runtime objects.
* Registry must never:

  * allocate runtime representations,
  * call external toolboxes,
  * bind or execute operator implementations.
* Registry IDs remain hierarchical (e.g., `gradient.dec`, `gradient.fem`).

### 1.2 Runtime binds representations and produces executable artifacts

* Runtime’s responsibility is:

  * decide which operators are available given a context,
  * bind representations (DEC/FEM/Graph/etc.) and parameters,
  * return a uniform runtime artifact.

### 1.3 Operator artifact is a struct (value-like)

* No handle classes.
* No internal caching stored inside operator artifacts beyond simple keys.
* Caching of heavy computed matrices belongs in runtime (or existing manifold cache), not inside the operator artifact.

### 1.4 Backward compatibility

* Existing code expects `bct.runtime.operators(context)` to return a dictionary of function handles.
* After refactor, it should return a dictionary of Operator structs.
* To preserve some compatibility, introduce a **legacy adapter** mode or a helper that returns function handles, but the default should move to Operator structs.

---

## 2. High-Level Architecture

### 2.1 Components and responsibilities

#### A) `bct.registry.operators.*` (keep as-is, minimal changes)

* **Responsibilities**

  * Define operator specifications (OperatorSpec).
  * Validate that specs conform to the registry schema.
  * Provide listing and schema introspection.

* **What to keep**

  * `defs.m` remains the authoritative catalog.
  * `schema.m`, `validate.m`, `list.m` remain as registry utilities.

* **Allowed modifications**

  * Adjust schema/validation to ensure runtime needs are covered (e.g., ensure `parameters` always exists as a struct, ensure `function` is present and callable).
  * Do NOT change IDs or rename existing operators in this step.

#### B) `bct.runtime.operators.*` (core refactor)

* **Responsibilities**

  * Build a runtime dictionary of available operators.
  * For each operator spec:

    * check dependency availability,
    * check representation availability (DEC/FEM/Graph/etc.),
    * bind representation + any required parameters,
    * produce a runtime Operator struct artifact.

* **Key deliverable**

  * `bct.runtime.operators.dictionary(context)` returns: `dictionary(string -> OperatorStruct)`.

#### C) `bct.operators` (new user-friendly entrypoint)

* **Responsibilities**

  * Provide a stable public API around operators.
  * Avoid exposing `registry/runtime` internals to users.
  * Offer ergonomic ways to:

    * list operators,
    * get an operator,
    * apply an operator.

---

## 3. Operator Spec (Registry) vs Operator Artifact (Runtime)

### 3.1 Registry OperatorSpec (existing; keep structure)

The existing `OperatorSpec` fields include:

* `id`, `name`, `domain`, `representation`, `inputType`, `outputType`, `formDegree`,
  `parameters`, `requires`, `dependency`, `function`, `purity`, `description`

This stays.

### 3.2 Runtime Operator Artifact (new struct schema)

#### 3.2.1 Required fields

The runtime operator artifact is a struct with **at minimum**:

* `id` (string)
  Hierarchical operator ID (same as spec.id).

* `name` (string)
  Display name (same as spec.name).

* `meshId` (string)
  Identifier of the manifold (e.g., `context.Manifold.ID`). Empty allowed if not mesh-bound.

* `backend` (string)
  Describes the toolbox/backend used (e.g., `"DECLab"`, `"gptoolbox"`, `"gspbox"`, `"MATLAB"`).
  Derived from `spec.domain` and/or `spec.dependency`.

* `domain` (struct)
  Concrete runtime typing and sizing of input. Required fields:

  * `support` (string): `"vertex" | "face" | "edge" | "halfedge" | "coefficients" | ...`
  * `semanticType` (string): e.g., `"signal"`, `"0-form"`, `"1-form"`, `"vector-field"`
  * `sizeHint` (double array or []): e.g., `[N, T]` or `[N, 1]` or empty if variable
  * `formDegree` (double or []): copy from spec.formDegree if DEC

* `codomain` (struct)
  Same fields as `domain` but for output.

* `params` (struct)
  Fully resolved parameters for this operator instance (merge defaults + context overrides).

* `requires` (string array)
  Propagate from spec.

* `dependency` (struct)
  Propagate from spec (toolbox name/path/version metadata).

* `purity` (string)
  `"pure"` or `"impure"` from spec.

#### 3.2.2 Execution payload

* `applyFcn` (function_handle)
  Canonical execution signature:

  * `y = op.applyFcn(x, varargin{:})`
    Representation is already bound; caller passes only data + extra args.

Optional:

* `matrix` (sparse/double/single or [])
  If this operator naturally materializes as a linear operator matrix and it is cheap/appropriate to store.

* `isLinear` (logical)
  True if operator is linear in the mathematical sense (helps composition rules later).
  This can be set conservatively; default false unless explicitly known.

#### 3.2.3 Provenance and caching

* `provenance` (struct)

  * `bctVersion`
  * `createdAt`
  * `specId` (same as id)
  * `specHash` (hash of spec struct or stable signature string)
  * `contextSummary` (small struct: N, F, E, presence of DEC/FEM/Graph)
  * `dependencyVersions` if discoverable

* `cacheKey` (string)
  A stable key used by runtime caching (see section 6).

---

## 4. Public API: `bct.operators`

### 4.1 Goals

* Stable and user-friendly, minimal cognitive overhead.
* Must not expose registry/runtime internals.
* Must be callable with minimal inputs.

### 4.2 Functions to implement

#### A) `bct.operators(context)` (primary)

* Returns the runtime dictionary of Operator structs, i.e. delegates to runtime.
* Should accept:

  * `context` struct (preferred)
  * OR a `bct.Manifold` instance (convenience), in which case it calls `bct.runtime.context(M)` internally.

**Signature**

```matlab
function ops = bct.operators(input, options)
```

**Behavior**

* If `input` is a `bct.Manifold`: create context via `bct.runtime.context(input)`
* If `input` is a struct: treat as context directly
* Returns `dictionary(string -> OperatorStruct)`
* Optional Name-Value:

  * `'LegacyHandles'` (logical, default false): if true returns dictionary(id -> function_handle) for transitional compatibility.

#### B) `bct.operators.get(input, id, options)`

* Returns a single Operator struct.
* Errors if not found unless `options.AllowMissing=true`.

#### C) `bct.operators.list(input, options)`

* Returns a table/struct array listing available operator IDs and descriptions.
* Suitable for UI menus.

#### D) `bct.operators.apply(input, idOrOp, x, varargin)`

* Apply operator by ID or by Operator struct.
* Uniform checks (minimal) that domain type matches `x` when feasible.

---

## 5. Runtime Refactor: `bct.runtime.operators`

### 5.1 Current behavior

`bct.runtime.operators.dictionary(context)` returns bound function handles:

* `ops("gradient.dec") = @(x) ...`

### 5.2 New behavior

Return Operator structs:

* `ops("gradient.dec") = opStruct`

### 5.3 New required runtime functions

Create the following functions under:
`toolbox/+bct/+runtime/+operators/`

#### 5.3.1 `dictionary(context, options)` (refactor existing)

* Builds the dictionary of available ops.
* For each spec:

  * `isAvailable(spec, context)` decides if it can be instantiated.
  * `bind(spec, context)` returns Operator struct.

Options:

* `LegacyHandles` (default false): produce handles rather than Operator structs (adapter mode)

#### 5.3.2 `isAvailable(spec, context)`

Checks:

* Required external dependency exists (toolbox / class / function).
* Required representation is available or can be lazily created (DEC/FEM/Graph).
* Required capabilities in `spec.requires` are satisfied (if you use this field in runtime).

Implementation guidance:

* For `spec.representation`:

  * if `"DiscreteExteriorCalculus"`: ensure class exists and context has DEC or can create via `context.Manifold.DEC()` (or equivalent).
  * if FEM/Graph: check similarly.
* For `spec.dependency`: do not load anything; only check presence via `exist`, `which`, `ver`, etc.

Return:

* `tf` logical
* optionally `reason` string (useful for debugging/UI).

#### 5.3.3 `bind(spec, context)`

Construct Operator struct:

* Resolve bound representation object `rep`:

  * DEC: `rep = context.DEC` or `context.Manifold.DEC()`
  * FEM: `rep = context.FEM` or `context.Manifold.FEM()` (even if this is a struct)
  * Graph: `rep = context.Graph` or `context.Manifold.Graph()`
* Create `applyFcn` that matches the spec’s expected signature.

**Critical instruction:** do not change existing operator implementations. Bind them.

Binding pattern:

* If current operator `spec.function` expects `(rep, x, ...)` bind as:

  * `applyFcn = @(x,varargin) spec.function(rep, x, varargin{:});`
* If it expects `(context, x, ...)` bind accordingly.
* This must be consistent with your existing operator function signatures. The binding code must accommodate both patterns (detect by convention or spec flag).

Set:

* `op.params` by merging defaults + spec.parameters + any `context.OperatorOverrides` (if exists).
* Fill domain/codomain descriptors using resolver functions.

#### 5.3.4 `resolveDomain(spec, context)` and `resolveCodomain(spec, context)`

Purpose:

* Convert `inputType/outputType/formDegree` into concrete runtime descriptors.

Initial implementation can be conservative:

* Use semantic types from spec; fill support as:

  * `"vertex"` for `"signal"` / `"0-form"` unless otherwise specified
  * `"edge"` for `"1-form"` if DEC; `"face"` for face vector fields (FEM gradient)
  * `"coefficients"` if spectral
* Fill `sizeHint` using mesh counts:

  * `N = context.Manifold.numVertices()`
  * `F = context.Manifold.numFaces()`
  * `E = context.Manifold.numEdges()`

**Important:** do not attempt to fully type-check everything in v1. The goal is metadata and standardization.

#### 5.3.5 `provenance(spec, context)` and `cacheKey(spec, context)`

* Compute `cacheKey` deterministically from:

  * `spec.id`
  * `context.Manifold.ID` (or mesh hash if you have it)
  * relevant parameters that affect assembly (mass type, boundary handling, etc.)
  * backend version if known

The key should be stable and string-based.

---

## 6. Caching Strategy

### 6.1 Current caching

You already cache expensive computations in `bct.Manifold.Cache` and/or internal caches (FEM eigenpairs cache, etc.).

### 6.2 New rule

* Operator artifacts themselves do not cache heavy data.
* Runtime binding may attach `matrix` if it is already computed cheaply or already cached.
* If an operator needs expensive assembly (e.g., Laplacian), then:

  * assembly happens in existing functions (unchanged)
  * caching remains in Manifold cache or runtime cache keyed by `op.cacheKey`

### 6.3 Implementation guidance

* Add a runtime cache map in `context` (optional):

  * `context.Cache` map string -> any
* Or reuse `context.Manifold.Cache` with namespaced keys such as:

  * `"operator:" + cacheKey`

Do not implement a new caching system if your Manifold cache works; just namespace keys.

---

## 7. Refactoring Plan: What to Change vs Keep

### 7.1 Keep as-is

* `bct.registry.operators.defs()` content (operator list, IDs, descriptions, dependency metadata, function handles)
* `bct.registry.operators()` facade
* Existing operator implementation functions in:

  * `+bct/+fem`
  * `+bct/+manifold`
  * `+bct/+geometry`
  * `+bct/+graph`
  * `+bct/+runtime/+operators` existing operator implementations
* Existing external toolboxes and their usage

### 7.2 Modify

#### A) `bct.runtime.operators.dictionary(context)`

* Change return payload to dictionary of Operator structs.
* Add optional legacy mode to return function handles.

#### B) `bct.runtime.operators(context)` facade

* Update docstring and example:

  * `op = ops("gradient.dec"); y = op.applyFcn(x);`

#### C) UI/Call sites

* Any call sites that do:

  * `fn = ops(id); y = fn(x);`
    must be updated to:
  * `op = ops(id); y = op.applyFcn(x);`

If you enable `'LegacyHandles'=true` mode in `bct.operators`, you can defer UI migration; but the long-term goal is to migrate.

### 7.3 Add (new files)

Under `toolbox/+bct/+runtime/+operators/`:

* `bind.m`
* `isAvailable.m`
* `resolveDomain.m`
* `resolveCodomain.m`
* `provenance.m`
* `cacheKey.m`

Under `toolbox/+bct/`:

* `operators.m` (public entrypoint returning runtime dictionary)
  Under `toolbox/+bct/+operators/` (package for helpers, consistent naming):
* `get.m`
* `list.m`
* `apply.m`

Note: MATLAB package naming allows both `bct.operators` (function) and `+bct/+operators/` package.
To avoid name conflicts:

* Make `bct.operators` a *function* (entrypoint)
* Put helper functions under `+bct/+operators/` so they are called as:

  * `bct.operators.get(...)`
  * `bct.operators.list(...)`
  * `bct.operators.apply(...)`

This is consistent with MATLAB’s function/package resolution.

---

## 8. Detailed Behavior Specifications

### 8.1 `bct.operators` entrypoint behavior

```matlab
ops = bct.operators(M);      % where M is bct.Manifold
ops = bct.operators(ctx);    % where ctx is runtime context struct
```

* If input is `bct.Manifold`, call `ctx = bct.runtime.context(M)`
* Return `ops = bct.runtime.operators.dictionary(ctx)`
* If option `'LegacyHandles'` true:

  * return dictionary(id -> function_handle) by mapping `op.applyFcn`

### 8.2 `bct.operators.get`

* If `ops = bct.operators(input)` already computed, allow:

  * `bct.operators.get(ops, id)`
* Also allow:

  * `bct.operators.get(input, id)` where input is context or manifold

### 8.3 `bct.operators.apply`

* Accept either:

  * `id` (string) and internally resolve,
  * or `Operator` struct directly.
* Apply via `op.applyFcn(x, varargin{:})`.
* Implement minimal checks:

  * If `x` is numeric array and `op.domain.support` expects vertex scalar, check `size(x,1)==N` when feasible.

Do not over-engineer validation in v1; just catch obvious mismatches.

---

## 9. Migration and Compatibility Plan

### 9.1 Stepwise migration (recommended)

1. Implement runtime Operator structs and `bct.operators`.
2. Implement `LegacyHandles` option to preserve old execution style where needed.
3. Migrate internal code and UI incrementally:

   * change calls to use `.applyFcn`
4. Once migrated, remove `LegacyHandles` usage from internal code (keep option for external users if desired).

### 9.2 Deprecation messaging

* In docstrings, mark that:

  * `bct.runtime.operators(context)` returns Operator structs.
  * For legacy function handles, use `bct.operators(context, 'LegacyHandles', true)`.

Do not print warnings unless you have a warning infrastructure; keep changes quiet for now.

---

## 10. Testing Requirements (must implement)

### 10.1 Registry tests

* `bct.registry.operators.validate()` passes.
* `bct.registry.operators.list()` returns stable output.

### 10.2 Runtime tests

For a known mesh (e.g., fsaverage6 from your assets):

* `ops = bct.operators(M)` returns a dictionary.
* IDs from registry that should be available are present.
* For a small set of operators:

  * `gradient.dec`, `gradient.fem`, `laplacian.fem` (or whatever exists)
  * applying them produces numeric output with expected sizes.

### 10.3 Legacy adapter test

* `opsLegacy = bct.operators(M, 'LegacyHandles', true)`
* `opsLegacy(id)` is function_handle
* `opsLegacy(id)(x)` equals `ops(id).applyFcn(x)` for a test case

---

## 11. Notes on Signature Binding (important)

The binding function must not assume a single signature pattern. Operator implementations may currently follow different patterns. The binder must support at least:

* Pattern A: `y = f(rep, x, ...)`
* Pattern B: `y = f(ctx, x, ...)`
* Pattern C: `y = f(x, ...)` (rare; when no rep needed)

Implementation instruction:

* Add a field to OperatorSpec (registry) only if necessary, such as:

  * `signature = "rep_first" | "ctx_first" | "data_only"`
    If it already exists implicitly (e.g., by domain), the binder can infer it.
    Prefer inference to avoid editing registry content.

If inference is unreliable, add `spec.signature` with a default and update `schema/validate`.

---

## 12. Deliverables Summary (Checklist)

### Must create

* `toolbox/+bct/operators.m`
* `toolbox/+bct/+operators/get.m`
* `toolbox/+bct/+operators/list.m`
* `toolbox/+bct/+operators/apply.m`
* `toolbox/+bct/+runtime/+operators/bind.m`
* `toolbox/+bct/+runtime/+operators/isAvailable.m`
* `toolbox/+bct/+runtime/+operators/resolveDomain.m`
* `toolbox/+bct/+runtime/+operators/resolveCodomain.m`
* `toolbox/+bct/+runtime/+operators/provenance.m`
* `toolbox/+bct/+runtime/+operators/cacheKey.m`

### Must refactor

* `toolbox/+bct/+runtime/+operators/dictionary.m` (or wherever it lives)
* `toolbox/+bct/+runtime/operators.m` facade docstring and examples

### Must NOT change (in this step)

* Existing operator implementation logic in external toolboxes or your curated functions
* Operator IDs and their definitions in `defs.m` unless signature metadata is truly needed

---

## 13. Success Criteria

The change is successful when:

1. `bct.operators(M)` returns a dictionary mapping operator IDs to Operator structs.
2. Existing curated operators still execute and return identical numeric results as before.
3. Runtime filters operators based on available representations and dependencies exactly as before.
4. UI and internal code can be migrated by changing:

   * `fn = ops(id); y = fn(x);` to
   * `op = ops(id); y = op.applyFcn(x);`
5. Legacy function-handle behavior remains available via an option.

