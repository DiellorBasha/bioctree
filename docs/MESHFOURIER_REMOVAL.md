# meshFourier Removal - Migration Guide

## Summary
Removed `bct.Manifold.meshFourier` static method. Eigenbasis computation should now be done through `bct.Lambda.eigenbasis()` with orchestration by the main `bct` class.

## Correct Pattern

### OLD (Incorrect - Removed):
```matlab
% Don't do this anymore
[U, lam] = bct.Manifold.meshFourier(mesh, k);
M.meshFourier(100);  % This method no longer exists
```

### NEW (Correct):
```matlab
% Method 1: Using bct class orchestration (RECOMMENDED)
B = bct.bct.fromMesh(V, F);
B = B.computeEigenbasis(500);  % Orchestrates Manifold→Lambda eigenbasis

% Method 2: Manual (for advanced usage)
M = bct.Manifold(struct('V', V, 'F', F));
eigenStruct = struct('eigenvalues', [], 'eigenvectors', []);
L = bct.Lambda(eigenStruct);
L = L.eigenbasis(M.MassMatrix, M.CotangentMatrix, 500);
```

## Files Updated

### Core Implementation (COMPLETED ✓):
1. **toolbox/+bct/@Manifold/meshFourier.m** - DELETED
2. **toolbox/+bct/@Manifold/Manifold.m** - Removed meshFourier from static methods
3. **toolbox/+bct/@Manifold/estimateLambdaMax.m** - Updated comments
4. **toolbox/+bct/@Manifold/maxLambda.m** - Updated See also
5. **toolbox/+bct/@Lambda/eigenbasis.m** - Updated See also
6. **toolbox/+bct/@bct/bct.m** - Updated comments (3 locations)

### Tests Updated (COMPLETED ✓):
1. **tests/unit/TestManifold.m** - Removed all 6 meshFourier tests
2. **tests/unit/TestLambda.m** - Updated to use eigenbasis pattern
3. **tests/unit/TestJoint.m** - Updated to use eigenbasis pattern

### Files Still Containing meshFourier References (Need Manual Review):

#### Test/Example Scripts (Non-critical):
- `tests/unit/test_resolution_auto.m` (lines 27-28)
- `tests/unit/test_manifold_gaussian_filter.m` (lines 25-27)
- `tests/unit/test_filter_workflow.m` (line 4 - comment only)
- `tests/unit/test_filter_class.m` (line 19)
- `tests/unit/test_domain_transforms.m` (lines 100, 102)
- `tests/performance/PerfEigenSolve.m` (multiple lines)

#### Experimental/Legacy Files (Can be ignored):
- `experimental/tt3.m`
- `experimental/toolbox_legacy/transforms/meshFourier.m` (old copy)
- `experimental/toolbox_legacy/simulations/*`
- `experimental/toolbox_legacy/bct_cot_fourier.m`

#### Documentation (Need updates):
- `docs/architecture_overview.md` (lines 56, 197)
- `docs/TRANSFORM_USAGE.md` (lines 48, 180, 190, 216, 218)

## Key Architecture Points

1. **Manifold** only provides:
   - `MassMatrix` (from cotmatrix)
   - `CotangentMatrix` (from massmatrix)
   - `Laplacian` (computed property)
   - No eigenbasis computation

2. **Lambda** handles eigenbasis:
   - `eigenbasis(MassMatrix, CotangentMatrix, k)` method
   - Stores U (eigenvectors) and lambda (eigenvalues)
   - Called by bct.computeEigenbasis()

3. **bct** orchestrates:
   - `computeEigenbasis(k)` calls Lambda.eigenbasis with Manifold's matrices
   - Handles transform initialization for both domains
   - Maintains dual relationships

## Migration for Existing Code

Replace:
```matlab
M = bct.Manifold(struct('V', V, 'F', F));
[U, lam] = bct.Manifold.meshFourier(M, 500);
```

With:
```matlab
B = bct.bct.fromMesh(V, F);
B = B.computeEigenbasis(500);
U = B.Lambda.U;
lam = B.Lambda.lambda;
```

## Status
- ✅ Core implementation cleaned
- ✅ Main unit tests updated
- ⏳ Test scripts need manual review/update
- ⏳ Documentation needs updates
- ✅ No meshFourier in Manifold class
