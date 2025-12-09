# Joint Spectral Domain

## Introduction

The **Joint Domain** in Bioctree represents the tensor product of multiple 1D domains, enabling multidimensional spectral analysis. The most common is the joint spectral-temporal domain: **Lambda × Omega**.

## Motivation

Many real-world signals have structure in multiple dimensions simultaneously:

- **Neural oscillations**: Specific spatial patterns at specific frequencies
- **Traveling waves**: Coupled spatiotemporal dynamics
- **Event-related responses**: Transient spatiotemporal patterns

Standard separated analysis (spatial-then-temporal) misses joint structure.

## Mathematical Foundation

### Tensor Product of Domains

For domains $\mathcal{D}_1$ and $\mathcal{D}_2$:

$$
\mathcal{D}_1 \otimes \mathcal{D}_2 = \{(x_1, x_2) : x_1 \in \mathcal{D}_1, x_2 \in \mathcal{D}_2\}
$$

### Joint Transform

Forward transform (2D):
$$
\hat{f}(i, j) = \langle f, \phi_i \otimes \psi_j \rangle
$$

where $\phi_i$ are bases of $\mathcal{D}_1$ and $\psi_j$ are bases of $\mathcal{D}_2$.

## Lambda × Omega Domain

### Definition

$$
\text{Joint} = \Lambda \otimes \Omega
$$

- **Lambda**: Spatial frequency (eigenmodes)
- **Omega**: Temporal frequency (Hz)

**Dimensions**: $[K \times F]$ where:
- $K$: Number of eigenmodes
- $F$: Number of frequency bins

### Creating Joint Domains

```matlab
% Create BCT object with eigenbasis
B = bct.bct.fromMesh(V, F);
B.computeEigenbasis(100);

% Add temporal dimension
B.Manifold.Time = bct.Time(200, 250);  % 200 samples at 250 Hz

% Joint domain is automatically available
joint = bct.Joint(B.Lambda, B.Omega);

% Or access via BCT object
joint = B.getJointDomain('Lambda', 'Omega');
```

## Joint Domain Filtering

### Separable Filters

Product of 1D filters:
$$
h(i, j) = h_{\Lambda}(i) \cdot h_{\Omega}(j)
$$

```matlab
% Spatial low-pass × Temporal band-pass
spatial_filt = bct.Filter(B.Lambda, 'lowpass', 'cutoff', 30);
temporal_filt = bct.Filter(B.Omega, 'bandpass', 'low', 8, 'high', 12);

% Combined separable filter
joint_filt = bct.Filter(joint, 'separable', ...
    'spatial', spatial_filt, ...
    'temporal', temporal_filt);
```

### Non-Separable Filters

General 2D kernel $h(i, j)$ that cannot be factored:

```matlab
% 2D Gaussian on joint domain
joint_filt = bct.Filter(joint, 'gaussian', ...
    'center', [20, 10], ...   % [spatial_mode, freq_Hz]
    'sigma', [5, 2]);         % [spatial_bw, freq_bw]

% Apply to spatiotemporal signal
sig = bct.Signal(B.Manifold, data_NxT, 'meg_data');
filtered = joint_filt.apply(sig);
```

## Applications

### 1. Oscillation Detection

Find spatial patterns oscillating at specific frequencies:

```matlab
% Alpha oscillation (8-12 Hz) with smooth spatial pattern
alpha_filt = bct.Filter(joint, 'gaussian', ...
    'center', [10, 10], ...   % Low spatial freq, 10 Hz temporal
    'sigma', [5, 2]);

alpha_pattern = alpha_filt.apply(signal);
```

### 2. Traveling Wave Analysis

```matlab
% Wave with specific velocity
% Uses dispersion relation: ω = c|λ|
wave_filt = bct.Filter(joint, 'wavepacket', ...
    'velocity', 0.5, ...      % m/s
    'center_freq', 10, ...    % Hz
    'bandwidth', 2);

wave_signal = wave_filt.apply(signal);
```

### 3. Multi-Scale Time-Frequency

```matlab
% Different spatial scales at different frequencies
bands = [
    1, 20, 4, 8;      % Spatial 1-20, Temporal 4-8 Hz
    20, 40, 8, 12;    % Spatial 20-40, Temporal 8-12 Hz
    40, 60, 13, 30;   % Spatial 40-60, Temporal 13-30 Hz
];

for i = 1:size(bands, 1)
    filt = bct.Filter(joint, 'bandpass', ...
        'spatial_low', bands(i,1), 'spatial_high', bands(i,2), ...
        'temporal_low', bands(i,3), 'temporal_high', bands(i,4));
    
    decomposition{i} = filt.apply(signal);
end
```

## Visualization

### 2D Spectrum

```matlab
% Compute joint spectrum
spectrum_2d = joint.computeSpectrum(signal);

% Visualize as heatmap
figure;
imagesc(spectrum_2d);
xlabel('Temporal Frequency (Hz)');
ylabel('Spatial Frequency (Eigenmode)');
colorbar;
title('Joint Spectral-Temporal Power');
```

### Filter Kernel Visualization

```matlab
% Visualize 2D filter kernel
filt = bct.Filter(joint, 'gaussian', ...);
kernel_2d = filt.evaluate();

figure;
imagesc(kernel_2d);
xlabel('Omega (Hz)');
ylabel('Lambda (Mode)');
title('Joint Filter Kernel');
colorbar;
```

## Higher-Order Joint Domains

### 3D: Lambda × Omega × Layer

For multi-condition experiments:

```matlab
% Add layer dimension
Layer = bct.Layer([1, 2, 3]);  % 3 experimental conditions

% Create 3D joint domain
joint_3d = bct.Joint(B.Lambda, B.Omega, Layer);

% 3D filter
filt_3d = bct.Filter(joint_3d, 'gaussian', ...
    'center', [20, 10, 2], ...  % [spatial, temporal, layer]
    'sigma', [5, 2, 0.5]);
```

### Time × Lambda (Time-Varying Spatial)

```matlab
% Joint time-spectral (different from Lambda × Omega!)
joint_time_lambda = bct.Joint(B.Time, B.Lambda);

% Filter: smooth in time, bandpass in space
filt = bct.Filter(joint_time_lambda, 'separable', ...
    'time', bct.Filter(B.Time, 'gaussian', 'sigma', 10), ...
    'lambda', bct.Filter(B.Lambda, 'bandpass', 'low', 20, 'high', 40));
```

## Efficient Computation

### Separable Kernels

For separable filters, use 1D operations:

```matlab
% Instead of 2D convolution
% Step 1: Filter in spatial domain
sig_spatial = spatial_filt.apply(signal);

% Step 2: Filter in temporal domain
sig_both = temporal_filt.apply(sig_spatial);

% Result same as joint filter, but faster
```

### Partial Transforms

```matlab
% Transform only in one dimension
% Keep other dimension in time/space
sig_spectral = B.Lambda.forward(signal);  % [K × T]
% Now filter in (Lambda, Time) space instead of (Lambda, Omega)
```

## Further Reading

- [Wave Packets](wave-packets.md)
- [Dispersion](dispersion.md)
- [Joint Filters](../filters/joint-filters.md)
- [Time-Frequency Example](../examples/time-frequency.md)
