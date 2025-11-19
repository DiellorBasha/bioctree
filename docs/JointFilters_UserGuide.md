# Joint Mesh-Time Spectral Filters in BioCTree

## Overview

The `bct.filters` package has been extended to support **joint mesh-time spectral filters** for spatiotemporal signal analysis on cortical surfaces. This enables sophisticated filtering of brain signals that couple spatial and temporal dynamics through dispersion relationships.

## Core Concept

Joint filters are defined on the mesh-time spectral grid as:

```matlab
W(λ,t) = K(λ,t) * ψ_mesh(λ) * φ_time(t)
```

Where:
- **ψ_mesh(λ)**: Spatial kernel on mesh eigenvalue spectrum
- **φ_time(t)**: Temporal kernel in time domain
- **K(λ,t)**: Dispersion relationship (coupling spatial and temporal dynamics)

## Architecture

### Class Hierarchy

```
bct.filters.Filter                    % Original spatial-only filter
bct.filters.JointFilter               % New joint mesh-time filter
  ├── +design/
  │   ├── diffusion.m                 % Heat diffusion-coupled filter
  │   ├── wave.m                      % Wave propagation filter
  │   └── separable.m                 % No dispersion (separable)
```

### Integration with Bct Infrastructure

```matlab
Bct.Manifold  →  meshFourier()  →  Eigenvalues λ
Bct.Time      →  get_time_vector()  →  Time axis t
                            ↓
         Bct.buildSpectralGrid([λ_min, λ_max])
                            ↓
              SpectralGrid.lambda_grid [numModes × T]
              SpectralGrid.t_grid      [numModes × T]
                            ↓
         JointFilter.synthesize()
                            ↓
              W(λ,t) evaluated on grid
```

## Workflow

### 1. Design Phase

Choose a filter design function based on your application:

```matlab
% Diffusion-coupled filter (for spreading activation patterns)
filt = bct.filters.design.diffusion(B, ...
    'lambda_band', [0, 5], ...      % Spatial frequency band
    'freq_hz', 10, ...               % 10 Hz temporal center
    'sx', 2, ...                     % Spatial scale
    'st', 0.05);                     % 50 ms temporal scale

% Wave-coupled filter (for traveling waves)
filt = bct.filters.design.wave(B, ...
    'lambda_band', [1, 10], ...
    'freq_hz', 15, ...
    'velocity', 0.5, ...             % Wave velocity
    'sx', 3, 'st', 0.04);

% Separable filter (no coupling)
filt = bct.filters.design.separable(B, ...
    'lambda_band', [0.5, 10], ...
    'freq_hz', 12, ...
    'spatial_kernel', 'gabor', ...
    'temporal_kernel', 'gabor');
```

### 2. Synthesis Phase

Build the spectral grid and evaluate the joint filter:

```matlab
% Synthesize filter on spectral grid
filt.synthesize('numModes', 200);

% The filter is now evaluated on:
%   - lambda_grid: [numModes × T]
%   - t_grid: [numModes × T]
%   - W_lambda_t: [numModes × T] joint filter values
```

### 3. Analysis Phase

Visualize and inspect the filter:

```matlab
% Visualize joint filter as 2D image
filt.plotJoint();

% View spatial and temporal marginals separately
filt.plotMarginals();

% Display filter properties
disp(filt);

% Get filter values
W = filt.evaluate();  % Returns synthesized filter
```

### 4. Evaluation Phase

Evaluate filter at arbitrary points:

```matlab
% Query at custom lambda and time points
lambda_query = linspace(0, 10, 100);
t_query = linspace(0, 0.5, 50);
W_custom = filt.evaluate(lambda_query, t_query);
```

## Filter Components

### Spatial Kernels (ψ_mesh)

| Type | Equation | Use Case |
|------|----------|----------|
| **Mexican Hat** | `(1 - λ/s²) * exp(-λ/(2s²))` | Bandpass with negative sidelobes |
| **Morlet** | `exp(-λ/(2s²))` | Smooth lowpass |
| **Gabor** | `exp(-(λ-λ₀)²/(2s²))` | Narrowband centered at λ₀ |
| **Gaussian** | `exp(-λ²/(2s²))` | Smooth lowpass from zero |
| **Heat** | `exp(-s*λ)` | Exponential decay |
| **Custom** | User-defined function | Any custom kernel |

### Temporal Kernels (φ_time)

