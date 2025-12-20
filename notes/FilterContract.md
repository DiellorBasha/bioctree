# bct.filter — Design Contract (Authoritative)

## 1. Purpose

`bct.filter` implements the **application layer** that turns kernels into **operators acting on data**. It applies kernels to signals using representation machinery (eigenpairs, transforms, Laplacians, mass inner products), but it never owns signals, never stores UI state, and never defines kernels.

This contract commits to a single strategy:

> **Filters consume configured unary kernels `k(x)` (from `bct.kernel.bind`) and apply them via representation-specific spectral machinery, with `Eigenpairs` as the primary spectral interface.**

This unifies FEM/Graph/DEC spectral filtering behind the same core implementation and enables high-performance execution on large meshes.

---

## 2. Concepts and Definitions

### 2.1 Filter
A **filter** is an operator that maps an input signal `x` to an output signal `y`:

- Spectral filter (graph/manifold):
````

y = U * ( k(λ) .* (Uᵀ M x) )

```
where:
- `U` are eigenvectors
- `λ` are eigenvalues
- `M` is the inner product matrix (mass/Hodge/identity depending on representation)

### 2.2 Filter kernel
In `bct.filter`, a **kernel** is always a configured unary handle:

```

w = k(axis)

````

For spectral filtering:
- `axis` = eigenvalues vector `λ`

### 2.3 Eigenpairs as the spectral contract
`bct.filter` is built around the existence of a stable `bct.Eigenpairs` interface that provides:
- eigenvalues: `E.values`
- eigenvectors: `E.vectors` (U)
- inner product: `E.innerProduct` (M), if applicable
- projection/reconstruction methods (preferred)

This ensures FEM/Graph/DEC differences are captured upstream in how eigenpairs are computed, not in filter logic.

---

## 3. Package Boundaries and Ownership

### 3.1 What belongs in `bct.filter`
- Core filter application functions:
  - `applySpectral` (primary)
- Helper functions:
  - weight evaluation and normalization (`evalWeights`)
  - validation (`validateInputs`)
  - truncation management (`selectK`)
  - numerical safeguards (e.g., handling complex weights)
- Optional performance features:
  - caching evaluated weights tied to a specific axis vector and kernel spec (caller-provided memo keys)

### 3.2 What does NOT belong in `bct.filter`
- Kernel definitions (belong to `bct.kernel.dictionary`)
- Kernel semantics/schema (belong to `bct.registry.kernels`)
- Session availability gating (belongs to `bct.runtime`)
- UI concerns or interactive parameter selection
- Eigenproblem solving (belongs to `bct.eigenpairs`)
- Representation construction (belongs to `Manifold.FEM()`, `Manifold.Graph()`, `Manifold.DEC()`)

---

## 4. Primary API Contract

## 4.1 `bct.filter.applySpectral(E, x, k, opts)`
**Purpose**: Apply a spectral filter to signal(s) defined on the eigenvector domain.

### Inputs
- `E` : `bct.Eigenpairs` (or compatible struct meeting the same contract)
- `x` : input signal
  - size `[N×1]` for a single signal, or `[N×T]` for multiple signals
- `k` : configured unary kernel handle
  - `w = k(E.values)` returns weights of length `K` (or length `N` if full basis)
- `opts` : struct controlling truncation, normalization, and computation strategy

