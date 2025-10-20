function demo_alphaband_analysis()
% DEMO_ALPHABAND_ANALYSIS Alpha-band source analysis demonstration
%
% This demo script demonstrates the core functionality of the MEG-GSP toolbox
% by analyzing alpha-band (8-12 Hz) activity from simulated Brainstorm source data.
%
% The demo covers:
% 1. Loading cortical surface and source time series
% 2. Building cortical graph with cotangent weights
% 3. Alpha-band filtering and spectral analysis
% 4. Computing spatial gradients and total variation
% 5. Joint time-vertex analysis with JFT
% 6. Visualization of results on cortical surface
%
% Requirements:
%   - MEG-GSP toolbox properly installed (run scripts/setup.m)
%   - GSPBOX in path
%   - Sample data (generated if not available)

fprintf('=== MEG-GSP Toolbox Demo: Alpha-Band Analysis ===\n\n');

%% 1. Setup and Data Loading
fprintf('1. Setting up demo environment...\n');

% Add toolbox paths (in case setup wasn't run)
try
    addpath(genpath(fileparts(mfilename('fullpath'))));
    fprintf('   Added toolbox paths\n');
catch
    warning('Could not add toolbox paths. Run setup.m first.');
end

% Check if GSPBOX is available
if ~exist('gsp_start', 'file')
    warning('GSPBOX not found. Some functionality may not work.');
else
    fprintf('   GSPBOX detected\n');
end

%% 2. Load or Generate Cortical Data
fprintf('\n2. Loading cortical surface and source data...\n');

% Try to load real Brainstorm data, otherwise generate synthetic
try
    % Look for sample data files
    dataFiles = dir('data/*cortex*.mat');
    if ~isempty(dataFiles)
        dataPath = fullfile('data', dataFiles(1).name);
        fprintf('   Loading real data: %s\n', dataPath);
        S = meg_gsp.io.loadBrainstormSource(dataPath);
    else
        error('No real data found, generating synthetic');
    end
catch
    fprintf('   No sample data found. Generating synthetic cortical surface...\n');
    S = generateSyntheticCorticalData();
end

fprintf('   Loaded: %d vertices, %d time points (%.1f s at %.1f Hz)\n', ...
        size(S.X_src, 1), size(S.X_src, 2), length(S.tvec)/S.fs, S.fs);

%% 3. Build Cortical Graph
fprintf('\n3. Building cortical graph with cotangent weights...\n');

% Create graph with cotangent weights for smooth Laplacian
opts_graph = struct();
opts_graph.WeightType = 'cotangent';
opts_graph.NormalizedLap = true;
opts_graph.Verbose = true;

G = meg_gsp.graph.fromCortex(S.V, S.F, opts_graph);

fprintf('   Graph created: %d vertices, %d edges\n', G.N, G.Ne);
fprintf('   Spectral radius: %.3f\n', G.lmax);

%% 4. Alpha-Band Filtering
fprintf('\n4. Extracting alpha-band activity (8-12 Hz)...\n');

% Design alpha-band filter
alpha_band = [8, 12];  % Hz
nyquist = S.fs / 2;
[b, a] = butter(4, alpha_band / nyquist, 'bandpass');

% Apply filter to source time series
X_alpha = filtfilt(b, a, S.X_src')';
fprintf('   Applied %d-th order Butterworth bandpass filter\n', 4);

% Compute alpha power envelope
X_alpha_power = abs(hilbert(X_alpha'))';
fprintf('   Computed instantaneous alpha power\n');

%% 5. Spatial Analysis with Graph Operators
fprintf('\n5. Computing spatial derivatives and total variation...\n');

% Compute graph gradient of alpha power
gradAlpha = meg_gsp.ops.graphGradient(G, X_alpha_power);
fprintf('   Computed graph gradient (edge-wise differences)\n');

% Total variation (L1 norm of gradient)
tvAlpha = meg_gsp.ops.graphTotalVariation(G, X_alpha_power, 1);
fprintf('   Computed total variation (spatial roughness)\n');

% Time-averaged metrics for visualization
meanAlphaPower = mean(X_alpha_power, 2);
meanTV = mean(tvAlpha, 2);
gradMagnitude = sqrt(sum(gradAlpha.^2, 1));  % L2 norm over edges per time
meanGradMag = mean(gradMagnitude);

fprintf('   Mean alpha power: %.2e ± %.2e\n', mean(meanAlphaPower), std(meanAlphaPower));
fprintf('   Mean total variation: %.2e ± %.2e\n', mean(meanTV), std(meanTV));

%% 6. Joint Time-Vertex Spectral Analysis
fprintf('\n6. Performing joint time-vertex spectral analysis...\n');

% Select subset for JFT (computational efficiency)
time_indices = 1:10:length(S.tvec);  % Subsample time
X_sub = X_alpha(:, time_indices);
fprintf('   Subsampled to %d time points for JFT\n', length(time_indices));

% Compute Joint Fourier Transform
try
    Xhat_joint = meg_gsp.transforms.jft(G, X_sub);
    fprintf('   Computed JFT: %d x %d coefficients\n', size(Xhat_joint));
    
    % Joint spectral energy
    spectral_energy = abs(Xhat_joint).^2;
    fprintf('   Joint spectral energy range: [%.2e, %.2e]\n', ...
            min(spectral_energy(:)), max(spectral_energy(:)));
    
catch ME
    warning('JFT computation failed: %s', ME.message);
    fprintf('   Skipping joint spectral analysis\n');
    Xhat_joint = [];
end

%% 7. Visualization
fprintf('\n7. Creating visualizations...\n');

% Create figure with multiple subplots
fig = figure('Name', 'MEG-GSP Alpha-Band Analysis', 'Position', [100, 100, 1200, 800]);

% Plot 1: Mean alpha power on cortical surface
subplot(2, 3, 1);
try
    meg_gsp.viz.plotCortexMap(S.V, S.F, meanAlphaPower);
    title('Mean Alpha Power');
    colorbar;
    fprintf('   Plotted cortical alpha power map\n');
catch
    % Fallback to simple scatter plot
    scatter3(S.V(:,1), S.V(:,2), S.V(:,3), 20, meanAlphaPower, 'filled');
    title('Mean Alpha Power');
    colorbar;
    axis equal;
    fprintf('   Plotted fallback scatter plot\n');
end

% Plot 2: Total variation (spatial roughness)
subplot(2, 3, 2);
try
    meg_gsp.viz.plotCortexMap(S.V, S.F, meanTV);
    title('Spatial Total Variation');
    colorbar;
catch
    scatter3(S.V(:,1), S.V(:,2), S.V(:,3), 20, meanTV, 'filled');
    title('Spatial Total Variation');
    colorbar;
    axis equal;
end

% Plot 3: Time series at peak alpha vertex
[~, peak_vertex] = max(meanAlphaPower);
subplot(2, 3, 3);
plot(S.tvec, S.X_src(peak_vertex, :), 'b-', 'LineWidth', 1);
hold on;
plot(S.tvec, X_alpha(peak_vertex, :), 'r-', 'LineWidth', 2);
xlabel('Time (s)');
ylabel('Amplitude');
title(sprintf('Time Series (Vertex %d)', peak_vertex));
legend('Original', 'Alpha-filtered', 'Location', 'best');
grid on;

% Plot 4: Alpha power time series  
subplot(2, 3, 4);
plot(S.tvec, X_alpha_power(peak_vertex, :), 'g-', 'LineWidth', 2);
xlabel('Time (s)');
ylabel('Alpha Power');
title('Alpha Power Envelope');
grid on;

% Plot 5: Gradient magnitude over time
subplot(2, 3, 5);
plot(S.tvec, gradMagnitude, 'k-', 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('||∇G α||');
title('Graph Gradient Magnitude');
grid on;

% Plot 6: Joint spectral content (if computed)
subplot(2, 3, 6);
if ~isempty(Xhat_joint)
    try
        imagesc(log10(abs(Xhat_joint) + eps));
        xlabel('Temporal Frequency Index');
        ylabel('Graph Frequency Index');
        title('Joint Spectrum |X̂(λ,ω)|');
        colorbar;
    catch
        histogram(log10(spectral_energy(:) + eps), 50);
        xlabel('log₁₀(|X̂|²)');
        ylabel('Count');
        title('Joint Spectral Energy Distribution');
        grid on;
    end
else
    text(0.5, 0.5, 'JFT not computed', 'HorizontalAlignment', 'center');
    title('Joint Spectrum (Unavailable)');
end

sgtitle('MEG-GSP Toolbox: Alpha-Band Analysis Results');

%% 8. Summary Statistics
fprintf('\n8. Analysis Summary:\n');
fprintf('   Dataset: %d vertices, %.1f seconds\n', G.N, S.tvec(end));
fprintf('   Graph edges: %d (%.1f%% connectivity)\n', G.Ne, 100*G.Ne/(G.N*(G.N-1)/2));
fprintf('   Alpha power range: [%.2e, %.2e]\n', min(meanAlphaPower), max(meanAlphaPower));
fprintf('   Peak alpha vertex: %d (%.2e power)\n', peak_vertex, meanAlphaPower(peak_vertex));
fprintf('   Mean spatial TV: %.2e (roughness measure)\n', mean(meanTV));

% Performance metrics
if ~isempty(Xhat_joint)
    fprintf('   JFT computed successfully on %d x %d data\n', size(X_sub));
else
    fprintf('   JFT computation skipped (implement transforms module)\n');
end

fprintf('\n=== Demo completed successfully! ===\n');
fprintf('Next steps:\n');
fprintf('  - Run demo_joint_filtering.m for filtering comparison\n');
fprintf('  - Run demo_dgw_propagation.m for wave analysis\n');
fprintf('  - Explore meg_gsp.viz functions for interactive visualization\n');

end

function S = generateSyntheticCorticalData()
% Generate synthetic cortical surface and source time series for demo
fprintf('   Generating synthetic cortical surface...\n');

% Create icosphere for cortical surface
try
    [V, F] = icosphere(3);  % 3 subdivisions ≈ 2562 vertices
    V = V * 100;  % Scale to realistic head size (mm)
catch
    % Fallback: simple sphere
    [x, y, z] = sphere(50);
    V = 100 * [x(:), y(:), z(:)];
    F = convhull(V);
    fprintf('   Used fallback sphere geometry\n');
end

N = size(V, 1);
fprintf('   Created mesh: %d vertices, %d faces\n', N, size(F, 1));

% Generate realistic MEG source time series
fs = 250;  % 250 Hz sampling rate
duration = 4;  % 4 seconds
t = (0:1/fs:duration-1/fs);
T = length(t);

fprintf('   Generating source signals: %d samples at %.1f Hz\n', T, fs);

% Initialize source matrix
X_src = zeros(N, T);

% Add alpha rhythm (8-12 Hz) with spatial structure
alpha_freq = 10;  % 10 Hz alpha
alpha_centers = [round(N*0.2), round(N*0.7)];  % Two alpha sources

for center = alpha_centers
    % Spatial Gaussian around center
    distances = sqrt(sum((V - V(center, :)).^2, 2));
    spatial_pattern = exp(-distances.^2 / (2 * 15^2));  % 15mm sigma
    
    % Temporal alpha with phase noise
    phase = 2*pi*rand();  % Random phase
    alpha_signal = sin(2*pi*alpha_freq*t + phase);
    
    % Add to sources
    X_src = X_src + spatial_pattern * alpha_signal;
end

% Add background noise
noise_level = 0.5;
X_src = X_src + noise_level * randn(N, T);

% Add some beta activity (20 Hz)
beta_freq = 20;
beta_center = round(N*0.5);
distances = sqrt(sum((V - V(beta_center, :)).^2, 2));
spatial_pattern = exp(-distances.^2 / (2 * 10^2));
beta_signal = 0.3 * sin(2*pi*beta_freq*t + 2*pi*rand());
X_src = X_src + spatial_pattern * beta_signal;

% Package in structure
S = struct();
S.V = V;
S.F = F;
S.X_src = X_src;
S.tvec = t;
S.fs = fs;

fprintf('   Generated realistic alpha + beta + noise signals\n');

end