| Type | Equation | Use Case |
|------|----------|----------|
| **Gabor** | `exp(-t²/s²) * cos(ω₀*t)` | Oscillatory with Gaussian envelope |
| **Morlet** | `exp(-t²/(2s²)) * cos(ω₀*t)` | Wavelet analysis |
| **Gaussian** | `exp(-t²/(2s²))` | Smooth temporal envelope |
| **Cosine** | `exp(-t²/s²) * cos(ω₀*t)` | Pure oscillation with envelope |
| **Custom** | User-defined function | Any custom kernel |

### Dispersion Relationships (K)

| Type | Equation | Physical Interpretation |
|------|----------|------------------------|
| **Heat** | `exp(-t*λ)` | Diffusive spreading (parabolic PDE) |
| **Wave** | `cos(√λ*t/v)` | Traveling waves (hyperbolic PDE) |
| **None** | `1` | Separable (no coupling) |
| **Custom** | User-defined `@(lambda,t)` | Any dispersion |

## Parameter Guide

### Spatial Parameters

- **lambda_band**: `[λ_min, λ_max]`
  - Defines spatial frequency range
  - Eigenvalues in this band are included in synthesis
  - Smaller λ → larger spatial scales (global patterns)
  - Larger λ → smaller spatial scales (local patterns)

- **sx**: Spatial scale parameter
  - Controls width of spatial kernel
  - Larger sx → broader spatial frequency response
  - Smaller sx → narrower spatial frequency response
  - Units depend on kernel type

### Temporal Parameters

- **freq_band**: `[f_min, f_max]` (Hz)
  - Temporal frequency range of interest
  - Used to set center frequency if omega0 not specified

- **freq_hz** or **omega0**: Center frequency
  - `freq_hz`: Frequency in Hz
  - `omega0`: Angular frequency in rad/s (ω₀ = 2πf)
  - Determines oscillation rate of temporal kernel

- **st**: Temporal scale parameter
  - Controls width of temporal envelope
  - Larger st → longer duration in time
  - Smaller st → shorter, more localized in time
  - Units: seconds or samples (kernel-dependent)

### Synthesis Parameters

- **numModes**: Number of eigenmodes to compute
  - Default: `min(200, N-1)`
  - More modes → finer spatial resolution, longer computation
  - Fewer modes → coarser spatial resolution, faster

## Applications

### 1. Alpha Oscillations on Cortical Surface

Detect and filter alpha-band (8-12 Hz) activity with spatial structure:

```matlab
B = bct.bct();
B.Manifold = bct.manifold.Manifold(V, F);
B.Time = bct.manifold.Time(1000, 250);  % 1000 samples @ 250 Hz

% Alpha-band diffusion filter
filt_alpha = bct.filters.design.diffusion(B, ...
    'lambda_band', [0, 5], ...
    'freq_band', [8, 12], ...
    'sx', 2, 'st', 0.08);

filt_alpha.synthesize();
filt_alpha.plotJoint();
```

### 2. Traveling Waves in MEG/EEG

Detect traveling waves across the cortical surface:

```matlab
% Wave-coupled filter for traveling wave detection
filt_wave = bct.filters.design.wave(B, ...
    'lambda_band', [2, 15], ...
    'freq_hz', 10, ...
    'velocity', 0.3, ...  % Wave velocity (m/s or mm/s)
    'sx', 5, 'st', 0.05);

filt_wave.synthesize();
filt_wave.plotJoint();
```

### 3. Multi-Scale Spatiotemporal Decomposition

Create filterbank for multi-scale analysis:

```matlab
% Low spatial frequency (global), alpha band
filt1 = bct.filters.design.diffusion(B, ...
    'lambda_band', [0, 2], 'freq_hz', 10, 'sx', 1, 'st', 0.1);

% High spatial frequency (local), alpha band  
filt2 = bct.filters.design.diffusion(B, ...
    'lambda_band', [5, 15], 'freq_hz', 10, 'sx', 0.5, 'st', 0.1);

filt1.synthesize();
filt2.synthesize();

% Compare spatial scales at same temporal frequency
figure;
subplot(1,2,1); filt1.plotJoint(); title('Global');
subplot(1,2,2); filt2.plotJoint(); title('Local');
```

### 4. Custom Dispersion for Specific Brain Processes

Define custom dispersion relationship:

```matlab
filt = bct.filters.JointFilter(B);
filt.lambda_band = [0, 10];

% Spatial kernel: Mexican hat
filt.setSpatialKernel('mexican_hat', 'sx', 3);

% Temporal kernel: Gabor
filt.setTemporalKernel('gabor', 'st', 0.06, 'freq_hz', 12);

% Custom dispersion: Damped oscillation
custom_K = @(lambda, t) exp(-0.5*t) .* exp(-0.1*t.*lambda) .* cos(sqrt(lambda).*t);
filt.setDispersion('custom', 'handle', custom_K);

filt.synthesize();
filt.plotJoint();
```

