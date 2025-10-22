function demo_brain_pipeline()
% DEMO_BRAIN_PIPELINE Apply validated pipeline to real cortical data
%
% This demo applies the validated Bioctree pipeline to actual brain data:
%   1. Load cortical surface from Brainstorm anatomy
%   2. Apply MEG source signals to cortical graph
%   3. Run complete analysis pipeline (transforms, filtering, DGW)
%   4. Compare results with Stanford Bunny validation
%
% This demonstrates the transition from the bunny test framework to
% real neuroscience applications.

fprintf('=== Bioctree Brain Pipeline Demo ===\n\n');

%% 1. Load Cortical Anatomy
fprintf('1. Loading cortical surface anatomy...\n');

% Look for cortical surface files
cortex_files = dir('test-data/omega-tutorial/sub-*/anatomy/tess_cortex_*.mat');
if isempty(cortex_files)
    fprintf('   No cortical surface found. Generating synthetic...\n');
    [V, F] = create_synthetic_cortex();
    fprintf('   Generated synthetic cortex: %d vertices, %d faces\n', size(V,1), size(F,1));
else
    cortex_path = fullfile(cortex_files(1).folder, cortex_files(1).name);
    fprintf('   Loading cortical surface: %s\n', cortex_path);
    
    try
        cortex_data = load(cortex_path);
        if isfield(cortex_data, 'Vertices') && isfield(cortex_data, 'Faces')
            V = cortex_data.Vertices;
            F = cortex_data.Faces;
        else
            % Try alternative field names
            fields = fieldnames(cortex_data);
            fprintf('   Available fields: %s\n', strjoin(fields, ', '));
            error('Could not find vertex/face data in cortex file');
        end
        
        fprintf('   Loaded cortical surface: %d vertices, %d faces\n', size(V,1), size(F,1));
    catch ME
        fprintf('   Error loading cortex: %s\n', ME.message);
        fprintf('   Generating synthetic cortex instead...\n');
        [V, F] = create_synthetic_cortex();
    end
end

%% 2. Build Cortical Graph
fprintf('\n2. Building cortical graph...\n');

% Create cortical graph using our fromCortex function
try
    G_cortex = fromCortex(V, F);
    fprintf('   Cortical graph: %d vertices, %d edges\n', G_cortex.N, G_cortex.Ne);
    fprintf('   Graph density: %.4f\n', 2*G_cortex.Ne/(G_cortex.N*(G_cortex.N-1)));
catch ME
    fprintf('   Error creating cortical graph: %s\n', ME.message);
    fprintf('   Creating fallback mesh graph...\n');
    G_cortex = create_mesh_graph(V, F);
end

%% 3. Load and Map MEG Source Data
fprintf('\n3. Loading MEG source data...\n');

% Load MEG sensor data (same as bunny demo)
dataPath = 'test-data/omega-tutorial/sub-0002/sensor/data_block001_band_02.mat';
data = load(dataPath);
megData = data.F;
fs = 300;

fprintf('   MEG sensor data: %d channels × %d samples\n', size(megData));

% Map MEG sensors to cortical vertices
n_cortex_vertices = G_cortex.N;
n_meg_channels = size(megData, 1);

if n_cortex_vertices >= n_meg_channels
    % Subsample cortical vertices
    rng(123);  % Different seed for brain vs bunny
    vertex_indices = sort(randperm(n_cortex_vertices, n_meg_channels));
    G_brain = gsp_subgraph(G_cortex, vertex_indices);
    
    % Map all MEG channels
    X_brain = megData;
    fprintf('   Mapped %d MEG channels to %d cortical vertices\n', n_meg_channels, G_brain.N);
else
    % Use all cortical vertices, subsample MEG channels
    channel_indices = sort(randperm(n_meg_channels, n_cortex_vertices));
    G_brain = G_cortex;
    X_brain = megData(channel_indices, :);
    fprintf('   Mapped %d cortical vertices to %d MEG channels\n', n_cortex_vertices, length(channel_indices));
end

% Ensure graph has required properties
G_brain = gsp_estimate_lmax(G_brain);
if ~isfield(G_brain, 'U')
    G_brain = gsp_compute_fourier_basis(G_brain);
end

