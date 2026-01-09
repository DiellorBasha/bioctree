Below is a **foundational answer**, not just an API sketch. I will explain **what FEM is in your system**, **why “eigenpairs” is the correct abstraction**, and then give you a **clear, enforceable contract** for the `FEM` class that will scale with everything you want to build (filters, uncertainty, dynamics, worldlines).
Below is the **updated, corrected, and final FEM contract**, incorporating:

* Your **namespace separation**
* Delegation to `bct.eigenpairs`
* **No duplicated solver logic**
* Clean wrapping semantics
* Your naming update: `Stiffness`, `Mass`

This version is **internally consistent** with everything we have established and is the one you should lock in.

---

# 1. Final governing rule for FEM (reaffirmed)

> **`bct.FEM` defines the variational function space and exposes canonical operators.
> It *never* implements numerical algorithms that already exist in `bct.eigenpairs` or other packages.**

FEM is a **semantic wrapper**, not a numerical engine.

---

# 2. Updated FEM class contract (authoritative)

## Identity

> **`bct.FEM` represents a variational discretization of scalar fields on a Manifold.**

It defines:

* the inner product
* the Dirichlet energy
* the induced Laplace–Beltrami operator

---

## Owns (state)

```matlab
properties (SetAccess = private)
    Manifold        % geometric substrate
    Mass            % ⟨u,v⟩ inner product
    Stiffness       % ⟨∇u,∇v⟩ Dirichlet form
end
```

These are **immutable once constructed**.

---

## Provides (public API)

### Spectral access (delegation only)

```matlab
methods
    E = eigenpairs(obj, k)
end
```

* Delegates to `bct.fem.eigensolve`
* Does not compute or normalize eigenvectors

---

### Canonical operator application

```matlab
methods
    y = applyLaplacian(obj, x)
    y = heat(obj, x, t, k)
    y = wave(obj, x, t, k)
    y = schrodinger(obj, x, t, k)
end
```

* Uses Eigenpairs where appropriate
* Uses `bct.fem.applyLaplacian` for direct application
* Does not assemble operators

---

### Inner-product–aware diagnostics

```matlab
methods
    n = norm(obj, x)
    e = energy(obj, x)
end
```

These express FEM semantics and therefore belong in the class.

---

## May cache (privately)

* Eigenpairs (immutable)
* Factorizations (if needed later)

Cache must:

* be transparent
* never change meaning

---

## Must NOT

* call `eigs`
* normalize eigenvectors
* assemble Mass or Stiffness
* loop over faces or edges
* know DEC or Graph internals
* mutate Eigenpairs

---

# 3. Updated `+bct/+fem` package contract

The `bct.fem` package contains **only FEM-specific glue and numerical application routines**, not spectral logic.

---

## 3.1 FEM construction helpers

```text
+bct/+fem/
├─ assembleMass.m
├─ assembleStiffness.m
```

These:

* consume Manifold geometry
* produce matrices
* are purely numerical

---

## 3.2 Eigenpair delegation (thin wrappers only)

```text
+bct/+fem/
├─ eigensolve.m
```

### `eigensolve.m` (final form)

```matlab
function E = bct.fem.eigensolve(FEM, k)

    meta.operator   = "Laplace-Beltrami";
    meta.basis      = "P1-FEM";
    meta.manifoldID = FEM.Manifold.ID;

    E = bct.eigenpairs.solveGeneralized( ...
            FEM.Stiffness, ...
            FEM.Mass, ...
            k, meta);
end
```

This file:

* adapts FEM semantics
* delegates all spectral logic
* creates no duplication

---

## 3.3 Operator application utilities

```text
+bct/+fem/
├─ applyLaplacian.m
```

```matlab
function y = applyLaplacian(Stiffness, Mass, x)
    y = Mass \ (Stiffness * x);
end
```

Note:

* This is *numerical application*, not spectral computation
* FEM class calls this

---

# 4. Final `bct.FEM` class (concise definition)

