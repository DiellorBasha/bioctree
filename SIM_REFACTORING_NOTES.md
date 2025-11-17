# bct.sim Package Refactoring Summary

## Overview
Successfully refactored the `bct.sim` package to move simulation functions out of the `sim` class and adapt them to work directly with `B.Manifold` objects, eliminating the need for file I/O operations.

## Changes Made

### 1. New Standalone Simulation Functions

All functions now accept a `Bct` object as the first parameter and use `B.Manifold` for topology and geometry:

#### `bct.sim.gaussian(B, varargin)`
- **Purpose**: Generate static Gaussian spatial activation patterns
- **Key Features**:
  - Center selection: node index or auto (nearest to centroid)
  - Distance modes: 'euclidean' (from coordinates) or 'geodesic' (graph shortest paths)
  - Customizable sigma and amplitude
- **Manifold Integration**:
  - Uses `size(B.Manifold.V, 1)` for vertex count
  - Uses `B.Manifold.V` for coordinates (euclidean distance)
  - Uses `B.Manifold.adjacency()` for graph topology (geodesic distance)

#### `bct.sim.gaussian_growth(B, varargin)`
- **Purpose**: Generate time series with growing Gaussian width
- **Key Features**:
  - Configurable time points (T) and sampling rate (fs)
  - Auto-selects center and sigma range based on graph diameter
  - Returns T×N time series
- **Manifold Integration**:
  - Same as `gaussian()` plus temporal dimension
  - Automatically computes graph diameter from geodesic distances

#### `bct.sim.patch_signal(B, varargin)`
- **Purpose**: Generate patch signals with optional temporal dynamics
- **Key Features**:
  - Static, growing, moving, or grow-and-move patches
  - Center selection: auto (graph center), random, or specified node
  - Customizable patch size, value, and background
- **Manifold Integration**:
  - Uses `B.Manifold.adjacency()` for graph-based patch selection
  - Uses geodesic distances via MATLAB's `graph()` object
  - Computes graph-theoretic center (minimum eccentricity node)

#### `bct.sim.synth_mesh_signal(B, spec, varargin)`
- **Purpose**: Synthesize graph signals from spectral power specifications
- **Key Features**:
  - Multiple spectral types: narrowband, twoband, flat, powerlaw, bandpass
  - Uses graph Laplacian eigenbasis
  - Configurable number of eigenvectors (k)
- **Manifold Integration**:
  - Uses `B.Manifold.laplacian()` for spectral decomposition
  - Computes eigenpairs with sparse eigs for efficiency

### 2. Updated sim Class for Backward Compatibility

The `bct.sim.sim` class now serves as a thin wrapper that delegates to the new package functions:

```matlab
function x = gaussian(obj, varargin)
    % Delegate to bct.sim.gaussian package function
    x = bct.sim.gaussian(obj.B, varargin{:});
end

function X_TN = gaussian_growth_default(obj, varargin)
    % Delegate to bct.sim.gaussian_growth package function
    X_TN = bct.sim.gaussian_growth(obj.B, varargin{:});
end
```

**Removed Methods** (as requested):
- `nodeDistances()` - moved to inline in new functions
- `nearestNodeIdx()` - moved to inline in new functions
- Helper methods are now duplicated where needed to keep functions self-contained

The `write_layer()` method remains in the class since it handles BCT file persistence, not simulation logic.

### 3. Architecture Benefits

**Before**: Class-based with file I/O dependencies
```matlab
S = bct.sim.sim(B);  % Requires file-backed Bct object
x = S.gaussian(...); % Accesses obj.Gsp.W from file
```

**After**: Functional with Manifold integration
```matlab
B = bct.io.graph.Import.fromFreeSurfer('lh.pial');
x = bct.sim.gaussian(B, ...);  % Uses B.Manifold directly
```

**Key Improvements**:
1. **No File I/O**: Functions work with in-memory Manifold objects
2. **Cleaner API**: Direct function calls instead of class methods
3. **Better Separation**: Simulation logic separated from data persistence
4. **Manifold Integration**: Leverages unified topology interface

### 4. Manifold Access Patterns

All simulation functions now use these Manifold patterns:

```matlab
% Get vertex count
N = size(B.Manifold.V, 1);

% Get coordinates for euclidean distance
coords = B.Manifold.V;  % N×3 single

% Get adjacency matrix for geodesic distance
A = B.Manifold.adjacency();  % sparse N×N
Gm = graph(A, 'OmitSelfLoops');
distances = distances(Gm, center_node, 'Method', 'positive');

% Get Laplacian for spectral decomposition
L = B.Manifold.laplacian();  % sparse N×N
[U, lam] = eigs(L, k, 'smallestabs');
```

## Testing

Created `test_sim_refactor.m` which validates:
- ✅ Gaussian signal generation with custom parameters
- ✅ Gaussian growth time series (T×N)
- ✅ Static patch signals
- ✅ Spectral synthesis from power specifications
- ✅ Backward compatibility with `bct.sim.sim` class

**Test Results**:
- All core functions work correctly with Manifold objects
- Output dimensions and types verified (N×1 single precision)
- Backward compatibility maintained (correlation = 1.0000)

## Files Created/Modified

### New Files
- `toolbox/+bct/+sim/gaussian.m` (157 lines)
- `toolbox/+bct/+sim/gaussian_growth.m` (112 lines)
- `toolbox/+bct/+sim/patch_signal.m` (275 lines)
- `toolbox/+bct/+sim/synth_mesh_signal.m` (150 lines)
- `test_sim_refactor.m` (140 lines)

### Modified Files
- `toolbox/+bct/+sim/sim.m` - Updated to delegate to package functions

### Unchanged Files (Legacy)
- `toolbox/simulations/*.m` - Original functions remain for reference

## Usage Examples

### Basic Gaussian Signal
```matlab
B = bct.io.graph.Import.fromFreeSurfer('lh.pial');
x = bct.sim.gaussian(B, 'center', 100, 'sigma', 10);
```

### Growing Gaussian Time Series
```matlab
X = bct.sim.gaussian_growth(B, 'T', 200, 'fs', 20);
% Returns 200×N time series with growing spatial extent
```

### Patch with Movement
```matlab
X = bct.sim.patch_signal(B, ...
    'T', 50, ...
    'growthMode', 'move', ...
    'moveDirection', 'random');
```

### Spectral Synthesis
```matlab
spec.type = 'narrowband';
spec.f0 = 0.1;
spec.bw_abs = 0.02;
[x, coeffs, freqs] = bct.sim.synth_mesh_signal(B, spec);
```

## Next Steps

1. **Additional Simulations**: Refactor remaining functions in `toolbox/simulations/`:
   - `generateSpatioTemporalPattern.m`
   - `generateRippleSurface.m`
   - `generateLineNoiseToWave.m`
   - etc.

2. **Documentation**: Add comprehensive examples to each function's help

3. **Performance**: Profile functions with large meshes (e.g., fsaverage)

4. **Integration**: Update workflows that use simulation functions

## Migration Guide

For users with existing code using the `sim` class:

**Old Code** (still works):
```matlab
S = bct.sim.sim(B);
x = S.gaussian('center', 1, 'sigma', 5);
```

**New Code** (recommended):
```matlab
x = bct.sim.gaussian(B, 'center', 1, 'sigma', 5);
```

Both approaches work identically due to the delegation pattern in the updated `sim` class.
