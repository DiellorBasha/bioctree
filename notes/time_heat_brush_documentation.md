# Spatiotemporal Heat Brush

## Overview

The `heat.m` brush in `bct.brush.time` creates spatiotemporal heat diffusion patterns along a geodesic trajectory. It outputs weights as an [N×T] array where N is the number of vertices and T is the number of time steps.

## Location

```
toolbox/+bct/+brush/+time/heat.m
```

## Algorithm

The heat brush generates spatiotemporal patterns by:

1. **Path Creation**: Computes shortest path between source and target
2. **Initial Signal**: Creates binary signal on path vertices
3. **Forward Transform**: Projects to eigenmode domain (Lambda) via MFT
4. **Time-Varying Filtering**: Applies heat kernel with tau increasing over time
   - `H(λ, t) = exp(-τ(t)·λ/λ_max)`
5. **Inverse Transform**: Reconstructs to spatial domain at each time step
6. **Output**: Returns [N×T] sparse matrix of spatiotemporal weights

## Parameters

### Required
- `params.source` - Source vertex index
- `params.target` - Target vertex index

### Optional
- `params.tau_range` - `[tau_start, tau_end]` diffusion range (default: `[0.01, 0.5]`)
- `params.tau_profile` - Evolution profile:
  - `'linear'` (default) - Linear increase in diffusion
  - `'exponential'` - Exponential growth
  - `'sigmoid'` - Slow-fast-slow S-curve
- `params.metric` - Distance metric: `"geometry"` (default), `"fem"`, or custom

## Usage Example

```matlab
% Setup
B = bct.bct();
B.Manifold = bct.Manifold(V, F);
B.Lambda = B.Manifold.dual('numModes', 100);
B.Time = bct.Time(0:0.01:1, 100);  % 1 second at 100 Hz

% Create heat brush
params.source = 100;
params.target = 500;
params.tau_range = [0.02, 0.4];
params.tau_profile = 'exponential';

w = bct.brush.time.heat(B.Manifold, B.Time, params);

% w is [N×T] where N=vertices, T=time steps

% Visualize specific time point
B.Manifold.plot('data', full(w(:, 50)));

% Extract temporal trace at vertex
vertex_trace = w(250, :);
plot(B.Time.axis, full(vertex_trace));
```

## Output Format

Returns `w` as [N×T] sparse matrix where:
- **N** = Number of vertices on manifold
- **T** = Number of time steps from Time domain
- `w(n,t)` = Normalized weight [0,1] at vertex n, time t

## Tau Profiles

### Linear
- Constant rate of diffusion increase
- `τ(t) = τ_start + (τ_end - τ_start)·(t/T)`
- Good for: Steady, predictable diffusion

### Exponential  
- Slow start, rapid later growth
- `τ(t) = τ_start·exp(log(τ_end/τ_start)·t/T)`
- Good for: Initially localized, then rapid spreading

### Sigmoid
- Slow-fast-slow S-curve
- Uses logistic function for smooth transitions
- Good for: Natural-looking onset and saturation

## Properties

- **Spatiotemporal**: Full [N×T] array with both spatial and temporal structure
- **Spectral Smoothness**: Uses eigenmodes for geometrically-aware diffusion
- **Normalized**: Each time slice normalized to [0,1]
- **Sparse**: Thresholded to maintain sparsity (< 1e-6 set to zero)
- **Progressive Diffusion**: Activity spreads from path over time

## Visualization Tips

```matlab
% Animate over time
for t = 1:B.Time.N
    B.Manifold.plot('data', full(w(:, t)));
    title(sprintf('t = %.2f s', B.Time.axis(t)));
    drawnow;
end

% Compare time slices
figure;
time_points = [1, 25, 50, 75, 100];
for i = 1:length(time_points)
    subplot(1, 5, i);
    B.Manifold.plot('data', full(w(:, time_points(i))));
    title(sprintf('t = %.2f', B.Time.axis(time_points(i))));
end
```

## Prerequisites

Both Manifold and Time domains must be initialized:

```matlab
% Manifold with eigenbasis
B.Lambda = B.Manifold.dual('numModes', k);

% Time domain
B.Time = bct.Time(t_vec, fs);
```

## Demo Script

Comprehensive demonstration at:
```
examples/demo_time_heat_brush.m
```

Shows:
- All three tau profiles (linear, exponential, sigmoid)
- Temporal evolution visualization
- Vertex-level temporal traces
- Performance metrics

## Technical Notes

1. **Heat Kernel**: `H(λ) = exp(-τ·λ/λ_max)` applied per time step
2. **Normalization**: λ normalized by λ_max for scale-invariant behavior
3. **MFT/IMFT**: Uses mass matrix M for proper L2 inner product
4. **Memory**: Sparse format keeps memory manageable for large N×T
5. **Temporal Independence**: Each time step computed independently (parallelizable)

## Related Brushes

- `bct.brush.trajectory.spectral` - Single time slice spectral filtering
- `bct.brush.patch.spectral` - Static spectral patch (no trajectory)
- `bct.brush.trajectory.gaussian` - Spatial-only Gaussian weighting
