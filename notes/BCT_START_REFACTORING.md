# BCT Initialization System Refactoring

## Summary

This refactoring replaces the old `bioctree_*` naming convention with `bct_*` for initialization scripts and configuration files, aligning with the +bct package structure.

## Files Created

### 1. bct_start.m
New initialization script that:
- Loads configuration from `bct_config()`
- Adds core paths (toolbox, data, examples, tests, docs)
- Initializes external dependencies:
  * **DECLab**: Discrete Exterior Calculus backend
  * **GSPBox**: Graph signal processing (calls `gsp_start()`)
  * **GPToolbox**: Geometry processing mesh utilities
- Validates +bct package classes and subpackages
- Prints system diagnostics and quick start guide
- Provides clean, professional output with Unicode box drawing

### 2. config/bct_config.m
Configuration loader that:
- Reads `bct_paths.json` and `bct_dependencies.json`
- Constructs absolute paths from relative paths in JSON
- Returns cfg struct with:
  * Core paths: root, toolbox, package, external
  * Data paths: data, mesh (with standard meshes)
  * Code paths: apps, app_code, examples, scripts
  * Dependencies manifest

### 3. config/bct_paths.json
Path definitions for:
- toolbox (contains +bct package)
- external dependencies
- app_code, data, examples, apps, scripts
- standard_meshes (fsaverage_lh_pial, fsaverage_rh_pial)

### 4. config/bct_dependencies.json
External dependency manifest with:
- **gptoolbox**: Geometry processing
- **gspbox**: Graph signal processing
- **DECLab**: Discrete Exterior Calculus (NEW)
- Each entry includes: repo URL, commit hash, key files

## Files Modified

### bioctree_start.m
Deprecated with:
- Warning message directing users to `bct_start()`
- Wrapper that calls `bct_start()` internally
- Maintains backward compatibility

## Changes from Old System

### Naming
- `bioctree_start` → `bct_start`
- `bioctree_config` → `bct_config`
- `bioctree_paths.json` → `bct_paths.json`
- `bioctree_dependencies.json` → `bct_dependencies.json`

### External Dependencies
Old system added:
- gspbox (full tree)
- gptoolbox/mesh only
- DECLab (full tree)

New system is clearer about:
- **DECLab**: Now explicitly listed in dependencies manifest
- **GSPBox**: Properly initialized with `gsp_start()`
- **GPToolbox**: Only mesh subdir (no other components)

### Validation
Old system validated:
- bct.bct (orchestrator class)
- Various domain classes

New system validates:
- **Core classes**: bct.Manifold, bct.FEM, bct.Graph, bct.DEC, bct.Eigenpairs
- **Subpackages**: +fem, +graph, +dec, +eigenpairs, +registry, +runtime
- Checks directory existence for packages (not just class availability)

## Usage

### New Way (Recommended)
```matlab
bct_start()
```

### Old Way (Deprecated but functional)
```matlab
bioctree_start()  % Shows warning, then calls bct_start()
```

## Quick Start Example

After running `bct_start()`:

```matlab
% Load test mesh
data = load('data/mesh/fsaverage_rh_pial.mat');
M = bct.Manifold(data.V, data.F);

% Create representations
F = M.FEM();      % Finite Element Method
G = M.Graph();    % Graph/Network
D = M.DEC();      % Discrete Exterior Calculus

% Use operator registry/runtime
specs = bct.registry.operators();
ctx = bct.runtime.context(M, 'FEM', true);
ops = bct.runtime.operators(ctx);
```

## Verification

Tested with:
```matlab
matlab -batch "bct_start"
```

Output shows:
✓ All config files loaded correctly
✓ All core paths added
✓ External dependencies initialized (DECLab, GSPBox, GPToolbox)
✓ All +bct classes and packages validated
✓ System diagnostics passed

## Backward Compatibility

The old `bioctree_start` script:
- Still works (calls `bct_start` internally)
- Shows deprecation warning
- Guides users to update their scripts
- Will be removed in future major release

## Next Steps

1. Update any remaining references to `bioctree_start` in:
   - Documentation
   - Example scripts
   - Test files
   - README files

2. Consider removing old config files:
   - bioctree_config.m (no longer used)
   - bioctree_paths.json (replaced by bct_paths.json)
   - bioctree_dependencies.json (replaced by bct_dependencies.json)

3. Update .gitignore if needed

## Architecture Notes

This refactoring maintains the three-tier representation architecture:
- **Manifold** → {FEM, Graph, DEC}
- FEM: Variational formulation (stiffness/mass matrices)
- Graph: Network representation (adjacency, Laplacian)
- DEC: Exterior calculus (differential forms, Hodge star)

All three representations use the same operator registry/runtime system for interoperability.
