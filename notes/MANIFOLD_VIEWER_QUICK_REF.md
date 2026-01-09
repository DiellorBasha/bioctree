# Quick Reference: Manifold Viewer Integration

## Three Ways to Use setMesh

### 1. Manifold Object (⭐ Recommended)
```matlab
M = bct.Manifold(V, F);
viewer.setMesh(M);
```
✅ Pre-computed normals  
✅ Best performance (~23ms JS)  
✅ Clean API  

### 2. Vertices & Faces Only
```matlab
viewer.setMesh(V, F);
```
⚠️ JavaScript computes normals  
⚠️ Slower performance (~145ms JS)  
✅ Simple for quick tests  

### 3. Explicit Normals
```matlab
viewer.setMesh(V, F, N);
```
✅ Pre-computed normals  
✅ Best performance (~23ms JS)  
✅ Direct control  

## Performance Comparison

| Method | JS Time | Speed |
|--------|---------|-------|
| `setMesh(M)` | 23ms | ⚡⚡⚡ |
| `setMesh(V,F,N)` | 23ms | ⚡⚡⚡ |
| `setMesh(V,F)` | 145ms | ⚡ |

## When to Use Each

### Use Manifold Object When:
- Building production applications
- Performance matters
- Working with multiple viewers
- Need access to other Manifold methods

### Use V, F Only When:
- Quick prototyping/testing
- Very small meshes (<10k vertices)
- Don't have Manifold object yet

### Use Explicit Normals When:
- Need custom normal computation
- Modifying normals before rendering
- Integrating with external tools

## Common Patterns

### Pattern 1: Create Once, Use Many Times
```matlab
% Create Manifold (one-time cost ~0.5s)
M = bct.Manifold(V, F);

% Use in multiple viewers (fast)
v1 = bct.ui.manifold.Viewer(gr);
v1.setMesh(M);  % ~0.001s + 23ms JS

v2 = bct.ui.manifold.Viewer(gr);
v2.setMesh(M);  % ~0.001s + 23ms JS (normals cached)
```

### Pattern 2: Explicit Normal Control
```matlab
M = bct.Manifold(V, F);
N = M.normals();

% Modify normals (example: invert)
N = -N;

% Render with modified normals
viewer.setMesh(M.Vertices, M.Faces, N);
```

### Pattern 3: Quick Test Without Manifold
```matlab
% Load and render directly
data = load('mesh.mat');
viewer.setMesh(data.V, data.F);
% Works, but slower (145ms vs 23ms)
```

## Checking Results

### Verify Normals Were Used
```matlab
viewer.setMesh(M);
pause(1.0);
logs = viewer.getLogs();

% Look for this:
% "Pre-computed normals provided"
% "Geometry has required attributes"

% Should NOT see:
% "WARNING: Normals missing"
% "computing fallback"
```

### Performance Profiling
```matlab
% MATLAB timing
tic; N = M.normals(); tN = toc;  % ~0.5s first call
tic; viewer.setMesh(M); tS = toc;  % ~0.001s

% JavaScript timing (from logs)
logs = viewer.getLogs();
% Look for: "validateGeometryAttributes: 1.23ms"
%           "TOTAL TIME: 22.45ms"
```

## Troubleshooting

### Problem: Still seeing "computing fallback" warning
**Solution**: Make sure you're passing Manifold object or explicit normals
```matlab
% Wrong
viewer.setMesh(V, F);  % No normals!

% Right
viewer.setMesh(M);  % Has normals
```

### Problem: "normals array length must match vertices"
**Solution**: Check that N has same number of rows as V
```matlab
size(V)  % [163842 3]
size(N)  % [163842 3] must match!
```

### Problem: Slow performance even with Manifold
**Solution**: Make sure normals() was called (it caches)
```matlab
% First call computes and caches
N1 = M.normals();  % ~0.5s

% Subsequent calls are instant
N2 = M.normals();  % <0.001s (cached)
```

## File Locations

- **Main Component**: `toolbox/+bct/+ui/+manifold/Viewer.m`
- **Demo Script**: `demo/demo_viewer_manifold.m`
- **Full Docs**: `docs/MANIFOLD_VIEWER_INTEGRATION.md`
- **Summary**: `docs/MANIFOLD_INTEGRATION_SUMMARY.md`

## Console Output Examples

### With Normals (Fast) ✅
```
[Viewer.setMesh] Sent mesh data: 163842 vertices, 327680 faces, normals included
[MeshManager] Clear model: 0.12ms
[MeshManager] Pre-computed normals provided (163842 vertices)
[MeshManager] Create typed arrays & set attributes: 9.87ms
[MeshManager] validateGeometryAttributes: 1.23ms
[meshBuilder] Geometry has required attributes (position, normals)
[MeshManager] TOTAL TIME: 22.45ms
```

### Without Normals (Slow) ⚠️
```
[Viewer.setMesh] Sent mesh data: 163842 vertices, 327680 faces
[MeshManager] Clear model: 0.11ms
[MeshManager] Create typed arrays & set attributes: 10.34ms
[MeshManager] validateGeometryAttributes: 122.67ms
[meshBuilder] WARNING: Normals missing, computing fallback (use Manifold.normals() in MATLAB!)
[meshBuilder] Computed normals (fallback): 121.89ms
[MeshManager] TOTAL TIME: 144.78ms
```

## Best Practices

1. ✅ Always use `setMesh(M)` in production code
2. ✅ Create Manifold objects once, reuse multiple times
3. ✅ Check console logs to verify normals were sent
4. ✅ Use `getLogs()` for performance monitoring
5. ⚠️ Avoid `setMesh(V, F)` for large meshes in production
6. ⚠️ Don't create new Manifold for every viewer

## Migration Checklist

- [ ] Identify all `setMesh(V, F)` calls in codebase
- [ ] Create bct.Manifold objects for mesh data
- [ ] Replace with `setMesh(M)`
- [ ] Test performance (should see ~84% speedup)
- [ ] Verify no "computing fallback" warnings
- [ ] Update documentation/comments

## Quick Start

```matlab
% 1. Load mesh
data = load('data/mesh/fsaverage_rh_pial.mat');

% 2. Create Manifold
M = bct.Manifold(data.V, data.F);

% 3. Create viewer
gr = groot;
viewer = bct.ui.manifold.Viewer(gr);

% 4. Set mesh (fast!)
viewer.setMesh(M);

% 5. Verify
pause(1.0);
disp(viewer.getLogs());
```

Expected output: "Pre-computed normals provided" + "TOTAL TIME: ~23ms"

---

**For complete documentation, see**: `docs/MANIFOLD_VIEWER_INTEGRATION.md`
