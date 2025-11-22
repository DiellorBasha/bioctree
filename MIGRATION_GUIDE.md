# Migration Guide: Removed Packages

This guide explains the changes from the removed BCT packages.

## Overview

**REMOVED packages:**
- `bct.manifold` - Use `bct.Manifold` and `bct.Time` instead
- `bct.resolution` - Resolution info now in domain classes

**Status:** These packages have been completely removed.

---

## 1. Domain Classes Migration

### `bct.manifold.Manifold` → `bct.Manifold`

**OLD (deprecated):**
```matlab
M = bct.manifold.Manifold(vertices, faces);
M.Time = bct.manifold.Time(100, 100);  % Creates Time property
```

**NEW:**
```matlab
M = bct.Manifold(vertices, faces);
% Time is now managed by BCT class, not Manifold
```

**Key changes:**
- `bct.Manifold` is a standalone domain class
- No longer has a `Time` property
- Time is managed by the `bct.bct` orchestrator class

### `bct.manifold.Time` → `bct.Time`

**OLD (deprecated):**
```matlab
time = bct.manifold.Time(1000, 250);  % 1000 samples @ 250 Hz
```

**NEW:**
```matlab
time = bct.Time(1000, 250);  % Same syntax, different class
```

**Key changes:**
- `bct.Time` no longer creates its own `Omega` (frequency) dual
- Omega dual is automatically created by the BCT class when Time is assigned
- Property name: `Time.N` (number of samples) instead of `Time.T`
- Still has `Time.T` as dependent property for backward compatibility

---

## 2. BCT Workflow Migration

### Creating BCT Objects

**OLD:**
```matlab
B = bct.bct.fromMesh(vertices, faces);
B.Manifold.Time = bct.manifold.Time(100, 100);
```

**NEW:**
```matlab
B = bct.bct.fromMesh(vertices, faces);
B.Time = bct.Time(100, 100);  % Omega auto-created as dual
```

**Automatic dual creation:**
When you assign `B.Time = bct.Time(...)`, the BCT class automatically:
1. Creates the `Omega` (frequency) dual domain
2. Links `Time` ↔ `Omega` as duals
3. Initializes transforms for both domains

### Accessing Domains

**OLD:**
```matlab
N_vertices = B.Manifold.N;
N_samples = B.Manifold.Time.T;
```

**NEW:**
```matlab
N_vertices = B.Manifold.N;
N_samples = B.Time.N;  % Access Time directly from BCT
```

---

## 3. Signal Class Migration

The `bct.signal.Signal` class now works with **both** old and new domain classes for backward compatibility.

**NEW (recommended):**
```matlab
% Create domains via BCT
B = bct.bct.fromMesh(vertices, faces);
B.Time = bct.Time(100, 100);

% Create signal
sig = bct.signal.Signal(B.Manifold, spatial_data);
sig_st = bct.signal.Signal(B.Manifold, B.Time, spatiotemporal_data);
```

**OLD (still works, shows deprecation warnings):**
```matlab
M = bct.manifold.Manifold(vertices, faces);
T = bct.manifold.Time(100, 100);
sig = bct.signal.Signal(M, T, data);  % Still functional
```

---

## 4. Resolution Package Migration

### `bct.resolution.temporal` → Domain Classes

**OLD:**
```matlab
time = bct.manifold.Time(1000, 250);
res = bct.resolution.temporal(time);
res.setBand([8, 12], bct.resolution.Quantity.frequency);  % Alpha band
f_nyquist = res.f_nyquist;
```

**NEW:**
```matlab
B.Time = bct.Time(1000, 250);
% Access resolution info directly:
f_nyquist = B.Time.fs / 2;
% Band selection handled by Filter architecture
```

### `bct.resolution.spatial` → Domain Classes

**OLD:**
```matlab
res = bct.resolution.spatial(B.Manifold);
res.setBand([0.01, 0.5], bct.resolution.Quantity.lambda);
modes = res.getModeIndices();
```

**NEW:**
```matlab
% Access spectral info from Lambda domain:
lambda_values = B.Lambda.lambda;
% Band selection handled by Filter architecture
modes = find(lambda_values >= 0.01 & lambda_values <= 0.5);
```

---

## 5. Filter Architecture Migration

### Creating Filters

**OLD (using deprecated manifold):**
```matlab
B.Manifold = bct.manifold.Manifold(V, F);
B.Time = bct.manifold.Time(100, 100);
F_spatial = bct.filters.design.manifold.heat(B.Manifold, scale);
```

**NEW:**
```matlab
B = bct.bct.fromMesh(V, F);
B.Time = bct.Time(100, 100);

% Use new filter architecture with kernels
kernel = bct.kernels.heat(scale);
F_spatial = bct.Filter(B.Lambda, kernel);
F_temporal = bct.Filter(B.Omega, kernel);
F_joint = bct.Filter(B.Lambda.join(B.Omega), kernel);
```