### Required behavior
1. Select truncation `K` (default: `E.K` if exists, else `numel(E.values)`).
2. Compute weights:
   ```matlab
   w = k(lambda(1:K));
````

3. Compute spectral coefficients `c` using the proper inner product:

   * If Eigenpairs provides `project(x,K)`, use it (preferred).
   * Else use:

     ```matlab
     c = U(:,1:K)' * (M * x)
     ```

     where `M` defaults to identity if not provided.
4. Apply weights:

   ```matlab
   c_f = w(:) .* c
   ```
5. Reconstruct:

   * If Eigenpairs provides `reconstruct(c_f,K)`, use it (preferred).
   * Else:

     ```matlab
     y = U(:,1:K) * c_f
     ```

### Output

* `y`: filtered signal of the same size as `x`.

### Performance requirements

* Must be vectorized for multi-signal input `[N×T]`.
* Must avoid forming dense `M` unless required:

  * if `M` is diagonal, apply as elementwise multiplication
  * if sparse, use sparse multiply `M*x` once
* Must avoid unnecessary allocation of `U(:,1:K)` copies (use indexing efficiently).

---

## 5. Options (`opts`) and Defaults

`opts` is a struct with the following canonical fields:

* `K` (int, optional): truncation rank
* `NormalizeWeights` (string): `"none" | "l1" | "l2" | "max"`

  * default `"none"`
* `AllowComplex` (logical): allow complex weights and outputs

  * default true (needed for Morlet/Gabor in complex form)
* `BatchSize` (int, optional): for very large `T`, allow block processing
* `CheckDimensions` (logical): default true in debug/testing; may be disabled in performance mode

No UI logic exists here; these are low-level numeric controls.

---

## 6. Integration with `bct.kernel`

`bct.filter` assumes kernels are already bound via:

```matlab
k = bct.kernel.bind(kernelId, params);
```

This separation is mandatory for clarity and correctness:

* `bct.kernel` enforces parameter validation and schema semantics.
* `bct.filter` focuses purely on operator application.

---

## 7. Integration with `Manifold` and Representations

### 7.1 How filters are used with Manifold

Manifold provides representations that provide eigenpairs:

```matlab
E = M.FEM().eigenpairs(K);
k = bct.kernel.bind("Heat", struct("tau", 0.05));
y = bct.filter.applySpectral(E, x, k);
```

### 7.2 Representation neutrality

`bct.filter` does not care whether `E` came from:

* FEM generalized eigenproblem with Mass matrix
* Graph Laplacian eigenproblem
* DEC k-form Laplacian with Hodge-star inner product

As long as `E` exposes the eigenpairs contract, filtering is identical.

---

## 8. Numerical Conventions and Correctness

### 8.1 Inner product correctness

The default projection for manifold/FEM eigenpairs is **mass-orthonormal**:

* `U' * M * U = I`

`bct.filter` must respect the inner product used when eigenpairs were normalized. Therefore:

* if `E.innerProduct` exists, it must be used
* if `E.project` exists, it must be used (it encodes the correct convention)

### 8.2 Weight length matching

* If `k(lambda)` returns length `K`, apply directly.
* If it returns length `N`, truncate to `K`.
* If mismatched, throw `bct:filter:KernelWeightSizeMismatch`.

### 8.3 Stable handling of DC / zero eigenvalues

Some operators have eigenvalue 0. Kernels must handle this; filters should not hack around it except to avoid divide-by-zero in optional normalizations.

---

## 9. High-Performance Design Principles

### 9.1 Prefer project/reconstruct methods

If `bct.Eigenpairs` offers:

* `project(x, K)`
* `reconstruct(c, K)`
  use them. This centralizes performance tricks (diagonal mass, sparse mass) and convention correctness in one place.

### 9.2 Minimize sparse multiplies

Compute `Mx = M*x` once per call, not per mode.

### 9.3 Support multi-signal batching

For large `[N×T]`, allow block processing via `opts.BatchSize`:

* avoids memory spikes
* improves cache locality
* enables streaming pipelines

### 9.4 Optional weight caching (caller-controlled)

Kernel evaluation `k(lambda)` is cheap, but in interactive UI it can be called repeatedly. `bct.filter` may support optional memoization controlled by an explicit key in `opts` (e.g., `opts.CacheKey`) supplied by the caller. The filter package itself does not maintain global caches.

---

## 10. Registry and Runtime Integration

### 10.1 `bct.registry.filters`

The filter package’s callable operators must be discoverable for UI and pipelines via `bct.registry.filters`, analogous to operators.

Each filter method spec should include:

* `Id` (e.g., `"spectral"`)
* `Function` handle (e.g., `@bct.filter.applySpectral`)
* `Requires` (e.g., `"Eigenpairs"`)
* `InputTypes` and `OutputTypes`
* performance notes (supports batching, complex)

### 10.2 `bct.runtime.filters(context)`

Runtime selects which filters are available given context:

* if eigenpairs exist / can be computed
* if required toolboxes exist (if any filter variant depends on them)

This keeps filtering discoverability consistent with your broader runtime/registry model.

---

## 11. Testing Requirements

Minimum tests:

1. **Correctness test**: identity kernel yields identity output:

   * `k(x)=1` → `y≈x` for normalized eigenpairs.
2. **Low-pass test**: heat kernel reduces high-frequency energy.
3. **Multi-signal test**: `[N×T]` input matches column-wise single-signal calls.
4. **Inner product test**:

   * verify that results match a reference implementation using `U' M x`.
5. **Complex kernel test**:

   * Morlet-style complex kernel works when `AllowComplex=true`.
6. **Mismatch error tests**:

   * incorrect kernel weight sizes raise appropriate errors.

---

## 12. Summary

`bct.filter` is the execution layer that:

* consumes **Eigenpairs** + **data** + a **bound kernel** `k(x)`
* applies the kernel efficiently and correctly under the proper inner product
* remains independent from Manifold and representation details
* integrates with registry/runtime for discoverability and UI pipelines

This design is minimal, mathematically correct, high-performance, and scales across FEM/Graph/DEC without duplicating logic.