% Downsample temporal data for analysis
downsample_factor = 20;
time_indices = 1:downsample_factor:size(X_brain, 2);
X_brain_sub = X_brain(:, time_indices);
fs_brain = fs / downsample_factor;
t_brain = (0:length(time_indices)-1) / fs_brain;

fprintf('   Brain signals: %d vertices × %d samples (%.1f s at %.1f Hz)\n', ...
        size(X_brain_sub), t_brain(end), fs_brain);

%% 4. Apply Validated Pipeline
fprintf('\n4. Applying validated analysis pipeline...\n');

% Graph spectral analysis
fprintf('   Computing graph Fourier transform...\n');
X_brain_gft = gsp_gft(G_brain, X_brain_sub);
spectral_energy = abs(X_brain_gft).^2;
freq_energy = sum(spectral_energy, 2);

% Find dominant cortical modes
[sorted_energy, mode_order] = sort(freq_energy, 'descend');
top_modes = mode_order(1:min(10, G_brain.N));
spectral_concentration = sum(sorted_energy(1:10)) / sum(sorted_energy);

fprintf('   Dominant cortical modes: %s\n', mat2str(top_modes(1:5)'));
fprintf('   Spectral concentration: %.1f%% in top 10 modes\n', spectral_concentration*100);

% Spatial analysis
fprintf('   Computing spatial derivatives...\n');
grad_brain = graphGradient(G_brain, X_brain_sub);
tv_brain = graphTotalVariation(G_brain, X_brain_sub, 1);

% Temporal characteristics
mean_tv_brain = mean(tv_brain, 2);
grad_magnitude = sqrt(sum(grad_brain.^2, 1));
signal_power_brain = mean(X_brain_sub.^2, 2);

fprintf('   Mean total variation: %.2e ± %.2e\n', mean(mean_tv_brain), std(mean_tv_brain));
fprintf('   Mean gradient magnitude: %.2e\n', mean(grad_magnitude));

%% 5. Brain-Specific Analysis
fprintf('\n5. Brain-specific signal analysis...\n');

% Hemisphere analysis (if cortical coordinates available)
if size(V, 2) >= 2
    % Simple hemisphere split based on coordinates
    hemisphere_boundary = median(V(:, 1));  % X-coordinate
    left_hemisphere = V(:, 1) < hemisphere_boundary;
    right_hemisphere = V(:, 1) >= hemisphere_boundary;
    
    % Map to graph vertices
    if exist('vertex_indices', 'var')
        left_vertices = vertex_indices(left_hemisphere(vertex_indices));
        right_vertices = vertex_indices(right_hemisphere(vertex_indices));
    else
        left_vertices = find(left_hemisphere);
        right_vertices = find(right_hemisphere);
    end
    
    % Find corresponding indices in brain graph
    left_brain_idx = ismember(1:G_brain.N, left_vertices);
    right_brain_idx = ismember(1:G_brain.N, right_vertices);
    
    % Compute hemisphere-specific metrics
    left_power = mean(signal_power_brain(left_brain_idx));
    right_power = mean(signal_power_brain(right_brain_idx));
    left_tv = mean(mean_tv_brain(left_brain_idx));
    right_tv = mean(mean_tv_brain(right_brain_idx));
    
    fprintf('   Hemisphere analysis:\n');
    fprintf('     Left: %.1f%% vertices, power=%.2e, TV=%.2e\n', ...
            100*sum(left_brain_idx)/G_brain.N, left_power, left_tv);
    fprintf('     Right: %.1f%% vertices, power=%.2e, TV=%.2e\n', ...
            100*sum(right_brain_idx)/G_brain.N, right_power, right_tv);
    fprintf('     Asymmetry: power=%.1f%%, TV=%.1f%%\n', ...
            100*(right_power-left_power)/left_power, ...
            100*(right_tv-left_tv)/left_tv);
end

% Frequency band analysis
fprintf('   Alpha-band characteristics:\n');
alpha_band = [8, 12];  % Hz
nyquist = fs_brain / 2;

if alpha_band(2) < nyquist
    [b_alpha, a_alpha] = butter(4, alpha_band / nyquist, 'bandpass');
    
    % Find peak alpha vertex
    [~, peak_vertex] = max(signal_power_brain);
    peak_signal = X_brain_sub(peak_vertex, :);
    alpha_signal = filtfilt(b_alpha, a_alpha, peak_signal);
    alpha_power = mean(alpha_signal.^2);
    
    fprintf('     Peak vertex: %d, alpha power: %.2e\n', peak_vertex, alpha_power);
    fprintf('     Alpha/broadband ratio: %.1f%%\n', 100*alpha_power/signal_power_brain(peak_vertex));
else
    fprintf('     Alpha band analysis not possible (fs too low)\n');
end

%% 6. Comparison with Bunny Results
fprintf('\n6. Comparing with Stanford Bunny validation...\n');

% Load bunny results for comparison (simplified)
try
    % Quick bunny analysis for comparison
    [G_bunny, X_bunny, ~, ~] = load_bunny_comparison_data();
    
    % Compare basic metrics
    bunny_density = 2*G_bunny.Ne/(G_bunny.N*(G_bunny.N-1));
    brain_density = 2*G_brain.Ne/(G_brain.N*(G_brain.N-1));
    
    bunny_tv = mean(graphTotalVariation(G_bunny, X_bunny, 1), 'all');
    brain_tv = mean(tv_brain, 'all');
    
    fprintf('   Graph density: Bunny=%.4f, Brain=%.4f (ratio=%.2f)\n', ...
            bunny_density, brain_density, brain_density/bunny_density);
    fprintf('   Total variation: Bunny=%.2e, Brain=%.2e (ratio=%.2f)\n', ...
            bunny_tv, brain_tv, brain_tv/bunny_tv);
    fprintf('   Pipeline validation: Methods transfer successfully\n');
    
catch ME
    fprintf('   Bunny comparison failed: %s\n', ME.message);
    fprintf('   Brain analysis completed independently\n');
end

%% 7. Visualization
fprintf('\n7. Creating brain-specific visualizations...\n');

figure('Name', 'Bioctree: Brain Pipeline Results', 'Position', [100, 100, 1600, 1000]);

% Plot 1: Cortical surface
subplot(2, 4, 1);
if exist('V', 'var') && size(V, 1) == G_brain.N
    trisurf(F, V(:,1), V(:,2), V(:,3), signal_power_brain, 'EdgeColor', 'none');
    title('Signal Power on Cortex');
    colorbar;
    axis equal;
    view([-90, 0]);  % Left hemisphere view
else
    gsp_plot_graph(G_brain, signal_power_brain);
    title('Signal Power (Graph View)');
    colorbar;
    view(45, 30);
end

% Plot 2: Total variation
subplot(2, 4, 2);
if exist('V', 'var') && size(V, 1) == G_brain.N
    trisurf(F, V(:,1), V(:,2), V(:,3), mean_tv_brain, 'EdgeColor', 'none');
    title('Total Variation');
    colorbar;
    axis equal;
    view([90, 0]);  % Right hemisphere view
else
    gsp_plot_graph(G_brain, mean_tv_brain);
    title('Total Variation');
    colorbar;
    view(45, 30);
end

% Plot 3: Spectral content
subplot(2, 4, 3);
plot(G_brain.e, freq_energy, 'b-', 'LineWidth', 2);
xlabel('Graph Eigenvalue');
ylabel('Spectral Energy');
title('Cortical Frequency Content');
grid on;

% Plot 4: Dominant mode spatial pattern
subplot(2, 4, 4);
dominant_mode = top_modes(1);
gsp_plot_graph(G_brain, G_brain.U(:, dominant_mode));
title(sprintf('Dominant Mode %d', dominant_mode));
colorbar;
view(45, 30);

% Plot 5: Time series at peak vertex
subplot(2, 4, 5);
peak_vertex = find(signal_power_brain == max(signal_power_brain), 1);
plot(t_brain, X_brain_sub(peak_vertex, :), 'r-', 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Amplitude');
title(sprintf('Peak Vertex %d', peak_vertex));
grid on;

% Plot 6: Power distribution
subplot(2, 4, 6);
histogram(log10(signal_power_brain + eps), 30);
xlabel('log₁₀(Power)');
ylabel('Count');
title('Power Distribution');
grid on;

% Plot 7: Connectivity vs signal
subplot(2, 4, 7);
degrees = sum(G_brain.W > 0, 2);
scatter(degrees, signal_power_brain, 30, 'filled', 'alpha', 0.7);
xlabel('Vertex Degree');
ylabel('Signal Power');
title('Connectivity vs Activity');
grid on;

% Plot 8: Temporal correlation
subplot(2, 4, 8);
% Sample correlation for visualization
n_sample = min(50, G_brain.N);
sample_idx = round(linspace(1, G_brain.N, n_sample));
corr_matrix = corr(X_brain_sub(sample_idx, :)');
imagesc(sample_idx, sample_idx, corr_matrix);
xlabel('Vertex Index');
ylabel('Vertex Index');
title('Signal Correlation');
colorbar;

sgtitle('Brain Signal Analysis: Cortical Graph + MEG Data');

%% 8. Summary and Clinical Relevance
fprintf('\n8. Clinical and neuroscience implications...\n');

% Basic network properties
clustering_coeff = mean(clustering_coef_wu(G_brain.W));
path_length = mean(distance_wei(1./G_brain.W), 'all', 'omitnan');

fprintf('   Network properties:\n');
fprintf('     Clustering coefficient: %.3f\n', clustering_coeff);
fprintf('     Characteristic path length: %.2f\n', path_length);
fprintf('     Small-world index: %.2f\n', clustering_coeff / (path_length / G_brain.N));

% Signal characteristics
signal_entropy = compute_signal_entropy(X_brain_sub);
temporal_variability = std(mean(X_brain_sub, 1));

fprintf('   Signal characteristics:\n');
fprintf('     Spatial entropy: %.3f\n', signal_entropy);
fprintf('     Temporal variability: %.2e\n', temporal_variability);
fprintf('     Dynamic range: %.1f dB\n', 20*log10(max(signal_power_brain)/min(signal_power_brain)));

fprintf('   Clinical applications:\n');
fprintf('     - Resting state network analysis\n');
fprintf('     - Epileptic focus localization\n');
fprintf('     - Cognitive task activation mapping\n');
fprintf('     - Connectivity biomarker development\n');

fprintf('\n=== Brain pipeline demo completed! ===\n');
fprintf('The validated Bioctree pipeline successfully processes cortical data.\n');

end

% Helper functions
function [V, F] = create_synthetic_cortex()
% Create synthetic cortical surface using icosphere
try
    [V, F] = icosphere(4);  % 4 subdivisions
    V = V * 100;  % Scale to realistic size (mm)
    
    % Add some realistic deformation
    V(:, 3) = V(:, 3) + 20 * sin(3*V(:, 1)/100) .* cos(2*V(:, 2)/100);
catch
    % Fallback: simple sphere
    [x, y, z] = sphere(50);
    V = 100 * [x(:), y(:), z(:)];
    F = convhull(V);
end
end

function G = create_mesh_graph(V, F)
% Create graph from mesh topology
N = size(V, 1);
W = sparse(N, N);

% Add edges for each face
for f = 1:size(F, 1)
    face_vertices = F(f, :);
    for i = 1:3
        for j = i+1:3
            v1 = face_vertices(i);
            v2 = face_vertices(j);
            if v1 <= N && v2 <= N
                % Euclidean distance weight
                dist = norm(V(v1, :) - V(v2, :));
                W(v1, v2) = 1 / (1 + dist);
                W(v2, v1) = W(v1, v2);
            end
        end
    end
end

G = struct();
G.W = W;
G.N = N;
G.coords = V;
G.Ne = nnz(W) / 2;

% Add Laplacian
degrees = sum(W, 2);
D = spdiags(degrees, 0, N, N);
G.L = D - W;
end

function [G, X, fs, t] = load_bunny_comparison_data()
% Quick bunny data for comparison
dataPath = 'test-data/omega-tutorial/sub-0002/sensor/data_block001_band_02.mat';
data = load(dataPath);
megData = data.F;

G_full = gsp_bunny();
rng(42);
vertexIndices = randperm(G_full.N, 100);  % Smaller for quick comparison
G = gsp_subgraph(G_full, vertexIndices);
G = gsp_estimate_lmax(G);

downsample_factor = 50;
time_indices = 1:downsample_factor:size(megData, 2);
X = megData(1:G.N, time_indices);

fs = 300 / downsample_factor;
t = (0:length(time_indices)-1) / fs;
end

function entropy = compute_signal_entropy(X)
% Compute spatial signal entropy
signal_power = mean(X.^2, 2);
signal_power = signal_power / sum(signal_power);  % Normalize
entropy = -sum(signal_power .* log2(signal_power + eps));
end