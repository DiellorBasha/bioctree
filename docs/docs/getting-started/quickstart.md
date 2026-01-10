# Quickstart Guide

Get up and running with Bioctree in 5 minutes! This guide walks you through a complete analysis from loading a mesh to visualizing filtered signals.

## Prerequisites

Ensure you've completed [installation](installation.md) and have run `bioctree_start`.

## 5-Minute Tutorial

### Step 1: Initialize Bioctree (30 seconds)

```matlab
% Start bioctree (if not already done)
bioctree_start;
```

### Step 2: Load a Cortical Mesh (30 seconds)

```matlab
% Load the right hemisphere pial surface from fsaverage
data = load('data/mesh/fsaverage_rh_pial.mat');

% Create bioctree object
B = bct.bct.fromMesh(data.V, data.F);

% Display info
disp(B);
```

**Output:**
```
bct object with:
  Manifold: 40962 vertices, 81920 faces
  Lambda: Not computed
  Signals: 0 signals
```

### Step 3: Compute Eigenbasis (1 minute)

```matlab
% Compute first 100 eigenmodes of the Laplace-Beltrami operator
B.computeEigenbasis(100);

% Visualize a few eigenmodes
bct.show.eigenmodes(B, [1, 5, 10, 20]);
```

This creates an interactive visualization showing spatial oscillation patterns on the cortical surface.

### Step 4: Create a Test Signal (30 seconds)

```matlab
% Generate random spatiotemporal data
num_vertices = B.Manifold.N;  % 40962
num_timepoints = 200;
sampling_rate = 250;  % Hz

% Random signal (simulating neural activity)
signal_data = randn(num_vertices, num_timepoints);

% Add temporal dimension to manifold
B.Manifold.Time = bct.Time(num_timepoints, sampling_rate);

% Create signal object
sig = bct.Signal(B.Manifold, signal_data, 'random_activity');

% Add to bct object
B.addSignal(sig);
```

### Step 5: Apply a Spatial Filter (1 minute)

```matlab
% Create a low-pass filter on the spectral domain (Lambda)
% This will smooth the signal spatially
spatial_filter = bct.Filter(B.Lambda, 'lowpass', 'cutoff', 30);

% Apply the filter
filtered_sig = spatial_filter.apply(sig);

% Visualize original vs filtered at time point 100
figure('Position', [100, 100, 1200, 400]);

subplot(1,2,1);
bct.show.signal(B, sig, 'TimePoint', 100, 'Title', 'Original Signal');

subplot(1,2,2);
bct.show.signal(B, filtered_sig, 'TimePoint', 100, 'Title', 'Spatially Filtered');
```

### Step 6: Temporal Filtering (1 minute)

```matlab
% Create temporal filter (alpha band: 8-12 Hz)
temporal_filter = bct.Filter(B.Omega, 'bandpass', ...
    'low', 8, 'high', 12, 'taper', true);

% Apply to signal
alpha_sig = temporal_filter.apply(sig);

% Plot time series at a random vertex
vertex_idx = randi(num_vertices);
time_vector = (0:num_timepoints-1) / sampling_rate;

figure;
plot(time_vector, sig.Data(vertex_idx, :), 'k', 'LineWidth', 0.5);
hold on;
plot(time_vector, alpha_sig.Data(vertex_idx, :), 'r', 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Amplitude');
legend('Original', 'Alpha Band (8-12 Hz)');
title(sprintf('Time Series at Vertex %d', vertex_idx));
grid on;
```

### Step 7: Save Results (30 seconds)

```matlab
% Create BCT file to save analysis
bct_obj = bct.create('quickstart_results');

% Write signal data
bct_obj.write_raw(signal_data, sampling_rate);

% Write mesh structure
graph_struct = struct('V', data.V, 'F', data.F);
bct_obj.write_graph(graph_struct);

% Validate the file
report = bct_obj.validate();
if report.ok
    fprintf('✓ BCT file saved successfully!\n');
else
    fprintf('⚠ Validation warnings:\n%s\n', strjoin(report.messages, '\n'));
end
```

## What You Just Did

1. ✅ Loaded a high-resolution cortical mesh (40,962 vertices)
2. ✅ Computed 100 eigenmodes of the Laplace-Beltrami operator
3. ✅ Created a spatiotemporal signal
4. ✅ Applied spatial filtering (spectral low-pass)
5. ✅ Applied temporal filtering (alpha band extraction)
6. ✅ Saved results to a standardized BCT file

## Next Steps: Real Analysis Examples

### Example 1: Detect Spatial Hotspots

```matlab
% Load MEG source-localized data (example)
% data = load('my_meg_source_data.mat');

% Find spatial hotspots using high-pass filter
highpass_filt = bct.Filter(B.Lambda, 'highpass', 'cutoff', 50);
edges_signal = highpass_filt.apply(sig);

% Threshold to find peaks
threshold = 2 * std(edges_signal.Data(:));
hotspots = edges_signal.Data > threshold;

% Visualize
bct.show.signal(B, edges_signal, 'Threshold', threshold);
```

### Example 2: Multi-Scale Decomposition

```matlab
% Define frequency bands (spatial scales)
bands = [
    1, 20;   % Very low frequencies (large spatial scales)
    20, 40;  % Low frequencies
    40, 60;  % Mid frequencies
    60, 80;  % High frequencies
];

% Decompose signal into bands
figure;
for i = 1:size(bands, 1)
    % Create bandpass filter
    filt = bct.Filter(B.Lambda, 'bandpass', ...
        'low', bands(i,1), 'high', bands(i,2));
    
    % Apply filter
    band_sig = filt.apply(sig);
    
    % Visualize
    subplot(2, 2, i);
    bct.show.signal(B, band_sig, 'TimePoint', 100);
    title(sprintf('Spatial Band %d-%d', bands(i,1), bands(i,2)));
end
```

