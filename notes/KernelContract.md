
# bct.kernel — Design Contract (Authoritative)

## 1. Purpose

`bct.kernel` defines the **kernel layer** of the BCT toolbox: a curated, discoverable library of **pure analytic function handles** that can be used to design filters, brushes, windows, and other operator weightings over arbitrary axes (λ, time, frequency, distance, index).

The kernel layer is intentionally **mathematics-first** and **representation-agnostic**:

- No knowledge of `Manifold`, `FEM`, `Graph`, `DEC`, Eigenpairs, or signal transforms
- No implicit axis binding (λ/time/frequency) in the raw library
- No operator application (that is `bct.filter`)
- No UI concerns (those belong to `bct.runtime` and higher-level UI modules)

This contract commits to a single strategy:

> **Kernels are stored as raw parametric anonymous function handles in a dictionary (library).  
> `bct.registry.kernels` describes semantics (parameters, tags, dependencies).  
> `bct.kernel.bind` produces a configured unary kernel handle for use by `bct.filter`.**

This yields:
- a fast lookup library of math primitives,
- a single authoritative semantic layer (registry),
- a consistent high-performance interface for filter application.

---

## 2. Concepts and Definitions

### 2.1 Raw kernel function (library function)
A **raw kernel function** is an anonymous function handle with signature:

```

w = f(x, p1, p2, ...)

````

where:
- `x` is the evaluation axis (vector or array)
- `p1, p2, ...` are kernel parameters (scalars/vectors as defined)

Example:
```matlab
f = @(x, mu, sigma) exp(-(x-mu).^2/(2*sigma.^2));
w = f(lambda, 0, 0.2);
````

Raw kernels are **stateless and pure** (deterministic given inputs).

### 2.2 Bound kernel (configured unary kernel)

A **bound kernel** is produced by `bct.kernel.bind` and has signature:

```
w = k(x)
```

It is equivalent to partially applying parameters to a raw kernel:

```matlab
k = @(x) f(x, mu, sigma);
```

Bound kernels are what filters consume.

### 2.3 Kernel specification (KernelSpec)

A **KernelSpec** is a pure metadata structure returned by `bct.registry.kernels` (and optionally by `bct.kernel.get`). It defines:

* identity (Id/Name)
* parameter schema and defaults
* category and tags
* dependency requirements
* intended use domains (axis kinds)
* calling convention / argument order

KernelSpec is **not executable** by itself; it describes how to bind and validate a raw kernel.

---

## 3. Package Boundaries and Ownership

### 3.1 What belongs in `bct.kernel`

`bct.kernel` owns:

1. **Kernel math library**: `bct.kernel.dictionary()`
2. **Kernel lookup**: `bct.kernel.get(id)`
3. **Kernel binding**: `bct.kernel.bind(id, params)`
4. **Kernel listing**: `bct.kernel.list(...)`
5. **Kernel validation (lightweight)**: `bct.kernel.validate(...)`

### 3.2 What does NOT belong in `bct.kernel`

* Semantic catalog definitions (those belong to `bct.registry.kernels`)
* Dependency gating and session-aware filtering (those belong to `bct.runtime.kernels`)
* Any filtering/operator application (those belong to `bct.filter`)
* Any representation-specific logic (FEM/Graph/DEC)
* Signal ownership, caching of results tied to signals, or UI state

### 3.3 Registry and runtime integration points

* `bct.registry.kernels()` is the **authoritative semantic catalog**
* `bct.runtime.kernels(context)` is the **availability and session view**:

  * removes kernels whose dependencies are not satisfied
  * provides UI-ready lists / schema for parameter editors

`bct.kernel` is the stable façade used by developers and internal code, but it never becomes a registry-of-truth.

---

## 4. Functional API Contract

### 4.1 `bct.kernel.dictionary()`

**Returns**: a MATLAB `dictionary` mapping **KernelId (string)** → **raw function handle**.

**Hard requirements**:

* Must be **pure**: returning the same functions on every call.
* Must not recurse due to name shadowing. If the function name is `dictionary.m`, it must instantiate the built-in dictionary via:

  ```matlab
  D = builtin("dictionary");
  ```

  (or the file must be renamed to avoid collision).

**Kernel library rules**:

* All entries must be deterministic unless explicitly categorized as stochastic in the registry.
* No implicit axis binding: the first input is always the evaluation axis `x`.
* Handles must be vectorized and accept numeric arrays.

**Example**:

```matlab
D = bct.kernel.dictionary();
f = D("Gaussian");
w = f(x, 0, 0.2);
```

### 4.2 `bct.kernel.get(id)`

**Returns**:

* `f`: raw function handle from the dictionary
* `spec`: KernelSpec from `bct.registry.kernels` (matched by Id)

