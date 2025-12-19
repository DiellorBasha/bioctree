````markdown
# BCT DEC Representation — Design Contract (`bct.DEC` + `bct.dec.*`)  
## Addendum: Registry, Runtime, and System Integrations

This addendum extends the DEC design contract with **explicit, normative integration requirements** for:

- `bct.registry`
- `bct.runtime`
- Operator ecosystem and UI binding
- Eigenpairs / spectral workflows
- Serialization and persistence expectations
- Cross-representation interoperability constraints

All requirements herein are **mandatory** unless explicitly labeled optional.

---

## 14. Integration with `bct.registry`

### 14.1 Registry purpose in DEC context

The DEC subsystem must participate in the global discovery and validation pipeline:

> `bct.registry` defines **what DEC operators exist**, what they require, and how they are invoked.

DEC must **not** have bespoke discovery pathways; it must be fully represented in the registry.

---

### 14.2 Registry entries required for all DEC operators

Every DEC operator implemented under `bct.dec.*` must have a corresponding entry in:

```matlab
spec = bct.registry.operators();
````

**No undocumented DEC operators are allowed**. If a function exists under `bct.dec.*` and is user-facing, it must be registered.

---

### 14.3 Required OperatorSpec fields (DEC-specific constraints)

DEC operators must conform to the `OperatorSpec` schema defined by the operator registry contract. For DEC operators, the following fields have additional constraints:

* `domain` must be `"dec"`
* `representation` must be `"bct.DEC"`
* `inputType` / `outputType` must use the DEC form taxonomy:

  * `"0-form"`, `"1-form"`, `"2-form"`
  * optionally `"k-form"` if parameterized
* `formDegree` must be:

  * `0`, `1`, or `2` for form-specific operators
  * `[]` only if operator is not form-degree specific
* `requires` must list DECLab primitives assumed, e.g.:

  * `"d0"`, `"d1"`, `"star0"`, `"star1"`, `"star2"`, `"laplacian0"`
* `function` must reference the `bct.dec.*` function handle directly

---

### 14.4 Recommended registry naming conventions

#### Operator IDs (stable)

* Use stable, lowercase IDs:

  * `"d0"`, `"d1"`, `"star0"`, `"gradient"`, `"divergence"`, `"curl"`, `"laplacian0"`, `"eigensolve"`

#### Operator names (human readable)

* Use short, clear names:

  * `"Exterior derivative (0→1)"`, `"Hodge star (1-form)"`, etc.

---

### 14.5 Required registry examples (minimum set)

At minimum, the following DEC entries must exist in `bct.registry.operators`:

* `d0`
* `d1`
* `star0`
* `star1`
* `star2`
* `gradient` (0→1)
* `divergence` (1→0) if defined
* `curl` (1→2 or scalar variant) if defined
* `laplacian0` (0-form Laplacian)
* `laplacian1` (1-form Laplacian) if supported
* `eigensolve` or `eigenpairs` wrapper (see Section 16)

If DEC form-degree Laplacians are available in DECLab, they must be registered explicitly (e.g., `"laplacian0"`, `"laplacian1"`), not via a generic `"laplacian"` entry.

---

## 15. Integration with `bct.runtime`

### 15.1 Runtime purpose in DEC context

Runtime adapts the registry to a session context:

> `bct.runtime` decides which DEC operators are applicable **given a specific manifold and representations**.

DEC must integrate cleanly into this dynamic binding system.

---

### 15.2 Required context support

`bct.runtime` must support the DEC representation via context fields such as:

```matlab
context.DEC = M.DEC();
```

If `context` is created via `bct.runtime.context(M)`, it must:

* construct and include `DEC` if available, or
* include a placeholder indicating DEC is not available (if DECLab missing)

---

### 15.3 Applicability rules for DEC operators

`bct.runtime.isApplicable(opSpec, context)` must confirm at minimum:

1. `context.DEC` exists and is valid
2. The DEC backend exists:

   * `isa(context.DEC.Backend, "DiscreteExteriorCalculus")`
3. Any required primitives exist on the backend (or via pass-through accessors):

   * e.g., if `requires` contains `"d0"`, confirm `bct.dec.d0(context.DEC)` returns a valid operator
4. Form degree constraints are satisfied:

   * `"inputType"="1-form"` requires a known edge-space dimension and conventions

If applicability fails, operator must not appear in runtime operator dictionary.

---

### 15.4 Runtime operator binding contract

The runtime binding entry point must include DEC operators:

```matlab
rtOps = bct.runtime.operators(context);
```

For DEC operators, runtime binding must produce function handles whose signature is consistent with BCT conventions:

* The bound function should not require the caller to pass the `DEC` object explicitly.
* The DEC object is captured by the runtime binding.

Example:

```matlab
f = rtOps("gradient");   % bound to context.DEC internally
a1 = f(f0);              % user supplies only the data
```

Internally, runtime binding wraps:

```matlab
@(varargin) bct.dec.gradient(context.DEC, varargin{:})
```

This ensures consistent UX without hiding execution semantics (the operator name and bound representation remain explicit by construction).

---

### 15.5 Runtime must not change DEC semantics

Runtime may:

* filter operators
* bind a DEC instance
* validate input argument counts and types

Runtime must not:

* change operator conventions
* insert hidden normalizations
* silently convert form degrees
* substitute alternative operators

---

## 16. Integration with `bct.eigenpairs` and Spectral Workflows

### 16.1 DEC spectral solves are allowed, but must be layered correctly

DEC-based eigenpairs must be supported without violating the global rule:

> All eigenproblem logic lives in `bct.eigenpairs.*`.

Therefore:

* `bct.dec.eigensolve(DEC, formDegree, k)` is allowed as a wrapper
* It must delegate to:

  * `bct.eigenpairs.solveGeneralized(...)`

---

### 16.2 Required metadata for DEC Eigenpairs

When `bct.dec.eigensolve` constructs an `Eigenpairs` object, it must populate metadata fields that preserve interpretability:

Recommended minimum:

* `meta.operator   = "DEC-Laplacian"`
* `meta.basis      = "DEC-<k>-form"`
* `meta.formDegree = <0|1|2>`
* `meta.manifoldID = DEC.Manifold.ID`
* `meta.backend    = "DECLab"`

---

### 16.3 Inner product selection rule

For DEC eigenpairs, the generalized eigenproblem inner product must be the appropriate Hodge star:

* 0-form eigenpairs: use `star0`
* 1-form eigenpairs: use `star1`
* 2-form eigenpairs: use `star2`

No alternative inner product is allowed unless explicitly documented and registered as a distinct operator.

---

### 16.4 Registry integration for spectral solves

If DEC spectral solves exist, registry must include entries such as:

* `dec_eigenpairs_0form`
* `dec_eigenpairs_1form`

or a single `"dec_eigenpairs"` with parameter schema including `formDegree`.

The operator spec must clearly encode:

* required form degree
* required `star<k>` and `laplacian<k>`

---

## 17. Integration with the Operator Ecosystem (Operators, Kernels, Brushes)

### 17.1 DEC operators as first-class operators

DEC operators must be usable as first-class operator endpoints in:

* kernel/filter binding pipelines
* brush composition pipelines
* UI operator selection via runtime binding

This implies:

* DEC operators must expose stable function signatures (see below)
* registry entries must be complete (types and requirements)

---

### 17.2 Required function signature conventions for DEC operators

All `bct.dec.*` operators must use the following convention:

```matlab
out = bct.dec.operatorName(DEC, in, varargin...)
```

Where:

* first argument is always the `bct.DEC` instance
* second argument is the primary input form/signal
* remaining arguments are explicit parameters

This is required to enable uniform runtime binding.

---

### 17.3 Type taxonomy integration

DEC form types must align with your global type taxonomy used by registry/runtime:

Recommended standardized strings:

* `"0-form"` : node-based scalar field
* `"1-form"` : edge-based oriented field / flow
* `"2-form"` : face-based density field

Optional specialized types (if needed later):

* `"primal-1-form"` / `"dual-1-form"`
* `"vector-field"` (only if tied to a clear mapping)

If you introduce specialized types, they must be documented in the operator registry contract and consistently used.

---

### 17.4 Interaction with brushes/filters

DEC operators must be composable in brush/filter pipelines via registry-based selection. For example:

* A brush might produce a 0-form mask
* Applying `gradient` yields a 1-form edge field
* Applying `divergence` returns a 0-form scalar divergence map

These compositional possibilities must be preserved by stable typing and registry specs.

---

## 18. Integration with `bct.Manifold` (Factory and Caching)

### 18.1 Required Manifold API symmetry

Manifold must expose DEC through a representation accessor consistent with FEM and Graph:

```matlab
D = M.DEC();  % returns bct.DEC instance
```

This accessor must:

* cache the `bct.DEC` instance
* lazily construct it when first called
* invalidate if Faces/Vertices change (if such mutation is allowed)

---

### 18.2 Backend availability and graceful degradation

If DECLab is not installed/available:

* `M.DEC()` must either:

  * throw a clear, namespaced error, or
  * return an empty handle and mark DEC unavailable for runtime binding

Recommended behavior for robust UX:

* allow `M.DEC()` to error with a clear message
* allow `bct.runtime.context(M)` to handle that gracefully and omit DEC from context

---

## 19. Integration with Persistence and Serialization

### 19.1 DEC should be reconstructible

Because DEC is derived from manifold geometry, the DEC backend should be treated as reconstructible:

* Do not serialize `DEC.Backend` by default
* Serialize enough manifold state to reconstruct DEC

If you later implement `bct` HDF5-backed persistence:

* store `Faces` and `Vertices` under the Manifold
* reconstruct DEC on load when needed

---

### 19.2 Registry/runtime are not persisted as state

* `bct.registry` is code-defined, not saved
* `bct.runtime` is session-defined, not saved

DEC objects loaded from persistence must be compatible with current registry/runtime without needing stored registry/runtime data.

---

## 20. Integration with Testing and Continuous Validation

DEC integration tests must cover registry/runtime compatibility:

### 20.1 Registry completeness tests

* every function in `bct.dec.*` intended as user-facing must have a registry entry
* every registry entry’s `function` must resolve to an existing function handle

### 20.2 Runtime binding tests

* build a context containing DEC
* build runtime operator dictionary
* confirm DEC operators appear and execute correctly on test data

### 20.3 Backend compatibility tests

* confirm `DiscreteExteriorCalculus` constructs successfully from Manifold Faces/Vertices
* confirm required primitives (`d0`, `star0`, etc.) exist as expected

---

## 21. Summary of Additional Integration Rules (Pin These)

1. **All `bct.dec.*` operators must be registered in `bct.registry.operators`.**
2. **Runtime must expose DEC operators via `bct.runtime.operators(context)` when DEC is available.**
3. **DEC operators must follow the standardized signature: `op(DEC, in, ...)`.**
4. **DEC eigenpairs must be computed only via `bct.eigenpairs.*`, with Hodge-star inner products.**
5. **DEC backend is reconstructible and should not be serialized as state by default.**
6. **Registry is static truth; runtime is dynamic binding; neither changes DEC semantics.**

These integration rules ensure DEC is a first-class representation in the BCT ecosystem while preserving DECLab as the mathematical authority.

```
```
