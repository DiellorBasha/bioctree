# Eigenpairs Refactoring Summary

## Overview

Refactored the Eigenpairs architecture to follow modern MATLAB namespacing and the EigenpairsContract design principles.

## Key Changes

### 1. **Eigenpairs Class** (`toolbox/+bct/Eigenpairs.m`)

**Before:**
- Class had static factory method `fromLaplaceBeltrami()`
- Mixed responsibilities: data container + algorithm

**After:**
- Pure immutable data container
- Removed all static factory methods
- Added introspection methods:
  - `numModes()` - get number of modes
  - `domainSize()` - get spatial dimension
  - `energy(coeffs)` - compute spectral energy
  - `subselect(indices)` - create subset
  - `truncate(k)` - keep first k modes
  - `bandlimit(range)` - filter by eigenvalue range

### 2. **Factory Functions Package** (`toolbox/+bct/+eigenpairs/`)

Created new package with algorithm/workflow functions:

**Core factory:**
- `fromFEM.m` - Create eigenpairs from FEM representation

**Algorithm utilities:**
- `solveGeneralized.m` - Solve K*u = λ*M*u eigenproblem
- `normalize.m` - Enforce M-orthonormality
- `removeDC.m` - Remove DC (constant) mode

**Validation & transformation:**
- `validate.m` - Check invariants (dimensions, orthonormality, ordering)
- `reorder.m` - Change eigenvalue ordering
- `merge.m` - Combine two Eigenpairs objects

### 3. **FEM Class Update** (`toolbox/+bct/FEM.m`)

**Before:**
```matlab
E = bct.Eigenpairs.fromLaplaceBeltrami(Mass, Stiffness, k, id, ...);
```

**After:**
```matlab
E = bct.eigenpairs.fromFEM(obj, k, 'RemoveDC', true);
```

FEM is now a **client** of the factory, not calling static methods on Eigenpairs.

## Architecture Benefits

### Follows EigenpairsContract:

1. **Eigenpairs owns meaning** (invariants, identity)
2. **bct.eigenpairs owns algorithms** (construction, derivation, transformation)
3. **Clear separation of concerns**
4. **Immutability enforced** (no mutation methods)
5. **Easy testing** (factories can be tested independently)
6. **Modular algorithms** (easy to add new factories for DEC, Graph)

## Usage Examples

### Creating Eigenpairs

```matlab
% From FEM (recommended)
M = bct.Manifold(struct('V', V, 'F', F));
fem = M.FEM();
E = bct.eigenpairs.fromFEM(fem, 100);

% Or via FEM wrapper
E = fem.eigenpairs(100);

% Direct construction (if eigenpairs already computed)
E = bct.Eigenpairs(lambda, U, M, ...
    'operator', "Laplace-Beltrami", ...
    'basis', "P1-FEM", ...
    'manifoldID', id);
```

### Using Eigenpairs

```matlab
% Projection/reconstruction
coeffs = E.project(signal);
signal_recon = E.reconstruct(coeffs);

% Subselection
E_lowfreq = E.truncate(50);
E_band = E.bandlimit([0.1, 1.0]);
E_custom = E.subselect([1:10, 50:60]);

% Introspection
k = E.numModes();
N = E.domainSize();
energy = E.energy(coeffs);
```

### Utilities

```matlab
% Validation
isValid = bct.eigenpairs.validate(E);

% Normalization
U_norm = bct.eigenpairs.normalize(U, M);

% Merging
E_combined = bct.eigenpairs.merge(E1, E2);

% Reordering
E_desc = bct.eigenpairs.reorder(E, 'descending');
```

## Testing

Comprehensive test suite: `tests/test_eigenpairs_refactor.m`

Tests verify:
- ✓ Factory functions work
- ✓ FEM uses factories (not static methods)
- ✓ Eigenpairs operations (project, truncate, bandlimit)
- ✓ Utilities (validate, normalize, merge, reorder)
- ✓ M-orthonormality maintained
- ✓ Immutability enforced
- ✓ Architecture follows contract

## Migration Guide

### Old code:
```matlab
E = bct.Eigenpairs.fromLaplaceBeltrami(Mass, Stiffness, k, id);
```

### New code:
```matlab
E = bct.eigenpairs.fromFEM(fem, k);
```

### If you need direct construction:
```matlab
% Compute eigenpairs manually
[U, lambda] = bct.eigenpairs.solveGeneralized(K, M, k);
[U, lambda] = bct.eigenpairs.removeDC(U, lambda);
U = bct.eigenpairs.normalize(U, M);

% Create object
E = bct.Eigenpairs(lambda, U, M, ...
    'operator', "Custom", ...
    'basis', "Custom", ...
    'manifoldID', id);
```

## Future Extensions

Easy to add new factory functions:

- `bct.eigenpairs.fromDEC()` - For differential forms
- `bct.eigenpairs.fromGraph()` - For graph Laplacian
- `bct.eigenpairs.fromCustom()` - For arbitrary operators

All follow the same pattern:
1. Extract operators
2. Call `solveGeneralized()`
3. Apply normalization/transformations
4. Construct `bct.Eigenpairs` object

## Files Modified/Created

### Modified:
- `toolbox/+bct/Eigenpairs.m` - Removed static factory, added introspection methods
- `toolbox/+bct/FEM.m` - Updated to use `bct.eigenpairs.fromFEM`

### Created:
- `toolbox/+bct/+eigenpairs/fromFEM.m`
- `toolbox/+bct/+eigenpairs/solveGeneralized.m`
- `toolbox/+bct/+eigenpairs/normalize.m`
- `toolbox/+bct/+eigenpairs/removeDC.m`
- `toolbox/+bct/+eigenpairs/validate.m`
- `toolbox/+bct/+eigenpairs/reorder.m`
- `toolbox/+bct/+eigenpairs/merge.m`
- `tests/test_eigenpairs_refactor.m`
