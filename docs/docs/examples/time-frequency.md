# Time-Frequency Analysis Example

Joint spectral-temporal decomposition for cortical signals.

## Overview

This example demonstrates multi-scale time-frequency analysis using bioctree's joint domain framework.

## Setup

```matlab
bioctree_start;

% Load mesh
data = load('data/mesh/fsaverage_rh_pial.mat');
B = bct.bct.fromMesh(data.V, data.F);
B.computeEigenbasis(100);

% Time parameters
T = 200;
fs = 250;  % Hz
B.Manifold.Time = bct.Time(T, fs);
```

## Multi-Band Decomposition

```matlab
% Define frequency bands
bands = struct();
bands.delta = [0.5, 4];
bands.theta = [4, 8];
bands.alpha = [8, 12];
bands.beta = [13, 30];
bands.gamma_low = [30, 60];

% Decompose signal into bands
decomposed = struct();
band_names = fieldnames(bands);

for i = 1:length(band_names)
    name = band_names{i};
    freq_range = bands.(name);
    
    % Create temporal filter
    filt = bct.Filter(B.Omega, 'bandpass', ...
        'low', freq_range(1), ...
        'high', freq_range(2), ...
        'taper', true);
    
    % Apply
    decomposed.(name) = filt.apply(signal);
end

% Visualize
figure('Position', [100, 100, 1400, 800]);
for i = 1:length(band_names)
    subplot(2, 3, i);
    bct.show.signal(B, decomposed.(band_names{i}), 'TimePoint', 100);
    title(sprintf('%s (%.1f-%.1f Hz)', ...
        band_names{i}, bands.(band_names{i})));
end
```

## Joint Spectral-Temporal Filtering

```matlab
% Create joint domain
joint = bct.Joint(B.Lambda, B.Omega);

% Smooth spatial patterns in alpha band
alpha_smooth = bct.Filter(joint, 'gaussian', ...
    'center', [10, 10], ...    % [spatial_mode, freq_Hz]
    'sigma', [5, 2]);

% Apply
alpha_pattern = alpha_smooth.apply(signal);

% Visualize
figure;
subplot(1,2,1);
bct.show.signal(B, signal, 'TimePoint', 100);
title('Original');

subplot(1,2,2);
bct.show.signal(B, alpha_pattern, 'TimePoint', 100);
title('Alpha-Band Smooth Pattern');
```

## Time-Varying Spectral Content

```matlab
% Compute short-time Fourier transform
window_size = 50;  % samples
overlap = 25;

% Compute STFT for each vertex (example: vertex 1000)
vertex_idx = 1000;
[S, F, T_stft] = spectrogram(signal.Data(vertex_idx, :), ...
    window_size, overlap, [], fs);

% Visualize
figure;
imagesc(T_stft, F, abs(S));
axis xy;
xlabel('Time (s)');
ylabel('Frequency (Hz)');
title(sprintf('STFT at Vertex %d', vertex_idx));
colorbar;
ylim([0, 50]);  % Focus on 0-50 Hz
```

## Further Reading

- [Joint Spectrum Concept](../concepts/joint-spectrum.md)
- [Joint Filters](../filters/joint-filters.md)
