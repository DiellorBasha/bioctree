# BCT DEC Representation — Design Contract (`bct.DEC` + `bct.dec.*`)

## 1. Purpose

This document defines the **authoritative design contract** for the Discrete Exterior Calculus (DEC) layer in the `bct` package.

The DEC layer in `bct` is built on top of an external, tested library:

- **DECLab**: `DiscreteExteriorCalculus(Faces, Vertices)`

`bct` must **not re-implement DEC mathematics**. Instead, `bct` provides:

1. A **thin representation wrapper**: `bct.DEC`
2. A set of **pure functional operators and adapters**: `bct.dec.*`

This separation ensures:
- correctness (DECLab is the single mathematical authority),
- clarity (DEC is a representation like FEM and Graph),
- modularity (operators remain pure functions),
- extensibility (multiple backends may be supported later).

This document is **normative**. Any DEC-related development must comply.

---

## 2. Scope and Non-Goals

### In scope
- A `bct.DEC` class that represents the **DEC discretization** of a `bct.Manifold`
- `bct.dec` namespace functions that:
  - access DECLab operators,
  - provide BCT-standard operator signatures,
  - optionally compute *compositions* of DECLab-provided primitives (when strictly necessary),
  - optionally compute eigenpairs via **`bct.eigenpairs`** (not in class, not in DEC backend)

### Out of scope (explicit non-goals)
- Implementing new DEC mathematics in `bct`
- Replacing DECLab operators with custom versions
- Embedding solver logic inside `bct.DEC`
- Storing or owning signals inside `bct.DEC`
- Mixing UI/runtime operator selection logic into DEC

---

## 3. Architectural Position in BCT

DEC is one of several representations of the same underlying manifold.

```

Manifold (geometry and topology)
│
├── FEM   (variational / Laplace–Beltrami via Mass+Stiffness)
├── Graph (combinatorial / navigation and shortest paths)
└── DEC   (exterior calculus / k-forms and Hodge stars)

````

### Key invariant
> **Manifold owns geometry. Representations own access to structure. Operators are pure functions.**

DEC must mirror FEM and Graph in architecture:
- `bct.DEC` is a representation wrapper
- `bct.dec.*` contains the operational API
- `bct.eigenpairs.*` contains all eigenproblem logic

---

## 4. Responsibilities

## 4.1 `bct.DEC` responsibilities (thin wrapper)

`bct.DEC` exists to:
1. Provide a **stable, BCT-owned semantic identity** for DEC representations
2. Hold a reference to the **DECLab backend object**
3. Provide **minimal accessors** to backend primitives (optional, but allowed)
4. Manage **lifecycle and caching** of the backend object in a uniform way

### `bct.DEC` MUST NOT:
- implement new DEC computations
- compute gradients, divergences, curls, Laplacians
- solve eigenproblems
- normalize eigenvectors
- define registry or runtime behavior
- store signals or mutable state tied to time series

In other words:
> `bct.DEC` is a *facade* and *identity wrapper*, not a computational engine.

---

## 4.2 `bct.dec.*` responsibilities (operators/adapters)

All DEC operations and any DEC-specific workflows must be implemented as **pure functions** under:

- `+bct/+dec/`

These functions may:
- call DECLab backend methods/properties
- apply operators to signals/k-forms
- form standard compositions (e.g., Laplacian from DEC components), **only when needed**
- delegate eigenpair computation to `bct.eigenpairs`

These functions must not:
- mutate the DEC backend
- rely on global runtime state
- embed UI behavior or selection logic

---

## 5. `bct.DEC` Class Contract

## 5.1 Identity

`bct.DEC` represents:
> The DEC discretization induced by a particular `bct.Manifold` (Faces, Vertices) using DECLab.

It is not a general DEC library. It is specifically:
- “DEC on this manifold, using this backend.”

---

## 5.2 Owned State (Minimal)

### Required properties

- `Manifold` (reference to parent `bct.Manifold`)
- `Backend` (the DECLab `DiscreteExteriorCalculus` instance)

Recommended contract:

```matlab
properties (SetAccess = private)
    Manifold   % bct.Manifold
    Backend    % DECLab DiscreteExteriorCalculus
end
````

### Optional metadata properties

