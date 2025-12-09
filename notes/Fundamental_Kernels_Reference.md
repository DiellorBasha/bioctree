# Fundamental Kernels Reference

Complete reference for all fundamental signal processing kernels in `bct.filters.kernels`.

## Overview

Every complete signal processing library provides these essential kernels. The BCT toolbox implements all of them in a domain-agnostic manner, allowing them to be applied to any domain (Manifold, Lambda, Time, Omega, Joint).

---

## 1. Gaussian

**Function**: `bct.filters.kernels.gaussian()`

**Mathematical Form**:
```
h(x) = exp(-(x - c)² / (2σ²))
```

**Parameters**:
- `center` (c): Center location
- `sigma` (σ): Standard deviation (bandwidth)

**Applications**:
- Smoothing on any domain
- Localization in spectral analysis
- Window functions for time-frequency analysis

**Example**:
```matlab
filt = bct.filters.Filter(B.Lambda, 'gaussian', 'center', 50, 'sigma', 10);
H = filt.evaluate();
```

---

## 2. Low-Pass

**Function**: `bct.filters.kernels.lowpass()`

**Mathematical Form**:
```
h(x) = 1  if x < cutoff
       0  otherwise
```

**Parameters**:
- `cutoff`: Threshold value

**Applications**:
- **On Lambda**: Spatial smoothing (retains low-frequency modes)
- **On Omega**: Temporal low-pass filtering
- **On Manifold**: Blurring/smoothing

**Example**:
```matlab
filt = bct.filters.Filter(B.Lambda, 'lowpass', 'cutoff', 30);
```

---

## 3. High-Pass

**Function**: `bct.filters.kernels.highpass()`

**Mathematical Form**:
```
h(x) = 1  if x > cutoff
       0  otherwise
```

**Parameters**:
- `cutoff`: Threshold value

**Applications**:
- **On Lambda**: Edge detection (retains high-frequency modes)
- **On Omega**: Remove DC and low frequencies
- **On Manifold**: Highlight edges and gradients

**Example**:
```matlab
filt = bct.filters.Filter(B.Lambda, 'highpass', 'cutoff', 70);
```

---

## 4. Band-Pass

**Function**: `bct.filters.kernels.bandpass()`

**Mathematical Form**:
```
h(x) = 1  if low ≤ x ≤ high
       0  otherwise

(Optional Hann tapering for smooth transitions)
```

**Parameters**:
- `low`: Lower cutoff
- `high`: Upper cutoff
- `taper` (optional): Apply Hann window tapering (default: false)

**Applications**:
- Frequency band selection (EEG/MEG bands)
- Isolate specific spatial scales
- Multi-band decomposition

**Example**:
```matlab
% Ideal rectangular
filt = bct.filters.Filter(B.Omega, 'bandpass', 'low', 8, 'high', 12);

% With Hann tapering (smooth transitions)
filt = bct.filters.Filter(B.Omega, 'bandpass', 'low', 8, 'high', 12, 'taper', true);
```

---

## 5. Delta (Kronecker Delta / Dirac)

**Function**: `bct.filters.kernels.delta()`

**Mathematical Form**:
```
Discrete: h(i) = 1  if i == i₀
                 0  otherwise

Continuous: h(x) = 1  if |x - x₀| < tol
                   0  otherwise
```

**Parameters**:
- `x0`: Impulse location
- `tol` (optional): Tolerance for continuous domains (default: eps)

**Applications**:
- **Critical for testing**: Impulse responses reveal system properties
- **Wave excitation**: Single-vertex impulse → global spectral response
- **Transform testing**: Delta in one domain → constant in dual domain

**Key Properties**:
- **Manifold**: Impulse at vertex → excites ALL eigenvalues
- **Lambda**: Impulse in λ → global spatial oscillation
- **Time**: Impulse in time → flat frequency spectrum
- **Omega**: Impulse in frequency → pure sinusoid in time

**Example**:
```matlab
% Discrete (vertex domain)
filt = bct.filters.Filter(B.Manifold, 'delta', 'x0', 500);

% Continuous (eigenvalue domain)
filt = bct.filters.Filter(B.Lambda, 'delta', 'x0', 50, 'tol', 1e-6);
```

---

## 6. Laplacian-of-Gaussian (LoG)

**Function**: `bct.filters.kernels.laplacian_gaussian()`

**Mathematical Form**:
```
h(x) = -(1/(√(2π)σ³)) · (1 - z²) · exp(-z²/2)

where z = (x - center) / sigma
```

**Parameters**:
- `center`: Center location
- `sigma`: Scale parameter (σ > 0)

**Applications**:
- Edge detection (zero-crossings = edges)
- Feature extraction at multiple scales
- Blob detection in images/signals
- Alternative to Mexican hat for some applications

