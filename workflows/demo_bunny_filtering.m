function demo_bunny_filtering()
% DEMO_BUNNY_FILTERING Joint filtering demonstration on Stanford bunny
%
% This demo showcases various joint graph-time filtering approaches:
%   - Separable filtering (graph × time independent)
%   - Non-separable joint filtering
%   - Fast Fourier-Convolution (FFC) algorithm
%   - Adaptive filtering based on signal characteristics
%
% The demo uses Stanford bunny graph with real MEG sensor data to
% demonstrate different filtering strategies and their trade-offs.

fprintf('=== Bioctree Filtering Demo: Stanford Bunny ===\n\n');

%% 1. Setup and Data Loading
fprintf('1. Loading data and preparing filters...\n');

[G, X, fs, t] = load_bunny_data();
fprintf('   Graph: %d vertices, %d edges\n', G.N, G.Ne);
fprintf('   Signal: %d samples at %.1f Hz\n', length(t), fs);

% Analyze signal characteristics
signal_power = mean(X.^2, 2);
noise_level = estimate_noise_level(X);
snr_db = 10 * log10(mean(signal_power) / noise_level^2);

fprintf('   Signal SNR: %.1f dB\n', snr_db);
fprintf('   Noise level estimate: %.2e\n', noise_level);

%% 2. Separable Filtering
fprintf('\n2. Separable filtering (graph ⊗ time)...\n');

% Define graph filter (low-pass)
graph_tau = 2.0;  % Graph smoothing parameter
graph_filter = @(x) exp(-graph_tau * x / G.lmax);

% Define temporal filter (bandpass for alpha band)
temp_low = 8;   % Hz
temp_high = 12; % Hz
nyquist = fs / 2;
[b_temp, a_temp] = butter(4, [temp_low, temp_high] / nyquist, 'bandpass');

fprintf('   Graph filter: exponential decay (τ=%.1f)\n', graph_tau);
fprintf('   Temporal filter: %.1f-%.1f Hz bandpass\n', temp_low, temp_high);

% Apply separable filtering
X_sep = zeros(size(X));

% Step 1: Apply graph filter to each time point
X_graph_filtered = gsp_filter(G, graph_filter, X);

% Step 2: Apply temporal filter to each vertex
for v = 1:G.N
    X_sep(v, :) = filtfilt(b_temp, a_temp, X_graph_filtered(v, :));
end

fprintf('   Separable filtering completed\n');

% Compute filtering performance
sep_snr_improvement = compute_snr_improvement(X, X_sep, noise_level);
fprintf('   SNR improvement: %.2f dB\n', sep_snr_improvement);

%% 3. Non-Separable Joint Filtering
fprintf('\n3. Non-separable joint filtering...\n');

% Design joint filter in graph-time spectral domain
% (This is a simplified example - full implementation would be more complex)

% Parameters for joint filter
joint_graph_tau = 1.5;
joint_time_sigma = 0.5;  % Temporal smoothing

fprintf('   Joint filter: graph smoothing τ=%.1f, time σ=%.1f\n', ...
        joint_graph_tau, joint_time_sigma);

% Apply joint filtering using iterative approach
X_joint = X;
n_iterations = 5;

for iter = 1:n_iterations
    % Alternate between graph and time smoothing with coupling
    coupling_strength = 0.1 * iter / n_iterations;
    
    % Graph smoothing with temporal coupling
    joint_graph_filter = @(x) exp(-joint_graph_tau * x / G.lmax) .* ...
                             (1 + coupling_strength * sin(2*pi*x/G.lmax));
    X_joint = gsp_filter(G, joint_graph_filter, X_joint);
    
    % Temporal smoothing with graph coupling
    for v = 1:G.N
        signal = X_joint(v, :);
        vertex_strength = signal_power(v) / max(signal_power);
        adaptive_sigma = joint_time_sigma * (1 + vertex_strength);
        
        % Gaussian smoothing in time
        kernel_size = ceil(3 * adaptive_sigma * fs);
        if kernel_size > 1
            kernel = gaussian_kernel(kernel_size, adaptive_sigma * fs);
            signal_padded = [signal(1) * ones(1, kernel_size), signal, ...
                           signal(end) * ones(1, kernel_size)];
            signal_smooth = conv(signal_padded, kernel, 'same');
            X_joint(v, :) = signal_smooth(kernel_size+1:end-kernel_size);
        end
    end
