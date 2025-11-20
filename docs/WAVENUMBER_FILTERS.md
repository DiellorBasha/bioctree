# Wavenumber-Based Filter Design

## Key Update: Physical Spatial Filtering

**Date:** November 20, 2025

### Problem with Raw Eigenvalue (λ) Filters

Using raw eigenvalues λ for spatial filtering causes:
- **Nonlinear frequency response** (λ = k², not k)
- **Unstable spatial bands**
- **High-frequency artifacts**
- **Speckled, noisy signals**

### Solution: Wavenumber-Based Filtering

Filters now use **physical wavenumber**:
```
k = sqrt(λ)  (rad/mm)
```

This provides:
✓ Linear spatial frequency response
✓ Smooth, stable bandpass characteristics  
✓ Clean signals without artifacts
✓ Physical interpretability

---

## Updated Filter API

### Gaussian Filter

**New (recommended):**
```matlab
[filt.g, params] = bct.filters.design.manifold.gaussian(B.Manifold, ...
    'k0', 7, 'sigma_k', 4.5);  % Wavenumber in rad/mm
```

**Old (deprecated):**
```matlab
[filt.g, params] = bct.filters.design.manifold.gaussian(B.Manifold, ...
    'lambda0', 50, 'sigma', 20);  % Shows deprecation warning
```

### Heat Filter

```matlab
[filt.g, params] = bct.filters.design.manifold.heat(B.Manifold, ...
    'tau', 0.1);  % Internally uses wavenumber
```

---

## Mathematical Formulation

### Manifold Filters (Spatial Only)

**Wavenumber-based Gaussian:**
```
H(k) = exp(-0.5 * ((k - k₀) / σₖ)²)
where k = sqrt(λ)
```

**Implementation:**
```matlab
g = @(lambda) exp(-0.5 * ((sqrt(lambda) - k0) / sigma_k).^2);
```

### Joint Filters (Future Implementation)

**Separable:**
```
H(k,ω) = Hₛ(k) · Hₜ(ω)
```

**Grid:**
```matlab
[K_grid, Omega_grid] = meshgrid(k, omega);
```

---

## Spatial Frequency Axes

### Wavenumber k (rad/mm)
- **Internal representation**
- Linear spatial frequency
- k = sqrt(λ)

### Spatial Frequency fₛ (cycles/mm)
- **User-friendly**
- fₛ = k / (2π)

### Eigenvalue λ
- **Legacy/internal only**
- λ = k²
- Used for eigendecomposition

---

## Temporal Frequency Axes

### Angular Frequency ω (rad/s)
- **Internal representation**
- ω = 2π · fₜ

### Frequency fₜ (Hz)
- **User-friendly**
- Standard neuroscience unit

---

## Parameters Returned

All filter design functions now return `params` structure:

```matlab
params.k0           % Center wavenumber (rad/mm)
params.sigma_k      % Wavenumber bandwidth (rad/mm)
params.k_band       % [k_min, k_max] in rad/mm
params.lambda_band  % [λ_min, λ_max] for Synthesize
params.lambda0      % For reference
```

---

## Complete Example

```matlab
% Load mesh
B = bct.io.import.mesh('path/to/mesh.pial');

% Design Gaussian filter in wavenumber
filt = bct.filters.Filter('Manifold');
filt.Manifold = B.Manifold;

k0 = 7;         % 7 rad/mm center wavenumber
sigma_k = 4.5;  % 4.5 rad/mm bandwidth

[filt.g, params] = bct.filters.design.manifold.gaussian(B.Manifold, ...
    'k0', k0, 'sigma_k', sigma_k);

filt.lambda_band = params.lambda_band;  % Auto: [7.56, 117.56]
filt.KernelType = "gaussian";

% Synthesize and generate
B.addFilter(filt);
B.Synthesize(1);
sig = B.Generate('label', 'gaussian_k7');

% Visualize
trisurf(B.Manifold.F, B.Manifold.V(:,1), B.Manifold.V(:,2), B.Manifold.V(:,3), ...
    sig.Data, 'EdgeColor', 'none');
```

---

## Backward Compatibility

Old `lambda0` and `sigma` parameters still work but show deprecation warnings:

```
Warning: lambda0 is deprecated. Use k0=sqrt(lambda0) instead.
Warning: sigma is deprecated. Use sigma_k for wavenumber width.
```

---

## Benefits Summary

1. **Physical Meaning:** k represents actual spatial frequency (rad/mm)
2. **Smooth Filters:** No nonlinear distortion from λ = k²
3. **Stable Signals:** No high-frequency artifacts or speckles
4. **Interpretable:** Easy to understand spatial scales
5. **Composable:** Works naturally with joint (k,ω) filters

---

## See Also

- `example_wavenumber_filters.m` - Complete demonstration
- `bct.filters.design.manifold.gaussian` - Updated documentation
- `bct.filters.design.manifold.heat` - Updated documentation
