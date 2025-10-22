function demo_bunny_visualization()
% DEMO_BUNNY_VISUALIZATION Interactive visualization for Stanford bunny + MEG
%
% This demo showcases advanced visualization capabilities:
%   - Interactive 3D graph visualization
%   - Animated signal propagation
%   - Multi-scale temporal views
%   - Joint graph-time visualization
%   - Export capabilities

fprintf('=== Bioctree Visualization Demo: Stanford Bunny ===\n\n');

%% 1. Setup and Data Loading
fprintf('1. Loading data and preparing visualizations...\n');

[G, X, fs, t] = load_bunny_data();
fprintf('   Graph: %d vertices, %d edges\n', G.N, G.Ne);
fprintf('   Signal: %d samples at %.1f Hz\n', length(t), fs);

% Prepare visualization data
signal_mean = mean(X, 2);
signal_std = std(X, [], 2);
signal_power = mean(X.^2, 2);

% Compute spatial metrics
try
    tv_X = graphTotalVariation(G, X, 1);
    mean_tv = mean(tv_X, 2);
    fprintf('   Computed spatial total variation\n');
catch
    mean_tv = zeros(G.N, 1);
    fprintf('   Using zero total variation (function not available)\n');
end

% Find interesting vertices
[~, max_power_vertex] = max(signal_power);
[~, max_std_vertex] = max(signal_std);
[~, max_tv_vertex] = max(mean_tv);

fprintf('   Peak vertices: power=%d, variability=%d, TV=%d\n', ...
        max_power_vertex, max_std_vertex, max_tv_vertex);

%% 2. Static 3D Visualizations
fprintf('\n2. Creating static 3D visualizations...\n');

figure('Name', 'Bioctree: Static Graph Visualizations', ...
       'Position', [100, 100, 1400, 800]);

% Plot 1: Graph structure
subplot(2, 3, 1);
gsp_plot_graph(G);
title('Graph Structure');
view(45, 30);

% Plot 2: Mean signal amplitude
subplot(2, 3, 2);
gsp_plot_graph(G, signal_mean);
title('Mean Signal Amplitude');
colorbar;
view(45, 30);

% Plot 3: Signal variability
subplot(2, 3, 3);
gsp_plot_graph(G, signal_std);
title('Signal Variability (std)');
colorbar;
view(45, 30);

% Plot 4: Signal power
subplot(2, 3, 4);
gsp_plot_graph(G, log10(signal_power + eps));
title('Signal Power (log₁₀)');
colorbar;
view(45, 30);

% Plot 5: Total variation
subplot(2, 3, 5);
if any(mean_tv > 0)
    gsp_plot_graph(G, mean_tv);
    title('Total Variation');
    colorbar;
else
    text(0.5, 0.5, 'TV not computed', 'HorizontalAlignment', 'center');
    title('Total Variation (N/A)');
end
view(45, 30);

% Plot 6: Multi-metric overlay
subplot(2, 3, 6);
% Create RGB overlay: R=power, G=variability, B=TV
rgb_signal = zeros(G.N, 3);
rgb_signal(:, 1) = signal_power / max(signal_power);
rgb_signal(:, 2) = signal_std / max(signal_std);
if any(mean_tv > 0)
    rgb_signal(:, 3) = mean_tv / max(mean_tv);
end

% Plot with custom colors (approximate)
scatter3(G.coords(:,1), G.coords(:,2), G.coords(:,3), 30, rgb_signal(:,1), 'filled');
title('Multi-metric View (Power)');
colorbar;
view(45, 30);

sgtitle('Static Graph Signal Visualizations');

%% 3. Temporal Evolution Animation
fprintf('\n3. Creating temporal evolution animation...\n');

% Select time windows for animation
n_frames = 20;
frame_indices = round(linspace(1, length(t), n_frames));
frame_times = t(frame_indices);

fprintf('   Animation: %d frames over %.1f seconds\n', n_frames, t(end));

% Create animation figure
fig_anim = figure('Name', 'Bioctree: Temporal Evolution Animation', ...
                  'Position', [200, 200, 800, 600]);

