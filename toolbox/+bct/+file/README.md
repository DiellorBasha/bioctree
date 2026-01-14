# bct.file Package - HDF5 I/O for BCT Manifold Workflows

Phased implementation of HDF5 read/write operations for BCT manifold data.

## Package Structure

```
+bct/+file/
├── Low-level file primitives (Phase 1 ✓)
│   ├── create.m         - Create HDF5 file with schema
│   ├── info.m           - Get file metadata
│   ├── validate.m       - Validate schema conformance
│   ├── exists.m         - Check path existence
│   ├── list.m           - List children at path
│   ├── read.m           - Read dataset
│   ├── write.m          - Write dataset
│   ├── readAttrs.m      - Read attributes
│   └── writeAttrs.m     - Write attributes
│
├── +h5/                 - HDF5 mechanics (Phase 1 ✓)
│   ├── normalizePath.m  - Path normalization
│   ├── ensureGroup.m    - Create group hierarchy
│   ├── readDataset.m    - Low-level dataset read
│   ├── writeDataset.m   - Low-level dataset write
│   ├── readAttribute.m  - Low-level attribute read
│   └── writeAttribute.m - Low-level attribute write
│
├── +read/               - Full-workflow readers
│   └── manifold.m       - Read full manifold (Phase 1 core ✓)
│
└── +manifold/           - Schema-aware adapters
    ├── paths.m          - Canonical path definitions (Phase 1 ✓)
    ├── schema.m         - Schema specification (Phase 1 ✓)
    │
    ├── +read/           - Manifold subtree readers
    │   ├── core.m       - Read vertices/faces/edges (Phase 1 ✓)
    │   ├── geometry.m   - Phase 3 TODO
    │   ├── topology.m   - Phase 2 TODO
    │   ├── operators.m  - Phase 2 TODO
    │   ├── eigenmodes.m - Phase 3 TODO
    │   └── health.m     - Phase 3 TODO
    │
    └── +write/          - Manifold subtree writers
        ├── core.m       - Write vertices/faces/edges (Phase 1 ✓)
        ├── geometry.m   - Phase 3 TODO
        ├── topology.m   - Phase 2 TODO
        ├── operators.m  - Phase 2 TODO
        ├── eigenmodes.m - Phase 3 TODO
        └── health.m     - Phase 3 TODO
```

## Implementation Status

### ✅ Phase 1 - Core File Primitives + Core Manifold (COMPLETE)

**Objective:** Create files, read/write core mesh data (vertices, faces, edges).

**Implemented:**
- Low-level file operations (create, info, validate, exists, list, read, write)
- Attribute read/write (readAttrs, writeAttrs)
- HDF5 utilities (path normalization, group creation, dataset/attribute I/O)
- Manifold core read/write (vertices, faces, edges)
- Full manifold orchestrator (core only)
- Canonical paths and schema specification

**Usage:**
```matlab
% Create file
bct.file.create("mesh.h5", "ManifoldID", "test_mesh");

% Write core mesh
core = struct("vertices", V, "faces", F, "edges", E);
bct.file.manifold.write.core("mesh.h5", core);

% Read core mesh
core = bct.file.manifold.read.core("mesh.h5");

% Full manifold workflow (core only)
S = bct.file.read.manifold("mesh.h5", "Parts", "core");
```

### 🔨 Phase 2 - Sparse Support + Operators/Topology (TODO)

**Objective:** Add sparse matrix encoding and structured subtree read/write.

**To Implement:**
- `bct.file.h5.sparseEncode/sparseDecode` - CSC encoding
- `bct.file.h5.readSparse/writeSparse` - Sparse I/O
- `bct.file.manifold.read/write.topology` - Topology subtree
- `bct.file.manifold.read/write.topology.halfedge` - Halfedge structure
- `bct.file.manifold.read/write.topology.adjacency` - Sparse adjacency
- `bct.file.manifold.read/write.operators` - Auto-detect sparse/dense

**Sparse Matrix Convention:**
```
/path/to/operator/csc/colptr   [nCols+1] uint64
/path/to/operator/csc/rowind   [nnz] uint32
/path/to/operator/csc/values   [nnz] double
Attributes on /path/to/operator:
  storage = "CSC"
  type = "sparse"
  shape = [nRows, nCols]
  index_base = 0  (CSC arrays use 0-based)
```

### 🔨 Phase 3 - Geometry/Eigenmodes/Health (TODO)

**Objective:** Complete all subtrees with generic traversal.

**To Implement:**
- `bct.file.manifold.read/write.geometry` - Geometry quantities
- `bct.file.manifold.read/write.eigenmodes` - Eigendecomposition
- `bct.file.manifold.read/write.health` - Health metrics
- `bct.file.readGroup/writeGroup` - Generic recursive traversal
- Extended `bct.file.read.manifold` - Support all parts

### 🔨 Phase 4 - Ergonomics + Metadata (TODO)

**Objective:** Improve usability and metadata handling.

**To Implement:**
- `WithAttrs` support for including attributes in output
- `Mode="update"` for partial writes
- Leaf-level convenience functions as needed
- `bct.field` integration (optional wrapper layer)

## Schema Conventions

**Root Attributes:**
- `schema = "bct.manifold.h5@1"`
- `created_utc = "<ISO8601>"`
- `bct_version = "<string>"` (optional)
- `manifold_id = "<string>"` (optional)

**/manifold Attributes:**
- `units_length = "m"` (canonical SI)
- `index_base_faces = 1` (MATLAB convention)
- `index_base_edges = 1`
- `coordinate_system = "RAS"` (optional)

**Core Datasets:**
- `/manifold/vertices` [N×3] double
- `/manifold/faces` [F×3] int32/uint32
- `/manifold/edges` [E×2] int32/uint32 (optional)

**Subtrees:**
- `/manifold/geometry` - Cached geometry (areas, normals, etc.)
- `/manifold/topology` - Halfedge, adjacency, etc.
- `/manifold/operators` - Differential operators (sparse/dense)
- `/manifold/eigenmodes` - Eigenvalues, eigenvectors
- `/manifold/health` - Mesh quality metrics

## Design Principles

1. **Path-first**: All data addressed by HDF5 paths
2. **Schema-aware**: Domain adapters map BCT conventions to paths
3. **Modular I/O**: Read/write subtrees independently
4. **Struct-based**: Operates on structs and arrays (no hard dependency on bct.Manifold class)
5. **Separation**: File layer (`bct.file.*`) vs domain layer (`bct.file.manifold.*`)

## Next Steps

Ready for Phase 2 integration of MATLAB HDF5 functions:
- Add sparse matrix encode/decode functions
- Implement topology and operator subtree readers/writers
- Extend full manifold orchestrator with new parts

See `notes/BCTFILE.md` for complete specification.
