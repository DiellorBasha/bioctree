# Manifolds

## Introduction

A **manifold** in Bioctree represents the geometric substrate on which signals are defined. For neuroimaging applications, this is typically a cortical surface mesh, but the framework applies to any triangulated surface or graph.

## Discrete Manifolds

### Definition

A discrete 2D manifold is defined by:

1. **Vertex set** $V = \{v_i\}_{i=1}^{N}$ where each $v_i \in \mathbb{R}^3$
2. **Face set** $F = \{f_j\}_{j=1}^{M}$ where each $f_j$ is a triple of vertex indices

This representation is called a **triangular mesh**.

### Example: Cortical Surface

```matlab
% Load fsaverage right hemisphere
data = load('data/mesh/fsaverage_rh_pial.mat');

% Vertices: [N × 3] array
V = data.V;  % 40962 × 3

% Faces: [M × 3] array of indices
F = data.F;  % 81920 × 3

% Create manifold
M = bct.Manifold(V, F);
```

### Properties

```matlab
M.N           % Number of vertices: 40962
M.Type        % 'mesh' or 'graph'
M.V           % Vertices [N × 3]
M.F           % Faces [M × 3]
M.Edges       % Edge list [E × 2]
```

## Geometric Properties

### Surface Area

The total surface area is the sum of triangle areas:

$$
A_{total} = \sum_{j=1}^{M} A_j
$$

where $A_j$ is the area of triangle $j$.

```matlab
% Compute per-vertex areas
areas = M.computeVertexAreas();

% Total surface area
total_area = sum(areas);
```

### Vertex Normals

Normal vector at each vertex (average of adjacent face normals):

```matlab
normals = M.computeVertexNormals();  % [N × 3]
```

### Edge Lengths

```matlab
edge_lengths = M.computeEdgeLengths();  % [E × 1]
mean_edge_length = mean(edge_lengths);
```

## Differential Geometry on Meshes

### The Cotangent Laplacian

The discrete Laplace-Beltrami operator on a triangle mesh is:

$$
L_{ij} = \begin{cases}
\sum_{k \sim i} \cot \alpha_{ij} + \cot \beta_{ij} & \text{if } i = j \\
-(\cot \alpha_{ij} + \cot \beta_{ij}) & \text{if } i \sim j \\
0 & \text{otherwise}
\end{cases}
$$

where $\alpha_{ij}$ and $\beta_{ij}$ are the two angles opposite edge $(i,j)$.

```matlab
% Compute Laplacian
L = M.cotLaplacian();  % Sparse matrix [N × N]
```

### Mass Matrix

The mass matrix $M$ represents the area associated with each vertex:

$$
M_{ij} = \begin{cases}
A_i & \text{if } i = j \\
0 & \text{otherwise}
\end{cases}
$$

where $A_i$ is the area associated with vertex $i$ (typically $\frac{1}{3}$ of adjacent triangles).

```matlab
% Compute mass matrix
M_mass = M.massMatrix();  % Diagonal matrix [N × N]
```

## Manifold Types in Bioctree

### 1. Triangle Mesh (Most Common)

**Use case**: Cortical surfaces, 3D shapes

```matlab
M = bct.Manifold(V, F);
```

**Requirements**:
- `V`: [N × 3] vertex positions
- `F`: [M × 3] face indices

### 2. Graph (Abstract)

**Use case**: Connectivity analysis, abstract networks

```matlab
% Create from adjacency matrix
W = sparse(adjacency_matrix);
M = bct.Manifold.fromGraph(W);
```

**Requirements**:
- `W`: [N × N] symmetric sparse matrix (adjacency or weights)

### 3. Hybrid: Mesh with Custom Connectivity

**Use case**: Modify mesh topology while preserving geometry

```matlab
M = bct.Manifold(V, F);
M.setCustomEdges(custom_edge_list);
```

## Manifold Operations

### Subsampling

Reduce mesh resolution:

```matlab
% Keep 50% of vertices
M_sub = M.subsample(0.5);

% Or specify target vertex count
M_sub = M.subsample('TargetVertices', 10000);
```

### Refinement

Increase mesh resolution:

```matlab
% Subdivide each triangle into 4
M_refined = M.subdivide(1);

% Multiple subdivisions
M_fine = M.subdivide(2);  % 16 triangles per original
```

### Region Extraction

Extract a subregion:

```matlab
% Define region by vertex indices
region_vertices = [100:500, 1000:1500];
M_region = M.extractRegion(region_vertices);
```

### Boundary Detection

```matlab
% Find boundary edges (if mesh has holes)
boundary_edges = M.findBoundary();

% Check if mesh is closed
is_closed = M.isClosed();
```

## Mesh Quality Metrics

### Triangle Quality

