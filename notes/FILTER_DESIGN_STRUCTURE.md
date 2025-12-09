# Filter Design Package Organization

## Overview
Complete reorganization of `bct.filters.design` package with five filter types and comprehensive design functions.

## Package Structure

```
bct.filters.design/
├── manifold/                    % H(λ) - Spatial spectral filters
│   ├── gaussian.m              % Gaussian bandpass
│   ├── bandpass.m              % Bandpass with tapering
│   ├── heat.m                  % Heat kernel (lowpass)
│   ├── mexh.m                  % Mexican hat wavelet
│   └── wavelet.m               % Laplace-Beltrami wavelets
│
├── time/                        % H(ω) or H(f) - Temporal filters
│   ├── bandpass.m              % Bandpass with tapering
│   ├── morlet.m                % Morlet wavelet
│   ├── gabor.m                 % Gabor wavelet
│   ├── lowpass.m               % Lowpass with tapering
│   └── hilbert.m               % Hilbert transform
│
└── joint/                       % Joint spatial-temporal filters
    ├── separable/               % H(λ,ω) = Hλ(λ) * Hω(ω)
    │   ├── spatial_temporal.m
    │   └── spatial_temporal_wavelet.m
    │
    ├── spectral/                % H(λ,ω) - Non-separable spectral
    │   ├── gaussian2d.m
    │   └── wavepacket.m
    │
    └── dynamic/                 % K(λ,t) - Dynamic propagators
        ├── heat.m               % (moved from diffusion.m)
        ├── wave.m
        ├── schrodinger.m
        └── telegraph.m
```

## Filter Types

### 1. Manifold Filters - H(λ)
Defined on **lambda axis** (eigenvalues).

**gaussian.m**: `g(λ) = exp(-0.5·((λ-λ₀)/σ)²)`
```matlab
g = bct.filters.design.manifold.gaussian(manifold, 'lambda0', 500, 'sigma', 100);
```

**bandpass.m**: Bandpass with Hann/Hamming/Tukey tapering
```matlab
g = bct.filters.design.manifold.bandpass(manifold, [100, 500], 'taper', 'hann');
```

**heat.m**: `g(λ) = exp(-τ·λ/λ_max)`
```matlab
g = bct.filters.design.manifold.heat(manifold, 'tau', 0.1);
```

**wavelet.m**: `g(λ) = √λ · exp(-λ/(2s²))`
```matlab
g = bct.filters.design.manifold.wavelet(manifold, 'scale', 10);
```

### 2. Time Filters - H(ω) or H(f)
Defined on **omega axis** (rad/s) by default, or frequency (Hz).

**gabor.m**: `φ(ω) = exp(-0.5·((ω-ω₀)/σ_ω)²)`
```matlab
phi = bct.filters.design.time.gabor('omega0', 2*pi*10, 'sigma_t', 0.05);
```

**morlet.m**: Morlet wavelet with admissibility correction
```matlab
phi = bct.filters.design.time.morlet('f0', 10);
```

**bandpass.m**: `H(f) ∈ [f_min, f_max]` with tapering
```matlab
phi = bct.filters.design.time.bandpass([8, 12], 'taper', 'hann');
```

**lowpass.m**: `H(f) ≤ f_cutoff` with tapering or Butterworth
```matlab
phi = bct.filters.design.time.lowpass(30, 'taper', 'butter', 'order', 4);
```

**hilbert.m**: Analytic signal extraction
```matlab
phi = bct.filters.design.time.hilbert();
```

### 3. Separable Filters - H(λ,ω)
Uses **meshgrid(lambda, omega)**.

**spatial_temporal.m**: `H(λ,ω) = Hλ(λ) · Hω(ω)`
```matlab
Hlambda = bct.filters.design.manifold.gaussian(manifold, 'sigma', 100);
Homega = bct.filters.design.time.gabor('omega0', 2*pi*10);
H = bct.filters.design.joint.separable.spatial_temporal(Hlambda, Homega);
```

**spatial_temporal_wavelet.m**: Combined wavelets
```matlab
H = bct.filters.design.joint.separable.spatial_temporal_wavelet(...
    manifold, 'scale_s', 10, 'omega0', 2*pi*8);
```

### 4. Spectral Filters - H(λ,ω)
Non-separable joint spectral filters. Uses **meshgrid(lambda, omega)**.

**gaussian2d.m**: `H(λ,ω) = exp(-0.5·[(λ-λ₀)²/σ_λ² + (ω-ω₀)²/σ_ω²])`
```matlab
H = bct.filters.design.joint.spectral.gaussian2d(...
    'lambda0', 500, 'omega0', 2*pi*10, ...
    'sigma_lambda', 100, 'sigma_omega', 2*pi*2);
```

**wavepacket.m**: Wave packet with dispersion relation
```matlab
H = bct.filters.design.joint.spectral.wavepacket(...
    'dispersion', @(lambda) c * sqrt(lambda), ...
    'lambda0', 500);
```

### 5. Dynamic Filters - K(λ,t)
Dynamic propagators in time domain. Uses **ndgrid(lambda, t)**.

**heat.m** (formerly diffusion.m): Heat diffusion
```matlab
K = bct.filters.design.joint.dynamic.heat(manifold, 'tau', 0.5);
```

