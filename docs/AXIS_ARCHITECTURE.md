# Axis-Based Architecture Update

## Overview
Updated Bct to use a fundamental axis-based architecture where filters are always defined on **Lambda** (manifold spectral) and **Omega** (temporal angular frequency) axes.

## Key Changes

### 1. Fundamental vs Derived Axes

**Fundamental Axes** (used internally by filters and transforms):
- `AxisTime` - Time in seconds (t)
- `AxisOmega` - Angular frequency in rad/s (ω) - **fundamental for temporal filters**
- `AxisVertices` - Vertex indices (1:N)
- `AxisLambda` - Eigenvalue axis (λ) - **fundamental for manifold filters**

**Derived Axes** (for human-readable interactions):
- `AxisFrequency` - Frequency in Hz (f = ω/2π)
- `AxisTemporalScale` - Temporal scale in seconds (s ≈ 1/ω)
- `AxisWavelength` - Spatial wavelength in mm (L = 2π/√λ)
- `AxisSpatialScale` - Spatial scale in mm (s = 1/√λ)

### 2. Filter Design on Fundamental Axes

**Manifold Filters** - Always defined on **Lambda** axis:
```matlab
% Heat kernel: g(λ) = exp(-τ·λ/λ_max)
g = bct.filters.design.manifold.heat(manifold, 'tau', 0.1);

% Gaussian: g(λ) = exp(-0.5·((λ-λ₀)/σ)²)
g = bct.filters.design.manifold.gaussian(manifold, 'lambda0', 500, 'sigma', 50);

% Mexican hat: g(λ) = (1-t²)·exp(-t²/2) where t = (λ-λ₀)/(sx·λ_max)
g = bct.filters.design.manifold.mexh(manifold, 'lambda0', 500, 'sx', 0.05);
```

**Temporal Filters** - Always defined on **Omega** axis (rad/s):
```matlab
% Gabor: φ(ω) = exp(-0.5·((ω-ω₀)/σ_ω)²)
phi = bct.filters.design.time.gabor('omega0', 2*pi*10, 'sigma_t', 0.05);
%                                     ω₀ = 20π rad/s (10 Hz)
```

### 3. SpectralGrid Construction

SpectralGrid now constructed from **Lambda × Omega** using `meshgrid`:

```matlab
% Old (deprecated):
[lambda_grid, t_grid] = ndgrid(lambda_vec, t);
SpectralGrid.t_grid = t_grid;

% New (fundamental):
[lambda_grid, omega_grid] = meshgrid(lambda_vec, omega_vec);
SpectralGrid.omega_grid = omega_grid;  % [T × K]
SpectralGrid.lambda_grid = lambda_grid; % [T × K]
SpectralGrid.omega = omega_vec;         % [T × 1] rad/s
```

### 4. New Bct Methods

**`initializeAxes()`** - Create all Axis objects:
```matlab
B.initializeAxes();
% Creates:
%   B.AxisTime, B.AxisOmega, B.AxisVertices, B.AxisLambda (fundamental)
%   B.AxisFrequency, B.AxisTemporalScale, B.AxisWavelength, B.AxisSpatialScale (derived)
```

**Updated `buildSpectralGrid()`**:
```matlab
B.buildSpectralGrid([100, 500]);  % Lambda band
% Automatically calls initializeAxes() if needed
% Creates meshgrid(lambda, omega)
```

### 5. Axis Class Usage

```matlab
% Get temporal omega axis
ax_omega = bct.resolution.Axis.omega(B.Time);
omega_vals = ax_omega.Values;  % rad/s

% Get manifold lambda axis
ax_lambda = bct.resolution.Axis.lambda(B.Manifold.Resolution);
lambda_vals = ax_lambda.Values;  % eigenvalues

% Create joint axis for visualization
ax_joint = bct.resolution.Axis.joint(ax_lambda, ax_omega);
surf(ax_joint.Values{1}, ax_joint.Values{2}, spectrum);
xlabel(ax_joint.Label{1});  % '\lambda (eigenvalue)'
ylabel(ax_joint.Label{2});  # '\omega (angular frequency)'
```

### 6. Human-Readable Conversions

For user interactions, convert between fundamental and derived:

```matlab
% Frequency (Hz) to Omega (rad/s)
omega = 2 * pi * f;

% Omega (rad/s) to Frequency (Hz)
f = omega / (2 * pi);

% Lambda to wavelength
L = 2 * pi ./ sqrt(lambda);

% Lambda to spatial scale
s = 1 ./ sqrt(lambda);
```

Access derived axes from Bct:
```matlab
B.initializeAxes();

% Get frequency in Hz (derived from omega)
freq_hz = B.AxisFrequency.Values;

% Get wavelength in mm (derived from lambda)
wavelength_mm = B.AxisWavelength.Values;
```

## Migration Guide

### Old Code (Deprecated)
```matlab
% Time domain filters on frequency (Hz)
phi = @(f) exp(-0.5 * ((f - f0) / sigma_f)^2);

% SpectralGrid with time
[lambda_grid, t_grid] = ndgrid(lambda, t);
```

### New Code (Current)
```matlab
% Time domain filters on omega (rad/s)
phi = @(omega) exp(-0.5 * ((omega - omega0) / sigma_omega)^2);

% SpectralGrid with omega
[lambda_grid, omega_grid] = meshgrid(lambda, omega);
```

## Benefits

1. **Consistency**: All filters defined on fundamental spectral axes (λ, ω)
2. **Clarity**: Separates internal representation (fundamental) from user interaction (derived)
3. **Flexibility**: Easy conversion between representations via Axis objects
4. **Standards**: Follows signal processing conventions (ω for angular frequency)
5. **Extensibility**: New derived scales can be added without changing filter design

## Files Modified

- `toolbox/+bct/@bct/bct.m`:
  - Added fundamental Axis properties (AxisTime, AxisOmega, AxisVertices, AxisLambda)
  - Added derived Axis properties (AxisFrequency, AxisTemporalScale, AxisWavelength, AxisSpatialScale)
  - Updated SpectralGrid to use lambda_grid and omega_grid
  - Added initializeAxes() method
  - Updated buildSpectralGrid() to use meshgrid(lambda, omega)
  - Updated clearSpectralGrid() and hasSpectralGrid()

- `toolbox/+bct/+filters/Filter.m`:
  - Updated plotResponse() to use omega axis for Time filters

- `toolbox/+bct/+filters/+design/+time/gabor.m`:
  - Changed from frequency (Hz) to omega (rad/s) parameterization
  - Updated sigma relationship: sigma_omega = 1/sigma_t

- `toolbox/+bct/+resolution/Axis.m`:
  - Already supports all fundamental and derived axes

- `toolbox/+bct/+filters/+design/+manifold/gaussian.m`:
  - New Gaussian filter on lambda axis
