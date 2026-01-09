
---

# Design Document: `+bct/+geometry` Package (Code Duplication for Safe Migration)

## 0. Objective (Step 1 of migration)

Create a new package: `toolbox\+bct\+geometry\` that contains **copied implementations** of the currently curated and working geometry routines from `toolbox\+bct\+manifold\`.

This is a **duplication step**. The intent is to:

1. Create `bct.geometry.*` as the future canonical geometry namespace.
2. Validate it produces identical results to `bct.manifold.*`.
3. Keep existing dependencies working unchanged.
4. Only later, deprecate the geometric functions of `bct.manifold.*` after `bct.geometry.*` is proven stable.

### Non-negotiable rule

**Do not create thin wrappers.**
Every `bct.geometry.*` function must contain a **local copy** of the implementation logic from the existing `bct.manifold.*` version.

This ensures `bct.geometry` is self-contained and can replace `bct.manifold` later without an indirection layer.

---

## 1. Scope of `bct.geometry` (v1)

`bct.geometry` contains **embedding-dependent** geometry computations on a triangular surface mesh.

### In scope (v1)

* `centroids`
* `normals`
* `tangents`
* `frame` (if used by tangents or other geometry logic)

### Out of scope (v1)

* Topology-only functionality: `halfedge`, adjacency, edges, incidence operators, etc.
* Operator assembly: mass matrix, stiffness, cotan Laplacian, Hodge stars, gradient/divergence matrices.
* Spectrum and eigenpairs.
* Read/write/convert.

**Important:** even if `bct.manifold` contains geometry-adjacent functions like `cotan.m`, they are not part of this step.

---

## 2. Source-of-truth and replication requirements

### Authoritative source files

Copy the implementation logic from these files:

* `toolbox\+bct\+manifold\centroids.m`
* `toolbox\+bct\+manifold\normals.m`
* `toolbox\+bct\+manifold\tangents.m`
* `toolbox\+bct\+manifold\frame.m` (if referenced by tangents or required for frames)

### Replication rules

When copying each function:

1. **Copy the body verbatim** to preserve behavior.
2. Change only what is necessary to:

   * rename the function and file path to `bct.geometry.*`
   * update internal package references (e.g., if `bct.manifold.tangents` calls `bct.manifold.frame`, update it to call `bct.geometry.frame`).
3. Preserve:

   * default arguments and parsing behavior
   * output sizes and data types
   * numerical conventions (normal orientation, normalization tolerances, handling degenerates)
4. Do not “improve,” “simplify,” or “optimize” algorithms in this step. Stability and equivalence are the goal.

---

## 3. Input support contract (must not break callers)

Each `bct.geometry.*` function must support **the same calling patterns** as its source `bct.manifold.*` counterpart.

Additionally, to support future refactoring and broader use, each function must also accept raw mesh arrays (`V,F`) **if it can be added without altering the original semantics**.

### Input normalization helper

Add a private helper:

* `toolbox\+bct\+geometry\private\parseMeshInputs.m`

Behavior:

* Accept either:

  * `M` (bct.Manifold) as first argument, or
  * raw `V, F`.
* Return `[V,F]` in the same numeric form expected by the copied implementation.
* This helper must not change face ordering, orientation, or indexing.

**Important:** If the original `bct.manifold.*` implementation already expects `M`, preserve that path and only add `(V,F)` handling if it is clearly non-breaking (e.g., by constructing `M = bct.Manifold(V,F)` only if doing so does not change outputs and does not introduce side effects).

Because we are prioritizing equivalence, it is acceptable for v1 to support only the original input signature and add `(V,F)` later—provided tests cover the canonical use.

---

## 4. Function-level contracts (exact behavior parity)

### 4.1 `bct.geometry.centroids`

Create file: `toolbox\+bct\+geometry\centroids.m`

* Start from the exact content of `toolbox\+bct\+manifold\centroids.m`
* Replace package references as needed.
* Ensure outputs match exactly for the same input.

### 4.2 `bct.geometry.normals`

Create file: `toolbox\+bct\+geometry\normals.m`

* Copy from `toolbox\+bct\+manifold\normals.m`
* Preserve default “vertex vs face” behavior and naming.
* Update internal calls (if any) to use `bct.geometry.*` equivalents.

### 4.3 `bct.geometry.tangents`

Create file: `toolbox\+bct\+geometry\tangents.m`

* Copy from `toolbox\+bct\+manifold\tangents.m`
* Preserve:

  * name-value arguments (especially `Domain`)
  * frame handedness and orthonormalization
  * any reference axis logic
* Update internal calls to `frame` or `normals` to reference `bct.geometry.*`.

### 4.4 `bct.geometry.frame` (if applicable)

Create file: `toolbox\+bct\+geometry\frame.m`

* Copy from `toolbox\+bct\+manifold\frame.m`
* Update any internal package calls to point to `bct.geometry` where relevant.

---

## 5. Directory structure (deliverables)

Create:

```
toolbox\+bct\+geometry\
    centroids.m
    normals.m
    tangents.m
    frame.m                 (only if required/exists)
    README.md
    private\
        parseMeshInputs.m