**Properties**:
- Zero-mean (balanced positive/negative lobes)
- Band-pass characteristic in frequency domain
- Scale-space extrema correspond to features

**Example**:
```matlab
% Single scale
filt = bct.filters.Filter(B.Lambda, 'laplacian_gaussian', 'center', 50, 'sigma', 10);

% Multi-scale edge detection
for sigma = [5, 10, 20]
  filt = bct.filters.Filter(B.Lambda, 'laplacian_gaussian', 'center', 50, 'sigma', sigma);
  H = filt.evaluate();
  % Zero-crossings indicate edges at this scale
end
```

---

## 7. Heat (Diffusion)

**Function**: `bct.filters.kernels.heat()`

**Mathematical Form**:
```
h(λ) = exp(-τλ)
```

**Parameters**:
- `tau` (τ): Diffusion time (τ > 0)

**Applications**:
- **On Lambda**: Heat diffusion on manifold
- Thermal smoothing
- Multi-scale analysis via τ scaling
- Spectral low-pass filtering

**Properties**:
- Larger τ → more smoothing
- Smaller τ → preserves more detail
- Physically corresponds to heat equation solution

**Example**:
```matlab
filt = bct.filters.Filter(B.Lambda, 'heat', 'tau', 0.1);
```

---

## 8. Gabor

**Function**: `bct.filters.kernels.gabor()`

**Mathematical Form** (2D):
```
h(x, y) = exp(-((x-cₓ)²/(2σₓ²)) - ((y-cᵧ)²/(2σᵧ²)))
```

**Parameters**:
- `center_x`, `center_y`: Center locations
- `sigma_x`, `sigma_y`: Bandwidths

**Applications**:
- Localized oscillations in joint domains
- Time-frequency analysis
- Spatiotemporal wave packets

**Example**:
```matlab
joint = B.createJoint('Lambda', 'Omega');
filt = bct.filters.Filter(joint, 'gabor', ...
  'center_x', 50, 'center_y', 15, 'sigma_x', 10, 'sigma_y', 3);
```

---

## 9. Velocity Gabor (Traveling Waves)

**Function**: `bct.filters.kernels.velocity_gabor()`

**Mathematical Form**:
```
ω = v√λ + Dλ  (dispersion relation)

h(λ, ω) = exp(-((ω-(v√λ+Dλ))²/(2σ_w²))) · exp(-((λ-λ₀)²/(2σ_λ²)))
```

**Parameters**:
- `v`: Group velocity (rad/mm/s)
- `D`: Dispersion coefficient (curvature)
- `lambda0` (λ₀): Spatial center
- `sigma_l` (σ_λ): Spatial bandwidth
- `sigma_w` (σ_w): Temporal bandwidth

**Applications**:
- Traveling cortical waves
- Dispersion analysis
- Non-separable spatiotemporal filters

**Example**:
```matlab
joint = B.createJoint('Lambda', 'Omega');
filt = bct.filters.Filter(joint, 'velocity_gabor', ...
  'v', 0.5, 'D', 0.01, 'lambda0', 50, 'sigma_l', 20, 'sigma_w', 10);
```

---

## Quick Reference Table

| Kernel | Domain | Key Parameters | Main Use |
|--------|--------|---------------|----------|
| `gaussian` | Any | center, sigma | Smoothing, localization |
| `lowpass` | Lambda/Omega | cutoff | Smoothing, low-freq retention |
| `highpass` | Lambda/Omega | cutoff | Edge enhancement |
| `bandpass` | Lambda/Omega | low, high, taper | Band selection |
| `delta` | Any | x0, tol | Impulse response, testing |
| `laplacian_gaussian` | Any | center, sigma | Edge/feature detection |
| `heat` | Lambda | tau | Diffusion smoothing |
| `gabor` | Joint | center_x/y, sigma_x/y | Localized oscillations |
| `velocity_gabor` | Lambda-Omega | v, D, lambda0 | Traveling waves |

---

## Design Philosophy

All kernels follow these principles:

1. **Domain-Agnostic**: Pure mathematical functions, no domain-specific logic
2. **Filter Binding**: Become filters when bound to a Domain via `bct.filters.Filter`
3. **Consistent API**: All return function handles with signature `@(x, params...)`
4. **Composable**: Can be combined via separable joint kernels
5. **Testable**: Delta kernel enables rigorous testing of all transforms

---

## See Also

- `bct.filters.Filter` - Filter class that binds kernels to domains
- `bct.ui.KernelEditor` - Interactive parameter control
- `examples/demo_fundamental_kernels.m` - Complete demonstration
- `examples/demo_kernel_editors.m` - Interactive GUI examples
