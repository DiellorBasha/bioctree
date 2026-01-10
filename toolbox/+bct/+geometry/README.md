# bct.geometry Package

## Purpose

`bct.geometry` is a self-contained package containing **copied implementations** of curated geometric computation routines for triangular surface meshes. This package was created as **Step 1 of a safe migration** from scattered geometry functions in `bct.manifold`.

## Scope

This package contains **embedding-dependent** geometry computations on triangular surface meshes:

### Functions (v1)

- **`centroids.m`** - Compute face centroids (geometric centers)
- **`normals.m`** - Compute face and vertex normal vectors
- **`tangents.m`** - Construct tangent frames on faces or vertices
- **`frame.m`** - Coordinate frame utilities for tangent space

### Out of Scope

- Topology-only operations (edges, adjacency, halfedge) → see `bct.topology`
- Operator assembly (mass matrix, stiffness, Laplacian) → see `bct.fem`
- Spectral computations → see `bct.eigenpairs`
- I/O operations → see `bct.manifold.read/write`

## Design Principles

1. **Self-contained** - Each function contains full implementation logic (not thin wrappers)
2. **Behavior preservation** - Exact equivalence with original `bct.manifold.*` functions
3. **No breaking changes** - Existing code continues working unchanged
4. **Regression tested** - Validated against original implementations

## Migration Strategy

This is Step 1 of migration:

1. ✅ Create `bct.geometry.*` with copied implementations
2. ✅ Validate equivalence via regression tests
3. ⏳ Update callers to use `bct.geometry.*` (future)
4. ⏳ Deprecate geometry functions in `bct.manifold` (future)

## Usage

```matlab
% Load a mesh
M = bct.Manifold(V, F);

% Compute geometric properties
C = bct.geometry.centroids(M);           % Face centroids
N_face = bct.geometry.normals(M, 'face');    % Face normals
N_vert = bct.geometry.normals(M, 'vertex');  % Vertex normals
T = bct.geometry.tangents(M, 'Domain', 'face');  % Face tangents
```

## See Also

- **`bct.topology`** - Pure connectivity operations (edges, halfedge, adjacency)
- **`bct.manifold`** - Original implementations (will be deprecated for geometry)
- **`bct.Manifold`** - Main manifold class with convenience methods
