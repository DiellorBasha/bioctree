# Dispersion

## Introduction

**Dispersion** describes how waves of different frequencies propagate at different speeds on a manifold. Understanding dispersion is crucial for detecting and characterizing traveling waves in cortical signals.

## Dispersion Relation

### Definition

The relationship between temporal frequency $\omega$ and spatial frequency $\lambda$:

$$
\omega = \omega(\lambda)
$$

### Physical Interpretation

- **Non-dispersive** ($\omega \propto \lambda$): All frequencies travel at same speed
- **Dispersive** ($\omega \propto f(\lambda)$ nonlinear): Different frequencies spread out over time

## Types of Dispersion

### 1. Linear (Non-Dispersive)

$$\omega = c \lambda$$

where $c$ is constant velocity.

**Example**: Diffusion on flat surfaces

```matlab
% Linear dispersion
c = 0.5;  % m/s
omega = c * lambda;
```

### 2. Square Root (Weakly Dispersive)

$$\omega = a \sqrt{\lambda}$$

**Example**: Cortical waves with spatially extended interactions

```matlab
% Fit square root dispersion
B.computeDispersion('Type', 'sqrt');
```

### 3. General Polynomial

$$\omega = a_0 + a_1 \lambda + a_2 \lambda^2 + \cdots$$

```matlab
% Polynomial fit
B.computeDispersion('Type', 'polynomial', 'Order', 3);
```

## Computing Dispersion in Bioctree

### From Data

```matlab
% Load spatiotemporal signal
signal = bct.Signal(B.Manifold, data_NxT, 'meg_data');

% Compute dispersion relation
B.computeDispersion(signal);

% Access fitted parameters
omega_of_lambda = B.Lambda.dispersion;
dispersion_type = B.Lambda.dispersionType;
coefficients = B.Lambda.dispersionCoeffs;
```

### Visualization

```matlab
% Plot dispersion relation
figure;
B.Lambda.plotDispersion();
xlabel('Spatial Frequency λ (eigenvalue)');
ylabel('Temporal Frequency ω (Hz)');
title('Dispersion Relation');
grid on;
```

## Velocity Kernels

### Phase Velocity

Speed of phase fronts:

$$
v_p(\lambda) = \frac{\omega(\lambda)}{\lambda}
$$

```matlab
% Compute phase velocity
vp = B.Lambda.phaseVelocity();

% Plot
plot(B.Lambda.eigenvalues, vp);
xlabel('λ');
ylabel('v_p (m/s)');
title('Phase Velocity');
```

### Group Velocity

Speed of wave packet envelope:

$$
v_g(\lambda) = \frac{d\omega(\lambda)}{d\lambda}
$$

```matlab
% Compute group velocity
vg = B.Lambda.groupVelocity();

% Plot both
figure;
plot(B.Lambda.eigenvalues, vp, 'DisplayName', 'Phase');
hold on;
plot(B.Lambda.eigenvalues, vg, 'DisplayName', 'Group');
legend;
xlabel('λ');
ylabel('Velocity (m/s)');
```

## Velocity-Selective Filtering

### Filter for Specific Velocity

```matlab
% Extract waves traveling at 0.5 m/s
vg_filter = bct.Filter(joint, 'groupvelocity', ...
    'target', 0.5, ...         % Target velocity
    'tolerance', 0.1);         % ±0.1 m/s

waves_05 = vg_filter.apply(signal);
```

### Multi-Velocity Decomposition

```matlab
% Decompose into velocity components
velocities = [0.2, 0.5, 0.8, 1.2];  % m/s

for i = 1:length(velocities)
    filt = bct.Filter(joint, 'groupvelocity', ...
        'target', velocities(i), 'tolerance', 0.1);
    
    components{i} = filt.apply(signal);
end
```

## Dispersion Analysis

### Measure from Cross-Spectrum

```matlab
% Compute cross-spectrum between spatial modes
cross_spec = B.Lambda.crossSpectrum(signal);

% Extract peak frequencies per mode
[peak_freqs, peak_powers] = B.Lambda.peakFrequencies(cross_spec);

% Fit dispersion relation
[coeffs, fit_quality] = B.Lambda.fitDispersion(peak_freqs);
```

### Validate Dispersion Model

```matlab
% Compute residuals
omega_predicted = B.Lambda.dispersion(lambda_values);
omega_measured = measured_frequencies;
residuals = omega_measured - omega_predicted;

% R² goodness of fit
R2 = 1 - sum(residuals.^2) / sum((omega_measured - mean(omega_measured)).^2);
fprintf('R² = %.3f\n', R2);
```

## Wave Packet Filtering with Dispersion

### Dispersion-Aware Wave Packets

```matlab
% Use empirical dispersion relation
wp_filter = bct.Filter(joint, 'wavepacket', ...
    'dispersion', B.Lambda.dispersion, ...  % Use fitted relation
    'center_freq', 10, ...
    'bandwidth', 2);

wp_signal = wp_filter.apply(signal);
```

### Chirp Detection

For dispersive media, wave packets "chirp" (change frequency):

```matlab
% Detect chirping wave packets
chirp_filter = bct.Filter(joint, 'chirp', ...
    'dispersion', B.Lambda.dispersion, ...
    'start_freq', 8, ...
    'end_freq', 12, ...
    'duration', 0.5);  % seconds
```

## Applications

### 1. Differentiate Wave Types

```matlab
% Alpha waves (linear dispersion)
alpha_disp = B.computeDispersion(alpha_signal, 'Type', 'linear');

% Spindles (dispersive)
spindle_disp = B.computeDispersion(spindle_signal, 'Type', 'sqrt');

% Compare
figure;
subplot(1,2,1); alpha_disp.plot(); title('Alpha');
subplot(1,2,2); spindle_disp.plot(); title('Spindles');
```

### 2. Wave Speed Mapping

```matlab
% Create velocity map across cortex
vg_map = zeros(B.Manifold.N, 1);
for i = 1:B.Manifold.N
    % Dominant frequency at vertex i
    [~, dom_freq_idx] = max(abs(fft(signal.Data(i, :))));
    dom_lambda = B.Lambda.eigenvalues(dom_freq_idx);
    
    % Group velocity at that frequency
    vg_map(i) = B.Lambda.groupVelocity(dom_lambda);
end

% Visualize
bct.show.signal(B, vg_map, 'Title', 'Group Velocity Map');
```

### 3. Direction-Resolved Waves

```matlab
% Combine velocity with direction
phase_grad = B.Manifold.computeGradient(phase);
wave_velocity_vectors = vg_map .* phase_grad;

% Show as vector field
bct.show.vectorField(B, wave_velocity_vectors);
```

## Numerical Methods

### Fitting Algorithms

```matlab
% Least squares (default)
B.computeDispersion('Method', 'leastsquares');

% Robust fit (outlier resistant)
B.computeDispersion('Method', 'robust');

% Weighted fit (confidence weights)
B.computeDispersion('Method', 'weighted', 'Weights', weights);
```

### Uncertainty Quantification

```matlab
% Bootstrap confidence intervals
[coeffs, ci] = B.computeDispersion('Bootstrap', true, 'Iterations', 1000);

% Plot with confidence bands
B.Lambda.plotDispersion('ConfidenceIntervals', true);
```

## Further Reading

- [Wave Packets](wave-packets.md)
- [Joint Spectrum](joint-spectrum.md)
- [Wave Packet Tutorial](../tutorials/wavepacket.md)
- [Detect Waves Tutorial](../tutorials/detect-waves.md)