end

fprintf('   Joint filtering completed (%d iterations)\n', n_iterations);

% Compute joint filtering performance
joint_snr_improvement = compute_snr_improvement(X, X_joint, noise_level);
fprintf('   SNR improvement: %.2f dB\n', joint_snr_improvement);

%% 4. Fast Fourier-Convolution (FFC) Algorithm
fprintf('\n4. Fast Fourier-Convolution filtering...\n');

% FFC parameters
ffc_graph_cutoff = 0.3;  % Fraction of graph spectrum to keep
ffc_time_cutoff = 0.4;   % Fraction of temporal spectrum to keep

fprintf('   FFC: graph cutoff=%.1f%%, time cutoff=%.1f%%\n', ...
        ffc_graph_cutoff*100, ffc_time_cutoff*100);

% Apply FFC algorithm
X_ffc = apply_ffc_filter(G, X, ffc_graph_cutoff, ffc_time_cutoff);

fprintf('   FFC filtering completed\n');

% Compute FFC performance
ffc_snr_improvement = compute_snr_improvement(X, X_ffc, noise_level);
fprintf('   SNR improvement: %.2f dB\n', ffc_snr_improvement);

%% 5. Adaptive Filtering
fprintf('\n5. Adaptive filtering based on local signal characteristics...\n');

% Analyze local signal properties
local_smoothness = compute_local_smoothness(G, X);
local_activity = compute_local_activity(X);

fprintf('   Local smoothness range: [%.2f, %.2f]\n', ...
        min(local_smoothness), max(local_smoothness));
fprintf('   Local activity range: [%.2f, %.2f]\n', ...
        min(local_activity), max(local_activity));

% Adaptive filter parameters based on local properties
X_adaptive = X;

for v = 1:G.N
    % Adapt graph filtering strength
    smoothness_factor = local_smoothness(v);
    activity_factor = local_activity(v);
    
    % Higher smoothness → less graph filtering needed
    % Higher activity → more temporal filtering needed
    adaptive_graph_tau = graph_tau * (1 - 0.5 * smoothness_factor);
    adaptive_time_strength = 1 + 0.5 * activity_factor;
    
    % Apply vertex-specific graph filter
    vertex_signal = X(v, :);
    neighbors = find(G.W(v, :));
    
    if ~isempty(neighbors)
        neighbor_signals = X(neighbors, :);
        weights = full(G.W(v, neighbors))';  % Make column vector
        weighted_mean = sum(weights .* neighbor_signals, 1) / sum(weights);
        
        % Adaptive blending
        alpha = exp(-adaptive_graph_tau);
        X_adaptive(v, :) = alpha * vertex_signal + (1 - alpha) * weighted_mean;
    end
    
    % Apply vertex-specific temporal filter
    if adaptive_time_strength > 1.1
        % Apply temporal smoothing for high-activity vertices
        window_size = ceil(adaptive_time_strength * 3);
        if window_size > 1 && window_size < length(t)/4
            X_adaptive(v, :) = smooth_signal(X_adaptive(v, :), window_size);
        end
    end
end

fprintf('   Adaptive filtering completed\n');

% Compute adaptive filtering performance
adaptive_snr_improvement = compute_snr_improvement(X, X_adaptive, noise_level);
fprintf('   SNR improvement: %.2f dB\n', adaptive_snr_improvement);

%% 6. Comparative Analysis
fprintf('\n6. Filtering comparison...\n');

% Compute metrics for all methods
methods = {'Original', 'Separable', 'Joint', 'FFC', 'Adaptive'};
signals = {X, X_sep, X_joint, X_ffc, X_adaptive};

snr_improvements = [0, sep_snr_improvement, joint_snr_improvement, ...
                   ffc_snr_improvement, adaptive_snr_improvement];

% Compute total variation (smoothness)
tv_scores = zeros(size(methods));
for i = 1:length(methods)
    tv_scores(i) = mean(graphTotalVariation(G, signals{i}, 1), 'all');
end

% Compute energy preservation
energy_preservation = zeros(size(methods));
original_energy = norm(X, 'fro')^2;
for i = 1:length(methods)
    energy_preservation(i) = norm(signals{i}, 'fro')^2 / original_energy;
end

