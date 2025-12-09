# Wave Packet Detection Example

Complete example demonstrating traveling wave detection in MEG data.

## Setup

```matlab
% Initialize bioctree
bioctree_start;

% Load cortical mesh (fsaverage right hemisphere)
data = load('data/mesh/fsaverage_rh_pial.mat');
B = bct.bct.fromMesh(data.V, data.F);

% Compute eigenbasis
fprintf('Computing eigenbasis...\n');
B.computeEigenbasis(100);
```

## Simulate Traveling Wave Data

For demonstration, we'll simulate a traveling wave:

```matlab
% Parameters
N = B.Manifold.N;     % Number of vertices
T = 200;              % Time points
fs = 250;             % Sampling rate (Hz)
wave_freq = 10;       % Hz (alpha band)
wave_velocity = 0.5;  % m/s

% Add time dimension
B.Manifold.Time = bct.Time(T, fs);

% Create synthetic traveling wave
time = (0:T-1) / fs;
source_vertex = round(N / 4);  % Start from one location

% Compute distances from source
distances = B.Manifold.geodesicDistance(source_vertex);

% Create wave: phase = 2π(ft - x/v)
phase = 2 * pi * (wave_freq * time - distances / wave_velocity);
wave_signal = cos(phase);

% Add noise
noise_level = 0.5;
noisy_wave = wave_signal + noise_level * randn(size(wave_signal));

% Create signal object
sig = bct.Signal(B.Manifold, noisy_wave, 'simulated_wave');
```

## Detect Traveling Waves

### Step 1: Compute Dispersion Relation

```matlab
fprintf('Computing dispersion relation...\n');
B.computeDispersion(sig);

% Visualize
figure('Position', [100, 100, 800, 400]);
B.Lambda.plotDispersion();
title('Empirical Dispersion Relation');
```

### Step 2: Create Wave Packet Filter

```matlab
% Create joint domain
joint = bct.Joint(B.Lambda, B.Omega);

% Design wave packet filter
wp_filter = bct.Filter(joint, 'wavepacket', ...
    'velocity', 0.5, ...        % Target velocity
    'center_freq', 10, ...      % Alpha frequency
    'bandwidth', 2, ...         % ±2 Hz
    'spatial_sigma', 0.05);     % 5cm spatial extent

% Apply filter
fprintf('Detecting wave packets...\n');
wp_response = wp_filter.apply(sig);
```

### Step 3: Extract Wave Characteristics

```matlab
% Compute analytic signal via Hilbert transform
analytic = hilbert(wp_response.Data, [], 2);

% Extract envelope
envelope = abs(analytic);

% Extract instantaneous phase
phase_instant = angle(analytic);

% Compute phase gradient (wave direction)
phase_grad = B.Manifold.computeGradient(phase_instant);
```

## Visualization

### Snapshot Comparison

```matlab
figure('Position', [100, 100, 1400, 500]);

% Original signal
subplot(1,3,1);
bct.show.signal(B, sig, 'TimePoint', 100);
title('Original Signal (t=100)');
colorbar;

% Wave packet response
subplot(1,3,2);
bct.show.signal(B, wp_response, 'TimePoint', 100);
title('Wave Packet Response');
colorbar;

% Envelope
subplot(1,3,3);
bct.show.signal(B, envelope(:, 100));
title('Instantaneous Envelope');
colorbar;
```

### Phase Evolution

```matlab
figure('Position', [100, 100, 1400, 500]);

time_points = [50, 100, 150];
for i = 1:length(time_points)
    subplot(1, 3, i);
    bct.show.phase(B, phase_instant(:, time_points(i)));
    title(sprintf('Phase at t=%d', time_points(i)));
end
```

### Wave Packet Movie

```matlab
% Animate traveling wave detection
bct.show.wavepacket_movie(B, wp_response, ...
    'FrameRate', 20, ...
    'TimeRange', [50, 150]);
```

## Quantitative Analysis

### Detect Wave Events

```matlab
% Threshold envelope to find significant wave events
threshold = mean(envelope(:)) + 2 * std(envelope(:));
wave_events = envelope > threshold;

% Count events per time point
events_per_time = sum(wave_events, 1);

% Plot event detection
figure;
plot((0:T-1)/fs, events_per_time);
xlabel('Time (s)');
ylabel('Number of Vertices in Wave');
title('Wave Event Detection');
grid on;
```

### Estimate Wave Speed

```matlab
% Track phase front over time
t1 = 80;
t2 = 120;
delta_t = (t2 - t1) / fs;

% Phase difference
delta_phase = phase_instant(:, t2) - phase_instant(:, t1);

% Unwrap phase
delta_phase_unwrap = mod(delta_phase + pi, 2*pi) - pi;

% Speed = distance / time for 2π phase change
wave_period = 1 / wave_freq;
speed_estimate = distances ./ (delta_phase_unwrap / (2*pi) * wave_period);

% Remove outliers
valid_speed = speed_estimate(abs(speed_estimate) < 2);  % < 2 m/s
mean_speed = mean(valid_speed);
std_speed = std(valid_speed);

fprintf('Estimated wave speed: %.2f ± %.2f m/s\n', mean_speed, std_speed);
fprintf('True wave speed: %.2f m/s\n', wave_velocity);
```

### Multi-Velocity Decomposition

```matlab
% Test multiple velocities
test_velocities = [0.3, 0.5, 0.7, 1.0];  % m/s
responses = cell(length(test_velocities), 1);

for i = 1:length(test_velocities)
    filt = bct.Filter(joint, 'wavepacket', ...
        'velocity', test_velocities(i), ...
        'center_freq', 10, ...
        'bandwidth', 2);
    
    responses{i} = filt.apply(sig);
end

% Compare responses
figure('Position', [100, 100, 1200, 800]);
for i = 1:length(test_velocities)
    subplot(2, 2, i);
    bct.show.signal(B, responses{i}, 'TimePoint', 100);
    title(sprintf('v = %.1f m/s', test_velocities(i)));
end
```

## Real Data Application

For real MEG/EEG data:

```matlab
% Load source-localized MEG data
% meg_data = load_meg_source_data('subject_01_task.mat');

% Create signal
% meg_sig = bct.Signal(B.Manifold, meg_data.source_estimates, 'meg');

% Detect alpha waves
% alpha_wp = bct.Filter(joint, 'wavepacket', ...
%     'velocity', 0.3, ...      % Typical cortical alpha velocity
%     'center_freq', 10, ...
%     'bandwidth', 2);
%
% alpha_waves = alpha_wp.apply(meg_sig);
```

## Summary

This example demonstrated:
1. ✅ Simulating traveling waves on cortical surface
2. ✅ Computing dispersion relation
3. ✅ Designing wave packet filters
4. ✅ Detecting wave events
5. ✅ Extracting wave characteristics (phase, velocity, direction)
6. ✅ Visualizing propagation
7. ✅ Quantitative wave analysis

## Further Reading

- [Wave Packets Concept](../concepts/wave-packets.md)
- [Wave Packet Tutorial](../tutorials/wavepacket.md)
- [Dispersion](../concepts/dispersion.md)
