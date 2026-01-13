# bct.manifold.topology Package

## Purpose

`bct.manifold.topology` contains **coordinate-free** connectivity and topology routines for triangulated surface meshes (manifolds). This package provides pure topological operations that depend only on mesh connectivity, not embedding.

## Scope

This package contains topological primitives for simplicial complexes (triangular meshes):

### Functions

- **`edges.m`** - Extract unique undirected edges from face connectivity
- **`adjacency.m`** - Build binary vertex adjacency matrix from faces
- **`halfedge.m`** - Construct halfedge data structure for mesh navigation

### Out of Scope

- Anything requiring vertex positions V (lengths, areas, normals, curvature) → see `bct.manifold.geometry`
- Metric-dependent operators (mass, stiffness, Laplacian) → see `bct.manifold` functions
- Spectral computations → see `bct.Eigenpairs`

## Design Principles

1. **Coordinate-free** - Functions operate on face connectivity `F` alone
2. **Pure functions** - No persistent state, no caching (stateless)
3. **Deterministic** - Identical faces → identical results
4. **Self-contained** - Full implementation logic, not thin wrappers
5. **Flexible inputs** - Support both `bct.Manifold` objects and raw face arrays

## Relationship to Other Packages

```
bct.Manifold (class)
├── Vertices, Faces (immutable data)
├── bct.manifold.topology.* (connectivity: edges, adjacency, halfedge)
├── bct.manifold.geometry.* (embedding: centroids, normals, tangents)
└── bct.manifold.eigen.* (spectral decomposition)
```

## Usage

```matlab
% Load a mesh
M = bct.Manifold(V, F);

% Extract topology from Manifold
E = bct.manifold.topology.edges(M);           % Unique edges [nE×2]
A = bct.manifold.topology.adjacency(M);       % Binary adjacency matrix [N×N]
he = bct.manifold.topology.halfedge(V, F);    % Halfedge structure

% Or use raw face connectivity (no vertex positions needed)
E = bct.manifold.topology.edges(F);           % Just faces
A = bct.manifold.topology.adjacency(F, nV);   % Faces + vertex count
he = bct.manifold.topology.halfedge([], F);   % Empty V acceptable for halfedge

% Halfedge navigation example
he = bct.manifold.topology.halfedge(V, F);
% Navigate: halfedge h -> next(h) -> twin(h) for boundary/manifold traversal
```

## Function Details

### edges(M) or edges(F)

Extracts unique undirected edges from triangular faces.

- **Input**: `bct.Manifold` object or face array `F` [nF×3]
- **Output**: Edge array `E` [nE×2] where each row is a vertex pair
- **Properties**: Edges sorted lexicographically, deduplicated

```matlab
E = bct.manifold.topology.edges(M);
% E = [v1 v2; v1 v3; v2 v3; ...] with v1 < v2
```

### adjacency(M) or adjacency(F, nV)

Builds symmetric binary adjacency matrix indicating vertex connectivity.

- **Input**: `bct.Manifold` or `(F, nV)` where nV is vertex count
- **Output**: Sparse logical matrix `A` [N×N]
- **Properties**: Symmetric, no self-loops, A(i,j)==1 ↔ edge (i,j) exists

```matlab
A = bct.manifold.topology.adjacency(M);
% A(i,j) == true ⟺ vertices i and j share an edge
```

### halfedge(V, F)

Constructs comprehensive halfedge data structure for efficient mesh navigation.

- **Input**: Vertex positions `V` [nV×3] and faces `F` [nF×3]  
  (V can be empty `[]` if positions not needed)
- **Output**: Structure `he` with fields:
  - `.v`, `.to` - Tail/head vertices
  - `.f` - Incident face
  - `.next`, `.prev`, `.twin` - Navigation pointers
  - `.isBoundary` - Boundary edge indicator
  - `.edgeList` - Unique edge list with IDs

```matlab
he = bct.manifold.topology.halfedge(V, F);
% Navigate clockwise around face: h -> he.next(h) -> he.next(he.next(h))
% Jump to opposite face: h -> he.twin(h)
% Find boundary: he.isBoundary == true when twin==0
```

## See Also

- `bct.Manifold` - Main manifold class
- `bct.manifold.geometry` - Embedding-dependent operations (centroids, normals, tangents)
- `bct.manifold.operator.mass`, `bct.manifold.cotmatrix` - FEM operators