**Key architectural change:**
- Filters are now created from **kernels** (pure math functions) + **domains**
- Kernels are domain-agnostic (in `+bct/+kernels/`)
- Domain binding happens in the `Filter` class

---

## 6. Common Patterns

### Pattern 1: Mesh with Time Evolution

**OLD:**
```matlab
M = bct.manifold.Manifold(V, F);
M.Time = bct.manifold.Time(100, 100);
sig = bct.signal.Signal(M, M.Time, data);
```

**NEW:**
```matlab
B = bct.bct.fromMesh(V, F);
B.Time = bct.Time(100, 100);  % Auto-creates B.Omega
sig = bct.signal.Signal(B.Manifold, B.Time, data);
```

### Pattern 2: Spatial-Only Signal

**OLD:**
```matlab
M = bct.manifold.Manifold(V, F);
sig = bct.signal.Signal(M, spatial_data);
```

**NEW:**
```matlab
B = bct.bct.fromMesh(V, F);
sig = bct.signal.Signal(B.Manifold, spatial_data);
```

### Pattern 3: Joint Filtering

**OLD:**
```matlab
% Complex manual setup with Resolution objects
```

**NEW:**
```matlab
B = bct.bct.fromMesh(V, F);
B.Time = bct.Time(100, 100);
joint_domain = B.Lambda.join(B.Omega);  % 2D spectral-frequency domain
kernel = bct.kernels.heat(scale);
F_joint = bct.Filter(joint_domain, kernel);
response = F_joint.evaluate();  % [n_lambda × n_omega] response
```

---

## 7. Property Changes Summary

### `bct.Time` (new) vs `bct.manifold.Time` (old)

| Property | Old Class | New Class | Notes |
|----------|-----------|-----------|-------|
| Sample count | `.T` | `.N` | `.T` exists as dependent property |
| Sampling rate | `.fs` | `.fs` | Unchanged |
| Time vector | `.t` | `.axis` | New name for consistency |
| Dual domain | Creates internally | Created by BCT | Architectural change |

### `bct.Manifold` (new) vs `bct.manifold.Manifold` (old)

| Property | Old Class | New Class | Notes |
|----------|-----------|-----------|-------|
| Vertices | `.V` | `.Vertices` | Renamed |
| Faces | `.F` | `.Faces` | Renamed |
| Vertex count | `.N` | `.N` | Unchanged (dependent) |
| Time property | `.Time` | ❌ Removed | Time managed by BCT class |
| Resolution | `.Resolution` | ❌ Removed | Info in domain classes |

---

## 8. Testing Your Migration

After migrating, verify:

1. **No deprecation warnings:**
   ```matlab
   warning('on', 'bct:manifold:Time:deprecated');
   warning('on', 'bct:manifold:Manifold:deprecated');
   % Run your code - should see no warnings
   ```

2. **BCT workflow functional:**
   ```matlab
   B = bct.bct.fromMesh(V, F);
   B.Time = bct.Time(100, 100);
   assert(~isempty(B.Omega));  % Omega auto-created
   assert(B.Time.Dual == B.Omega);  % Duals linked
   ```

3. **Signals work:**
   ```matlab
   sig_spatial = bct.signal.Signal(B.Manifold, rand(B.Manifold.N, 1));
   sig_st = bct.signal.Signal(B.Manifold, B.Time, rand(B.Manifold.N, B.Time.N));
   ```

4. **Filters work:**
   ```matlab
   kernel = bct.kernels.heat(1.0);
   F = bct.Filter(B.Lambda, kernel);
   response = F.evaluate();
   ```

---

## 9. Backward Compatibility

**The old packages have been completely removed.** You must update all code to use the new classes:
- `bct.manifold.Manifold` → `bct.Manifold`
- `bct.manifold.Time` → `bct.Time`
- `bct.resolution.*` → Domain classes

The Signal class now only accepts the new domain classes.

---

## 10. Quick Reference

| Deprecated | Replacement | Category |
|------------|-------------|----------|
| `bct.manifold.Manifold` | `bct.Manifold` | Domain class |
| `bct.manifold.Time` | `bct.Time` | Domain class |
| `bct.resolution.temporal` | Domain classes (`bct.Time`, `bct.Omega`) | Resolution info |
| `bct.resolution.spatial` | Domain classes (`bct.Lambda`, `bct.Manifold`) | Resolution info |
| `B.Manifold.Time` | `B.Time` | Property access |
| `Time.T` (samples) | `Time.N` | Property name |

---

## Need Help?

- Run test suite: `test_bct_workflow_after_deprecation.m`
- Check examples in `toolbox/+bct/+signal/Signal.m`
- See filter examples in `toolbox/+bct/@Filter/Filter.m`