### Example 3: Gaussian Smoothing Kernel

```matlab
% Instead of ideal low-pass, use smooth Gaussian kernel
gaussian_filt = bct.Filter(B.Lambda, 'gaussian', ...
    'center', 0, ...     % Center at DC (0 Hz spatial)
    'sigma', 15);        % Bandwidth

smoothed = gaussian_filt.apply(sig);

% Visualize kernel and result
figure;
subplot(1,2,1);
kernel = gaussian_filt.evaluate();
plot(0:length(kernel)-1, kernel, 'LineWidth', 2);
title('Gaussian Kernel');
xlabel('Eigenmode Index');
ylabel('Filter Gain');
grid on;

subplot(1,2,2);
bct.show.signal(B, smoothed, 'TimePoint', 100);
title('Smoothed Signal');
```

### Example 4: Joint Spatiotemporal Filtering

```matlab
% Create joint domain (Lambda × Omega)
joint_domain = bct.Joint(B.Lambda, B.Omega);

% Create 2D filter: low spatial frequencies × alpha band
joint_filter = bct.Filter(joint_domain, 'gaussian', ...
    'center', [10, 10], ...   % [spatial_freq, temporal_freq] in Hz
    'sigma', [5, 2]);         % Bandwidth in each dimension

% Apply joint filter
joint_filtered = joint_filter.apply(sig);

% Compare
figure;
subplot(1,2,1);
bct.show.signal(B, sig, 'TimePoint', 100);
title('Original');

subplot(1,2,2);
bct.show.signal(B, joint_filtered, 'TimePoint', 100);
title('Joint Filtered (spatial + temporal)');
```

## Common Workflows

### Workflow 1: Source-Localized MEG/EEG Analysis

```matlab
% 1. Load your data
meg_data = ...; % [vertices × time]
B = bct.bct.fromMesh(V, F);
B.computeEigenbasis(100);

% 2. Band-pass filter (e.g., beta band)
beta_filter = bct.Filter(B.Omega, 'bandpass', 'low', 13, 'high', 30);
sig = bct.Signal(B.Manifold, meg_data, 'meg_beta');
beta_sig = beta_filter.apply(sig);

% 3. Spatial smoothing
spatial_smooth = bct.Filter(B.Lambda, 'gaussian', 'center', 0, 'sigma', 20);
final_sig = spatial_smooth.apply(beta_sig);

% 4. Visualize evolution
bct.show.signal_movie(B, final_sig, 'FrameRate', 10);
```

### Workflow 2: Wave Packet Detection

```matlab
% 1. Compute dispersion relation
B.computeDispersion();

% 2. Create wave packet filter
wp_filter = bct.Filter(joint_domain, 'wavepacket', ...
    'velocity', 0.5, ...      % m/s
    'center_freq', 10, ...    % Hz
    'bandwidth', 2);          % Hz

% 3. Detect traveling waves
wp_sig = wp_filter.apply(sig);

% 4. Track wave fronts
bct.show.wavefront(B, wp_sig);
```

### Workflow 3: Multi-Layer Experimental Design

```matlab
% Load data from multiple conditions
condition_A = ...; % [vertices × time]
condition_B = ...; % [vertices × time]
condition_C = ...; % [vertices × time]

% Stack as 3D array [layers × time × vertices]
multi_layer = cat(1, ...
    reshape(condition_A, [1, size(condition_A)]), ...
    reshape(condition_B, [1, size(condition_B)]), ...
    reshape(condition_C, [1, size(condition_C)]));

% Save to BCT file
bct_obj = bct.create('experiment_results');
bct_obj.write_raw_layers(multi_layer, fs, [0, 1, 2]);

% Retrieve specific condition
cond_A = bct_obj.read_raw_layers(1, ':', ':');
```

## Tips for Efficient Analysis

### 1. **Start with fewer eigenmodes**
```matlab
% Good for initial exploration
B.computeEigenbasis(50);  % Fast, covers main features

% Increase for final analysis
B.computeEigenbasis(200); % More detail, slower
```

### 2. **Visualize filter kernels before applying**
```matlab
filt = bct.Filter(B.Lambda, 'gaussian', 'center', 20, 'sigma', 5);
kernel = filt.evaluate();
plot(kernel);  % Check the shape before applying
```

### 3. **Use partial data loading for large files**
```matlab
% Load only specific time range and vertices
bct_obj = bct.open('large_dataset.h5');
subset = bct_obj.read_raw([100, 500], [1, 1000]);  % Time 100-500, vertices 1-1000
```

### 4. **Leverage GPU for large datasets** (if available)
```matlab
% Convert to GPU array for faster computation
signal_data_gpu = gpuArray(signal_data);
% Process on GPU, then gather results
result = gather(processed_data_gpu);
```

## Troubleshooting

**Q: Eigendecomposition is slow**  
A: Reduce number of modes or use sparse solver:
```matlab
B.computeEigenbasis(50, 'Method', 'sparse');
```

**Q: Visualization is cluttered**  
A: Use subsampling or focus on regions of interest:
```matlab
bct.show.signal(B, sig, 'Subsample', 0.1);  % Show 10% of vertices
```

**Q: Out of memory**  
A: Process data in chunks or use partial loading from BCT files.

## Where to Go from Here

- **[Tutorials](../tutorials/load-mesh.md)**: Detailed step-by-step guides
- **[Concepts](../concepts/overview.md)**: Deep dive into the mathematics
- **[API Reference](../api/matlab/bct.md)**: Complete function documentation
- **[Examples](../examples/index.md)**: Real-world analysis examples