```matlab
% Compute quality metrics
quality = M.triangleQuality();

% Metrics include:
% - Aspect ratio
% - Minimum angle
% - Area
% - Regularity
```

### Connectivity

```matlab
% Vertex valence (number of neighbors)
valence = M.vertexValence();

% Most cortical meshes have valence ≈ 6
mean_valence = mean(valence);
```

### Curvature

```matlab
% Mean curvature at each vertex
curvature = M.meanCurvature();

% Gaussian curvature
gaussian_curv = M.gaussianCurvature();
```

## Common Mesh Sources

### FreeSurfer

```matlab
% FreeSurfer stores surfaces as ?h.pial, ?h.white, etc.
% Use FreeSurfer MATLAB tools to load

addpath('/Applications/freesurfer/matlab');
[V, F] = read_surf('lh.pial');
M = bct.Manifold(V, F);
```

### BrainStorm

```matlab
% Load BrainStorm cortex file
cortex = load('cortex_file.mat');
M = bct.Manifold(cortex.Vertices, cortex.Faces);
```

### GIFTI

```matlab
% Requires GIFTI toolbox
g = gifti('surface.gii');
M = bct.Manifold(g.vertices, g.faces);
```

### Custom/Synthetic

```matlab
% Create icosphere (for testing)
[V, F] = icosphere(4);  % 4 subdivisions
M = bct.Manifold(V, F);
```

## Visualization

### Basic Visualization

```matlab
% Plot mesh
figure;
M.plot();

% With options
M.plot('FaceColor', [0.8 0.8 0.8], 'EdgeColor', 'none');
```

### Colored by Property

```matlab
% Color by curvature
curvature = M.meanCurvature();
M.plot('CData', curvature);
colorbar;
title('Mean Curvature');
```

### Interactive Inspection

```matlab
% Open in interactive viewer
bct.show.manifold(M);
```

## Integration with BCT System

### From Mesh to Full Analysis

```matlab
% 1. Create manifold
M = bct.Manifold(V, F);

% 2. Create BCT object
B = bct.bct.fromManifold(M);

% 3. Compute eigenbasis
B.computeEigenbasis(100);

% 4. Now ready for signal processing
% B.Lambda is the spectral domain
% M is still accessible as B.Manifold
```

### Adding Temporal Dimension

```matlab
% Add time axis to manifold
M.Time = bct.Time(200, 250);  % 200 samples at 250 Hz

% Now can create spatiotemporal signals
signal = bct.Signal(M, data_matrix, 'meg_data');  % [N × T]
```

## Advanced Topics

### Geodesic Distance

Compute shortest path distances on the surface:

```matlab
% Distance from vertex 100 to all others
source_vertex = 100;
distances = M.geodesicDistance(source_vertex);

% Pairwise distances (computationally expensive)
D = M.pairwiseGeodesicDistance([v1, v2, v3, v4]);
```

### Parallel Transport

Transport vectors along the surface:

```matlab
% Transport vector from v1 to v2
vector_at_v1 = [1, 0, 0];  % Tangent vector
vector_at_v2 = M.parallelTransport(vector_at_v1, v1, v2);
```

### Heat Kernel

```matlab
% Compute heat kernel signature
t = 1.0;  % Time parameter
hks = M.heatKernelSignature(t);
```

## Best Practices

### ✅ Do's

- **Check mesh quality** before analysis:
  ```matlab
  M.validateTopology();
  ```

- **Use appropriate resolution**: 
  - Too coarse: Miss features
  - Too fine: Slow computation

- **Normalize vertex positions** if working with multiple subjects:
  ```matlab
  M.normalize();  % Center and scale
  ```

### ❌ Don'ts

- **Don't modify V or F directly** without updating dependent properties
- **Don't assume manifolds are closed** (check with `M.isClosed()`)
- **Don't mix different coordinate systems** (MNI, native, etc.) without transformation

## Troubleshooting

### Issue: "Mesh has non-manifold vertices"

**Cause**: Vertex with non-disk neighborhood  
**Fix**: Clean mesh
```matlab
M_clean = M.cleanNonManifold();
```

### Issue: "Negative triangle areas"

**Cause**: Flipped face orientation  
**Fix**: Correct orientation
```matlab
M.flipFaces();
```

### Issue: "Disconnected components"

**Cause**: Mesh has separate pieces  
**Fix**: Extract largest component
```matlab
M_main = M.largestComponent();
```

## Further Reading

- [Laplace-Beltrami Operator](laplace-beltrami.md): How manifolds connect to spectral analysis
- [Graph Structure](graph-structure.md): Graph interpretation of meshes
- [Load Mesh Tutorial](../tutorials/load-mesh.md): Step-by-step mesh loading
- [API: bct.Manifold](../api/matlab/manifold.md): Complete API reference
