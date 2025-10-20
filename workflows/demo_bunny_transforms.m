function demo_bunny_transforms()
% DEMO_BUNNY_TRANSFORMS Transform analysis on Stanford bunny with MEG data
%
% This demo showcases various graph-time signal transforms using the
% Stanford bunny graph with real MEG sensor data:
%   - Graph Fourier Transform (GFT)
%   - Joint Fourier Transform (JFT) 
%   - Short-Time Vertex Fourier Transform (STVFT)
%   - Short-Time Vertex Wavelet Transform (STVWT)
%
% Each transform provides different perspectives on the signal structure
% in the joint graph-time domain.

fprintf('=== Bioctree Transforms Demo: Stanford Bunny ===\n\n');

%% 1. Setup and Data Loading
fprintf('1. Loading data and preparing graph...\n');

% Load graph and data (reuse from main pipeline)
[G, X, fs, t] = load_bunny_data();
fprintf('   Graph: %d vertices, %d edges\n', G.N, G.Ne);
fprintf('   Signal: %d samples at %.1f Hz\n', length(t), fs);

%% 2. Graph Fourier Transform (GFT)
fprintf('\n2. Graph Fourier Transform analysis...\n');

% Compute GFT for all time points
X_gft = gsp_gft(G, X);
fprintf('   GFT computed: %d graph frequencies × %d time points\n', size(X_gft));

% Analyze spectral content
spectral_power = abs(X_gft).^2;
freq_power = mean(spectral_power, 2);  % Average over time
temporal_power = mean(spectral_power, 1);  % Average over frequencies

% Find spectral peaks
[sorted_power, freq_order] = sort(freq_power, 'descend');
dominant_modes = freq_order(1:min(10, G.N));