```

### README.md requirements

* State that `bct.geometry` is a self-contained copy of curated geometry routines from `bct.manifold` created for safe migration.
* State this is step 1; deprecation will happen later.

---

## 6. Regression tests (must prove equivalence)

Add test file:

* `tests/test_geometry_migration_equivalence.m`

Test requirements:

1. Construct at least one representative mesh:

   * A small synthetic mesh (e.g., subdivided square into triangles), and
   * Optionally a sphere-like mesh if available in test assets.

2. For each function:

   * Compare outputs from `bct.manifold.*` vs `bct.geometry.*` for identical inputs.

Required comparisons:

* `bct.manifold.centroids(M)` equals `bct.geometry.centroids(M)`
* `bct.manifold.normals(M,'Vertex')` equals `bct.geometry.normals(M,'Vertex')`
* `bct.manifold.normals(M,'Face')` equals `bct.geometry.normals(M,'Face')`
* `bct.manifold.tangents(M,'Domain','face')` equals `bct.geometry.tangents(M,'Domain','face')`
* `bct.manifold.tangents(M,'Domain','vertex')` equals `bct.geometry.tangents(M,'Domain','vertex')`

Use strict comparison if possible; otherwise use tight numeric tolerances:

* `max(abs(a(:)-b(:))) < 1e-12` (or use `norm(a-b,'fro')` with `1e-12`)

3. If `frame` is public and produces outputs, compare it similarly.

**Pass criteria:** all tests pass with no differences beyond numeric tolerance.

---

## 7. Safety rules (avoid breaking the repo)

* Do not modify existing files in `toolbox\+bct\+manifold\` in this step.
* Do not modify `bct.Manifold`.
* Do not touch `bct.fem` or any operator assembly.
* Do not rename functions in existing namespaces.
* Only add the new package and tests.

---

## 8. Definition of done

This step is complete when:

* `toolbox\+bct\+geometry\` exists with copied implementations.
* `bct.geometry.*` results match `bct.manifold.*` on regression tests.
* No existing call sites are changed.
* The repo builds/runs with both namespaces present.

---

## 9. Implementation checklist (agent workflow)

1. Create folder `toolbox\+bct\+geometry\` and subfolder `private\`.
2. Copy `centroids.m`, `normals.m`, `tangents.m`, `frame.m` from `+bct\+manifold\` into `+bct\+geometry\`.
3. Edit each copied file:

   * update the function declaration to the new package path (MATLAB uses file location; ensure function name matches)
   * update internal calls from `bct.manifold.*` to `bct.geometry.*` where necessary.
4. Add `private\parseMeshInputs.m` only if needed to preserve/extend input patterns safely; otherwise do not change parsing logic.
5. Add regression tests verifying equivalence.
6. Run tests and ensure pass.

---
