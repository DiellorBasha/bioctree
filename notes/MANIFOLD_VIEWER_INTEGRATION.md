# Manifold Integration with Viewer

## Overview

The `bct.ui.manifold.Viewer` component now supports direct integration with `bct.Manifold` objects, enabling automatic extraction and transfer of pre-computed geometric attributes (especially vertex normals) from MATLAB to the Three.js renderer.

## Key Benefits

1. **Performance**: Pre-computed normals in MATLAB (~0.5s) eliminate expensive JavaScript computation (~120ms for 163k vertices)
2. **Architecture**: Clean separation between computation (MATLAB/bct.Manifold) and rendering (JavaScript/Three.js)
3. **Flexibility**: Supports multiple input signatures for different use cases

## API Reference

### `setMesh` Method Signatures

```matlab
% Signature 1: Manifold object (recommended)
viewer.setMesh(manifold)

% Signature 2: Vertices and faces only
viewer.setMesh(V, F)

% Signature 3: Vertices, faces, and explicit normals
viewer.setMesh(V, F, N)
```

### Parameters

- **`manifold`** (`bct.Manifold`) - Manifold object with mesh geometry
  - Automatically extracts vertices via `manifold.Vertices` property
  - Automatically extracts faces via `manifold.Faces` property
  - Automatically computes normals via `manifold.normals()` method

- **`V`** (`double [N×3]`) - Vertex positions in MATLAB Z-up coordinates
  - Must be real, finite values
  - Row i contains [x, y, z] for vertex i

- **`F`** (`uint32 [M×3]`) - Face indices (1-based)
  - Must be positive integers
  - Row i contains [v1, v2, v3] vertex indices for face i
  - Automatically converted to 0-based for JavaScript

- **`N`** (`double [N×3]`) - Vertex normals (optional)
  - Must match number of vertices
  - Must be real, finite values
  - Row i contains [nx, ny, nz] normal for vertex i

### Return Value

None. Method triggers asynchronous rendering in JavaScript viewer.

## Usage Examples

### Example 1: Using Manifold Object (Recommended)

```matlab
% Load mesh data
data = load('data/mesh/fsaverage_rh_pial.mat');

% Create Manifold object
M = bct.Manifold(data.V, data.F);

% Create viewer and set mesh
gr = groot;
viewer = bct.ui.manifold.Viewer(gr);
viewer.setMesh(M);  % Normals computed automatically
```

**Advantages:**
- Single line of code
- Normals computed once in MATLAB (cached)
- No expensive JavaScript computation
- Clean separation of concerns

### Example 2: Direct Vertex/Face Arrays

```matlab
% Load mesh data
data = load('data/mesh/fsaverage_rh_pial.mat');
V = data.V;  % [N×3] vertices
F = data.F;  % [M×3] faces

% Create viewer and set mesh
gr = groot;
viewer = bct.ui.manifold.Viewer(gr);
viewer.setMesh(V, F);  % JavaScript will compute normals (slower)
```

**Use Case:**
- Quick testing without creating Manifold object
- Simple meshes where performance is not critical
- When normals are not needed

**Warning:** JavaScript will compute normals as fallback (~120ms for large meshes)

### Example 3: Pre-computed Normals

```matlab
% Load mesh data
data = load('data/mesh/fsaverage_rh_pial.mat');
M = bct.Manifold(data.V, data.F);

% Pre-compute normals
V = M.Vertices;   % Access property
F = M.Faces;      % Access property
N = M.normals();  % Explicit normals computation

% Create viewer and set mesh
gr = groot;
viewer = bct.ui.manifold.Viewer(gr);
viewer.setMesh(V, F, N);  % No JavaScript computation
```

**Use Case:**
- When you want explicit control over normal computation
- When you need to modify normals before rendering
- When using custom normal computation methods

## Performance Comparison

| Method | MATLAB Time | JavaScript Time | Notes |
|--------|-------------|-----------------|-------|
| `setMesh(manifold)` | ~0.5s (normals) | ~23ms (no normals) | **Recommended** |
| `setMesh(V, F, N)` | ~0.5s (normals) | ~23ms (no normals) | Explicit control |
| `setMesh(V, F)` | ~0s | ~145ms (with normals) | Fallback mode |

**Key Insight:** Pre-computing normals in MATLAB eliminates 122ms of JavaScript computation, reducing total rendering time from 145ms to 23ms (84% reduction).

## Data Flow

### With Manifold Object

