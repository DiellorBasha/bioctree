# Joint Domain Class Reference

The `bct.Joint` class represents tensor products of domains.

## Constructor

```matlab
joint = bct.Joint(domain1, domain2);
joint = bct.Joint(domain1, domain2, domain3, ...);  % Higher-order
```

**Parameters**:
- `domain1, domain2, ...`: Domain objects to combine

## Common Joint Domains

### Lambda × Omega
Spectral-frequency domain:

```matlab
joint_spectral = bct.Joint(B.Lambda, B.Omega);
```

**Dimensions**: [K × F] where K = num eigenmodes, F = num frequencies

### Time × Lambda
Time-varying spectral:

```matlab
joint_time_spectral = bct.Joint(B.Time, B.Lambda);
```

### Higher-Order
```matlab
% Lambda × Omega × Layer
joint_3d = bct.Joint(B.Lambda, B.Omega, Layer);
```

## Properties

### Domains
Constituent domains.
```matlab
domains = joint.Domains;  % Cell array
```

### Size
Total dimension.
```matlab
sz = joint.size();  % Product of domain sizes
```

## Methods

### transform
Transform signal to/from joint domain.

```matlab
% Transform to joint domain
joint_coeffs = joint.transform(signal);

% Transform from joint domain
reconstructed = joint.inverse(joint_coeffs);
```

## Usage with Filters

```matlab
% Create joint filter
filt = bct.Filter(joint, 'gaussian', ...
    'center', [20, 10], ...   % [spatial_mode, freq_Hz]
    'sigma', [5, 2]);

% Apply
filtered = filt.apply(signal);
```

## Separable Operations

For efficiency, decompose into sequential 1D operations:

```matlab
% Instead of 2D joint filtering
% Do sequential 1D filtering

% Step 1: Spatial
sig_spatial = spatial_filt.apply(signal);

% Step 2: Temporal
sig_both = temporal_filt.apply(sig_spatial);
```

## See Also

- [Joint Spectrum Concept](../../concepts/joint-spectrum.md)
- [Joint Filters](../../filters/joint-filters.md)
