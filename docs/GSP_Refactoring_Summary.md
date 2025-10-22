# GSP Directory Refactoring Summary

## Overview
Successfully refactored the old `gsp/` directory structure to consolidate functionality into appropriate locations within the existing toolbox organization.

## Changes Made

### Files Moved

#### IO Functions → `io/`
- `gsp/io/exportDerivedMaps.m` → `io/exportDerivedMaps.m`
- `gsp/io/loadBrainstormSource.m` → `io/loadBrainstormSource.m`

#### Graph Utilities → `toolbox/graphs/` (newly created)
- `gsp/graph/ensureLaplacian.m` → `toolbox/graphs/ensureLaplacian.m`
- `gsp/graph/fromCortex.m` → `toolbox/graphs/fromCortex.m`

#### Graph Operators → `toolbox/operators/` (newly created)
- `gsp/ops/graphDivergence.m` → `toolbox/operators/graphDivergence.m`
- `gsp/ops/graphGradient.m` → `toolbox/operators/graphGradient.m`
- `gsp/ops/graphTotalVariation.m` → `toolbox/operators/graphTotalVariation.m`

### Empty Directories Removed
- `gsp/examples/` (empty) 
- `gsp/filters/` (empty)
- `gsp/transforms/` (empty)
- `gsp/utils/` (empty)
- `gsp/viz/` (empty)
- `gsp/dgw/` (empty)

### Directory Structure Cleanup
- **Removed**: Entire `gsp/` directory tree
- **Created**: `toolbox/graphs/` for graph construction utilities
- **Created**: `toolbox/operators/` for graph differential operators

### Updated References
- **Modified `bioctree_start.m`**: 
  - Removed `addpath(genpath(fullfile(bioctree_root, 'gsp')))` 
  - Updated functionality descriptions to reflect new locations
  - Updated module paths to point to `toolbox/graphs/` and `toolbox/operators/`

## New Organization

### IO Functions (`io/`)
- `exportDerivedMaps.m` - Export derived per-vertex maps for downstream applications
- `loadBrainstormSource.m` - Load Brainstorm source results and anatomy

### Graph Utilities (`toolbox/graphs/`)
- `ensureLaplacian.m` - Compute/update Laplacian matrix for GSPBOX graphs
- `fromCortex.m` - Create GSPBOX graph from cortical surface mesh

### Graph Operators (`toolbox/operators/`)
- `graphDivergence.m` - Compute graph divergence operator (adjoint of gradient)
- `graphGradient.m` - Compute graph gradient operator on signals
- `graphTotalVariation.m` - Compute total variation of graph signals

## Benefits
1. **Cleaner organization**: Functions grouped by purpose rather than legacy structure
2. **No conflicts**: Eliminates confusion between old `gsp/` and external GSPBox
3. **Better discoverability**: IO functions with other IO functions, graph utilities together
4. **Maintained functionality**: All functions remain accessible via updated paths
5. **Future-proof**: Clear separation between local utilities and external GSPBox plugin

## Verification
- ✅ All files successfully moved to new locations
- ✅ Old `gsp/` directory completely removed
- ✅ `bioctree_start()` function updated and tested
- ✅ Functions accessible in new locations (`which` commands confirm paths)
- ✅ No functionality lost in the refactoring

The Bioctree toolbox now has a cleaner structure with GSPBox as the sole GSP plugin in `external/gspbox/` and all custom graph utilities properly organized in `toolbox/` subdirectories.