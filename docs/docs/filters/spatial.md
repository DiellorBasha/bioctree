# Spatial Filters

Spatial filters operate on the manifold or its spectral dual (Lambda domain) to process spatial structure of signals.

## Overview

Spatial filtering in Bioctree modifies the spatial frequency content of signals on cortical surfaces or graphs, analogous to image filtering but adapted to curved geometries.

## Filter Domains

### Manifold Domain
Direct spatial operations (less common):
```matlab
filt = bct.Filter(B.Manifold, 'delta', 'x0', vertex_idx);
```

### Lambda Domain (Spectral)
Most spatial filtering happens here:
```matlab
filt = bct.Filter(B.Lambda, 'lowpass', 'cutoff', 30);
```

## Common Spatial Filters

### 1. Low-Pass (Smoothing)

```matlab
% Ideal low-pass
lp = bct.Filter(B.Lambda, 'lowpass', 'cutoff', 30);
smooth_signal = lp.apply(signal);

% Gaussian smoothing (preferred)
gauss = bct.Filter(B.Lambda, 'gaussian', 'center', 0, 'sigma', 15);
smooth_signal = gauss.apply(signal);
```

**Effect**: Removes fine spatial details, smooths across surface

**Use cases**:
- Noise reduction
- Multi-subject averaging
- Visualization enhancement

### 2. High-Pass (Edge Detection)

```matlab
% Ideal high-pass
hp = bct.Filter(B.Lambda, 'highpass', 'cutoff', 50);
edges = hp.apply(signal);
```

**Effect**: Retains sharp spatial changes, removes smooth background

**Use cases**:
- Detect activation boundaries
- Find spatial gradients
- Highlight sulcal/gyral patterns

### 3. Band-Pass (Scale Selection)

```matlab
% Select spatial scale
bp = bct.Filter(B.Lambda, 'bandpass', 'low', 20, 'high', 60);
mid_scale = bp.apply(signal);

% With smooth transitions
bp_smooth = bct.Filter(B.Lambda, 'bandpass', ...
    'low', 20, 'high', 60, 'taper', true);
```

**Effect**: Isolates specific spatial frequencies

**Use cases**:
- Multi-scale decomposition
- Texture analysis
- Feature extraction at specific scales

### 4. Notch (Remove Specific Modes)

```matlab
% Remove artifact in specific eigenmodes
notch = bct.Filter(B.Lambda, 'notch', 'center', 42, 'width', 2);
cleaned = notch.apply(signal);
```

## Kernel Functions

All fundamental kernels work on Lambda:

```matlab
% Gaussian (smooth transition)
bct.Filter(B.Lambda, 'gaussian', 'center', 25, 'sigma', 10);

% Box (ideal, ringing)
bct.Filter(B.Lambda, 'box', 'center', 25, 'width', 20);

% Hamming window
bct.Filter(B.Lambda, 'hamming', 'center', 25, 'width', 20);

% Custom kernel
custom_kernel = exp(-0.01 * B.Lambda.eigenvalues);
bct.Filter(B.Lambda, 'custom', 'kernel', custom_kernel);
```

## Multi-Scale Analysis

### Octave Bands

```matlab
% Dyadic decomposition
num_octaves = 4;
base_freq = 10;

for oct = 1:num_octaves
    low = base_freq * 2^(oct-1);
    high = base_freq * 2^oct;
    
    filt = bct.Filter(B.Lambda, 'bandpass', 'low', low, 'high', high);
    scales{oct} = filt.apply(signal);
end
```

### Laplacian Pyramid

```matlab
% Build pyramid
pyramid = bct.filters.buildPyramid(B, signal, 'Levels', 5);

% Reconstruct
reconstructed = bct.filters.reconstructPyramid(pyramid);
```

## Practical Examples

### Example 1: Noise Removal

```matlab
% Add noise
noisy = signal;
noisy.Data = noisy.Data + 0.5 * randn(size(noisy.Data));

% Low-pass filter
denoised_filt = bct.Filter(B.Lambda, 'gaussian', 'center', 0, 'sigma', 20);
denoised = denoised_filt.apply(noisy);

% Compare
figure;
subplot(1,2,1); bct.show.signal(B, noisy); title('Noisy');
subplot(1,2,2); bct.show.signal(B, denoised); title('Denoised');
```

### Example 2: ROI Extraction

```matlab
% Localize around vertex
roi_center = 5000;
roi_filter = bct.Filter(B.Manifold, 'delta', 'x0', roi_center);

% Transform to spectral
roi_spectral = B.Manifold.transform(roi_filter.evaluate(), B.Lambda);

% Create spatial window
spatial_window = B.Lambda.inverse(roi_spectral .* (B.Lambda.eigenvalues < 50));
```

### Example 3: Mesh-Adaptive Smoothing

```matlab
% Smooth proportional to mesh resolution
edge_lengths = B.Manifold.computeEdgeLengths();
avg_edge = mean(edge_lengths);

% Sigma proportional to edge length
sigma = 10 * avg_edge;  % ~10 edge lengths

filt = bct.Filter(B.Lambda, 'gaussian', 'center', 0, 'sigma', sigma);
```

## Advanced Topics

### Anisotropic Filtering

```matlab
% Different smoothing in different directions
% (Requires directional decomposition)
tangent_filter = bct.Filter(B.Lambda, 'directional', ...
    'direction', direction_vector, ...
    'bandwidth', 20);
```

### Bilateral Filtering

```matlab
% Edge-preserving smoothing
bilateral = bct.filters.bilateral(B, signal, ...
    'SpatialSigma', 15, ...
    'IntensitySigma', 0.5);
```

## Further Reading

- [Temporal Filters](temporal.md)
- [Joint Filters](joint-filters.md)
- [Filter Tutorial](../tutorials/spatial-filters.md)
- [Laplace-Beltrami Operator](../concepts/laplace-beltrami.md)
