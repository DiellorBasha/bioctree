# GSPBox Integration Summary

## Overview
Successfully integrated GSPBox graph generation functions into the Bioctree toolbox with automatic installation and initialization.

## Changes Made

### 1. Enhanced `bioctree_start.m`
- **Auto-cloning**: Automatically clones GSPBox from https://github.com/epfl-lts2/gspbox.git if not present
- **Auto-initialization**: Always runs `gsp_start()` when GSPBox is available
- **Path management**: Properly adds GSPBox to MATLAB path
- **Error handling**: Graceful fallback if GSPBox installation fails

### 2. Updated `createTestGraphWithTime.m`
Updated all graph creation functions to use GSPBox functions preferentially with custom fallbacks:

#### GSPBox Integration Details:
- **`createGrid2D()`**: Uses `gsp_2dgrid()` → Default: 100 vertices (10×10 grid)
- **`createSphere()`**: Uses `gsp_sphere()` → Default: 300 vertices
- **`createRandomGeometric()`**: Uses `gsp_sensor()` → Default: 64 vertices  
- **`createSwissRoll()`**: Uses `gsp_swiss_roll()` → Default: 200 vertices

#### Fallback Behavior:
- If GSPBox function fails or is unavailable, automatically falls back to custom implementation
- Warning messages inform user when fallback is used
- Maintains same API and functionality regardless of which implementation is used

## Default Graph Sizes (GSPBox)
When using GSPBox functions, these are the default vertex counts:
- `gsp_sphere()`: **300 vertices**
- `gsp_2dgrid(10)`: **100 vertices** (10×10 grid)
- `gsp_sensor()`: **64 vertices**
- `gsp_swiss_roll()`: **200 vertices**
- `gsp_bunny()`: **2503 vertices**

## Available GSPBox Graph Functions
Located in `external/gspbox/graphs/`:
- `gsp_2dgrid.m` - 2D grid graphs
- `gsp_sphere.m` - Spherical meshes
- `gsp_sensor.m` - Random sensor networks
- `gsp_swiss_roll.m` - Swiss roll manifolds
- `gsp_bunny.m` - Stanford bunny mesh
- `gsp_torus.m` - Torus graphs
- `gsp_cube.m` - Cube graphs
- `gsp_airfoil.m` - Airfoil meshes
- And many more...

## Usage
```matlab
% Initialize Bioctree (auto-installs GSPBox if needed)
bioctree_start();

% Create graphs using GSPBox functions (keeps default sizes)
G_sphere = createTestGraphWithTime('sphere');     % 300 vertices
G_grid = createTestGraphWithTime('grid2d');       % 100 vertices  
G_sensor = createTestGraphWithTime('random');     % 64 vertices
G_swiss = createTestGraphWithTime('swiss_roll');  % 200 vertices

% Add temporal structure for spatiotemporal patterns
G_sphere.jtv.T = 100;  % 100 time steps
G_sphere.jtv.fs = 20;  % 20 Hz sampling rate
```

## Key Benefits
1. **Seamless GSPBox integration** with automatic installation
2. **Preserves default GSPBox graph sizes** as requested
3. **Robust fallback system** ensures functionality even without GSPBox
4. **Maintains API compatibility** with existing spatiotemporal pattern functions
5. **Proper GSP structure** with G.W, G.coords, G.jtv fields

The spatiotemporal pattern generation suite (`generatePatchSignal.m`, `generateSpatioTemporalPattern.m`, etc.) now works seamlessly with authentic GSPBox graphs while maintaining full backward compatibility.