# bct.topology Package

## Purpose

`bct.topology` is a self-contained package containing **copied implementations** of curated topology and connectivity routines for triangular surface meshes. This package was created as **Step 1 of a safe migration** to establish a clear separation between topology (coordinate-free) and geometry (embedding-dependent) operations.

## Scope

This package contains **coordinate-free** connectivity primitives for simplicial complexes:

### Functions (v1)

- **`edges.m`** - Extract unique undirected edges from faces
- **`adjacency.m`** - Build binary vertex adjacency matrix from faces
- **`halfedge.m`** - Construct halfedge connectivity structure for navigation

### Out of Scope

- Anything requiring vertex positions `V` (lengths, areas, normals, tangents, curvature)
- Metric-dependent operators (mass matrix, stiffness, Laplacian, Hodge stars)
- DEC numerical workflows → see `bct.dec`
- Spectral computations → see `bct.eigenpairs`
- Geometry computations → see `bct.geometry`

## Design Principles

1. **Coordinate-free** - Functions operate on face connectivity alone (topology)
2. **Pure** - No persistent state, no caching (functions are stateless)
3. **Deterministic** - Given identical faces, returns identical results
4. **Self-contained** - Full implementation logic (not thin wrappers)
5. **Behavior preservation** - Exact equivalence with original implementations

## Relationship to Other Packages

```
bct.Manifold (class)
├── Vertices, Faces (immutable data)
├── bct.topology.* (connectivity: edges, adjacency, halfedge)
├── bct.geometry.* (embedding: centroids, normals, tangents)
├── bct.fem.* (operators: mass, stiffness, Laplacian)
└── bct.eigenpairs.* (spectral decomposition)
```

## Migration Strategy

This is Step 1 of migration:

1. ✅ Create `bct.topology.*` with copied implementations
2. ✅ Validate equivalence via regression tests
3. ⏳ Update callers to use `bct.topology.*` (future)
4. ⏳ Deprecate topology functions in `bct.manifold` (future)

## Usage

```matlab
% Create a mesh
M = bct.Manifold(V, F);

% Extract topology
E = bct.topology.edges(M);           % Unique edges [nE×2]
A = bct.topology.adjacency(M);        % Binary adjacency matrix [N×N]
he = bct.topology.halfedge(V, F);     % Halfedge structure

% From faces directly (no Manifold object needed)
E = bct.topology.edges(F);
A = bct.topology.adjacency(F, nV);
```

## Function Details

### edges(M) or edges(F)
Extracts unique undirected edges from triangular faces. Returns [nE×2] matrix where each row is a vertex pair forming an edge. Edges are sorted and deduplicated.

### adjacency(M) or adjacency(F, nV)
Builds symmetric binary adjacency matrix indicating which vertices are connected by edges. Returns sparse [N×N] logical matrix with no self-loops.

### halfedge(V, F)
Constructs comprehensive halfedge data structure for efficient mesh navigation:
- Per-halfedge: tail/head vertices, incident face, next/prev/twin pointers
- Boundary detection: identifies boundary halfedges (twin==0)
- Edge list: unique undirected edges with IDs

## See Also

- **`bct.geometry`** - Embedding-dependent operations (centroids, normals, tangents)
- **`bct.manifold`** - I/O, conversion, and original implementations (load, read, write, in, out, convert)
- **`bct.Manifold`** - Main manifold class with convenience methods
- **`bct.fem`** - Finite element operators