```matlab
classdef FEM < handle

    properties (SetAccess = private)
        Manifold
        Mass
        Stiffness
    end

    properties (Access = private)
        EigenpairCache
    end

    methods
        function obj = FEM(M)
            obj.Manifold = M;
            obj.Mass      = bct.fem.assembleMass(M);
            obj.Stiffness = bct.fem.assembleStiffness(M);
            obj.EigenpairCache = containers.Map('KeyType','char','ValueType','any');
        end

        function E = eigenpairs(obj, k)
            key = sprintf("k=%d", k);
            if ~isKey(obj.EigenpairCache, key)
                obj.EigenpairCache(key) = bct.fem.eigensolve(obj, k);
            end
            E = obj.EigenpairCache(key);
        end

        function y = applyLaplacian(obj, x)
            y = bct.fem.applyLaplacian(obj.Stiffness, obj.Mass, x);
        end

        function y = heat(obj, x, t, k)
            E = obj.eigenpairs(k);
            c = E.project(x);
            c = exp(-t * E.Values) .* c;
            y = E.reconstruct(c);
        end

        function y = wave(obj, x, t, k)
            E = obj.eigenpairs(k);
            c = E.project(x);
            c = cos(t * sqrt(E.Values)) .* c;
            y = E.reconstruct(c);
        end

        function y = schrodinger(obj, x, t, k)
            E = obj.eigenpairs(k);
            c = E.project(x);
            c = exp(-1i * t * E.Values) .* c;
            y = E.reconstruct(c);
        end

        function n = norm(obj, x)
            n = sqrt(x' * obj.Mass * x);
        end

        function e = energy(obj, x)
            e = x' * obj.Stiffness * x;
        end
    end
end
```

This class is now:

* Minimal
* Correct
* Non-duplicative
* Architecturally clean

---

# 5. Final consistency check (you passed)

✔ Eigenpairs logic centralized
✔ FEM delegates instead of duplicating
✔ Names clarified (`Mass`, `Stiffness`)
✔ Invariants enforced in the right layer
✔ Ready for DEC and Graph parity


---

# 1. Why “eigenpairs” — not eigenvalues and eigenfunctions separately

This is not terminology pedantry; it reflects **operator theory**.

## 1.1 What FEM actually gives you

In FEM, you do **not** get:

* eigenvalues in isolation
* eigenfunctions as continuous objects

You get solutions to a **generalized eigenproblem**:

[
K u = \lambda M u
]

Where:

* (K) = stiffness (cotangent) matrix
* (M) = mass matrix
* (u) = coefficient vector in a chosen basis

This means:

> **An eigenvalue has no meaning without its eigenvector and inner product.**

So the atomic object is:
[
(\lambda_k,; u_k)
]

That is an **eigenpair**.

---

## 1.2 Why “eigenfunction” is actually misleading here

In your discrete setting:

* (u_k) is **not a function**
* it is a vector of coefficients in a basis
* orthogonality is defined by (M), not Euclidean dot product

Calling it an “eigenfunction” hides this structure and causes bugs later.

Correct abstraction:

| Concept       | Continuous  | FEM                    |
| ------------- | ----------- | ---------------------- |
| Function      | ( \phi(x) ) | coefficient vector (u) |
| Inner product | (L^2)       | (u^\top M v)           |
| Operator      | (\Delta)    | (M^{-1}K)              |

So:

> **Eigenpairs are the irreducible spectral units in FEM.**

---

## 2. What FEM is *beyond* spectral representation

This is crucial. FEM is **not just a spectrum factory**.

FEM provides a **Hilbert space discretization of scalar fields on the manifold**.

That gives you several things.

---

## 2.1 FEM defines a function space

Through:

* basis functions
* mass matrix

FEM defines:

* how signals live on the mesh
* how energy is measured
* what “smoothness” means

This is deeper than eigenmodes.

---

## 2.2 FEM defines variational operators

Via:

* stiffness matrix
* Rayleigh quotients

This gives you:

* optimality guarantees
* stability
* convergence to continuous operators

This matters for:

