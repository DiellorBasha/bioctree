# Applying Spatial Filters

Learn how to apply spatial filters to smooth, sharpen, or decompose signals on cortical surfaces.

## Basic Workflow

```matlab
% 1. Load mesh and compute eigenbasis
B = bct.bct.fromMesh(V, F);
B.computeEigenbasis(100);

% 2. Create signal
data = randn(B.Manifold.N, 1);  % Random data
sig = bct.Signal(B.Manifold, data, 'test_signal');

% 3. Create filter
filt = bct.Filter(B.Lambda, 'lowpass', 'cutoff', 30);

% 4. Apply filter
filtered = filt.apply(sig);

% 5. Visualize
figure;
subplot(1,2,1); bct.show.signal(B, sig); title('Original');
subplot(1,2,2); bct.show.signal(B, filtered); title('Filtered');
```

## Common Filtering Tasks

### Smoothing (Noise Removal)

```matlab
% Gaussian smoothing
smooth_filt = bct.Filter(B.Lambda, 'gaussian', ...
    'center', 0, ...
    'sigma', 15);

smoothed = smooth_filt.apply(noisy_signal);
```

### Edge Detection

```matlab
% High-pass filter
edge_filt = bct.Filter(B.Lambda, 'highpass', 'cutoff', 50);
edges = edge_filt.apply(signal);
```

### Multi-Scale Decomposition

```matlab
% Define bands
bands = [1, 20; 20, 40; 40, 60; 60, 80];

% Extract each scale
scales = cell(size(bands, 1), 1);
for i = 1:size(bands, 1)
    filt = bct.Filter(B.Lambda, 'bandpass', ...
        'low', bands(i,1), 'high', bands(i,2));
    scales{i} = filt.apply(signal);
end

% Visualize
figure;
for i = 1:length(scales)
    subplot(2, 2, i);
    bct.show.signal(B, scales{i});
    title(sprintf('Modes %d-%d', bands(i,1), bands(i,2)));
end
```

## Next Steps

- [Wave Packet Analysis](wavepacket.md)
- [Detect Traveling Waves](detect-waves.md)