**wave.m**: Wave propagator `K(λ,t) = cos(c·√λ·t)`
```matlab
K = bct.filters.design.joint.dynamic.wave(manifold, 'c', 1);
```

**schrodinger.m**: `K(λ,t) = exp(-i·(ℏλ/(2m))·t)`
```matlab
K = bct.filters.design.joint.dynamic.schrodinger(manifold, 'hbar', 1, 'mass', 1);
```

**telegraph.m**: Damped wave equation
```matlab
K = bct.filters.design.joint.dynamic.telegraph(manifold, 'c', 1, 'gamma', 0.2);
```

## Filter Class Usage

### Updated Filter Types
```matlab
% Create filter with new types
filt = bct.filters.Filter('Manifold');   % H(λ)
filt = bct.filters.Filter('Time');       % H(ω) or H(f)
filt = bct.filters.Filter('Separable');  % H(λ,ω) = Hλ(λ)·Hω(ω)
filt = bct.filters.Filter('Spectral');   % H(λ,ω) non-separable
filt = bct.filters.Filter('Dynamic');    % K(λ,t)
```

### Axes Requirements

| Filter Type | Axes Required | Grid Function | Notes |
|-------------|---------------|---------------|-------|
| Manifold | Lambda (λ) | N/A | 1D spectral |
| Time | Omega (ω) or Freq (f) | N/A | 1D temporal |
| Separable | Lambda, Omega | meshgrid(λ, ω) | Product form |
| Spectral | Lambda, Omega | meshgrid(λ, ω) | General 2D |
| Dynamic | Lambda, Time | ndgrid(λ, t) | Time evolution |

### Example Workflow

```matlab
% Initialize Bct with axes
B.initializeAxes();

% 1. Manifold filter
filt1 = bct.filters.Filter('Manifold');
filt1.g = bct.filters.design.manifold.gaussian(B.Manifold, 'sigma', 100);
filt1.lambda_band = [100, 500];

% 2. Time filter
filt2 = bct.filters.Filter('Time');
filt2.g = bct.filters.design.time.bandpass([8, 12]);
filt2.freq_band = [8, 12];

% 3. Separable filter
filt3 = bct.filters.Filter('Separable');
Hlambda = bct.filters.design.manifold.heat(B.Manifold, 'tau', 0.1);
Homega = bct.filters.design.time.gabor('omega0', 2*pi*10);
filt3.g = bct.filters.design.joint.separable.spatial_temporal(Hlambda, Homega);

% 4. Spectral filter
filt4 = bct.filters.Filter('Spectral');
filt4.g = bct.filters.design.joint.spectral.gaussian2d(...
    'lambda0', 500, 'omega0', 2*pi*10);

% 5. Dynamic filter
filt5 = bct.filters.Filter('Dynamic');
filt5.g = bct.filters.design.joint.dynamic.wave(B.Manifold, 'c', 1);

% Evaluate filters
% 1D filters
response1 = filt1.getResponse(lambda_vals);
response2 = filt2.getResponse(omega_vals);

% 2D filters (need grids)
[LAMBDA, OMEGA] = meshgrid(lambda_vals, omega_vals);
response3 = filt3.g(LAMBDA, OMEGA);
response4 = filt4.g(LAMBDA, OMEGA);

% Dynamic filters (need time grid)
[LAMBDA, T] = ndgrid(lambda_vals, t_vals);
response5 = filt5.g(LAMBDA, T);
```

## Migration Notes

### Old Structure (Deprecated)
```
+design/
  ├── diffusion.m    → joint/dynamic/heat.m
  ├── separable.m    → joint/separable/spatial_temporal.m
  └── wave.m         → joint/dynamic/wave.m
```

### New Additions
- **manifold/**: bandpass.m, wavelet.m
- **time/**: bandpass.m, lowpass.m, morlet.m, hilbert.m
- **joint/separable/**: spatial_temporal_wavelet.m
- **joint/spectral/**: gaussian2d.m, wavepacket.m
- **joint/dynamic/**: schrodinger.m, telegraph.m

## Key Design Principles

1. **Fundamental Axes**: Filters defined on Lambda (λ) and Omega (ω)
2. **Grid Functions**:
   - Separable/Spectral: `meshgrid(lambda, omega)` → [T × K]
   - Dynamic: `ndgrid(lambda, t)` → [K × T]
3. **Function Handles**: All kernels return function handles
4. **Composability**: Separable filters built from Manifold + Time components
5. **Physics-Based**: Dynamic filters represent PDE propagators

## Files Created/Modified

**New Manifold Filters**:
- `manifold/bandpass.m`
- `manifold/wavelet.m`

**New Time Filters**:
- `time/bandpass.m`
- `time/lowpass.m`
- `time/morlet.m`
- `time/hilbert.m`

**New Joint Filters**:
- `joint/separable/spatial_temporal_wavelet.m`
- `joint/spectral/gaussian2d.m`
- `joint/spectral/wavepacket.m`
- `joint/dynamic/schrodinger.m`
- `joint/dynamic/telegraph.m`

**Modified**:
- `Filter.m` - Updated to support 5 filter types
- `time/gabor.m` - Updated to use omega parameterization

**Moved**:
- `diffusion.m` → `joint/dynamic/heat.m`
- `separable.m` → `joint/separable/spatial_temporal.m`
- `wave.m` → `joint/dynamic/wave.m`
