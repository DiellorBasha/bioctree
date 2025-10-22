%% Bioctree HDF5 Export/Import Demonstration
% This script demonstrates the complete workflow for exporting and importing
% Bioctree analysis results using the HDF5 format with multidimensional querying.
%
% The demonstration covers:
% 1. Generate test graph signal with spatiotemporal features
% 2. Perform Bioctree analysis (simplified)
% 3. Export results to HDF5 format
% 4. Query and load specific data subsets
% 5. Visualize loaded results

close all; clear; clc;

%% Configuration
fprintf('=== Bioctree HDF5 Export/Import Demo ===\n\n');

% Demo parameters
N = 200;          % Number of vertices (cortical patches)
T = 500;          % Number of time points
fs = 250;         % Sampling frequency (Hz)
duration = T/fs;  % Signal duration (seconds)

% Configure Bioctree data system
config = bioctree_config();

% Output file (using Bioctree HDF5 format)
outputFile = fullfile(config.TempPath, 'demo_bioctree_results.bct');

%% Step 1: Generate Test Data
fprintf('1. Generating test graph signal...\n');

% Create sphere graph using GSPBox (if available) or fallback
try
    % Use GSPBox if available
    gsp_start;
    G = gsp_sphere(N);
    fprintf('   ✓ Using GSPBox sphere graph\n');
catch
    % Fallback to simple random graph
    fprintf('   ⚠ GSPBox not available, using fallback graph\n');
    
    % Generate random 3D coordinates on sphere
    theta = 2*pi*rand(N,1);
    phi = acos(2*rand(N,1)-1);
    
    coords = [sin(phi).*cos(theta), sin(phi).*sin(theta), cos(phi)];
    
    % Create adjacency matrix based on distance threshold
    D = pdist2(coords, coords);
    threshold = 0.3;
    W = sparse(D < threshold & D > 0);
    
    % Create graph structure
    G.W = W;
    G.coords = coords;
    G.N = N;
    
    % Compute Laplacian and eigendecomposition
    G.L = diag(sum(W,2)) - W;
    [G.U, lambda] = eig(full(G.L));
    G.e = diag(lambda);
end

% Generate time vector
time_vector = linspace(0, duration, T);

% Generate spatiotemporal signal with multiple patterns
fprintf('   Generating complex spatiotemporal patterns...\n');

% Base oscillatory activity
base_freq = 10; % 10 Hz
base_signal = sin(2*pi*base_freq*time_vector);

% Spatial pattern 1: Patch of activity (alpha band)
patch1_center = randi(N);
spatial_distances = pdist2(G.coords(patch1_center,:), G.coords);
alpha_patch = exp(-spatial_distances.^2 / 0.1);
alpha_freq = 8 + 4*rand(); % 8-12 Hz
alpha_signal = sin(2*pi*alpha_freq*time_vector + 2*pi*rand());

% Spatial pattern 2: Traveling wave (beta band)
wave_direction = randn(1,3);
wave_direction = wave_direction / norm(wave_direction);
projections = G.coords * wave_direction';
beta_freq = 15 + 10*rand(); % 15-25 Hz
wave_speed = 0.5; % spatial units per second
beta_signal = zeros(N, T);
for i = 1:N
    phase_shift = projections(i) / wave_speed;
    beta_signal(i,:) = sin(2*pi*beta_freq*(time_vector - phase_shift));
end

% Spatial pattern 3: Localized gamma burst
gamma_center = randi(N);
gamma_distances = pdist2(G.coords(gamma_center,:), G.coords);
gamma_patch = exp(-gamma_distances.^2 / 0.05);
gamma_freq = 40 + 20*rand(); % 40-60 Hz
gamma_window = time_vector > 0.5 & time_vector < 1.5; % 1 second burst
gamma_signal = gamma_patch * (sin(2*pi*gamma_freq*time_vector) .* gamma_window);

% Combine all patterns with noise
signal_clean = 0.3 * alpha_patch * alpha_signal + ...
               0.4 * beta_signal + ...
               0.5 * gamma_signal + ...
               0.2 * randn(N,1) * base_signal;

% Add measurement noise
noise_level = 0.1;
signal = signal_clean + noise_level * randn(N, T);

% Store in G.jtv format
G.jtv = signal;

fprintf('   ✓ Generated signal: %d vertices × %d timepoints\n', N, T);

%% Step 2: Perform Analysis
fprintf('\n2. Performing Bioctree analysis...\n');

% Spectral decomposition
fprintf('   Computing GFT...\n');
if isfield(G, 'U')
    gft_coeffs = G.U' * signal;
else
    % Compute eigendecomposition if not available
    [G.U, lambda] = eig(full(G.L));
    G.e = diag(lambda);
    gft_coeffs = G.U' * signal;
end

