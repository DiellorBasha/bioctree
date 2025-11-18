# UV Parametrization from FreeSurfer Spherical Registration

## Overview

Extended the BCT mesh import pipeline to automatically load FreeSurfer spherical registration files (`.sphere.reg`) and compute UV parametrization for texture mapping and 2D visualization.

## Implementation Details

### 1. Manifold Class Enhancement

**File**: `toolbox/+bct/+manifold/Manifold.m`

Added new property:
```matlab
UV double = []    % N×2 UV parametrization (from spherical registration)
```

### 2. Import Pipeline Extension

**File**: `toolbox/+bct/+io/+import/mesh.m`

Modified FreeSurfer import to:
1. Automatically detect corresponding `.sphere.reg` file
2. Load spherical coordinates
3. Compute UV parametrization
4. Store in `B.Manifold.UV`

### 3. Helper Functions

**File**: `toolbox/+bct/+io/+import/findSphereReg.m`

Locates the corresponding `.sphere.reg` file for a FreeSurfer surface:
- Given: `lh.pial` or `rh.pial`
- Finds: `lh.sphere.reg` or `rh.sphere.reg` in same directory

**File**: `toolbox/+bct/+io/+import/computeUVFromSphere.m`

Converts spherical coordinates to UV parametrization:
```matlab
theta = atan2(y, x)      % Azimuthal angle [-π, π]
phi   = acos(z)          % Polar angle [0, π]
u = (theta + π) / (2π)   % Normalize to [0, 1]
v = phi / π              % Normalize to [0, 1]
```

## Usage

### Basic Import
```matlab
path = 'test-data/freesurfer/fsaverage/surf/lh.pial';
B = bct.io.import.mesh(path);

% Check if UV is available (UV is OPTIONAL)
if B.Manifold.checkUV(false)  % Warns if missing, returns true/false
    UV = B.Manifold.UV;  % [N×2] matrix
    fprintf('UV available\n');
else
    fprintf('UV not available - sphere.reg not found\n');
end
```

### UV Validation Methods

**checkUV(false)** - Warning mode (recommended for optional UV features)
```matlab
if B.Manifold.checkUV(false)
    % UV is available - use it
    plot_in_uv_space(B.Manifold.UV, signal_data);
else
    % UV not available - use fallback
    plot_on_3d_mesh(B.Manifold.V, signal_data);
end
```

**checkUV(true)** - Error mode (for UV-dependent operations)
```matlab
try
    B.Manifold.checkUV(true);  % Throws error if UV missing
    % Proceed with UV-required operation
    texture_map = apply_texture(B.Manifold.UV, texture_data);
catch ME
    fprintf('Cannot proceed: %s\n', ME.message);
end
```

### Behavior
- **UV is OPTIONAL**: Not all meshes will have UV parametrization
- If `.sphere.reg` exists in same directory → UV automatically computed and stored
- If `.sphere.reg` not found → `B.Manifold.UV` remains empty (no error during import)
- Console message printed when spherical registration is successfully loaded
- Functions requiring UV should call `B.Manifold.checkUV()` for validation

### Safe UV Usage Pattern
```matlab
% Pattern 1: Optional UV feature with fallback
if B.Manifold.checkUV(false)  % Warns but doesn't error
    % Use UV-based visualization
    visualize_in_uv_space(B.Manifold.UV, data);
else
    % Fallback to 3D visualization
    visualize_on_mesh(B.Manifold.V, data);
end

% Pattern 2: UV required (will error if missing)
B.Manifold.checkUV(true);  % Throws error if UV not available
process_uv_texture(B.Manifold.UV, texture);
```

### Visualization
```matlab
% Visualize signal in UV space
trisurf(B.Manifold.F, B.Manifold.UV(:,1), B.Manifold.UV(:,2), ...
    zeros(size(B.Manifold.UV, 1), 1), signal_data);
view(2);
xlabel('U'); ylabel('V');
```

## Applications

1. **Texture Mapping**: UV coordinates enable texture mapping onto cortical surfaces
2. **2D Visualization**: Flatten 3D surface signals to 2D parametric space
3. **Feature Extraction**: Analyze patterns in UV space
4. **Cross-Subject Registration**: Common parametrization for group analysis

## File Structure

FreeSurfer directory structure:
```
test-data/freesurfer/fsaverage/surf/
├── lh.pial          ← Surface geometry
├── lh.sphere.reg    ← Spherical registration (auto-loaded)
├── rh.pial
└── rh.sphere.reg
```

## Testing

Run validation tests:
```matlab
run('tests/test_uv_validation.m')  % Tests checkUV() method
```

Run comprehensive tests:
```matlab
run('tests/test_uv_parametrization.m')  % Tests import pipeline
```

Run example:
```matlab
run('examples/example_uv_parametrization.m')
```

## API Reference

### Manifold.checkUV(throw_error)

Validates UV parametrization availability.

**Syntax:**
```matlab
hasUV = manifold.checkUV()           % Returns true/false, warns if missing
hasUV = manifold.checkUV(false)      % Same as above (explicit)
hasUV = manifold.checkUV(true)       % Returns true/false, errors if missing
```

**Parameters:**
- `throw_error` (logical, optional): If true, throws error when UV missing. Default: false

**Returns:**
- `hasUV` (logical): true if UV parametrization exists, false otherwise

**Behavior:**
- When UV missing and `throw_error=false`: Issues warning, returns false
- When UV missing and `throw_error=true`: Throws error with ID `bct:Manifold:NoUV`
- When UV present: Returns true, no warning/error

**Examples:**
```matlab
% Check with warning
if B.Manifold.checkUV(false)
    use_uv_features();
end

% Require UV (error if missing)
B.Manifold.checkUV(true);
mandatory_uv_operation();
```

## Technical Notes

### Coordinate System
- **Theta (θ)**: Azimuthal angle, measures rotation around z-axis
  - Range: [-π, π] → normalized to [0, 1] for U
- **Phi (φ)**: Polar angle, measures angle from north pole (z-axis)
  - Range: [0, π] → normalized to [0, 1] for V

### Hemisphere Detection
The `findSphereReg` function automatically detects hemisphere from filename prefix:
- `lh.*` → looks for `lh.sphere.reg`
- `rh.*` → looks for `rh.sphere.reg`

### Error Handling
- Missing `.sphere.reg`: Warning printed, UV remains empty, import continues
- Invalid sphere file: Warning printed, UV remains empty, import continues
- No errors thrown - graceful degradation

## Files Created/Modified

### Modified
- `toolbox/+bct/+manifold/Manifold.m` - Added UV property and checkUV() method
- `toolbox/+bct/+io/+import/mesh.m` - Extended import pipeline with UV validation

### Created
- `toolbox/+bct/+io/+import/findSphereReg.m` - Sphere file locator
- `toolbox/+bct/+io/+import/computeUVFromSphere.m` - UV computation
- `tests/test_uv_validation.m` - UV validation tests
- `tests/test_uv_parametrization.m` - Comprehensive import tests
- `examples/example_uv_parametrization.m` - Usage example
- `examples/uv_quick_reference.m` - Quick reference guide
- `docs/uv_parametrization.md` - This documentation

## Future Enhancements

Potential extensions:
1. Support for other parametrization methods (conformal, area-preserving)
2. Custom UV computation for non-spherical surfaces
3. UV-based texture mapping utilities
4. UV-space signal processing functions
