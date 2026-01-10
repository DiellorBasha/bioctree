

# Design Document: `+bct/+topology` Package (Code Duplication for Safe Migration)

## 0. Objective (Step 1 of migration for topology)

Create a new package: `toolbox\+bct\+topology\` that contains **copied implementations** of currently working topology/navigation routines.

This is a **duplication step**. The intent is to:

1. Make `bct.topology.*` the future canonical namespace for mesh topology/combinatorics.
2. Validate it matches the current behavior in `bct.manifold.*` and `bct.Manifold` methods.
3. Keep existing dependencies working unchanged.
4. Later deprecate/remove `bct.manifold.*` topology functions after `bct.topology.*` is stable.

### Non-negotiable rule

**Do not create thin wrappers.**
Every `bct.topology.*` function must contain a **local copy** of the implementation logic from the existing functions/methods it is replacing.

This package must be self-contained so `bct.manifold.*` can be deprecated later without leaving dependencies behind.

---

## 1. Scope of `bct.topology` (v1)

`bct.topology` contains **mesh connectivity / combinatorics** for triangular surface meshes.

### In scope (v1)

* Edge extraction from faces
* Binary adjacency from faces/edges
* Halfedge structure construction and boundary flags
* Neighborhood queries based on topology (the current `in/out` functions if they exist)
* Boundary loop extraction (if halfedge already supports this easily)

### Out of scope (v1)

* Anything requiring vertex positions `V` (lengths, areas, normals, tangents, curvature)
* Metric-dependent operators (mass matrix, stiffness, Laplacian, Hodge stars)
* DEC numerical workflows (Helmholtz decomposition, k-form Laplacians)
* Spectral computations, eigenpairs
* I/O (read/write) and conversion utilities

---

## 2. Authoritative source-of-truth mapping (must follow)

### Existing curated/working topology sources in your repo

Based on your tree:

* `toolbox\+bct\+manifold\halfedge.m`  ✅ authoritative for halfedge data structure
* `toolbox\+bct\+manifold\in.m`        ✅ authoritative for “in” neighborhood query
* `toolbox\+bct\+manifold\out.m`       ✅ authoritative for “out” neighborhood query

Additionally, two key topology behaviors exist in `bct.Manifold` class methods (not separate files), and must be duplicated exactly:

* `Manifold.computeEdges()` (private method) → edge list extraction logic
* `Manifold.adjacency()` (public method) → adjacency matrix logic

### Required v1 function mapping

| New function (target)    | Source (authoritative behavior) | Copy rule                                                       |
| ------------------------ | ------------------------------- | --------------------------------------------------------------- |
| `bct.topology.halfedge`  | `bct.manifold.halfedge`         | Copy implementation verbatim; update internal references if any |
| `bct.topology.in`        | `bct.manifold.in`               | Copy implementation verbatim                                    |
| `bct.topology.out`       | `bct.manifold.out`              | Copy implementation verbatim                                    |
| `bct.topology.edges`     | `bct.Manifold.computeEdges`     | Copy the edge extraction logic verbatim (from method body)      |
| `bct.topology.adjacency` | `bct.Manifold.adjacency`        | Copy adjacency logic verbatim (from method body)                |

If `bct.manifold.halfedge` already outputs `E` and boundary flags, preserve field names and semantics.

---

## 3. Package contract: what `bct.topology` is

### Definition

`bct.topology` provides **coordinate-free** connectivity primitives for a simplicial complex representing a triangulated surface.

It must be:

* **Pure** (no persistent state, no caching)
* **Deterministic** (given identical `F`, returns identical results)
* **Geometry-free** (must not depend on `V`)

### Acceptable inputs

Each function must accept:

* `M` (a `bct.Manifold`) **or**
* raw face connectivity `F` (and optionally `nV`)

However, to preserve existing behavior, input expansion must be conservative:

* If the source function expects `M`, keep that calling convention.
* If adding `(F,nV)` can be done without changing semantics, add it; otherwise leave it for later.

---

## 4. Input normalization helper (private)

Create:

* `toolbox\+bct\+topology\private\parseTopoInputs.m`

Contract:

* Accept either `(M)` or `(F)` or `(F,nV)` depending on caller.
* Return:

  * `F` as `double` or `int32` consistent with existing code,
  * `nV` if available (from `size(M.Vertices,1)` or passed in).
* This helper must not reorder faces or change orientation.

Also add:

* `toolbox\+bct\+topology\private\validateFaces.m` (optional, v1)

  * Minimal shape check: `size(F,2)==3`, indices are positive integers.

---

## 5. Public API and function-level contracts (v1)

### 5.1 `bct.topology.edges`

**Purpose**: Extract unique undirected edges from triangular faces.

**File**: `toolbox\+bct\+topology\edges.m`

**Source to copy**: logic from `bct.Manifold.computeEdges()` method body.

**Behavior requirements**:

* Must reproduce exactly the same edges that `Manifold` would compute.
* Must preserve the same sorting/uniqueness rules:

  * extract `[i j]` from each face’s three edges
  * sort each edge row so `(i,j)` and `(j,i)` match
  * `unique(...,'rows')`

**Signatures** (recommended):

* `E = bct.topology.edges(M)`
* `E = bct.topology.edges(F)`

**Outputs**:

* `E [nE×2]`, numeric type should match what Manifold currently returns (likely `double` or `int32`).

---

### 5.2 `bct.topology.adjacency`

**Purpose**: Compute binary adjacency matrix from faces.

**File**: `toolbox\+bct\+topology\adjacency.m`

**Source to copy**: logic from `bct.Manifold.adjacency()`.

**Behavior requirements**:

* Same output as `M.adjacency()`:

  * symmetric
  * no self-loops
  * binary (logical or sparse 0/1 consistent with current method)
* Must not require `V`.

**Signatures** (recommended):

* `A = bct.topology.adjacency(M)`
* `A = bct.topology.adjacency(F, nV)` (include `nV` for allocation)

If `nV` is not provided and input is `F`, infer `nV = max(F(:))`.

---

### 5.3 `bct.topology.halfedge`

**Purpose**: Construct halfedge connectivity structure for navigation and boundary detection.

**File**: `toolbox\+bct\+topology\halfedge.m`

**Source to copy**: `toolbox\+bct\+manifold\halfedge.m` (verbatim body).

**Behavior requirements**:

* Output struct fields must match the existing halfedge struct exactly (names, types, semantics), e.g.:

  * `nV, nF, nH`
  * `v, to, face, next, prev, twin, edge`
  * `E` edge list if present
  * `isBoundary`
  * any face-to-halfedge index mapping (`fh`) if present

**Signatures**:

* Must support the existing call form used in your codebase (likely `bct.manifold.halfedge(M)`); replicate that interface for `bct.topology.halfedge`.

If the original `bct.manifold.halfedge` requires `V` (unlikely for pure halfedge), preserve that requirement exactly. Do not change behavior in v1.

---

### 5.4 `bct.topology.in` and `bct.topology.out`

**Purpose**: Neighborhood queries (whatever your current semantics are).

**Files**:

* `toolbox\+bct\+topology\in.m`
* `toolbox\+bct\+topology\out.m`

**Source to copy**:

* `toolbox\+bct\+manifold\in.m`
* `toolbox\+bct\+manifold\out.m`

**Behavior requirements**:

* Must preserve the same calling patterns and outputs exactly.
* Update internal calls so that if they refer to `bct.manifold.halfedge`, they now refer to `bct.topology.halfedge` (only if required and only after copying the function).

---

### 5.5 Optional boundary convenience (only if already exists elsewhere)

If your existing codebase already has boundary loop extraction (in `halfedge` or utilities), you may include:

* `bct.topology.boundaryLoops(...)`
* `bct.topology.isBoundaryVertex(...)`

**But do not invent new algorithms in v1.** Only add these if you can copy from an existing curated implementation. Otherwise, leave for v2.

---

## 6. Dependency policy

### Allowed dependencies

* MATLAB base functions
* Other functions inside `bct.topology` (after copying)

### Prohibited dependencies (v1)

* `bct.geometry` (topology must be geometry-free)
* `bct.fem`, `bct.eigenpairs`, `bct.graph`
* DECLab / DEC toolboxes (not needed here)
* Any external geometry processing libs

### Temporary migration exception

To preserve equivalence, copying code from:

* `bct.manifold.*` files and
* `bct.Manifold` method bodies
  is required. After copying, `bct.topology` should not call `bct.manifold.*`.

---

## 7. Directory structure (deliverables)

Create:

```
toolbox\+bct\+topology\
    edges.m
    adjacency.m
    halfedge.m
    in.m
    out.m
    README.md
    private\
        parseTopoInputs.m
        validateFaces.m         (optional)
