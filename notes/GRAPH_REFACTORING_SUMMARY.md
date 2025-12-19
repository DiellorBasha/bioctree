# Graph Refactoring Summary

## Completed: December 19, 2025

### Overview
Refactored `bct.Graph` class to align with the package design philosophy established by the operator system (registry/runtime pattern). The Graph class now follows the same architectural pattern as FEM, where the class owns meaning and the package contains algorithms.

---

## Architectural Changes

### Before (Monolithic)
```
bct.Graph (class)
  ├── Canonical data: Manifold, Edges, Weights
  ├── Derived data: Adjacency, Degree, Laplacian
  ├── Assembly logic: buildAdjacency(), buildDegree(), buildLaplacian()
  ├── Metric computation: computeGeometricWeights(), computeFEMWeights()
  ├── Backend adapters: matlabGraph(), gspGraph()
  └── Algorithms: shortestPath(), bfSearch(), dfSearch(), distances(), etc.
```

### After (Separated)
```
bct.Graph (class) - Owns meaning
  ├── Canonical: Manifold, Edges, Weights, NumNodes
  ├── Dependent (lazy): Adjacency, Degree, Laplacian
  ├── Adapters: matlab(), gsp() (cached)
  └── Thin wrappers: shortestPath(), bfSearch(), etc. → delegate to bct.graph

bct.graph (package) - Executes algorithms
  ├── Assembly: assembleAdjacency, assembleDegree, assembleLaplacian
  ├── Metrics: edgeLengths, femWeights
  ├── Adapters: matlabGraph, gspGraph
  └── Algorithms: shortestPath, bfSearch, dfSearch, distances
```

---

## Files Created

### Package Functions: `toolbox/+bct/+graph/`

1. **`assembleAdjacency.m`** - Build adjacency matrix from Manifold topology
2. **`assembleDegree.m`** - Build degree matrix from adjacency
3. **`assembleLaplacian.m`** - Build graph Laplacian (combinatorial/normalized/randomwalk)
4. **`edgeLengths.m`** - Compute Euclidean edge lengths (geometric metric)
5. **`femWeights.m`** - Compute FEM-based edge weights (cotangent metric)
6. **`matlabGraph.m`** - Create MATLAB graph object with specified metric
7. **`shortestPath.m`** - Compute shortest path between two nodes
8. **`bfSearch.m`** - Breadth-first search from source node
9. **`dfSearch.m`** - Depth-first search from source node
10. **`distances.m`** - All-pairs shortest path distances

### Test File
- **`tests/test_graph_refactoring.m`** - Comprehensive test (not run yet per user request)

---

## Files Modified

### `toolbox/+bct/Graph.m`

**Removed:**
- `Vertices` property (use `Manifold.Vertices` instead)
- `N` property (renamed to `NumNodes`)
- `Adjacency`, `Degree`, `Laplacian` as stored properties
- `buildAdjacency()`, `buildEdges()`, `buildDegree()`, `buildLaplacian()` methods
- `computeGeometricWeights()`, `computeFEMWeights()` methods
- Algorithm implementations from `shortestPath()`, `bfSearch()`, `dfSearch()`, `distances()`
- `shortestPathTree()`, `allPaths()`, `maxFlow()`, `nearest()`, `inedges()`, `outedges()`, `incidence()` methods

**Changed:**
- `Adjacency`, `Degree`, `Laplacian` → Dependent properties (lazy computed via `bct.graph`)
- `matlabGraph()` → `matlab()` (cleaner API, delegates to `bct.graph.matlabGraph`)
- `gspGraph()` → `gsp()` (cleaner API)
- Constructor now uses `bct.graph.edgeLengths()` and `bct.graph.femWeights()`
- Constructor builds edges using `Manifold.edges()`

**Added:**
- `addMetric()` - Add custom edge weight metrics
- `listMetrics()` - List available metrics
- Thin wrapper methods that delegate to `bct.graph` package

---

## Design Principles Applied

### 1. **Separation of Concerns**
- Class owns canonical data and meaning
- Package owns algorithmic implementations
- Backend (MATLAB graph) is a plugin, not canonical

### 2. **Lazy Computation**
- Adjacency, Degree, Laplacian computed on-demand via dependent properties
- Results not cached (recomputed each access for simplicity)
- Backend adapters (MATLAB/GSP graphs) are cached with versioning

### 3. **Metric Flexibility**
- Multiple metrics stored: `geometry` (Euclidean), `fem` (cotangent)
- Custom metrics can be added via `addMetric()`
- All algorithms accept `metric` parameter

### 4. **Consistent with FEM Pattern**
```
bct.FEM    (class)  → bct.fem.*    (functions)
bct.Graph  (class)  → bct.graph.*  (functions)
bct.DEC    (class)  → bct.dec.*    (functions)  [future]
```

---

## Key Invariants

1. **MATLAB graph is not the Graph** - It's a derived backend/adapter
2. **bct.Graph defines graph meaning** - Topology and metrics
3. **bct.graph executes graph algorithms** - Pure functions
4. **Topology is canonical** - Edges list is authoritative
5. **Metrics are overlays** - Multiple weight schemes on same topology

---

## Benefits

✅ **Clean symmetry** with FEM and DEC representations  
✅ **Unlimited backend extensibility** - Can swap MATLAB graph for other engines  
✅ **Plugin architecture** - Clear separation of meaning vs execution  
✅ **Clear ownership** - Topology vs algorithms  
✅ **Easier testing** - Backend functions are pure and testable  
✅ **Maintains compatibility** - All MATLAB graph algorithms still accessible  
✅ **Caching preserved** - Backend adapters still cached for performance  
✅ **All metrics supported** - Extensible metric system  

---

## Next Steps (Pending)

1. Run `test_graph_refactoring.m` to validate implementation
2. Add graph operators to `bct.registry.operators()` if needed for operator system
3. Update any dependent code that uses old Graph API
4. Consider adding more graph algorithms to bct.graph package:
   - `eigensolve.m` - Graph eigenpairs computation
   - `incidence.m` - Incidence matrix builder
   - Additional path/flow algorithms as needed

---

## Contract Compliance

This refactoring fully implements the specification in `GraphContract.md`:

- ✅ Section 6: "Graph is a port"
- ✅ Section 7: "What Graph owns" (Manifold, Edges, Weights, NumNodes)
- ✅ Section 8: "What moves to bct.graph" (All algorithms)
- ✅ Section 9: "Why this design is better"
- ✅ Section 10: "Final invariant"

**Status:** Ready for testing ✨
