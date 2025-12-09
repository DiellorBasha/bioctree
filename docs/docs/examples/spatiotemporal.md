# Spatiotemporal Analysis Pipeline

Complete end-to-end workflow for analyzing cortical signals.

## Complete Workflow

```matlab
%% 1. Initialization
bioctree_start;

%% 2. Load Mesh
fprintf('Loading cortical mesh...\n');
data = load('data/mesh/fsaverage_rh_pial.mat');
B = bct.bct.fromMesh(data.V, data.F);

fprintf('  Vertices: %d\n', B.Manifold.N);
fprintf('  Faces: %d\n', size(B.Manifold.F, 1));

%% 3. Compute Eigenbasis
fprintf('\nComputing eigenbasis...\n');
tic;
B.computeEigenbasis(100);
fprintf('  Completed in %.2f seconds\n', toc);

%% 4. Load Signal Data
% Example: MEG source-localized data
% In practice, load your data here
fprintf('\nCreating test signal...\n');
T = 200;
fs = 250;
B.Manifold.Time = bct.Time(T, fs);

% Simulate data (replace with real data)
signal_data = randn(B.Manifold.N, T);
sig = bct.Signal(B.Manifold, signal_data, 'test_signal');

%% 5. Spatial Filtering
fprintf('\nApplying spatial filter...\n');
spatial_filt = bct.Filter(B.Lambda, 'gaussian', ...
    'center', 0, 'sigma', 20);
sig_spatial = spatial_filt.apply(sig);

%% 6. Temporal Filtering
fprintf('Applying temporal filter (alpha band)...\n');
temporal_filt = bct.Filter(B.Omega, 'bandpass', ...
    'low', 8, 'high', 12, 'taper', true);
sig_alpha = temporal_filt.apply(sig_spatial);

%% 7. Joint Filtering
fprintf('Applying joint filter...\n');
joint = bct.Joint(B.Lambda, B.Omega);
joint_filt = bct.Filter(joint, 'separable', ...
    'spatial', spatial_filt, ...
    'temporal', temporal_filt);
sig_joint = joint_filt.apply(sig);

%% 8. Visualization
fprintf('\nVisualizing results...\n');

figure('Position', [100, 100, 1400, 900]);

% Original
subplot(2,3,1);
bct.show.signal(B, sig, 'TimePoint', 100);
title('Original Signal');

% Spatially filtered
subplot(2,3,2);
bct.show.signal(B, sig_spatial, 'TimePoint', 100);
title('Spatial Filtering');

% Temporally filtered
subplot(2,3,3);
bct.show.signal(B, sig_alpha, 'TimePoint', 100);
title('Temporal Filtering (Alpha)');

% Joint filtered
subplot(2,3,4);
bct.show.signal(B, sig_joint, 'TimePoint', 100);
title('Joint Filtering');

% Time series at random vertex
vertex_idx = randi(B.Manifold.N);
time_vector = (0:T-1) / fs;

subplot(2,3,5);
plot(time_vector, sig.Data(vertex_idx, :), 'k', 'LineWidth', 0.5);
hold on;
plot(time_vector, sig_alpha.Data(vertex_idx, :), 'r', 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Amplitude');
legend('Original', 'Alpha Filtered');
title(sprintf('Time Series (Vertex %d)', vertex_idx));
grid on;

% Eigenmode spectrum
subplot(2,3,6);
kernel = spatial_filt.evaluate();
plot(0:length(kernel)-1, kernel, 'LineWidth', 2);
xlabel('Eigenmode Index');
ylabel('Filter Gain');
title('Spatial Filter Kernel');
grid on;

%% 9. Save Results
fprintf('\nSaving results...\n');
bct_obj = bct.create('analysis_results');
bct_obj.write_raw(sig_joint.Data, fs);
bct_obj.write_graph(struct('V', data.V, 'F', data.F));

fprintf('✓ Analysis complete!\n');
```

## Summary

This pipeline demonstrated:
- ✅ Loading cortical mesh
- ✅ Computing eigenbasis
- ✅ Spatial filtering
- ✅ Temporal filtering
- ✅ Joint domain filtering
- ✅ Comprehensive visualization
- ✅ Saving results to BCT file

## Adapt for Your Data

Replace the simulated data section with your actual data loading:

```matlab
% Load your MEG/EEG source data
meg_data = load('my_meg_source.mat');
sig = bct.Signal(B.Manifold, meg_data.source_estimates, 'meg_signal');
```
