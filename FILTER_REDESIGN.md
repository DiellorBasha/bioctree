# Filter System Redesign - Complete

## Overview
The Filter class has been redesigned to use function handles (like JointFilter) instead of discrete arrays. This provides:
- Evaluation at arbitrary spectral points
- Consistent design pattern across all filter types
- Separation of concerns: Manifold, Time, and Joint filters
- Clean package organization

## New Structure

### Filter Class (`bct.filters.Filter`)
- **Type**: 'Manifold', 'Time', or 'Joint'
- **Key Property**: `g` - function handle @(x) or @(lambda, t)
- **Methods**:
  - `getResponse(x)` - Evaluate filter at query points
  - `plotResponse()` - Visualize filter response
  - `getModeIndices()` - Get eigenmode indices in band (Manifold only)

### Package Organization

```
toolbox/+bct/+filters/
├── Filter.m              (NEW - function handle based)
├── JointFilter.m         (existing)
└── +design/
    ├── +manifold/        (NEW)
    │   ├── heat.m        - g = @(λ) exp(-τ*λ/λ_max)
    │   └── mexh.m        - Mexican hat wavelet
    ├── +time/            (NEW)
    │   └── gabor.m       - Gabor wavelet in frequency domain
    └── +joint/           (REORGANIZED)
        ├── diffusion.m   (moved)
        ├── separable.m   (moved)
        └── wave.m        (moved)
```

## Design Functions

### Manifold Filters

#### Heat Kernel
```matlab
% Returns: g = @(lambda) exp(-tau * lambda / lambda_max)
g = bct.filters.design.manifold.heat(manifold, 'tau', 0.1);

% Usage:
filt = bct.filters.Filter('Manifold');
filt.Manifold = B.Manifold;
filt.g = bct.filters.design.manifold.heat(B.Manifold, 'tau', 0.05);
filt.KernelType = 'heat';
```

**Parameters**:
- `tau` - Diffusion time (default: 0.1)
  - Higher τ → more diffusion (lowpass)
  - Lower τ → less diffusion (preserves high freq)

#### Mexican Hat Wavelet
```matlab
% Returns: g = @(lambda) (1-t²)·exp(-t²/2) where t=(λ-λ₀)/(sx·λ_max)
g = bct.filters.design.manifold.mexh(manifold, 'sx', 0.1, 'lambda0', 500);

% Usage:
filt = bct.filters.Filter('Manifold');
filt.Manifold = B.Manifold;
filt.g = bct.filters.design.manifold.mexh(B.Manifold, 'sx', 0.05, 'lambda0', 500);
filt.KernelType = 'mexh';
```

**Parameters**:
- `sx` - Spectral width (default: 0.1)
  - Smaller → narrower bandpass
  - Larger → wider bandpass
- `lambda0` - Center eigenvalue (default: λ_max/2)

### Time Filters

#### Gabor Wavelet
```matlab
% Returns: phi = @(f) exp(-0.5 * ((f-f₀)/σ_f)²)
phi = bct.filters.design.time.gabor('f0', 10, 'sigma_t', 0.05);

% Usage:
filt = bct.filters.Filter('Time');
filt.Time = B.Time;
filt.g = bct.filters.design.time.gabor('f0', 10, 'sigma_t', 0.05);
filt.KernelType = 'gabor';
```

**Parameters**:
- `f0` - Center frequency in Hz (default: 10)
- `sigma_t` - Temporal width in seconds (default: 0.1)
- `sigma_f` - Frequency width in Hz (auto: 1/(2π·σ_t))

### Joint Filters

Existing joint filter designs have been moved to `+design/+joint/`:
- `diffusion.m` - Heat diffusion with dispersion
- `separable.m` - Separable spatial-temporal filter
- `wave.m` - Wave propagation filter

These return `JointFilter` objects with both spatial and temporal kernels.

## Usage Examples

### Create and Evaluate Manifold Filter
```matlab
% Create filter
filt = bct.filters.Filter('Manifold');
filt.Manifold = B.Manifold;
filt.g = bct.filters.design.manifold.heat(B.Manifold, 'tau', 0.1);
filt.KernelType = 'heat';

% Evaluate at specific eigenvalues
response = filt.getResponse([0, 100, 500, 1000]);

% Plot response
filt.plotResponse();

% Get modes in a band
filt.lambda_band = [100, 500];
mode_indices = filt.getModeIndices();
```

### Create and Evaluate Time Filter
```matlab
% Create filter
filt = bct.filters.Filter('Time');
filt.Time = B.Time;
filt.g = bct.filters.design.time.gabor('f0', 10, 'sigma_t', 0.05);
filt.KernelType = 'gabor';

% Evaluate at specific frequencies
response = filt.getResponse([8, 10, 12, 15, 20]);

% Plot response
filt.plotResponse();
```

## Key Differences from Old Filter Class

### Old Design (Deleted)
- Stored discrete arrays: `lambda_support` [1000×1], `g_support` [1000×1]
- Required eigenvalues for design
- `kernelBand()` created tapered arrays
- `evaluateKernel()` recreated function for new points
- Inconsistent with JointFilter

### New Design
- Stores function handles: `g = @(x) ...`
- No eigenvalues needed (uses λ_max)
- Direct function evaluation at any point
- Consistent with JointFilter pattern
- Cleaner separation: Manifold/Time/Joint

## Migration Notes

### For bct.designFilter
Will need updates to work with new Filter class:
1. Create Filter('Manifold') instead of old Filter()
2. Call design.manifold.* functions to get function handles
3. Set filter.g directly (no more design() method)
4. Set filter.lambda_band for band specification

### For bct.Synthesize
Will need updates to use function handles:
1. Call filter.getResponse(eigenvalues) instead of evaluateKernel
2. For Manifold filters, evaluate at actual eigenvalues
3. For Time filters, evaluate at frequency grid
4. Filter response is now continuous (function handle)

## Testing Checklist

- [ ] Test heat kernel creation and evaluation
- [ ] Test Mexican hat wavelet creation and evaluation
- [ ] Test Gabor wavelet creation and evaluation
- [ ] Test plotResponse() for Manifold filters
- [ ] Test plotResponse() for Time filters
- [ ] Test getModeIndices() with various bands
- [ ] Update bct.designFilter to work with new Filter
- [ ] Update bct.Synthesize to use getResponse()
- [ ] Test complete workflow: design → synthesize → generate
- [ ] Verify joint filters still work (diffusion, separable, wave)

## Files Modified

Created:
- `toolbox/+bct/+filters/Filter.m` (NEW - 200 lines)
- `toolbox/+bct/+filters/+design/+manifold/heat.m` (56 lines)
- `toolbox/+bct/+filters/+design/+manifold/mexh.m` (75 lines)
- `toolbox/+bct/+filters/+design/+time/gabor.m` (62 lines)

Moved:
- `toolbox/+bct/+filters/+design/diffusion.m` → `+joint/diffusion.m`
- `toolbox/+bct/+filters/+design/separable.m` → `+joint/separable.m`
- `toolbox/+bct/+filters/+design/wave.m` → `+joint/wave.m`

Deleted:
- Old `toolbox/+bct/+filters/Filter.m` (previous discrete array implementation)
