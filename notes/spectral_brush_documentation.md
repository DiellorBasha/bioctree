# Spectral Trajectory Brush

## Overview

The `spectral.m` brush in `bct.brush.trajectory` creates spectrally-filtered trajectories on a manifold by combining geodesic path computation with spectral domain filtering.

## Location

```
toolbox/+bct/+brush/+trajectory/spectral.m
```

## Algorithm

The spectral brush follows this workflow:

1. **Path Creation**: Computes shortest path between source and target vertices using `manifold.Graph.shortestPath()`
2. **Signal Generation**: Creates a binary signal with 1s on path vertices, 0s elsewhere
3. **Forward Transform**: Projects the signal to eigenmode domain (Lambda) using Manifold Fourier Transform (MFT)
   - `spectral_coeffs = U' * M * path_signal`
4. **Filtering**: Applies a spectral kernel (filter) to the coefficients
   - `filtered_coeffs = spectral_coeffs .* H`
5. **Inverse Transform**: Reconstructs the filtered signal back to spatial domain using IMFT
   - `w = U * filtered_coeffs`
6. **Post-processing**: Takes absolute value, normalizes to [0,1], and returns sparse result

## Parameters

### Required
- `params.source` - Source vertex index
- `params.target` - Target vertex index  
- `params.kernel` - Kernel type string (e.g., 'gaussian', 'heat', 'bandpass')

### Optional
- `params.metric` - Distance metric: "geometry" (default), "fem", or custom
- `params.kernel_params` - Struct with kernel-specific parameters
  - For `'heat'`: `struct('tau', 0.1)` - diffusion parameter
  - For `'gaussian'`: `struct('center', 50, 'sigma', 20)` - center eigenvalue and bandwidth
  - For `'bandpass'`: `struct('low', 10, 'high', 100)` - frequency band

## Usage Example

```matlab
% Load mesh and compute eigenbasis
B = bct.bct();
B.Manifold = bct.Manifold(V, F);
B.Lambda = B.Manifold.dual('numModes', 100);  % Compute 100 eigenmodes

% Create spectral brush with heat kernel (low-pass)
params = struct();
params.source = 100;
params.target = 500;
params.kernel = 'heat';
params.kernel_params = struct('tau', 0.1);

w = bct.brush.trajectory.spectral(B.Manifold, params);

% Visualize
B.Manifold.plot('data', full(w));
```

## Kernel Options

The brush supports any kernel available in the `bct.filters.Filter` system:

- **`'heat'`** - Heat diffusion kernel (low-pass smoothing)
  - Parameters: `tau` (diffusion time)
  - Effect: Smooth, diffused trajectory
  
- **`'gaussian'`** - Gaussian bandpass filter
  - Parameters: `center` (center eigenvalue), `sigma` (bandwidth)
  - Effect: Localized band-pass filtering
  
- **`'bandpass'`** - Rectangular bandpass with optional tapering
  - Parameters: `low`, `high` (eigenvalue bounds), `taper` (optional)
  - Effect: Sharp frequency cutoff

## Properties

- **Smooth Trajectories**: Unlike geodesic or Gaussian brushes that operate in spatial domain, this brush creates trajectories that are smooth in the spectral sense
- **Spectral Characteristics**: Respects the manifold's eigenmode structure
- **Flexible Filtering**: Can create low-pass (smooth), band-pass, or other spectral responses
- **Normalized Output**: Returns weights in [0, 1] range as sparse column vector

## Prerequisites

The manifold **must** have computed eigenbasis with its dual Lambda domain before using this brush:

```matlab
B.Lambda = B.Manifold.dual('numModes', k);  % k = number of eigenmodes
```

or using the bct orchestrator:

```matlab
B.computeEigenbasis(k);
```

If the Lambda domain or its eigenvectors/eigenvalues are missing, the brush will throw an error.

## Demo Script

A demonstration script is available at:
```
examples/demo_spectral_trajectory_brush.m
```

This script shows:
- Heat kernel filtering (low-pass)
- Gaussian bandpass filtering
- Comparison with geodesic brush
- Visualization of all three methods

## Technical Notes

1. The MFT uses the mass matrix M for proper L2 inner product: `U' * M * x`
2. Filtering is done via pointwise multiplication in spectral domain
3. Results are normalized to avoid negative values from spectral reconstruction
4. Very small weights (<1e-6) are set to zero to maintain sparsity

## Related Brushes

- `bct.brush.trajectory.geodesic` - Direct geodesic path (no filtering)
- `bct.brush.trajectory.gaussian` - Gaussian weighting in spatial domain
