# Wave Packet Analysis

Detect and analyze traveling waves on cortical surfaces.

## Overview

This tutorial demonstrates how to detect traveling wave packets in spatiotemporal neural data.

## Setup

```matlab
% Load mesh and compute eigenbasis
B = bct.bct.fromMesh(V, F);
B.computeEigenbasis(100);

% Add temporal dimension
num_timepoints = 200;
sampling_rate = 250;  % Hz
B.Manifold.Time = bct.Time(num_timepoints, sampling_rate);

% Load/create spatiotemporal signal [N × T]
signal = bct.Signal(B.Manifold, meg_data, 'meg_signal');
```

## Step 1: Compute Dispersion Relation

```matlab
% Estimate dispersion from data
B.computeDispersion(signal);

% Visualize
figure;
B.Lambda.plotDispersion();
xlabel('Spatial Frequency λ');
ylabel('Temporal Frequency ω (Hz)');
title('Empirical Dispersion Relation');
```

## Step 2: Create Wave Packet Filter

```matlab
% Create joint domain
joint = bct.Joint(B.Lambda, B.Omega);

% Wave packet filter
wp_filter = bct.Filter(joint, 'wavepacket', ...
    'velocity', 0.5, ...        % Group velocity (m/s)
    'center_freq', 10, ...      % Alpha band center
    'bandwidth', 2, ...         % Frequency bandwidth
    'spatial_sigma', 0.05);     % Spatial extent (5 cm)

% Apply filter
wp_response = wp_filter.apply(signal);
```

## Step 3: Detect Wave Events

```matlab
% Threshold wave packet response
threshold = 3 * std(wp_response.Data(:));
wave_mask = wp_response.Data > threshold;

% Find peaks in time
num_detected = sum(any(wave_mask, 1));
fprintf('Detected %d time points with waves\n', num_detected);
```

## Step 4: Visualize Traveling Waves

```matlab
% Animate wave propagation
bct.show.wavepacket_movie(B, wp_response, 'FrameRate', 20);

% Plot phase map at specific time
t = 100;
phase = angle(hilbert(wp_response.Data, [], 2));
bct.show.phase(B, phase(:, t), 'Colormap', 'hsv');
```

## Further Reading

- [Detect Traveling Waves](detect-waves.md)
- [Wave Packets Concept](../concepts/wave-packets.md)
- [Examples: Wave Packets](../examples/wavepackets.md)