## Advanced Features

### Custom Kernel Functions

Define completely custom spatial or temporal kernels:

```matlab
% Custom spatial kernel: Double-peaked
custom_psi = @(lambda) exp(-((lambda-2).^2)/2) + 0.5*exp(-((lambda-8).^2)/4);

% Custom temporal kernel: Amplitude-modulated chirp
custom_phi = @(t) exp(-t.^2/0.01) .* sin(2*pi*10*t + 100*t.^2);

filt = bct.filters.JointFilter(B);
filt.lambda_band = [0, 15];
filt.setSpatialKernel('custom', 'handle', custom_psi);
filt.setTemporalKernel('custom', 'handle', custom_phi);
filt.setDispersion('heat');

filt.synthesize();
```

### Frequency Band Specification

Automatically set temporal parameters from frequency bands:

```matlab
% The design functions use freq_band to set omega0
filt = bct.filters.design.diffusion(B, ...
    'lambda_band', [0, 5], ...
    'freq_band', [8, 12]);  % Uses center frequency 10 Hz

% Or specify directly
filt = bct.filters.design.diffusion(B, ...
    'lambda_band', [0, 5], ...
    'freq_hz', 10);  % Explicit 10 Hz
```

## Technical Details

### Spectral Grid Construction

The spectral grid is built using MATLAB's `ndgrid`:

```matlab
% 1. Get eigenvalues in lambda_band via meshFourier
[~, lambda_vec] = Manifold.meshFourier(numModes, opts);

% 2. Get time vector from Time object
t = Time.get_time_vector();  % [T × 1]

% 3. Create joint grid
[lambda_grid, t_grid] = ndgrid(lambda_vec, t);
% Result: lambda_grid and t_grid are [numModes × T]
```

### Filter Evaluation

The joint filter is evaluated element-wise:

```matlab
% Evaluate kernels on grids
psi_vals = psi_mesh(lambda_grid);  % [numModes × T]
phi_vals = phi_time(t_grid);       % [numModes × T]

% Include dispersion if present
if ~isempty(K_dispersion)
    K_vals = K_dispersion(lambda_grid, t_grid);  % [numModes × T]
    W = K_vals .* psi_vals .* phi_vals;
else
    W = psi_vals .* phi_vals;  % Separable
end
```

### Memory Considerations

For large meshes and long time series:

- Grid size: `numModes × T` elements
- For 200 modes × 1000 time points: 200,000 values
- Memory: ~1.6 MB per filter (double precision)
- Reduce `numModes` for faster synthesis if spatial resolution not critical

## Testing

Run comprehensive test suite:

```matlab
run('test_joint_filters.m')
```

Tests cover:
1. Diffusion-coupled filters
2. Wave-coupled filters
3. Separable filters
4. Custom kernels
5. Arbitrary point evaluation
6. Frequency band specification

All visualizations are generated automatically.

## Future Extensions

Planned enhancements:

1. **Filter Application**: 
   - Integrate with `bct.signal.transform` for signal filtering
   - Implement forward and inverse transforms

2. **Analysis Tools**:
   - Automatic scale selection based on data
   - Filter response analysis in frequency domain
   - Cross-filter coherence

3. **Additional Kernels**:
   - Meyer wavelets
   - Daubechies wavelets
   - Biorthogonal wavelets

4. **Optimization**:
   - GPU acceleration for large grids
   - Sparse representations
   - Fast multipole methods

## References

- Hammond, D. K., Vandergheynst, P., & Gribonval, R. (2011). Wavelets on graphs via spectral graph theory. *Applied and Computational Harmonic Analysis*, 30(2), 129-150.

- Shuman, D. I., Ricaud, B., & Vandergheynst, P. (2016). Vertex-frequency analysis on graphs. *Applied and Computational Harmonic Analysis*, 40(2), 260-291.

- Muller, L., Chavane, F., Reynolds, J., & Sejnowski, T. J. (2018). Cortical travelling waves: mechanisms and computational principles. *Nature Reviews Neuroscience*, 19(5), 255-268.

## See Also

- `bct.filters.Filter` - Original spatial-only filter class
- `bct.bct.buildSpectralGrid` - Spectral grid construction
- `bct.manifold.Manifold.meshFourier` - Mesh eigendecomposition
- `bct.manifold.Time` - Time dimension management
- `bct.signal.transform` - Signal transformation tools

---

**Copyright (c) 2025 BioCTree Project**
