# Wave Packets

## Introduction

**Wave packets** are localized oscillatory patterns that propagate across manifolds. In neuroscience, they appear as traveling waves in cortical activity. Bioctree provides specialized tools for detecting and analyzing wave packets on cortical surfaces.

## Theory

### Definition

A wave packet is a signal localized in both **space** and **frequency**:

$$
\psi(x, t) = A(x) e^{i(\mathbf{k} \cdot \mathbf{x} - \omega t)}
$$

where:
- $A(x)$: Envelope (localization)
- $\mathbf{k}$: Wave vector (spatial frequency)
- $\omega$: Temporal frequency
- $\mathbf{k} \cdot \mathbf{x} - \omega t$: Phase

### On Manifolds

Replace Euclidean wave vector with eigenmode decomposition:

$$
\psi_i(t) = \sum_{k} a_k(t) \phi_k(x_i)
$$

where $a_k(t)$ are time-varying spectral coefficients.

## Dispersion Relation

Connects spatial and temporal frequencies:

$$
\omega = \omega(\lambda)
$$

For cortical waves, common forms:
- **Diffusive**: $\omega \propto \lambda$ (linear)
- **Oscillatory**: $\omega \propto \sqrt{\lambda}$ (dispersive)

```matlab
% Compute dispersion relation from data
B.computeDispersion();

% Access fitted relation
omega_lambda = B.Lambda.dispersion(lambdas);

% Visualize
B.Lambda.plotDispersion();
```

## Wave Packet Detection

### Method 1: Template Matching

```matlab
% Create wave packet filter
wp_filter = bct.Filter(joint_domain, 'wavepacket', ...
    'velocity', 0.5, ...        % Group velocity (m/s)
    'center_freq', 10, ...      % Central frequency (Hz)
    'bandwidth', 2, ...         % Frequency bandwidth (Hz)
    'spatial_sigma', 0.02);     % Spatial localization (m)

% Detect wave packets
wp_response = wp_filter.apply(signal);

% Find peaks (detected wave packets)
[peaks, locs] = findpeaks(wp_response.Data(:));
```

### Method 2: Time-Frequency Decomposition

```matlab
% Continuous wavelet transform in joint domain
scales = logspace(log10(8), log10(30), 20);  % 8-30 Hz
cwt_coeffs = bct.transforms.cwtJoint(signal, scales, B);

% Identify wave packet regions
threshold = 3 * std(abs(cwt_coeffs(:)));
wp_mask = abs(cwt_coeffs) > threshold;
```

## Group Velocity

The speed of wave packet propagation:

$$
v_g = \frac{d\omega}{d\lambda}
$$

```matlab
% Compute group velocity kernel
vg_kernel = B.Lambda.groupVelocity();

% Create velocity-selective filter
vg_filter = bct.Filter(joint, 'velocity', ...
    'target_velocity', 0.5, ...  % m/s
    'tolerance', 0.1);

% Extract waves at specific velocity
waves_05ms = vg_filter.apply(signal);
```

## Wave Packet Features

### 1. Envelope

```matlab
% Extract envelope via Hilbert transform
analytic_signal = hilbert(signal.Data, [], 2);  % Along time
envelope = abs(analytic_signal);

% Visualize envelope
bct.show.signal(B, envelope, 'TimePoint', 100);
```

### 2. Instantaneous Phase

```matlab
% Phase from analytic signal
phase = angle(analytic_signal);

% Phase velocity
phase_velocity = diff(unwrap(phase, [], 2), 1, 2) * fs / (2*pi);
```

### 3. Instantaneous Frequency

```matlab
% Frequency from phase derivative
inst_freq = fs * diff(unwrap(phase, [], 2), 1, 2) / (2*pi);

% Average frequency per vertex
mean_freq = mean(inst_freq, 2);
```

## Traveling Wave Analysis

### Direction Detection

```matlab
% Compute phase gradient (wave direction)
phase_grad = B.Manifold.computeGradient(phase(:, t));

% Direction vector at each vertex
wave_direction = phase_grad ./ vecnorm(phase_grad, 2, 2);

% Visualize as vector field
bct.show.vectorField(B, wave_direction);
```

### Wave Speed Estimation

```matlab
% Track phase front over time
t1 = 50; t2 = 60;
phase_diff = phase(:, t2) - phase(:, t1);
time_diff = (t2 - t1) / fs;

% Speed = distance / time
distances = B.Manifold.geodesicDistance(source_vertex);
speed = distances ./ (phase_diff / (2*pi) * time_diff);
```

## Applications in Neuroscience

### Alpha Waves

```matlab
% Detect alpha-band traveling waves
alpha_wp = bct.Filter(joint, 'wavepacket', ...
    'velocity', 0.3, ...       % Typical alpha velocity
    'center_freq', 10, ...     % Alpha peak
    'bandwidth', 2);

alpha_waves = alpha_wp.apply(meg_signal);
```

### Theta Waves

```matlab
% Theta traveling waves (4-8 Hz)
theta_wp = bct.Filter(joint, 'wavepacket', ...
    'velocity', 0.1, ...       % Slower than alpha
    'center_freq', 6, ...
    'bandwidth', 2);
```

### Spindles

```matlab
% Sleep spindles (10-16 Hz, transient)
spindle_wp = bct.Filter(joint, 'wavepacket', ...
    'velocity', 0.5, ...
    'center_freq', 13, ...
    'bandwidth', 3, ...
    'temporal_sigma', 0.5);    % Short-lived
```

## Visualization

### Wave Packet Movie

```matlab
% Animate wave packet propagation
bct.show.wavepacket_movie(B, wp_response, 'FrameRate', 20);
```

### Phase Map

```matlab
% Show instantaneous phase on surface
bct.show.phase(B, phase, 'TimePoint', 100, 'Colormap', 'hsv');
```

### Wavefront Tracking

```matlab
% Track specific phase value (e.g., π/2)
target_phase = pi/2;
wavefront = bct.show.wavefront(B, phase, target_phase);
```

## Advanced Topics

### Multi-Component Wave Packets

```matlab
% Separate multiple simultaneous wave packets
num_components = 3;
[components, params] = bct.analysis.separateWavePackets(signal, num_components);
```

### Wave Packet Interactions

```matlab
% Detect collision/interference
interaction_metric = bct.analysis.waveInteraction(wp1, wp2);
```

## Further Reading

- [Dispersion](dispersion.md)
- [Joint Spectrum](joint-spectrum.md)
- [Wave Packet Tutorial](../tutorials/wavepacket.md)
- [Detection Example](../examples/wavepackets.md)
