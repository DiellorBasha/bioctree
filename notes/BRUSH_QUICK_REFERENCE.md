# BCT Brush System - Quick Reference

**For Users:** This guide shows how to use the new brush system.  
**For Developers:** See `BrushContract.md` for complete technical reference.

---

## Basic Usage (Backward Compatible)

The simplest way to use brushes - existing code continues to work:

```matlab
% Load mesh
M = bct.Manifold(V, F);

% Apply brush with parameters
params = struct('center', 1000, 'radius', 20);
w = bct.brush.apply('patch_gaussian', M, params);
```

---

## Available Brushes

### Patch Brushes (Spatial Selection)
- `patch_nearest` - K-nearest neighbors
- `patch_gaussian` - Gaussian kernel with radius
- `patch_spectral` - Spectral-filtered selection

### Trajectory Brushes (Path-based)
- `trajectory_geodesic` - Geodesic distance along path
- `trajectory_gaussian` - Gaussian kernel along path
- `trajectory_spectral` - Spectral-filtered trajectory

### Time Brushes (Spatiotemporal)
- `time_heat` - Heat diffusion over time
- `time_spectral` - Spectral-filtered spatiotemporal

---

## Discovery

### List All Available Brushes
```matlab
ids = bct.registry.brushes('list');
% Returns: ["patch_nearest", "patch_gaussian", ...]
```

### Find Compatible Brushes for Your Mesh
```matlab
M = bct.Manifold(V, F);
availableIds = bct.runtime.brushes('list', M);
% Returns only brushes that work with M
```

### Get Brush Information
```matlab
spec = bct.registry.brushes('get', 'patch_spectral');
fprintf('Name: %s\n', spec.Name);
fprintf('Category: %s\n', spec.Category);
fprintf('Parameters: %s\n', strjoin(spec.ParamNames, ', '));
```

---

## Parameters

### Get Default Parameters
```matlab
M = bct.Manifold(V, F);
spec = bct.registry.brushes('get', 'patch_gaussian');

% Defaults are context-specific (depend on mesh size)
defaults = spec.DefaultParams(M);
% Example: defaults.radius = 0.05 * characteristic_length
```

### Get Parameter Ranges
```matlab
ranges = spec.ParamRanges(M);
% Example: ranges.radius = [min_edge_length, mesh_diameter]
```

### Override Parameters
```matlab
% User params override defaults
userParams = struct('center', 5000, 'radius', 30);
w = bct.brush.apply('patch_gaussian', M, userParams);
```

---

## Advanced Usage

### Direct Evaluation
```matlab
spec = bct.registry.brushes('get', 'patch_spectral');
params = spec.DefaultParams(M);
params.center = 1000;  % Override center
params.numModes = 150; % Override number of modes
w = spec.Evaluate(M, params);
```

### Context-Aware Resolution
```matlab
context = struct(...
    'manifold', M, ...
    'params', struct('center', 1000));

spec = bct.runtime.brushes('resolve', 'patch_gaussian', context);
% spec.DefaultParamsResolved contains merged parameters
w = spec.Evaluate(M, spec.DefaultParamsResolved);
```

### Filter by Requirements
```matlab
% Get all brushes
defs = bct.registry.brushes();

% Find brushes that require eigenpairs
spectralBrushes = defs(contains({defs.Requires}, 'Eigenpairs'));
```

---

## Parameter Reference

### Patch Brushes

**patch_nearest**
- `center` (integer): Seed vertex index [1, N]
- `k` (integer): Number of neighbors [1, N]

**patch_gaussian**
- `center` (integer): Seed vertex index [1, N]
- `radius` (double): Spatial extent (geodesic distance)

**patch_spectral**
- `center` (integer): Seed vertex index [1, N]
- `numModes` (integer): Number of eigenmodes [1, N]
- `bandwidth` (double): Spectral kernel width [0, ∞)

### Trajectory Brushes

**trajectory_geodesic**
- `path` (integer array): Vertex indices defining trajectory
- `width` (double): Spatial extent perpendicular to path

**trajectory_gaussian**
- `path` (integer array): Vertex indices
- `width` (double): Gaussian kernel width

**trajectory_spectral**
- `path` (integer array): Vertex indices
- `numModes` (integer): Number of eigenmodes
- `bandwidth` (double): Spectral kernel width

### Time Brushes

**time_heat**
- `center` (integer): Initial seed vertex
- `numTimeSteps` (integer): Temporal resolution
- `maxTime` (double): Total diffusion time
- `numModes` (integer): Eigenmodes for computation

**time_spectral**
- `center` (integer): Seed vertex
- `numModes` (integer): Spatial eigenmodes
- `numFreqs` (integer): Temporal frequencies
- `spatialBandwidth` (double): Spatial filtering
- `temporalBandwidth` (double): Temporal filtering

---

## Common Patterns