% Temporal Fourier analysis
fprintf('   Computing temporal FFT...\n');
signal_fft = fft(signal, [], 2);
frequencies = (0:T-1) * fs / T;

% Joint time-frequency-space analysis
fprintf('   Computing joint spectrum...\n');
joint_spectrum = abs(G.U' * signal_fft).^2;

% Gradient computation
fprintf('   Computing spatial gradients...\n');
gradients = zeros(size(G.W,1), T);
[i_idx, j_idx] = find(G.W);
for t = 1:T
    for k = 1:length(i_idx)
        i = i_idx(k);
        j = j_idx(k);
        gradients(i,t) = gradients(i,t) + (signal(j,t) - signal(i,t))^2;
    end
end
gradients = sqrt(gradients);

% Total variation
fprintf('   Computing total variation...\n');
total_variation = zeros(N, T);
for i = 1:N
    neighbors = find(G.W(i,:));
    if ~isempty(neighbors)
        for t = 1:T
            tv_sum = 0;
            for j = neighbors
                tv_sum = tv_sum + abs(signal(i,t) - signal(j,t));
            end
            total_variation(i,t) = tv_sum;
        end
    end
end

% Signal statistics
fprintf('   Computing statistics...\n');
signal_stats = zeros(N, 4); % mean, std, skewness, kurtosis
for i = 1:N
    signal_stats(i,1) = mean(signal(i,:));
    signal_stats(i,2) = std(signal(i,:));
    signal_stats(i,3) = skewness(signal(i,:));
    signal_stats(i,4) = kurtosis(signal(i,:));
end

% Simple event detection (threshold crossings)
fprintf('   Performing event detection...\n');
threshold = 2 * std(signal(:));
[event_vertices, event_times] = find(abs(signal) > threshold);
events = [event_vertices, event_times, signal(sub2ind(size(signal), event_vertices, event_times))];

% Define spatial patches for demonstration
anterior_mask = G.coords(:,3) > 0; % Upper hemisphere
posterior_mask = G.coords(:,3) < 0; % Lower hemisphere
left_mask = G.coords(:,1) < 0;     % Left hemisphere  
right_mask = G.coords(:,1) > 0;    % Right hemisphere

patches = struct();
patches.anterior = find(anterior_mask);
patches.posterior = find(posterior_mask);
patches.left = find(left_mask);
patches.right = find(right_mask);

% Define frequency bands
freq_bands = struct();
freq_bands.delta = [1, 4];
freq_bands.theta = [4, 8];
freq_bands.alpha = [8, 13];
freq_bands.beta = [13, 30];
freq_bands.gamma = [30, 100];

fprintf('   ✓ Analysis completed\n');

%% Step 3: Export to HDF5
fprintf('\n3. Exporting to HDF5 format...\n');

% Delete existing file if it exists
if exist(outputFile, 'file')
    delete(outputFile);
end

% Prepare analysis results structure
analysis_results = struct();
analysis_results.signal_stats = signal_stats;
analysis_results.events = events;

% Export complete dataset
outbct(outputFile, G, ...
    'IncludeRawSignal', true, ...
    'IncludeSpectral', true, ...
    'IncludeDerived', true, ...
    'IncludeAnalysis', true, ...
    'GFTCoeffs', gft_coeffs, ...
    'JointSpectrum', joint_spectrum, ...
    'Gradients', gradients, ...
    'TotalVariation', total_variation, ...
    'SpatialPatches', patches, ...
    'FrequencyBands', freq_bands, ...
    'AnalysisResults', analysis_results, ...
    'TimeVector', time_vector, ...
    'FrequencyVector', frequencies, ...
    'SamplingFrequency', fs, ...
    'Verbose', true);

fprintf('   ✓ Export completed: %s\n', outputFile);

%% Step 4: Demonstrate Selective Loading
fprintf('\n4. Demonstrating selective data loading...\n');

% Query 1: Load complete dataset
fprintf('\n   Query 1: Loading complete dataset...\n');
data_complete = inbct(outputFile, 'Verbose', true);

% Query 2: Load only alpha band activity
fprintf('\n   Query 2: Loading alpha band data only...\n');
data_alpha = inbct(outputFile, ...
    'FreqBands', {'alpha'}, ...
    'DataTypes', {'raw', 'spectral'}, ...
    'Verbose', true);

% Query 3: Load specific time window
fprintf('\n   Query 3: Loading time window 0.5-1.5 seconds...\n');
data_timewin = inbct(outputFile, ...
    'TimeRange', [0.5, 1.5], ...
    'DataTypes', {'raw', 'derived'}, ...
    'Verbose', true);

% Query 4: Load anterior cortex data
fprintf('\n   Query 4: Loading anterior cortex patch...\n');
data_anterior = inbct(outputFile, ...
    'SpatialPatch', 'anterior', ...
    'DataTypes', {'raw', 'analysis'}, ...
    'Verbose', true);

% Query 5: Load only metadata and structure
fprintf('\n   Query 5: Loading metadata only...\n');
info_only = inbct(outputFile, ...
    'DataTypes', {}, ...
    'LoadMetadata', true, ...
    'Verbose', true);

%% Step 5: Visualize Results
fprintf('\n5. Visualizing results...\n');

% Create figure with subplots
figure('Position', [100, 100, 1200, 800]);

% Plot 1: Original signal at peak activity time
subplot(2,3,1);
[~, peak_time] = max(var(signal, [], 1));
if isfield(data_complete, 'graph') && isfield(data_complete.graph, 'coords')
    scatter3(data_complete.graph.coords(:,1), ...
             data_complete.graph.coords(:,2), ...
             data_complete.graph.coords(:,3), ...
             50, signal(:, peak_time), 'filled');
else
    scatter3(G.coords(:,1), G.coords(:,2), G.coords(:,3), ...
             50, signal(:, peak_time), 'filled');
end
colormap(gca, 'jet');
colorbar;
title('Original Signal at Peak Activity');
xlabel('X'); ylabel('Y'); zlabel('Z');
axis equal;

% Plot 2: Alpha band query result
subplot(2,3,2);
if isfield(data_alpha, 'signal')
    time_alpha = data_alpha.temporal.time_vector;
    signal_alpha = mean(data_alpha.signal.signal, 1);
    plot(time_alpha, signal_alpha, 'b-', 'LineWidth', 2);
    title('Alpha Band Activity (Average)');
    xlabel('Time (s)'); ylabel('Amplitude');
    grid on;
else
    text(0.5, 0.5, 'Alpha data not loaded', 'HorizontalAlignment', 'center');
    title('Alpha Band Query');
end

% Plot 3: Time window query result
subplot(2,3,3);
if isfield(data_timewin, 'signal')
    time_window = data_timewin.temporal.time_vector;
    signal_window = data_timewin.signal.signal;
    imagesc(time_window, 1:size(signal_window,1), signal_window);
    colormap(gca, 'jet');
    colorbar;
    title('Time Window 0.5-1.5s');
    xlabel('Time (s)'); ylabel('Vertex');
else
    text(0.5, 0.5, 'Time window data not loaded', 'HorizontalAlignment', 'center');
    title('Time Window Query');
end

% Plot 4: Spatial patch query result
subplot(2,3,4);
if isfield(data_anterior, 'signal')
    signal_anterior = data_anterior.signal.signal;
    vertex_activity = mean(signal_anterior, 2);
    
    if isfield(data_anterior, 'graph') && isfield(data_anterior.graph, 'coords')
        scatter3(data_anterior.graph.coords(:,1), ...
                 data_anterior.graph.coords(:,2), ...
                 data_anterior.graph.coords(:,3), ...
                 50, vertex_activity, 'filled');
    else
        % Use subset of original coordinates
        coords_subset = G.coords(patches.anterior, :);
        scatter3(coords_subset(:,1), coords_subset(:,2), coords_subset(:,3), ...
                 50, vertex_activity, 'filled');
    end
    
    colormap(gca, 'jet');
    colorbar;
    title('Anterior Cortex Patch');
    xlabel('X'); ylabel('Y'); zlabel('Z');
    axis equal;
else
    text(0.5, 0.5, 'Anterior patch data not loaded', 'HorizontalAlignment', 'center');
    title('Spatial Patch Query');
end

% Plot 5: Joint spectrum
subplot(2,3,5);
if isfield(data_complete, 'spectral') && isfield(data_complete.spectral, 'joint_spectrum')
    joint_spec_mag = abs(data_complete.spectral.joint_spectrum);
    freq_subset = data_complete.temporal.frequency_vector(1:min(100, end));
    
    imagesc(freq_subset, 1:size(joint_spec_mag,1), joint_spec_mag(:, 1:length(freq_subset)));
    colormap(gca, 'hot');
    colorbar;
    title('Joint Time-Frequency-Space Spectrum');
    xlabel('Frequency (Hz)'); ylabel('Graph Frequency Index');
else
    imagesc(frequencies(1:100), 1:size(joint_spectrum,1), joint_spectrum(:,1:100));
    colormap(gca, 'hot');
    colorbar;
    title('Joint Spectrum (Original)');
    xlabel('Frequency (Hz)'); ylabel('Graph Frequency Index');
end

% Plot 6: File information summary
subplot(2,3,6);
axis off;

% Display file information
info_text = {
    'HDF5 File Information:';
    sprintf('File: %s', outputFile);
    sprintf('Size: %.2f MB', dir(outputFile).bytes / 1024^2);
    '';
    'Loaded Queries:';
    sprintf('Complete: %d fields', length(fieldnames(data_complete)));
    sprintf('Alpha band: %d fields', length(fieldnames(data_alpha)));
    sprintf('Time window: %d fields', length(fieldnames(data_timewin)));
    sprintf('Anterior patch: %d fields', length(fieldnames(data_anterior)));
    '';
    'Graph Properties:';
    sprintf('Vertices: %d', N);
    sprintf('Time points: %d', T);
    sprintf('Sampling rate: %.0f Hz', fs);
    sprintf('Duration: %.2f s', duration);
};

text(0.05, 0.95, info_text, 'Units', 'normalized', ...
     'VerticalAlignment', 'top', 'FontName', 'FixedWidth', ...
     'FontSize', 8);

sgtitle('Bioctree HDF5 Export/Import Demonstration', 'FontSize', 14, 'FontWeight', 'bold');

%% Step 6: Performance Analysis
fprintf('\n6. Performance analysis...\n');

% File size analysis
fileInfo = dir(outputFile);
fprintf('   File size: %.2f MB\n', fileInfo.bytes / 1024^2);

% Query timing comparison
fprintf('   Timing selective queries...\n');

% Time complete loading
tic;
data_complete_timed = inbct(outputFile, 'Verbose', false);
complete_time = toc;

% Time selective loading (alpha band only)
tic;
data_alpha_timed = inbct(outputFile, ...
    'FreqBands', {'alpha'}, ...
    'DataTypes', {'spectral'}, ...
    'Verbose', false);
alpha_time = toc;

% Time metadata-only loading
tic;
info_timed = inbct(outputFile, ...
    'DataTypes', {}, ...
    'LoadMetadata', true, ...
    'Verbose', false);
metadata_time = toc;

fprintf('   ✓ Complete loading: %.3f seconds\n', complete_time);
fprintf('   ✓ Alpha band loading: %.3f seconds\n', alpha_time);
fprintf('   ✓ Metadata loading: %.3f seconds\n', metadata_time);
fprintf('   ✓ Speedup (alpha vs complete): %.1fx\n', complete_time / alpha_time);

%% Step 7: Demonstrate Data Management System
fprintf('\n7. Demonstrating Bioctree data management...\n');

% Show data system information
fprintf('\n   Current data configuration:\n');
bioctree_config();

% Get data system info
dataInfo = db_data_info('summary');
fprintf('\n   Data system status:\n');
fprintf('   • Total files: %d\n', dataInfo.summary.total_files);
fprintf('   • Storage used: %.1f MB\n', dataInfo.summary.total_size_mb);
fprintf('   • Bioctree files: %d .h5 + %d legacy .bct\n', ...
        dataInfo.summary.bioctree_h5_files, dataInfo.summary.legacy_bct_files);

%% Summary
fprintf('\n=== Demo Summary ===\n');
fprintf('✅ Generated %dx%d spatiotemporal graph signal\n', N, T);
fprintf('✅ Performed multi-scale Bioctree analysis\n');
fprintf('✅ Exported complete results to Bioctree HDF5 format (.h5)\n');
fprintf('✅ Demonstrated selective data querying:\n');
fprintf('   • Frequency band filtering (alpha: 8-13 Hz)\n');
fprintf('   • Temporal windowing (0.5-1.5 seconds)\n');
fprintf('   • Spatial patch selection (anterior cortex)\n');
fprintf('   • Metadata-only access\n');
fprintf('✅ Visualized loaded results in multiple formats\n');
fprintf('✅ Analyzed performance benefits of selective loading\n');
fprintf('✅ Demonstrated Bioctree data management system\n');

fprintf('Bioctree data engine features:\n');
fprintf('• Structured HDF5 storage with .h5 extension\n');
fprintf('• Organized data directories (raw/processed/derivatives)\n');
fprintf('• Automatic configuration and path management\n');
fprintf('• Performance monitoring and cleanup capabilities\n');
fprintf('• Multidimensional querying for large-scale analysis\n');

% Cleanup option with data management
fprintf('\nDemo file created: %s\n', outputFile);
fprintf('File size: %.2f MB\n', dir(outputFile).bytes / 1024^2);

response = input('Delete demo file? (y/n): ', 's');
if strcmpi(response, 'y')
    delete(outputFile);
    fprintf('Demo file deleted.\n');
    
    % Show updated data info
    dataInfo = db_data_info('summary');
    fprintf('Updated storage: %d files, %.1f MB total\n', ...
            dataInfo.summary.total_files, dataInfo.summary.total_size_mb);
else
    fprintf('Demo file preserved in: %s\n', config.TempPath);
    fprintf('Use inbct(''%s'') to reload data\n', outputFile);
    fprintf('Use db_data_info() for data system status\n');
end

fprintf('\n=== Demo Complete ===\n');