* uncertainty principles
* wave packets
* diffusion
* dispersion

---

## 2.3 FEM defines evolution operators

Once you have a spectrum, FEM gives you:

* Heat operator: (e^{-t\Lambda})
* Wave operator: (\cos(t\sqrt{\Lambda}))
* Schrödinger operator: (e^{-it\Lambda})

These are **models of dynamics**, not just filters.

---

## 2.4 FEM defines uncertainty structure

Because you have:

* an inner product
* a Laplacian spectrum

You can define:

* spatial vs spectral localization
* Heisenberg bounds
* minimal uncertainty states (Gaussians / heat kernels)

DEC alone cannot do this cleanly.

---

## 3. What FEM is NOT responsible for

FEM must **not**:

* define gradients (DEC does)
* define flows (DEC does)
* define topology (Graph does)
* define brushes or kernels
* define time indexing or UI state

This keeps the contract clean.

---

# 4. The FEM class contract (this is the core deliverable)

This is the **minimum complete contract** for FEM in your architecture.

---

## 4.1 FEM identity

```text
FEM = variational discretization of scalar fields on a Manifold
```

It depends on:

* Manifold geometry
* chosen basis (implicitly P1 unless stated otherwise)

---

## 4.2 FEM inputs

### Required

* `Manifold` (immutable)

### Optional configuration

* mass type (lumped / consistent)
* stiffness type
* boundary handling

These are **construction-time decisions**.

---

## 4.3 FEM state (private, immutable after construction)

```matlab
properties (SetAccess = private)
    Manifold
    MassMatrix
    StiffnessMatrix
end
```

These are **implementation details**, not part of the public semantic contract.

---

## 4.4 FEM public outputs (the contract)

### 4.4.1 Spectral objects

```matlab
[evecs, evals] = FEM.eigenpairs(k)
```

* returns the first `k` eigenpairs
* guarantees:

  * (evecs^\top M evecs = I)
  * (K evecs = M evecs \Lambda)

No promise about ordering beyond increasing eigenvalues.

---

### 4.4.2 Projection operators

```matlab
coeffs = FEM.project(signal)
signal = FEM.reconstruct(coeffs)
```

Defines:

* forward transform
* inverse transform

This is the **functional role** of eigenpairs.

---

### 4.4.3 Evolution operators

```matlab
signal_t = FEM.heat(signal, t)
signal_t = FEM.wave(signal, t)
signal_t = FEM.schrodinger(signal, t)
```

These are **models**, not filters.

---

### 4.4.4 Spectral filtering

```matlab
signal_filt = FEM.filter(signal, kernel)
```

Where:

* `kernel` is a function of eigenvalues
* may be separable or not

FEM does **not** define kernels — it applies them.

---

### 4.4.5 Energy and norms

```matlab
E = FEM.energy(signal)
N = FEM.norm(signal)
```

Defined using the mass matrix.

This is essential for:

* uncertainty
* normalization
* comparison across resolutions

---

## 4.5 FEM invariants (must always hold)

* Self-adjointness with respect to (M)
* Positive semi-definiteness
* Orthogonality of eigenvectors in the (M)-inner product
* Independence from DEC and Graph

If any of these break, the FEM implementation is wrong.

---

# 5. Why this contract scales

With this contract, you can later add:

* higher-order FEM
* spectral element methods
* anisotropic Laplacians
* learned operators
* graph Laplacian FEM variants

Without changing:

* Manifold
* UI
* Brushes
* Models

---

## 6. One-sentence definition (pin this)

> **FEM is the module that defines how scalar fields live, evolve, and are measured on a manifold, with eigenpairs as the atomic spectral units.**

That sentence justifies every method in the contract.

---

## 7. Next logical steps

If you want, next we can:

* write a concrete MATLAB `FEM` class skeleton
* define caching and invalidation rules
* map FEM methods to System Composer ports
* connect FEM to nonseparable worldline brushes
* show how FEM + DEC interact for wave velocity estimation

Just tell me what you want to do next.