fprintf('   Method comparison:\n');
for i = 1:length(methods)
    fprintf('     %s: SNR=%.1fdB, TV=%.2e, Energy=%.1f%%\n', ...
            methods{i}, snr_improvements(i), tv_scores(i), ...
            energy_preservation(i)*100);
end

%% 7. Visualization
fprintf('\n7. Creating filtering visualizations...\n');

figure('Name', 'Bioctree Filtering Demo', 'Position', [100, 100, 1600, 1200]);

% Plot 1: Original signal on graph
subplot(3, 4, 1);
gsp_plot_graph(G, mean(X, 2));
title('Original Signal');
colorbar;
view(45, 30);

% Plot 2: Separable filtered
subplot(3, 4, 2);
gsp_plot_graph(G, mean(X_sep, 2));
title('Separable Filtered');
colorbar;
view(45, 30);

% Plot 3: Joint filtered
subplot(3, 4, 3);
gsp_plot_graph(G, mean(X_joint, 2));
title('Joint Filtered');
colorbar;
view(45, 30);

% Plot 4: FFC filtered
subplot(3, 4, 4);
gsp_plot_graph(G, mean(X_ffc, 2));
title('FFC Filtered');
colorbar;
view(45, 30);

% Plot 5: SNR improvement comparison
subplot(3, 4, 5);
bar(snr_improvements);
set(gca, 'XTickLabel', methods);
ylabel('SNR Improvement (dB)');
title('SNR Performance');
grid on;
xtickangle(45);

% Plot 6: Total variation comparison
subplot(3, 4, 6);
bar(tv_scores);
set(gca, 'XTickLabel', methods);
ylabel('Total Variation');
title('Spatial Smoothness');
grid on;
xtickangle(45);

% Plot 7: Energy preservation
subplot(3, 4, 7);
bar(energy_preservation * 100);
set(gca, 'XTickLabel', methods);
ylabel('Energy Preserved (%)');
title('Energy Conservation');
grid on;
xtickangle(45);

% Plot 8: Temporal evolution comparison
subplot(3, 4, 8);
[~, peak_vertex] = max(signal_power);
plot(t, X(peak_vertex, :), 'k-', 'LineWidth', 1, 'DisplayName', 'Original');
hold on;
plot(t, X_sep(peak_vertex, :), 'b-', 'LineWidth', 1.5, 'DisplayName', 'Separable');
plot(t, X_joint(peak_vertex, :), 'r-', 'LineWidth', 1.5, 'DisplayName', 'Joint');
plot(t, X_ffc(peak_vertex, :), 'g-', 'LineWidth', 1.5, 'DisplayName', 'FFC');
xlabel('Time (s)');
ylabel('Amplitude');
title(sprintf('Vertex %d Evolution', peak_vertex));
legend('Location', 'best');
grid on;

% Plot 9: Frequency response comparison
subplot(3, 4, 9);
% Compute power spectral density for peak vertex
[psd_orig, f] = pwelch(X(peak_vertex, :), [], [], [], fs);
[psd_sep, ~] = pwelch(X_sep(peak_vertex, :), [], [], [], fs);
[psd_joint, ~] = pwelch(X_joint(peak_vertex, :), [], [], [], fs);
[psd_ffc, ~] = pwelch(X_ffc(peak_vertex, :), [], [], [], fs);

