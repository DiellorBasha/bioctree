
# 1. The governing rule 

> **The `Eigenpairs` class owns *meaning and invariants*.
> The `bct.eigenpairs` package owns *algorithms and workflows*.**

This single rule answers all sub-questions.

---

# 2. What belongs in `bct.Eigenpairs` (the class itself)

The class should be:

* **Small**
* **Immutable**
* **Invariant-enforcing**
* **Semantically explicit**

### 2.1 Things that *must* live in the class

These are **non-negotiable**.

#### (a) Stored data (state)

* Eigenvalues
* Eigenvectors
* Inner product (MassMatrix / Hodge star)
* Metadata (operator, basis, manifold ID)

#### (b) Invariant enforcement

* Orthonormality under inner product
* Dimension consistency
* Ordering guarantees

#### (c) Identity-preserving operations

These operate *within* the same spectral space and do **not** change the meaning of the object.

Examples:

* `project(signal)`
* `reconstruct(coeffs)`
* `subselect(k)`
* `truncate(k)`
* `energy(coeffs)`
* `bandlimit([λmin λmax])`

These are *pure*, closed-form, and safe.

#### (d) Introspection / metadata

* `numModes`
* `domainSize`
* `operatorType`
* `basisType`

---

### 2.2 What must *not* live in the class

The class must **not**:

* compute eigenpairs from operators
* know about FEM, DEC, or Graph
* solve eigenproblems
* cache results
* evolve signals in time
* implement heat / wave / Schrödinger
* update itself in-place

In other words:

> **Eigenpairs must never call `eigs`.**

That is a hard rule.

---

# 3. What belongs in `+bct/+eigenpairs` (the package)

The package should contain **everything that *produces*, *derives*, or *transforms* Eigenpairs**, but does not define their identity.

Think of it as a **factory + algorithm library**.

---

## 3.1 Lifecycle functions (yes, here)

You asked specifically:

> *Should `bct.eigenpairs` contain the full lifecycle of Eigenpairs, including construction, updating, etc.?*

**Answer:**

* ✔ **Construction:** YES
* ✔ **Derivation:** YES
* ✔ **Validation utilities:** YES
* ✖ **Mutation / updating:** NO (Eigenpairs are immutable)

### Examples that belong in `bct.eigenpairs`

```text
+bct/+eigenpairs/
├─ fromFEM.m
├─ fromDEC.m
├─ fromGraph.m
├─ solveGeneralized.m
├─ normalize.m
├─ validate.m
├─ reorder.m
├─ merge.m
├─ align.m
├─ compare.m
└─ serialize.m
```

These functions:

* **return new Eigenpairs**
* never mutate existing ones
* are allowed to call solvers
* are allowed to know about FEM/DEC/Graph

---

## 3.2 Example: construction via factory function

```matlab
function E = bct.eigenpairs.fromFEM(FEM, k)

    [K, M] = FEM.variationalForms();
    [U, D] = eigs(K, M, k, 'smallestabs');

    lambda = diag(D);
    U = bct.eigenpairs.normalize(U, M);

    meta.operator   = "Laplace-Beltrami";
    meta.basis      = "P1-FEM";
    meta.manifoldID = FEM.Manifold.ID;

    E = bct.Eigenpairs(lambda, U, M, meta);
end
```

Notice:

* All solver logic lives **outside** the class
* The class constructor only validates

---

## 3.3 Example: derivation / transformation

```matlab
function E2 = bct.eigenpairs.truncate(E1, k)
    E2 = bct.Eigenpairs( ...
        E1.Values(1:k), ...
        E1.Vectors(:,1:k), ...
        E1.MassMatrix, ...
        E1.meta());
end
```

This preserves immutability and meaning.

---

# 4. How FEM / DEC / Graph should use this

Your representations should be **clients** of the factory.

### FEM

```matlab
function E = eigenpairs(obj, k)
    E = bct.eigenpairs.fromFEM(obj, k);
end
```

### DEC

```matlab
function E = eigenpairs(obj, form, k)
    E = bct.eigenpairs.fromDEC(obj, form, k);
end
```

### Graph

```matlab
function E = eigenpairs(obj, k)
    E = bct.eigenpairs.fromGraph(obj, k);
end
```

This keeps representation classes lean and focused.

---

# 5. What about “updating” Eigenpairs?

Eigenpairs should **never be updated**.

If something changes:

* mesh resolution
* operator definition
* number of modes
* inner product

Then you create **a new Eigenpairs object**.

That’s why:

> **Eigenpairs are values, not stateful objects.**

If you want caching:

* cache *outside* the object (e.g., FEM, DEC)

---

# 6. Why this split is the right one

### You get:

* Strong invariants
* Clear ownership
* Easy testing
* Easy replacement of solvers
* Compatibility across representations

### You avoid:

* God classes
* Circular dependencies
* Hidden solver calls
* Accidental mutation
* Hard-to-debug spectral bugs

