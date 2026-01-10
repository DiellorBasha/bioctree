# Joint Filters (λ–ω)

Joint filters operate on the tensor product of spatial and temporal frequency domains, enabling simultaneous spatiotemporal-spectral decomposition.

## Overview

Joint filtering combines spatial and temporal filtering in the **Lambda × Omega** domain, allowing detection of specific spatial patterns oscillating at specific frequencies.

## Creating Joint Filters

```matlab
% Create joint domain
joint = bct.Joint(B.Lambda, B.Omega);

% Create filter on joint domain
joint_filt = bct.Filter(joint, kernel_type, parameters);
```

## Filter Types

### 1. Separable Filters

Product of 1D filters:

```matlab
% Spatial low-pass × Temporal alpha-band
spatial = bct.Filter(B.Lambda, 'lowpass', 'cutoff', 30);
temporal = bct.Filter(B.Omega, 'bandpass', 'low', 8, 'high', 12);

joint_sep = bct.Filter(joint, 'separable', ...
    'spatial', spatial, 'temporal', temporal);
```

**Efficient computation**: Apply filters sequentially instead of 2D operation

### 2. Gaussian 2D

```matlab
% 2D Gaussian centered at (mode=20, freq=10Hz)
joint_gauss = bct.Filter(joint, 'gaussian', ...
    'center', [20, 10], ...    % [spatial_mode, temporal_freq]
    'sigma', [5, 2]);          % [spatial_bw, temporal_bw]
```

### 3. Dispersion-Based

Uses empirical dispersion relation:

```matlab
% Compute dispersion
B.computeDispersion(signal);

% Filter along dispersion curve
disp_filt = bct.Filter(joint, 'dispersion', ...
    'velocity', 0.5, ...       % Group velocity
    'bandwidth', 0.1);         % Velocity tolerance
```

## Applications

### Alpha-Band Spatial Patterns

```matlab
% Extract smooth spatial patterns in alpha band
alpha_smooth = bct.Filter(joint, 'gaussian', ...
    'center', [10, 10], ...    % Low spatial freq, 10 Hz
    'sigma', [5, 2]);

alpha_pattern = alpha_smooth.apply(signal);
```

### Multi-Band Spatial Decomposition

```matlab
bands = {'delta', 'theta', 'alpha', 'beta'};
freq_ranges = [1, 4; 4, 8; 8, 12; 13, 30];
spatial_cutoff = 30;

for i = 1:length(bands)
    spatial_filt = bct.Filter(B.Lambda, 'lowpass', 'cutoff', spatial_cutoff);
    temporal_filt = bct.Filter(B.Omega, 'bandpass', ...
        'low', freq_ranges(i,1), 'high', freq_ranges(i,2));
    
    joint_filt = bct.Filter(joint, 'separable', ...
        'spatial', spatial_filt, 'temporal', temporal_filt);
    
    results.(bands{i}) = joint_filt.apply(signal);
end
```

## Further Reading

- [Wave Packet Filters](wavepacket-filters.md)
- [Joint Spectrum Concept](../concepts/joint-spectrum.md)
- [Dispersion](../concepts/dispersion.md)
