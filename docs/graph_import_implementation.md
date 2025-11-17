# Graph Import Implementation Summary

## Overview
Modified `bct.io.graph.Import.fromFreeSurfer` to create graph-type Manifold objects instead of mesh-type, enabling graph-based analysis while preserving spatial embedding information.

## Changes Made

### 1. Modified `bct.io.graph.Construct.buildBct()`
**File:** `toolbox/+bct/+io/+graph/Construct.m`

- Added optional parameter `opts.ManifoldType` with values "mesh" (default) or "graph"
- When `ManifoldType="graph"`:
  - Extracts edges from faces using existing `edgesFromFaces()` function
  - Creates edges table with `EndNodes` (Mx2 matrix) and `Weight` columns
  - Creates graph-type Manifold with `N` nodes and edges table
  - Preserves vertices in `Manifold.V` for spatial embedding
- When `ManifoldType="mesh"` (default):
  - Creates mesh-type Manifold with vertices and faces (backward compatible)
- Updated to create bct object directly with Manifold instead of using `fromMesh()`

### 2. Updated `bct.io.graph.Import.fromFreeSurfer()`
**File:** `toolbox/+bct/+io/+graph/Import.m`

- Modified to call `buildBct()` with `ManifoldType="graph"`
- Updated documentation to reflect graph topology creation

### 3. Fixed `bct.bct` Vertices Getter
**File:** `toolbox/+bct/@bct/bct.m`

- Removed Type check in `get.Vertices()` to support both mesh and graph Manifolds
- Now delegates to `Manifold.V` for both mesh and graph types

## Backward Compatibility

All changes maintain backward compatibility:
- `buildBct()` defaults to "mesh" type if `ManifoldType` not specified
- `bct.fromMesh()` continues to create mesh-type Manifolds
- Legacy properties (`Vertices`, `Faces`, `mesh`) continue to work through delegation
- Existing mesh import workflows unchanged

## Testing

Created comprehensive test suite in `tests/unit/test_graph_import.m` with 7 test cases:

1. ✅ `testGraphTypeCreation` - Verifies graph-type Manifold creation
2. ✅ `testEdgesCreated` - Validates edges table structure and content
3. ✅ `testVerticesPreserved` - Ensures vertices retained for spatial embedding
4. ✅ `testNMatchesVertexCount` - Confirms N property matches vertex count
5. ✅ `testAdjacencyMatrix` - Tests adjacency matrix generation (sparse, symmetric, no self-loops)
6. ✅ `testLaplacian` - Validates Laplacian computation
7. ✅ `testBackwardCompatibilityProperties` - Ensures legacy property delegation works

All 7 tests pass.

## Usage Example

```matlab
% Import FreeSurfer surface as graph
path = 'test-data/freesurfer/fsaverage/surf/lh.pial';
B = bct.io.graph.Import.fromFreeSurfer(path);

% Access graph properties
fprintf('Type: %s\n', B.Manifold.Type);              % "graph"
fprintf('Vertices: %d\n', size(B.Manifold.V, 1));    % 163842
fprintf('Edges: %d\n', height(B.Manifold.Edges));    % 491520

% Use graph analysis methods
A = B.Manifold.adjacency();  % Sparse adjacency matrix
L = B.Manifold.laplacian();  % Graph Laplacian

% Backward compatibility
V = B.Vertices;  % Delegates to B.Manifold.V
```

## Benefits

1. **Graph-based Analysis**: Enables graph signal processing on cortical surfaces
2. **Spatial Embedding**: Preserves 3D vertex coordinates for visualization
3. **Efficient Representation**: Sparse edge list instead of dense faces
4. **Unified API**: Same Manifold interface for mesh and graph operations
5. **Backward Compatible**: Existing code continues to work

## Technical Details

### Edge Extraction
Edges are extracted from triangular faces by taking all unique pairs:
- Edge 1-2 from each face
- Edge 2-3 from each face  
- Edge 3-1 from each face
- Sorted and deduplicated

For the fsaverage left hemisphere:
- Input: 327680 faces (triangles)
- Output: 491520 unique edges

### Manifold Constructor
Uses the `Manifold(N, EdgesTable)` constructor signature:
- `N`: Number of nodes (matches vertex count)
- `EdgesTable`: Table with `EndNodes` (Mx2) and `Weight` (Mx1) columns

### Memory Efficiency
Graph representation is more memory-efficient than mesh:
- Mesh: 327680 × 3 = 983040 face indices
- Graph: 491520 × 2 = 983040 edge indices
- Similar storage but graph enables different operations

## Future Work

- Consider adding optional weights (e.g., edge lengths, cotangent weights)
- Add graph-specific visualization methods
- Implement graph Fourier transform for spectral analysis
- Support directed graphs if needed