* `BackendVersion` or `BackendInfo` (string/struct for diagnostics only)
* `CacheVersion` (if Manifold may change topology and DEC must be invalidated)

---

## 5.3 Construction & Lifecycle

### Creation

`bct.DEC` must be constructed from a `bct.Manifold`:

* `DEC = bct.DEC(M);`

Construction must:

* read `Faces` and `Vertices` from `Manifold`
* instantiate DECLab backend:

```matlab
Backend = DiscreteExteriorCalculus(Faces, Vertices);
```

### Ownership and caching location

The `bct.DEC` instance should normally be cached by `Manifold`:

* `M.DEC()` returns the cached representation if available
* otherwise constructs and stores it

This preserves symmetry with:

* `M.FEM()`
* `M.Graph()`

### Topology changes and invalidation

If `Manifold` geometry/topology is immutable after construction, no invalidation is needed.

If `Manifold` may change `Vertices/Faces/Edges` at runtime:

* `Manifold` must invalidate its DEC cache
* `bct.DEC` should not attempt to patch-update backend state

Preferred rule:

> If Faces or Vertices change, the DEC backend must be reconstructed.

---

## 5.4 Minimal API Surface

`bct.DEC` should remain small. Recommended methods:

* `backend()` or `getBackend()` (optional)
* lightweight accessors (optional) for common primitives if they improve readability:

  * `d0()`, `d1()` (exterior derivatives)
  * `star0()`, `star1()`, `star2()` (Hodge stars)

However, these accessors must remain strict pass-throughs; no new math.

---

## 6. `bct.dec` Package Contract

## 6.1 Namespace Structure

Recommended package layout:

```
+bct/+dec/
  ├─ d0.m
  ├─ d1.m
  ├─ star0.m
  ├─ star1.m
  ├─ star2.m
  ├─ gradient.m
  ├─ divergence.m
  ├─ curl.m
  ├─ laplacian0.m
  ├─ laplacian1.m
  ├─ eigensolve.m
  └─ validate.m
```

The “primitive” files (`d0`, `star0`, etc.) should typically be thin accessors to backend fields to standardize naming and reduce scattered backend property usage.

---

## 6.2 Primitive Accessors (Pass-throughs)

Example: `bct.dec.d0(DEC)`:

* returns the 0→1 incidence/exterior derivative operator from the backend

Similarly:

* `bct.dec.d1(DEC)` returns 1→2 incidence operator
* `bct.dec.star0(DEC)` returns 0-form Hodge star, etc.

These functions:

* standardize access
* improve testability
* allow backend swapping in the future

---

## 6.3 Core Operators (Applied to Data)

Operators such as `gradient`, `divergence`, `curl` belong to `bct.dec.*` and must:

* accept a `bct.DEC` object
* accept an input array (0-form, 1-form, etc.)
* return the output array
* remain pure and deterministic

Example contracts:

* `gradient(DEC, f0)` : 0-form → 1-form
* `divergence(DEC, a1)` : 1-form → 0-form (requires Hodge star)
* `curl(DEC, a1)` : 1-form → 2-form or scalar curl depending on convention

All such functions must use:

* `DEC.Backend` primitives

No new discretization formulas should be introduced unless they are explicit compositions of backend primitives (see next section).

---

## 6.4 Laplacians (Form-Degree Specific)

DEC supports multiple Laplacians depending on form degree:

* 0-form Laplacian (scalar functions)
* 1-form Laplacian (vector/flow fields)
* 2-form Laplacian (densities on faces)

If DECLab exposes these directly, `bct.dec.laplacian0` should return them.

If not exposed directly, `bct.dec.laplacian0` may build them as a **composition of backend primitives**, e.g.:

* using `d0`, `d0'`, Hodge stars, etc.

This is acceptable only if:

* it uses backend operators exclusively,
* it does not introduce alternative discretizations.

This preserves the “DECLab is authority” principle.

---

## 6.5 Spectral Solves (Eigenpairs)

DEC spectral computations must follow the global BCT rule:

> **All eigenproblem logic lives in `bct.eigenpairs.*`.**

Therefore:

* `bct.dec.eigensolve(DEC, formDegree, k)` is allowed
* It must:

  * construct or retrieve the DEC Laplacian for that form degree
  * select the correct inner product (Hodge star for that form degree)
  * delegate to `bct.eigenpairs.solveGeneralized(...)`