### Pattern 1: Interactive Selection
```matlab
% Let user click on mesh
centerIdx = userSelection();  % Your UI code

% Apply brush at clicked location
params = struct('center', centerIdx);
w = bct.brush.apply('patch_gaussian', M, params);
```

### Pattern 2: ROI Analysis
```matlab
% Define region of interest
roi_params = struct('center', 1500, 'radius', 25);
w = bct.brush.apply('patch_gaussian', M, roi_params);

% Use weights for analysis
roi_signal = signal .* w;  % Weight signal by ROI
```

### Pattern 3: Path-Based Filtering
```matlab
% Define anatomical pathway
path = [100, 150, 200, 250, 300];  % Vertex indices
params = struct('path', path, 'width', 10);
w = bct.brush.apply('trajectory_gaussian', M, params);
```

### Pattern 4: Spatiotemporal Analysis
```matlab
% Heat diffusion from seed
params = struct(...
    'center', 1000, ...
    'numTimeSteps', 50, ...
    'maxTime', 1.0);
W = bct.brush.apply('time_heat', M, params);
% W is N×T matrix
```

---

## Performance Tips

### Caching
The runtime system automatically caches brush dictionaries:
```matlab
% First call: builds cache
dict1 = bct.runtime.brushes('dictionary', M);

% Subsequent calls: uses cache (fast)
dict2 = bct.runtime.brushes('dictionary', M);

% Clear cache if needed
bct.runtime.brushes('clear');
```

### Eigenpair Reuse
Spectral brushes compute eigenpairs once per session:
```matlab
% First spectral brush: computes eigenpairs
w1 = bct.brush.apply('patch_spectral', M, params1);

% Second spectral brush: reuses cached eigenpairs (fast)
w2 = bct.brush.apply('time_heat', M, params2);
```

### Pre-compute for Interaction
```matlab
% Pre-compute expensive parts
spec = bct.registry.brushes('get', 'patch_spectral');
defaults = spec.DefaultParams(M);

% Fast interactive updates (just change center)
for centerIdx = selectedVertices
    params = defaults;
    params.center = centerIdx;
    w = spec.Evaluate(M, params);
    % Update visualization
end
```

---

## Troubleshooting

### "Unknown brush" Error
```matlab
% Check available brushes
ids = bct.runtime.brushes('list', M);
% Make sure your brushId is in the list
```

### "Brush requires FEM" Error
```matlab
% Some brushes need FEM capabilities
% Check if manifold supports FEM
if hasMethod(M, 'FEM')
    % OK to use spectral brushes
else
    % Use geometric brushes only
end
```

### Parameter Out of Range
```matlab
% Get valid ranges
spec = bct.registry.brushes('get', 'patch_gaussian');
ranges = spec.ParamRanges(M);
fprintf('radius range: [%.2f, %.2f]\n', ranges.radius);
```

### Slow Performance
```matlab
% Check if caching is working
bct.runtime.brushes('clear');  % Clear cache
tic;
dict1 = bct.runtime.brushes('dictionary', M);
t1 = toc;  % Should be ~100-500ms

tic;
dict2 = bct.runtime.brushes('dictionary', M);
t2 = toc;  % Should be <1ms (cached)

fprintf('Cache speedup: %.0fx\n', t1/t2);
```

---

## Migration from Old Code

### Before (Old Style)
```matlab
% Old registry system
R = bct.brush.registry();
alg = R.patch_gaussian.Algorithm;
w = alg(M, params);
```

### After (New Style)
```matlab
% New system (but old style still works!)
w = bct.brush.apply('patch_gaussian', M, params);
```

**No changes needed** - your existing code continues to work!

---

## Getting Help

1. **Quick reference:** This file
2. **Complete reference:** `notes/BrushContract.md`
3. **Integration details:** `notes/BRUSH_INTEGRATION_PLAN.md`
4. **Examples:** Run `test_brush_integration.m`

---

## Example Session

```matlab
%% Setup
M = bct.Manifold(V, F);

%% Explore available brushes
ids = bct.runtime.brushes('list', M);
fprintf('Available: %s\n', strjoin(ids, ', '));

%% Try a simple patch brush
params = struct('center', 1000, 'radius', 20);
w = bct.brush.apply('patch_gaussian', M, params);
figure; bct.show.mesh(M); bct.show.signal(w);

%% Try a spectral brush
params = struct('center', 1000, 'numModes', 100, 'bandwidth', 0.05);
w = bct.brush.apply('patch_spectral', M, params);
figure; bct.show.mesh(M); bct.show.signal(w);

%% Try a trajectory brush
path = [1000, 1100, 1200, 1300];  % Define path
params = struct('path', path, 'width', 15);
w = bct.brush.apply('trajectory_gaussian', M, params);
figure; bct.show.mesh(M); bct.show.signal(w);
```

---

**Last Updated:** 2024  
**Related:** `BrushContract.md`, `BRUSH_INTEGRATION_PLAN.md`, `BRUSH_INTEGRATION_COMPLETE.md`
