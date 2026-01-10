# Introduction to Bioctree

## Overview

**Bioctree** is a MATLAB toolbox that brings together spectral geometry, graph signal processing, and time-frequency analysis into a unified framework for analyzing signals on cortical manifolds.

## What Makes Bioctree Unique?

### 1. Domain-Dual Architecture

Bioctree is built around the concept of **domains and their duals**, connected by transforms:

```
Manifold (mesh vertices) ←eigenbasis→ Lambda (spatial frequencies)
Time (temporal samples)  ←FFT→        Omega (temporal frequencies)
```

Every operation in Bioctree respects this dual structure, making transforms explicit and mathematically rigorous.

### 2. Unified Filter Framework

All filters in Bioctree use the same fundamental kernels, whether applied to:
- Spatial domains (smoothing on the mesh)
- Spectral domains (eigenmode selection)
- Temporal domains (time-series filtering)
- Joint domains (spatiotemporal decomposition)

### 3. Wave Packet Theory

Bioctree implements dispersion relations and group velocity kernels for detecting and tracking traveling waves on cortical surfaces.

### 4. Professional Data Management

The BCT (Bioctree) file format provides:
- HDF5-based standardized storage
- Schema validation
- Multi-layer experimental designs
- Efficient partial data loading
- Time-frequency coefficient storage

## Core Concepts

### Domains

A **domain** represents the space where a signal lives. Bioctree defines several domain types:

#### Manifold Domain
The geometric mesh or graph structure:
```matlab
M = bct.Manifold(vertices, faces);
```

#### Lambda Domain
The spectral (eigenmode) representation:
```matlab
Lambda = bct.Lambda.fromManifold(M, num_modes);
```

#### Time Domain
The temporal axis:
```matlab
T = bct.Time(num_samples, sampling_rate);
```

#### Omega Domain
The frequency domain:
```matlab
Omega = bct.Omega.fromTime(T);
```

#### Joint Domain
Tensor product of multiple domains:
```matlab
J = bct.Joint(Lambda, Omega);  % Spatiotemporal-spectral
```

### Signals

Signals are always associated with a domain:

```matlab
% Spatial signal on manifold
sig = bct.Signal(Manifold, data_spatial, 'activation_map');

% Spectral signal on lambda
sig = bct.Signal(Lambda, coefficients, 'spectral_coeffs');

% Spatiotemporal signal
sig = bct.Signal(Manifold, data_matrix, 'timeseries');  % [N × T]
```

### Transforms

Transforms move signals between dual domains:

```matlab
% Manifold → Lambda (forward spectral transform)
spectral_coeffs = M.transform(spatial_signal, Lambda);

% Lambda → Manifold (inverse spectral transform)
spatial_signal = Lambda.transform(spectral_coeffs, Manifold);
```

### Filters

Filters are defined by:
1. A **domain** (where the filter operates)
2. A **kernel** (the filter shape)
3. **Parameters** (kernel-specific settings)

```matlab
% Low-pass filter on Lambda domain
filt = bct.Filter(Lambda, 'lowpass', 'cutoff', 50);

% Gaussian filter on Omega domain
filt = bct.Filter(Omega, 'gaussian', 'center', 10, 'sigma', 2);

% Apply to signal
filtered_signal = filt.apply(original_signal);
```

## The BCT Class: Your Main Interface

The `bct.bct` class orchestrates all operations:

```matlab
% Create from mesh
B = bct.bct.fromMesh(V, F);

% Compute eigenbasis
B.computeEigenbasis(100);

% Add signals
sig = bct.Signal(B.Manifold, data, 'my_signal');
B.addSignal(sig);

% Access domains
B.Manifold  % Mesh domain
B.Lambda    % Spectral domain
B.Time      % Temporal domain (if configured)
B.Omega     % Frequency domain (if configured)

% Create filters
filt = bct.Filter(B.Lambda, 'gaussian', ...);

% Visualize
bct.show.signal(B, sig);
bct.show.eigenmodes(B, [1, 5, 10]);
```

## Key Design Principles

### 1. Everything is Explicit

No hidden transforms or implicit conversions. If you move from spatial to spectral, you explicitly call the transform.

### 2. Type Safety

Signals know their domain. Filters know their domain. Mismatched operations are caught early with clear error messages.

### 3. Composability

Build complex analysis pipelines by composing simple operations:

```matlab
% Multi-step pipeline
sig_spatial = ...;
sig_spectral = M.transform(sig_spatial, Lambda);
sig_filtered = filt.apply(sig_spectral);
sig_back = Lambda.transform(sig_filtered, Manifold);
```

### 4. Reproducibility

All operations are deterministic and documented. Save results to BCT files with full metadata.

## Comparison with Other Toolboxes

| Feature | Bioctree | GSPBox | FieldTrip |
|---------|----------|--------|-----------|
| Mesh geometry | ✅ Native | ❌ Limited | ✅ Yes |
| Spectral analysis | ✅ Full | ✅ Yes | ❌ Limited |
| Time-frequency | ✅ Joint domain | ❌ No | ✅ Yes |
| Wave packets | ✅ Yes | ❌ No | ❌ No |
| Object-oriented | ✅ Full OOP | ❌ Functional | ❌ Struct-based |
| HDF5 I/O | ✅ BCT format | ❌ No | ✅ Custom |
| MATLAB only | ✅ Yes | ✅ Yes | ✅ Yes |

## What Can You Do with Bioctree?

### Spatial Analysis
- Smooth signals on cortical surfaces
- Detect spatial hotspots
- Compute spatial gradients
- Multi-scale spatial decomposition

### Spectral Analysis
- Eigenmode decomposition
- Spectral filtering
- Graph wavelets
- Spectral clustering

### Temporal Analysis
- Time-series filtering
- Frequency decomposition
- Phase analysis

### Spatiotemporal Analysis
- Joint spectral-temporal filtering
- Wave packet detection
- Dispersion analysis
- Group velocity computation
- Traveling wave tracking

### Data Management
- Save analysis results
- Load partial data efficiently
- Multi-layer experimental designs
- Share data with collaborators

## Next Steps

- **[Installation](installation.md)**: Set up Bioctree on your system
- **[Quickstart](quickstart.md)**: Run your first analysis
- **[Concepts](../concepts/overview.md)**: Dive deeper into the mathematics
- **[Tutorials](../tutorials/load-mesh.md)**: Step-by-step guides