Example conceptual flow:

* `L = bct.dec.laplacian0(DEC)`
* `H = bct.dec.star0(DEC)`
* `E = bct.eigenpairs.solveGeneralized(L, H, k, meta)`

The DEC class itself must not do this.

---

## 7. Integration with `bct.Manifold`

## 7.1 Manifold should expose DEC as a representation factory

`Manifold` should expose:

* `M.DEC()` returning a `bct.DEC` object (cached)

The DEC backend object should not be stored as a raw DECLab object on `Manifold` (or if it is present historically, it should be migrated to a private cache). The public representation should be `bct.DEC`, not the backend.

Recommended pattern:

* `Manifold` caches `bct.DEC`
* `bct.DEC` owns `Backend`

This preserves:

* symmetry with FEM/Graph
* future backend swapping
* clean registry/runtime semantics

---

## 8. External Backend Policy (DECLab)

DECLab is the DEC authority. Therefore:

* `bct.DEC` must treat the backend as read-only
* `bct.dec.*` must not mutate backend internal state
* any additional DEC-related functionality must be expressed as:

  1. an operator applied to data, or
  2. a composition of backend operators,
     never a new discretization

If DECLab changes its API, the adaptation should occur in:

* `bct.dec` primitive accessors
  not in user-facing code.

---

## 9. Operator Registry and Runtime

### Registry

DEC operators must be declared in the operator registry (per your architecture):

* `bct.registry.operators()`

Each DEC operator spec should include:

* `domain = "dec"`
* `representation = "bct.DEC"`
* `inputType` / `outputType` (e.g., "0-form", "1-form")
* `formDegree` where applicable
* `requires` listing the backend primitives assumed (e.g., "d0", "star1")

### Runtime binding

`bct.runtime.operators(context)` should include DEC operators only if:

* `context.DEC` exists (or can be constructed)
* DEC is applicable to the manifold state

---

## 10. Testing and Validation Requirements

Minimum tests required for DEC operators:

1. **Shape tests**

   * operator outputs have correct dimensionality:

     * `d0`: (E×N) or (N×E) depending on convention
     * `gradient`: returns 1-form sized output

2. **Consistency tests**

   * `d1*d0 = 0` (boundary of boundary is zero), where applicable

3. **Adjointness tests**

   * validate Hodge-based adjoints for divergence/codifferentials when implemented

4. **Spectral tests**

   * smallest eigenvalue near zero for 0-form Laplacian (if expected)
   * orthonormality under Hodge star for eigenvectors when using generalized solve

All tests should focus on:

* correctness of wrapper access,
* correctness of operator usage,
  not re-deriving DEC theory.

---

## 11. Performance and Caching Policy

* The DECLab backend may be expensive to construct.
* Therefore, caching `bct.DEC` at the Manifold level is recommended.
* Operator functions in `bct.dec` should remain stateless.

If performance requires caching derived matrices (e.g., Laplacian0), prefer:

* caching inside `bct.DEC` as **private cached fields**, or
* caching in `bct.dec` via memoization helpers,
  but only if:
* it does not change semantics,
* it can be invalidated cleanly.

Primary rule:

> Prefer caching representations and derived operators, never signals or results tied to time.

---

## 12. Versioning and Serialization

`bct.DEC` itself should generally be treated as:

* reconstructible from `Manifold.Faces` and `Manifold.Vertices`

Therefore:

* serialization should store only enough information to recreate it
* the backend object itself should not be serialized unless required

Preferred approach:

* on load, reconstruct `bct.DEC` from `Manifold` state
* treat backend as derived

If you later adopt HDF5-backed storage, DEC should be reconstructible without storing the entire backend.

---

## 13. Summary of Rules (Pin These)

1. **DECLab is the sole DEC math authority.**
2. **`bct.DEC` is a thin wrapper and identity layer.**
3. **All DEC operations live in `bct.dec.*` functions.**
4. **No eigenproblem logic in DEC or bct.dec; it must delegate to `bct.eigenpairs`.**
5. **Manifold exposes DEC as a representation via `M.DEC()` (cached).**
6. **Operators are pure; execution is explicit; runtime/registry remain separate.**

Adhering to these rules ensures DEC remains robust, maintainable, and consistent with the rest of the BCT architecture.

```
```


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