fprintf('   Dominant graph frequencies: %s\n', mat2str(dominant_modes(1:5)'));
fprintf('   Spectral concentration: %.1f%% in top 10 modes\n', ...
        100 * sum(sorted_power(1:10)) / sum(sorted_power));

%% 3. Joint Fourier Transform (JFT) - if implemented
fprintf('\n3. Joint Fourier Transform (JFT)...\n');

% Note: This would use custom JFT implementation
try
    if exist('jft', 'file')
        % Window selection for JFT
        window_size = min(256, size(X, 2));
        X_windowed = X(:, 1:window_size);
        
        X_jft = jft(G, X_windowed);
        fprintf('   JFT computed: %d × %d joint coefficients\n', size(X_jft));
        
        % Analyze joint spectrum
        joint_power = abs(X_jft).^2;
        fprintf('   Joint spectral energy range: [%.2e, %.2e]\n', ...
                min(joint_power(:)), max(joint_power(:)));
    else
        fprintf('   JFT implementation → to be implemented in gsp/transforms/\n');
        X_jft = [];
    end
catch ME
    fprintf('   JFT failed: %s\n', ME.message);
    X_jft = [];
end

%% 4. Short-Time Vertex Fourier Transform (STVFT)
fprintf('\n4. Short-Time Vertex Fourier Transform...\n');

% STVFT parameters
window_length = 64;  % Samples
overlap = 32;        % Samples
nfft = 64;          % FFT points

% Compute STVFT for a subset of vertices
n_vertices_stvft = min(20, G.N);
vertices_stvft = 1:n_vertices_stvft;

fprintf('   Computing STVFT for %d vertices...\n', n_vertices_stvft);

% Initialize STVFT storage
n_windows = floor((size(X, 2) - overlap) / (window_length - overlap));
X_stvft = zeros(n_vertices_stvft, nfft, n_windows);

% Compute STVFT
for v = 1:n_vertices_stvft
    vertex_idx = vertices_stvft(v);
    signal = X(vertex_idx, :);
    
    % Short-time Fourier transform
    [S, ~, ~] = spectrogram(signal, window_length, overlap, nfft, fs, 'yaxis');
    X_stvft(v, :, :) = S;
end

fprintf('   STVFT computed: %d vertices × %d frequencies × %d windows\n', ...
        size(X_stvft, 1), size(X_stvft, 2), size(X_stvft, 3));

%% 5. Short-Time Vertex Wavelet Transform (STVWT)
fprintf('\n5. Short-Time Vertex Wavelet Transform...\n');

% STVWT parameters (using continuous wavelet transform)
wavelet = 'cmor1-1';  % Complex Morlet wavelet
scales = 1:0.5:20;    % Scale range

% Compute STVWT for subset of vertices
n_vertices_stvwt = min(10, G.N);
vertices_stvwt = 1:n_vertices_stvwt;

fprintf('   Computing STVWT for %d vertices with %d scales...\n', ...
        n_vertices_stvwt, length(scales));

% Initialize storage
X_stvwt = cell(n_vertices_stvwt, 1);

% Compute wavelet transform for each vertex
for v = 1:n_vertices_stvwt
    vertex_idx = vertices_stvwt(v);
    signal = X(vertex_idx, :);
    
    % Continuous wavelet transform
    [wt, freq_wt] = cwt(signal, scales, wavelet, 1/fs);
    X_stvwt{v} = wt;
end

fprintf('   STVWT computed: %d vertices × %d scales × %d samples\n', ...
        n_vertices_stvwt, length(scales), size(X, 2));

%% 6. Comparative Analysis
fprintf('\n6. Comparative transform analysis...\n');

% Compare spectral concentration
gft_concentration = compute_spectral_concentration(spectral_power);
fprintf('   GFT spectral concentration: %.2f\n', gft_concentration);

if ~isempty(X_jft)
    jft_concentration = compute_spectral_concentration(abs(X_jft).^2);
    fprintf('   JFT spectral concentration: %.2f\n', jft_concentration);
end

% Analyze temporal resolution
stvft_temporal_res = (window_length - overlap) / fs;
stvwt_temporal_res = 1 / fs;  % Sample-level resolution

fprintf('   STVFT temporal resolution: %.3f s\n', stvft_temporal_res);
fprintf('   STVWT temporal resolution: %.3f s\n', stvwt_temporal_res);

%% 7. Visualization
fprintf('\n7. Creating transform visualizations...\n');

figure('Name', 'Bioctree Transforms Demo', 'Position', [100, 100, 1600, 1000]);

% Plot 1: GFT spectral content
subplot(2, 4, 1);
plot(G.e, freq_power, 'b-', 'LineWidth', 2);
xlabel('Graph Eigenvalue');
ylabel('Spectral Power');
title('GFT: Graph Frequency Content');
grid on;

% Plot 2: GFT time evolution of dominant mode
subplot(2, 4, 2);
dominant_mode = dominant_modes(1);
plot(t, abs(X_gft(dominant_mode, :)), 'r-', 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('|GFT Coefficient|');
title(sprintf('GFT: Mode %d Evolution', dominant_mode));
grid on;

% Plot 3: Joint spectrum (if available)
subplot(2, 4, 3);
if ~isempty(X_jft)
    imagesc(log10(abs(X_jft) + eps));
    xlabel('Temporal Frequency');
    ylabel('Graph Frequency');
    title('JFT: Joint Spectrum');
    colorbar;
else
    text(0.5, 0.5, 'JFT not computed', 'HorizontalAlignment', 'center');
    title('JFT: Not Available');
end

% Plot 4: STVFT spectrogram for peak vertex
subplot(2, 4, 4);
[~, peak_vertex] = max(mean(abs(X).^2, 2));
peak_idx = find(vertices_stvft == peak_vertex, 1);
if ~isempty(peak_idx)
    t_stvft = linspace(0, t(end), size(X_stvft, 3));
    f_stvft = linspace(0, fs/2, size(X_stvft, 2));
    imagesc(t_stvft, f_stvft, 20*log10(abs(squeeze(X_stvft(peak_idx, :, :))) + eps));
    xlabel('Time (s)');
    ylabel('Frequency (Hz)');
    title(sprintf('STVFT: Vertex %d', peak_vertex));
    colorbar;
end

% Plot 5: STVWT scalogram for peak vertex
subplot(2, 4, 5);
peak_wt_idx = find(vertices_stvwt == peak_vertex, 1);
if ~isempty(peak_wt_idx)
    imagesc(t, freq_wt, abs(X_stvwt{peak_wt_idx}));
    xlabel('Time (s)');
    ylabel('Frequency (Hz)');
    title(sprintf('STVWT: Vertex %d', peak_vertex));
    colorbar;
    set(gca, 'YDir', 'normal');
end

% Plot 6: Transform comparison - spectral concentration
subplot(2, 4, 6);
transforms = {'GFT'};
concentrations = [gft_concentration];
if ~isempty(X_jft)
    transforms{end+1} = 'JFT';
    concentrations(end+1) = jft_concentration;
end
bar(concentrations);
set(gca, 'XTickLabel', transforms);
ylabel('Spectral Concentration');
title('Transform Efficiency');
grid on;

% Plot 7: Graph signal overlay
subplot(2, 4, 7);
signal_mean = mean(X, 2);
gsp_plot_graph(G, signal_mean);
title('Signal on Graph');
colorbar;
view(45, 30);

% Plot 8: Reconstructed signal quality
subplot(2, 4, 8);
% Reconstruct from dominant GFT modes
k_modes = min(50, G.N);
X_recon = gsp_igft(G, X_gft);  % Perfect reconstruction
X_recon_k = zeros(size(X));
X_gft_k = X_gft;
X_gft_k(k_modes+1:end, :) = 0;  % Zero out high frequencies
X_recon_k = gsp_igft(G, X_gft_k);

% Compute reconstruction error
recon_error = norm(X - X_recon_k, 'fro') / norm(X, 'fro');
plot(1:k_modes, sort(freq_power(1:k_modes), 'descend'), 'b-', 'LineWidth', 2);
xlabel('Mode Number');
ylabel('Spectral Power');
title(sprintf('GFT Reconstruction (%.1f%% error)', recon_error*100));
grid on;

sgtitle('Transform Analysis: GFT, JFT, STVFT, STVWT');

%% 8. Summary
fprintf('\n8. Transform Summary:\n');
fprintf('   GFT: Global graph-frequency analysis\n');
fprintf('   JFT: Joint graph-time frequency analysis\n');
fprintf('   STVFT: Localized time-frequency analysis per vertex\n');
fprintf('   STVWT: Multi-scale time analysis per vertex\n');
fprintf('   \n');
fprintf('   Dominant graph modes capture %.1f%% of signal energy\n', ...
        100 * sum(sorted_power(1:10)) / sum(sorted_power));

fprintf('\n=== Transform demo completed! ===\n');

end

function [G, X, fs, t] = load_bunny_data()
% Helper function to load and prepare bunny graph with MEG data

% Load MEG data
dataPath = 'test-data/omega-tutorial/sub-0002/sensor/data_block001_band_02.mat';
data = load(dataPath);
megData = data.F;

% Create bunny subgraph
G_full = gsp_bunny();
G_full = gsp_compute_fourier_basis(G_full);

% Select subset
rng(42);
nVertices = 300;
vertexIndices = randperm(G_full.N, nVertices);
G = gsp_subgraph(G_full, vertexIndices);
G = gsp_estimate_lmax(G);
G = gsp_compute_fourier_basis(G);

% Prepare signals
downsample_factor = round(300 / 64);  % Target 64 Hz sampling rate
time_indices = 1:downsample_factor:size(megData, 2);
X = megData(1:G.N, time_indices);

fs = 300 / downsample_factor;
t = (0:length(time_indices)-1) / fs;

end

function concentration = compute_spectral_concentration(power_matrix)
% Compute spectral concentration measure
total_power = sum(power_matrix(:));
sorted_power = sort(power_matrix(:), 'descend');
cumsum_power = cumsum(sorted_power) / total_power;
concentration = find(cumsum_power >= 0.8, 1) / length(sorted_power);
end