**Contract**:

* `id` must match a key in the dictionary and a record in the registry.
* If either is missing, throw a namespaced error:

  * `bct:kernel:UnknownKernel`
  * `bct:kernel:MissingRegistryEntry`

### 4.3 `bct.kernel.bind(id, params)`

**Returns**:

* `k`: bound unary kernel handle `k(x)`
* `spec`: the KernelSpec (optional second output)

**Contract**:

* Must validate `params` against `spec.ParamSchema`.
* Must apply defaults from `spec.Defaults` (or `spec.Params`) for missing fields.
* Must map `params` into the raw handle’s positional argument order based on `spec.Signature`.

**Canonical parameter passing**:

* `params` is a scalar struct with named fields:

  ```matlab
  params = struct("mu", 0, "sigma", 0.2);
  k = bct.kernel.bind("Gaussian", params);
  ```
* Named struct is mandatory for internal use; positional args are not supported at the `bind` level (positional args are ambiguous and UI-hostile).

**Performance requirements**:

* Binding must be O(1) aside from validation.
* The produced unary handle must be vectorized and must not allocate unnecessary temporaries.

### 4.4 `bct.kernel.list(...)`

**Returns**:

* Names/Ids of kernels available, optionally filtered by category/tags/domain using the registry.

**Contract**:

* Listing uses the registry as the semantic source and may cross-check dictionary presence.

### 4.5 `bct.kernel.validate(id, params)`

**Returns**:

* normalized params (merged with defaults) and/or throws on invalid fields/types/ranges.

---

## 5. Kernel Registry Semantics (via `bct.registry.kernels`)

`bct.registry.kernels` must provide, at minimum, the following fields per kernel:

* `Id` (string): stable key used in dictionary
* `Name` (string): UI label
* `Category` (enum/string): `"kernel" | "pointwise" | "stochastic" | "phase" | "utility"`
* `AxisKinds` (string array): `"lambda" | "time" | "frequency" | "distance" | "index" | "generic"`
* `Signature` (string array): ordered parameter names matching raw handle signature after `x`

  * Example: `["mu","sigma"]`
* `Defaults` (struct): default parameter values
* `ParamSchema` (struct): validation rules for each parameter
* `Tags` (string array): e.g., `["smooth","lowpass","oscillatory","compactSupport"]`
* `Dependencies` (string array): toolboxes/functions required (e.g., `"signal_toolbox"`, `"pinknoise"`)
* `Description` (string): short scientific description

### 5.1 Category rule (critical)

Even if the physical dictionary contains mixed entries, the **Category** in the registry is authoritative.

Filters and other systems must only accept kernels where:

* `Category == "kernel"` (and optionally `"window"` if you introduce it explicitly)

Pointwise nonlinearities and stochastic generators are not used as spectral kernels unless explicitly designed as such and documented.

---

## 6. Error Handling and Diagnostics

All errors must be namespaced and diagnostic:

* Unknown kernel Id:

  * `bct:kernel:UnknownKernel`
* Missing registry entry:

  * `bct:kernel:MissingRegistryEntry`
* Parameter missing/invalid:

  * `bct:kernel:InvalidParam`
* Dependency missing (only checked when runtime is involved):

  * `bct:kernel:DependencyMissing`

---

## 7. High-Performance Design Principles

### 7.1 Vectorization and numeric safety

* Kernels must accept vector axes and return vector weights.
* Avoid repeated `numel`-dependent branching inside kernel handles.
* Use `eps` only where necessary; avoid silent clipping unless specified.

### 7.2 No hidden caching in kernel layer

`bct.kernel` does not cache evaluations (evaluations depend on axis and parameters).
Caching of evaluated weights, when beneficial, belongs in `bct.filter` or caller-level memoization tied to a specific axis.

### 7.3 Determinism and reproducibility

Stochastic entries (noise) must be categorized and must not be silently used in deterministic pipelines. If needed, seeding must be explicit at higher layers.

---

## 8. Testing Requirements

Minimum unit tests:

1. Dictionary constructs without recursion and contains expected keys.
2. For every registry entry with `Category="kernel"`, `dictionary` contains the key.
3. `bind`:

   * merges defaults correctly
   * enforces ParamSchema correctly
   * produces unary handle and returns correct outputs for known inputs
4. Category enforcement tests (e.g., prevent binding pointwise ops as kernels if disallowed).

---

## 9. Summary

The kernel layer is a **mathematical library + binder**:

* `dictionary()` defines *what math exists*
* `bct.registry.kernels()` defines *how it is used*
* `bind()` produces the single standardized object that filters consume: a unary kernel handle `k(x)`

This design is minimal, fast, stable, and scales cleanly to UI-driven workflows and large operator catalogs.