% Animation loop
for frame = 1:n_frames
    clf;
    
    % Get signal at this time
    time_idx = frame_indices(frame);
    signal_t = X(:, time_idx);
    
    % Plot graph with signal
    gsp_plot_graph(G, signal_t);
    title(sprintf('Signal Evolution: t = %.2f s (frame %d/%d)', ...
                  frame_times(frame), frame, n_frames));
    colorbar;
    view(45, 30);
    
    % Add time series subplot
    subplot(4, 1, 4);
    plot(t, X(max_power_vertex, :), 'b-', 'LineWidth', 1);
    hold on;
    plot(frame_times(frame), signal_t(max_power_vertex), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
    xlabel('Time (s)');
    ylabel('Amplitude');
    title(sprintf('Vertex %d Time Series', max_power_vertex));
    grid on;
    xlim([t(1), t(end)]);
    
    drawnow;
    pause(0.2);  % Animation speed
end

fprintf('   Animation completed\n');

%% 4. Interactive Multi-Scale Visualization
fprintf('\n4. Creating multi-scale interactive visualization...\n');

figure('Name', 'Bioctree: Multi-Scale Analysis', 'Position', [300, 100, 1600, 1000]);

% Time-frequency analysis for selected vertices
selected_vertices = [max_power_vertex, max_std_vertex, max_tv_vertex];
n_selected = length(selected_vertices);

for i = 1:n_selected
    vertex = selected_vertices(i);
    signal = X(vertex, :);
    
    % Subplot for each vertex
    subplot(n_selected, 4, (i-1)*4 + 1);
    
    % Highlight vertex on graph
    vertex_colors = zeros(G.N, 1);
    vertex_colors(vertex) = 1;
    gsp_plot_graph(G, vertex_colors);
    title(sprintf('Vertex %d Location', vertex));
    colorbar;
    view(45, 30);
    
    % Time series
    subplot(n_selected, 4, (i-1)*4 + 2);
    plot(t, signal, 'b-', 'LineWidth', 1.5);
    xlabel('Time (s)');
    ylabel('Amplitude');
    title(sprintf('Vertex %d Time Series', vertex));
    grid on;
    
    % Power spectral density
    subplot(n_selected, 4, (i-1)*4 + 3);
    [psd, f] = pwelch(signal, [], [], [], fs);
    semilogy(f, psd, 'r-', 'LineWidth', 1.5);
    xlabel('Frequency (Hz)');
    ylabel('PSD');
    title(sprintf('Vertex %d PSD', vertex));
    grid on;
    
    % Spectrogram
    subplot(n_selected, 4, (i-1)*4 + 4);
    window_length = min(64, length(signal)/4);
    overlap = round(window_length/2);
    [S, F, T] = spectrogram(signal, window_length, overlap, [], fs, 'yaxis');
    imagesc(T, F, 10*log10(abs(S) + eps));
    xlabel('Time (s)');
    ylabel('Frequency (Hz)');
    title(sprintf('Vertex %d Spectrogram', vertex));
    colorbar;
end

sgtitle('Multi-Scale Vertex Analysis');

%% 5. Joint Graph-Time Visualization
fprintf('\n5. Creating joint graph-time visualization...\n');

figure('Name', 'Bioctree: Joint Graph-Time Analysis', 'Position', [400, 50, 1400, 900]);

% Select subset for joint analysis (computational efficiency)
n_joint_vertices = min(50, G.N);
joint_vertices = 1:n_joint_vertices;
X_joint = X(joint_vertices, :);

% Create 3D surface plot
subplot(2, 2, 1);
[T_mesh, V_mesh] = meshgrid(t, joint_vertices);
surf(T_mesh, V_mesh, X_joint);
xlabel('Time (s)');
ylabel('Vertex Index');
zlabel('Signal Amplitude');
title('3D Signal Surface');
colorbar;
shading interp;

% 2D heatmap
subplot(2, 2, 2);
imagesc(t, joint_vertices, X_joint);
xlabel('Time (s)');
ylabel('Vertex Index');
title('Signal Heatmap');
colorbar;

% Cross-correlation matrix
subplot(2, 2, 3);
corr_matrix = corr(X_joint');
imagesc(joint_vertices, joint_vertices, corr_matrix);
xlabel('Vertex Index');
ylabel('Vertex Index');
title('Vertex Cross-Correlation');
colorbar;
axis square;

% Temporal correlation
subplot(2, 2, 4);
% Downsample time for correlation analysis
time_downsample = 10;
t_corr = t(1:time_downsample:end);
X_corr = X_joint(:, 1:time_downsample:end);
temporal_corr = corr(X_corr);
imagesc(t_corr, t_corr, temporal_corr);
xlabel('Time (s)');
ylabel('Time (s)');
title('Temporal Auto-Correlation');
colorbar;
axis square;

sgtitle('Joint Graph-Time Analysis');

%% 6. Advanced Visualization Features
fprintf('\n6. Demonstrating advanced features...\n');

% Network layout visualization
figure('Name', 'Bioctree: Network Analysis', 'Position', [500, 100, 1200, 800]);

% Plot 1: Force-directed layout
subplot(2, 3, 1);
if isfield(G, 'coords')
    coords_2d = G.coords(:, 1:2);  % Use first 2 dimensions
else
    % Create simple 2D layout
    coords_2d = randn(G.N, 2);
end
gplot(G.W, coords_2d);
hold on;
scatter(coords_2d(:,1), coords_2d(:,2), 30, signal_mean, 'filled');
title('2D Network Layout');
colorbar;

% Plot 2: Adjacency matrix
subplot(2, 3, 2);
spy(G.W);
title('Adjacency Matrix');
xlabel('Vertex');
ylabel('Vertex');

% Plot 3: Degree distribution
subplot(2, 3, 3);
degrees = sum(G.W > 0, 2);
histogram(degrees, 20);
xlabel('Degree');
ylabel('Count');
title('Degree Distribution');
grid on;

% Plot 4: Signal distribution
subplot(2, 3, 4);
histogram(signal_mean, 30);
xlabel('Mean Signal');
ylabel('Count');
title('Signal Distribution');
grid on;

% Plot 5: Power vs connectivity
subplot(2, 3, 5);
scatter(degrees, signal_power, 30, 'filled', 'alpha', 0.7);
xlabel('Vertex Degree');
ylabel('Signal Power');
title('Power vs Connectivity');
grid on;

% Plot 6: Clustering analysis
subplot(2, 3, 6);
if G.N <= 100  % Only for smaller graphs
    % Simple clustering based on signal similarity
    signal_corr = corr(X');
    signal_dist = 1 - abs(signal_corr);
    linkage_result = linkage(squareform(signal_dist), 'average');
    dendrogram(linkage_result, 'Labels', string(1:G.N));
    title('Signal-Based Clustering');
    xlabel('Vertex');
    ylabel('Distance');
else
    text(0.5, 0.5, 'Graph too large for clustering', 'HorizontalAlignment', 'center');
    title('Clustering (N/A)');
end

sgtitle('Network Structure Analysis');

%% 7. Export and Summary
fprintf('\n7. Visualization summary and export options...\n');

% Summary statistics
fprintf('   Visualization summary:\n');
fprintf('     - Signal range: [%.2e, %.2e]\n', min(signal_mean), max(signal_mean));
fprintf('     - Temporal span: %.1f seconds\n', t(end));
fprintf('     - Graph density: %.3f\n', 2*G.Ne/(G.N*(G.N-1)));
fprintf('     - Most variable vertex: %d (std=%.2e)\n', max_std_vertex, max(signal_std));

% Export options
fprintf('   Export options:\n');
fprintf('     - Figure export: File → Export Setup → Format\n');
fprintf('     - Data export: save(''analysis_results.mat'', ''G'', ''X'', ''t'')\n');
fprintf('     - Animation: getframe() in animation loop\n');
fprintf('     - Interactive: use datacursormode(''on'') for exploration\n');

% Enable interactive features
fprintf('   Interactive features enabled:\n');
fprintf('     - Data cursor mode for point inspection\n');
fprintf('     - Zoom and pan for detailed exploration\n');
fprintf('     - Rotate 3D plots for different perspectives\n');

% Set up data cursor for the last figure
dcm = datacursormode(gcf);
set(dcm, 'UpdateFcn', @(obj, event_obj) sprintf('Vertex: %d\nValue: %.3e', ...
    event_obj.DataIndex, event_obj.Position(2)));
datacursormode('on');

fprintf('\n=== Visualization demo completed! ===\n');
fprintf('Explore the interactive plots and try different viewing angles.\n');

end

% Helper function
function [G, X, fs, t] = load_bunny_data()
% Standard data loading for consistency
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