# Migration: Manifold Conversion Functions

## Summary
Moved conversion functions from `bct.manifold` package to `bct.io.convert` package to improve code organization as part of the BCT architectural restructuring.

## Changes Made

### New Files Created
1. `toolbox/+bct/+io/+convert/manifoldToGspGraph.m`
   - Converts Manifold to GSPBox graph structure
   - Replaces `bct.manifold.toGspGraph`

2. `toolbox/+bct/+io/+convert/manifoldToMatlabGraph.m`
   - Converts Manifold to MATLAB graph object
   - Replaces `bct.manifold.toMatlabGraph`

3. `toolbox/+bct/+io/+convert/manifoldToSurfaceMesh.m`
   - Converts Manifold to MATLAB surfaceMesh object
   - Replaces `bct.manifold.toSurfaceMesh`

### Files Modified

#### Core Package Files
1. `toolbox/+bct/+show/visualizer.m`
   - Updated: `bct.manifold.toSurfaceMesh` → `bct.io.convert.manifoldToSurfaceMesh`

2. `toolbox/surfaceMeshShowInParent.m`
   - Updated: `bct.manifold.toSurfaceMesh` → `bct.io.convert.manifoldToSurfaceMesh`

3. `tests/unit/test_bct_manifold_integration.m`
   - Updated all three conversion function calls to new locations

#### Backward Compatibility Wrappers
4. `toolbox/+bct/+manifold/toGspGraph.m`
   - Converted to deprecation wrapper
   - Calls `bct.io.convert.manifoldToGspGraph` internally
   - Shows deprecation warning

5. `toolbox/+bct/+manifold/toMatlabGraph.m`
   - Converted to deprecation wrapper
   - Calls `bct.io.convert.manifoldToMatlabGraph` internally
   - Shows deprecation warning

6. `toolbox/+bct/+manifold/toSurfaceMesh.m`
   - Converted to deprecation wrapper
   - Calls `bct.io.convert.manifoldToSurfaceMesh` internally
   - Shows deprecation warning

## Migration Path

### Old API (Deprecated)
```matlab
sm = bct.manifold.toSurfaceMesh(B.Manifold);
g = bct.manifold.toMatlabGraph(B.Manifold);
Gsp = bct.manifold.toGspGraph(B.Manifold);
```

### New API (Recommended)
```matlab
sm = bct.io.convert.manifoldToSurfaceMesh(B.Manifold);
g = bct.io.convert.manifoldToMatlabGraph(B.Manifold);
Gsp = bct.io.convert.manifoldToGspGraph(B.Manifold);
```

## Testing
All tests pass (`test_conversion_migration.m`):
- ✓ New functions work correctly
- ✓ Backward compatibility maintained
- ✓ Deprecation wrappers function properly
- ✓ Integration with visualization system verified
- ✓ Tested with FreeSurfer mesh (163,842 vertices)

## Rationale
- **Better Organization**: Conversion/transformation functions logically belong in `bct.io.convert`
- **Consistency**: Aligns with existing conversion functions like `manifoldToGspGraph.m` (already in convert)
- **Modularity**: Reduces coupling between Manifold class and conversion utilities
- **Future-Proof**: Prepares for upcoming migration of `bct.manifold` to `@Manifold` class directory

## Next Steps
This migration is the first step in the larger architectural restructuring that will:
1. ✓ Move conversion functions to `bct.io.convert` (COMPLETED)
2. Migrate `bct.manifold` package to `@Manifold` class directory
3. Introduce new Domain system (Manifold, Time, Lambda, Omega)
4. Deprecate `bct.manifold.Time` in favor of new `bct.@Time` class
5. Reduce code bloat in `bct.bct.m` through modularization
