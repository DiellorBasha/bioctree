# bct.manifold.geometry Package

## Purpose

`bct.manifold.geometry` contains **embedding-dependent** geometric computation routines for triangular surface meshes (manifolds). This package provides the fundamental geometry operations needed for manifold analysis.

## Scope

This package contains geometric computations on triangulated 2-manifolds:

### Functions

- **`centroids.m`** - Compute face centroids (geometric centers)
- **`normals.m`** - Compute face and vertex normal vectors  
- **`tangents.m`** - Construct orthonormal tangent frames on faces or vertices
- **`frame.m`** - Cached coordinate frame computation
- **`cotan.m`** - Cotangent values per triangle face

### Out of Scope

- Topology-only operations (edges, adjacency, halfedge) → see `bct.manifold.topology`
- Operator assembly (mass matrix, stiffness, Laplacian) → see `bct.manifold` functions
- Spectral computations → see `bct.Eigenpairs`
- I/O operations → see `bct.manifold.load/save`

## Design Principles

1. **Manifold-centric** - Operates on `bct.Manifold` objects or raw (V,F) data
2. **Self-contained** - Full implementation logic, not thin wrappers
3. **Cached geometry** - Manifold objects cache computed geometry via `getGeometry/setGeometry`
4. **Flexible inputs** - Support both Manifold objects and (V,F) pairs

## Usage

```matlab
% Load a mesh
M = bct.Manifold(V, F);

% Direct function calls
C = bct.manifold.geometry.centroids(M);          % Face centroids
N_face = bct.manifold.geometry.normals(M, 'face');   % Face normals
N_vert = bct.manifold.geometry.normals(M, 'vertex'); % Vertex normals
[N, e1, e2] = bct.manifold.geometry.tangents(M);     % Tangent frames

% Or use Manifold convenience methods
C = M.centroids();      % Calls bct.manifold.geometry.centroids()
N = M.normals();        % Calls bct.manifold.geometry.normals()
[N, e1, e2] = M.tangents();  % Calls bct.manifold.geometry.tangents()

% Cached frame computation
fr = bct.manifold.geometry.frame(M);  % Cached in M.Geometry.frame
fr = bct.manifold.geometry.frame(M, 'Force', true);  % Force recompute

% Raw (V,F) input also supported
C = bct.manifold.geometry.centroids(V, F);
N = bct.manifold.geometry.normals(V, F);
```

## Caching Strategy

For `bct.Manifold` objects, computed geometry is cached internally:

- `centroids()` → cached in `M.Geometry.centroids`
- `normals()` → cached in `M.Geometry.normals`  
- `tangents()` → cached in `M.Geometry.tangents`
- `frame()` → cached in `M.Geometry.frame`

This avoids redundant computation when geometry is requested multiple times.

## See Also

- `bct.Manifold` - Main manifold class
- `bct.manifold.topology` - Topological operations (halfedge, edges, adjacency)
- `bct.manifold.operator.mass`, `bct.manifold.operator.stiffness` - FEM operators