```

### README.md requirements

* Explain that `bct.topology` is a self-contained copy of curated topology routines (from `bct.manifold` and `bct.Manifold`) created for safe migration.
* State this is step 1; deprecation of `bct.manifold` topology functions will occur later.

---

## 8. Regression tests (must prove equivalence)

Add test file:

* `tests/test_topology_migration_equivalence.m`

### Test mesh requirements

Construct at least two meshes:

1. A small synthetic mesh with a boundary (e.g., two triangles forming a square) to test boundary halfedges.
2. A closed mesh (e.g., tetrahedron or icosa patch) to test no boundary.

### Required equivalence assertions

1. **Halfedge**

* `he_old = bct.manifold.halfedge(M)`
* `he_new = bct.topology.halfedge(M)`
* Compare all fields that exist in both, field-by-field:

  * sizes, integer arrays, logical arrays
  * use exact equality where possible

2. **Edges**

* `E_old = M.Edges` (or recompute using the same method if `Edges` is derived)
* `E_new = bct.topology.edges(M)`
* Must match exactly (order-sensitive if your current method yields deterministic ordering; otherwise compare as sets using `sortrows`).

3. **Adjacency**

* `A_old = M.adjacency()`
* `A_new = bct.topology.adjacency(M)`
* Must match exactly (`nnz(A_old-A_new)==0` or `isequal` on `spones` forms)

4. **in/out**

* `in_old = bct.manifold.in(...)` and `in_new = bct.topology.in(...)` with the same inputs
* `out_old = bct.manifold.out(...)` and `out_new = bct.topology.out(...)`
* Must match exactly.

### Numeric tolerances

Topology should be integer/logical; prefer exact comparisons. If any arrays are `double` but represent indices, still compare exact.

---

## 9. Safety rules (avoid breaking the repo)

* Do not modify existing files in `toolbox\+bct\+manifold\`.
* Do not modify `bct.Manifold`.
* Do not change any existing call sites.
* Only add `bct.topology` package and tests.

---

## 10. Definition of done

This step is complete when:

* `toolbox\+bct\+topology\` exists with copied implementations.
* `bct.topology.*` results match the corresponding existing outputs.
* Regression tests pass.
* Nothing else in the repo is changed.

---

## 11. Implementation checklist (agent workflow)

1. Create `toolbox\+bct\+topology\` and `private\`.
2. Copy:

   * `toolbox\+bct\+manifold\halfedge.m` → `toolbox\+bct\+topology\halfedge.m`
   * `toolbox\+bct\+manifold\in.m` → `toolbox\+bct\+topology\in.m`
   * `toolbox\+bct\+manifold\out.m` → `toolbox\+bct\+topology\out.m`
3. Create new files `edges.m` and `adjacency.m` by copying the exact logic from:

   * `bct.Manifold.computeEdges()` method body
   * `bct.Manifold.adjacency()` method body
4. Update internal references in copied files so `bct.topology.*` calls stay within `bct.topology` (e.g., if `in.m` calls `bct.manifold.halfedge`, change to `bct.topology.halfedge`).
5. Add tests proving equivalence.
6. Run tests and ensure pass.