semilogy(f, psd_orig, 'k-', 'LineWidth', 1, 'DisplayName', 'Original');
hold on;
semilogy(f, psd_sep, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Separable');
semilogy(f, psd_joint, 'r-', 'LineWidth', 1.5, 'DisplayName', 'Joint');
semilogy(f, psd_ffc, 'g-', 'LineWidth', 1.5, 'DisplayName', 'FFC');
xlabel('Frequency (Hz)');
ylabel('Power Spectral Density');
title('Frequency Response');
legend('Location', 'best');
grid on;

% Plot 10: Adaptive filter parameters
subplot(3, 4, 10);
gsp_plot_graph(G, local_smoothness);
title('Local Smoothness');
colorbar;
view(45, 30);

% Plot 11: Local activity
subplot(3, 4, 11);
gsp_plot_graph(G, local_activity);
title('Local Activity');
colorbar;
view(45, 30);

% Plot 12: Adaptive filtered result
subplot(3, 4, 12);
gsp_plot_graph(G, mean(X_adaptive, 2));
title('Adaptive Filtered');
colorbar;
view(45, 30);

sgtitle('Joint Graph-Time Filtering Comparison');

%% 8. Summary
fprintf('\n8. Filtering Summary:\n');
fprintf('   Best SNR improvement: %.1f dB (%s)\n', ...
        max(snr_improvements), methods{snr_improvements == max(snr_improvements)});
fprintf('   Smoothest result: %.2e TV (%s)\n', ...
        min(tv_scores), methods{tv_scores == min(tv_scores)});
fprintf('   Best energy preservation: %.1f%% (%s)\n', ...
        max(energy_preservation)*100, methods{energy_preservation == max(energy_preservation)});

fprintf('\n=== Filtering demo completed! ===\n');

end

% Helper functions
function [G, X, fs, t] = load_bunny_data()
% Reuse data loading from transforms demo
dataPath = 'test-data/omega-tutorial/sub-0002/sensor/data_block001_band_02.mat';
data = load(dataPath);
megData = data.F;

G_full = gsp_bunny();
G_full = gsp_compute_fourier_basis(G_full);

rng(42);
nVertices = 300;
vertexIndices = randperm(G_full.N, nVertices);
G = gsp_subgraph(G_full, vertexIndices);
G = gsp_estimate_lmax(G);
G = gsp_compute_fourier_basis(G);

downsample_factor = round(300 / 64);  % Target 64 Hz sampling rate
time_indices = 1:downsample_factor:size(megData, 2);
X = megData(1:G.N, time_indices);

fs = 300 / downsample_factor;
t = (0:length(time_indices)-1) / fs;
end

function noise_level = estimate_noise_level(X)
% Simple noise estimation using high-frequency content
X_diff = diff(X, 1, 2);
noise_level = median(abs(X_diff(:))) / 0.6745;  % Robust MAD estimator
end

function snr_improvement = compute_snr_improvement(X_orig, X_filtered, noise_level)
% Compute SNR improvement in dB
signal_power_orig = mean(X_orig(:).^2);
signal_power_filt = mean(X_filtered(:).^2);
noise_power = noise_level^2;

snr_orig = signal_power_orig / noise_power;
snr_filt = signal_power_filt / noise_power;

snr_improvement = 10 * log10(snr_filt / snr_orig);
end

function kernel = gaussian_kernel(size, sigma)
% Generate Gaussian kernel
x = -(size-1)/2:(size-1)/2;
kernel = exp(-x.^2 / (2*sigma^2));
kernel = kernel / sum(kernel);
end

function X_ffc = apply_ffc_filter(G, X, graph_cutoff, time_cutoff)
% Apply Fast Fourier-Convolution filter
% Transform to graph spectral domain
X_gft = gsp_gft(G, X);

% Transform to temporal frequency domain
X_joint_freq = fft(X_gft, [], 2);

% Apply joint filtering in frequency domain
[n_graph, n_time] = size(X_joint_freq);
graph_cutoff_idx = round(graph_cutoff * n_graph);
time_cutoff_idx = round(time_cutoff * n_time);

% Create joint filter
filter_mask = zeros(n_graph, n_time);
filter_mask(1:graph_cutoff_idx, 1:time_cutoff_idx) = 1;
filter_mask(1:graph_cutoff_idx, end-time_cutoff_idx+1:end) = 1;

% Apply filter
X_joint_filtered = X_joint_freq .* filter_mask;

% Transform back
X_gft_filtered = ifft(X_joint_filtered, [], 2, 'symmetric');
X_ffc = gsp_igft(G, X_gft_filtered);
end

function smoothness = compute_local_smoothness(G, X)
% Compute local signal smoothness for each vertex
smoothness = zeros(G.N, 1);
for v = 1:G.N
    neighbors = find(G.W(v, :));
    if ~isempty(neighbors)
        vertex_signal = mean(X(v, :).^2);
        neighbor_variance = var(mean(X(neighbors, :), 2));
        smoothness(v) = 1 / (1 + neighbor_variance / vertex_signal);
    end
end
end

function activity = compute_local_activity(X)
% Compute local temporal activity for each vertex
activity = std(X, [], 2) ./ (mean(abs(X), 2) + eps);
activity = activity / max(activity);  % Normalize
end

function signal_smooth = smooth_signal(signal, window_size)
% Simple moving average smoothing
if window_size <= 1
    signal_smooth = signal;
    return;
end
kernel = ones(1, window_size) / window_size;
signal_smooth = conv(signal, kernel, 'same');
end