```
┌─────────────────┐
│ bct.Manifold    │
│  V = .Vertices  │
│  F = .Faces     │
│  N = normals()  │
└────────┬────────┘
         │
         v
┌─────────────────┐
│ Viewer.setMesh()│
│  Flatten arrays │
│  Create payload │
└────────┬────────┘
         │
         v
┌─────────────────┐
│ JSON Transfer   │
│  Via uihtml     │
└────────┬────────┘
         │
         v
┌─────────────────┐
│ meshManager.js  │
│  Create buffers │
│  Set attributes │
└────────┬────────┘
         │
         v
┌─────────────────┐
│ Three.js Render │
│  MeshStandard   │
│  Material       │
└─────────────────┘
```

### Without Normals (Fallback)

```
┌─────────────────┐
│ V, F arrays     │
└────────┬────────┘
         │
         v
┌─────────────────┐
│ Viewer.setMesh()│
│  Flatten arrays │
└────────┬────────┘
         │
         v
┌─────────────────┐
│ meshManager.js  │
└────────┬────────┘
         │
         v
┌─────────────────────┐
│ validateGeometry    │
│  Compute normals ⚠️ │  <-- 122ms for 163k vertices
└────────┬────────────┘
         │
         v
┌─────────────────┐
│ Three.js Render │
└─────────────────┘
```

## Implementation Details

### MATLAB Side (`Viewer.m`)

1. **Input Parsing**: Detects signature and extracts V, F, N
2. **Validation**: Checks array dimensions and data types
3. **Flattening**: Reshapes [N×3] arrays to flat [1×N*3] for JSON
4. **Payload Creation**: Builds struct with vertices, faces, normals, indexBase, frame
5. **Transfer**: Sets `HTMLComponent.Data` to trigger JavaScript

### JavaScript Side (`meshManager.js`)

1. **Receive Data**: Extracts vertices, faces, normals from payload
2. **Create Buffers**: Converts to Float32Array, Uint32Array
3. **Set Attributes**: Creates THREE.BufferAttribute for position, index, normal
4. **Validate**: Checks for missing attributes (logs warning if normals missing)
5. **Render**: Creates mesh with MeshStandardMaterial

### Fallback Behavior

If normals are not provided:
1. JavaScript logs warning: `"WARNING: Normals missing, computing fallback"`
2. Calls `geometry.computeVertexNormals()` (~122ms for large meshes)
3. Continues rendering normally

## Coordinate Systems

- **MATLAB**: Z-up coordinate system
- **Three.js**: Y-up coordinate system
- **Transform**: Applied via `roots.matlab` frame (automatic Z→Y conversion)
- **Normals**: Transformed along with vertices (no special handling needed)

## Best Practices

1. **Use Manifold Objects**: Always prefer `setMesh(manifold)` for production code
2. **Pre-compute Once**: Create Manifold object once, reuse for multiple viewers
3. **Cache Normals**: `M.normals()` caches results, safe to call multiple times
4. **Monitor Logs**: Use `viewer.getLogs()` to check JavaScript performance
5. **Test Performance**: Compare with and without normals using demo scripts

## Debugging

### Check if Normals Were Sent

```matlab
viewer.setMesh(M);
pause(1.0);
logs = viewer.getLogs();
% Look for: "Pre-computed normals provided"
disp(logs);
```

### Verify No Fallback Computation

```matlab
% Should NOT see: "WARNING: Normals missing, computing fallback"
% Should see: "Geometry has required attributes (position, normals)"
```

### Performance Profiling

```matlab
% MATLAB side
tic; N = M.normals(); tNormals = toc;
tic; viewer.setMesh(M); tTransfer = toc;

% JavaScript side (from logs)
% Look for: "validateGeometryAttributes: Xms"
% Should be ~1ms if normals provided, ~122ms if computed
```

## Demo Scripts

- **`demo/demo_viewer_manifold.m`** - Comprehensive test of all signatures
- **`demo/demo_viewer_setMesh.m`** - Original V, F only test

## Related Documentation

- [Viewer Component Reference](./BCTUIMANIFOLDVIEWER.md)
- [Manifold Class Reference](../toolbox/+bct/Manifold.m)
- [Normals Computation](../toolbox/+bct/+manifold/normals.m)
- [Mesh Manager Architecture](./BRUSH_DESIGN_ARCHITECTURE.md#mesh-manager)

## Future Enhancements

1. **UVs Support**: Add optional UV coordinates for texture mapping
2. **Tangents Support**: Add tangents for normal mapping
3. **Face Normals**: Support face normals in addition to vertex normals
4. **Batch Updates**: Support updating normals without reloading entire mesh
5. **Progressive Loading**: Stream large meshes in chunks
