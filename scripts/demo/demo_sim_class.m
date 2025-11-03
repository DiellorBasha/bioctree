%% Demo: Using bct.sim.sim Class for Graph Signal Simulation
% This script demonstrates how to use the bct.sim.sim class to simulate
% graph signals with the BCT framework.

clear; close all;

% Add bioctree to path if needed
if ~exist('bct.bct', 'class')
    addpath(genpath('.'));
end

fprintf('=== BCT Sim Class Demo ===\n\n');

%% Step 1: Create a BCT file and initialize the sim class
fprintf('Step 1: Creating BCT file and initializing sim class...\n');

% Create a temporary BCT file
demo_file = fullfile(tempdir, 'sim_demo.h5');
if exist(demo_file, 'file')
    delete(demo_file);
end

% Create BCT instance
B = bct.bct.create(demo_file);
fprintf('  ✓ Created BCT file: %s\n', demo_file);

% Initialize sim class - this will automatically create a default graph
S = bct.sim.sim(B);
fprintf('  ✓ Initialized sim class\n');
fprintf('  ✓ Graph has %d nodes\n', S.N);

%% Step 2: Examine the default graph
fprintf('\nStep 2: Examining the default graph...\n');

% Read graph structure
G = B.read_graph_gsp();
fprintf('  ✓ Graph type: %s\n', class(G.W));
fprintf('  ✓ Number of nodes: %d\n', G.N);
fprintf('  ✓ Number of edges: %d\n', nnz(G.W)/2);

% Check if coordinates exist
if B.has('/graph/coords')
    coords = B.read_coords();
    fprintf('  ✓ Has coordinates: %dx%d\n', size(coords,1), size(coords,2));
    coord_range = [min(coords); max(coords)];
    fprintf('  ✓ Coordinate range: [%.2f, %.2f] to [%.2f, %.2f]\n', ...
            coord_range(1,1), coord_range(1,2), coord_range(2,1), coord_range(2,2));
else
    fprintf('  ! No coordinates found\n');
end

%% Step 3: Generate static Gaussian signals
fprintf('\nStep 3: Generating static Gaussian signals...\n');

% 3a. Simple Gaussian centered at node 1
x1 = S.gaussian();  % Default parameters
fprintf('  ✓ Generated Gaussian at node 1 (default)\n');
fprintf('    - Signal range: [%.3f, %.3f]\n', min(x1), max(x1));
fprintf('    - Signal at center node: %.3f\n', x1(1));

% 3b. Gaussian with custom parameters
center_node = ceil(S.N/2);  % Middle node
x2 = S.gaussian('center', center_node, 'sigma', 4, 'amplitude', 2);
fprintf('  ✓ Generated Gaussian at node %d, sigma=4, amplitude=2\n', center_node);
fprintf('    - Signal range: [%.3f, %.3f]\n', min(x2), max(x2));
fprintf('    - Signal at center node: %.3f\n', x2(center_node));

% 3c. Multiple centers with different combining strategies
if S.N >= 4
    centers = [1, ceil(S.N/3), ceil(2*S.N/3)];
    x3_sum = S.gaussian('center', centers, 'sigma', 3, 'combine', 'sum');
    x3_max = S.gaussian('center', centers, 'sigma', 3, 'combine', 'max');
    fprintf('  ✓ Generated multi-center Gaussians (%d centers)\n', length(centers));
    fprintf('    - Sum combine: range [%.3f, %.3f]\n', min(x3_sum), max(x3_sum));
    fprintf('    - Max combine: range [%.3f, %.3f]\n', min(x3_max), max(x3_max));
end

%% Step 4: Generate default growth time series
fprintf('\nStep 4: Generating default growth time series...\n');

% 4a. Default growth series (T=100, fs=10 Hz)
X_default = S.gaussian_growth_default();
[T_def, N_def] = size(X_default);
fprintf('  ✓ Generated default growth series: %dx%d (T×N)\n', T_def, N_def);
fprintf('    - Time duration: %.1f seconds\n', (T_def-1)/10);
fprintf('    - Signal range: [%.3f, %.3f]\n', min(X_default(:)), max(X_default(:)));

% Check growth pattern
signal_widths = zeros(T_def, 1);
for t = 1:T_def
    signal_widths(t) = sum(X_default(t, :) > 0.1 * max(X_default(t, :)));
end
fprintf('    - Signal width growth: %d → %d nodes (10%% threshold)\n', ...
        signal_widths(1), signal_widths(end));

% 4b. Custom growth series
X_custom = S.gaussian_growth_default('T', 50, 'fs', 20);
[T_cust, N_cust] = size(X_custom);
fprintf('  ✓ Generated custom growth series: %dx%d (T=50, fs=20 Hz)\n', T_cust, N_cust);
fprintf('    - Time duration: %.2f seconds\n', (T_cust-1)/20);

%% Step 5: Write signals to BCT file as layers
fprintf('\nStep 5: Writing signals to BCT file...\n');

% Note: BCT requires all layers to have the same T dimension
% We'll create a separate demo showing two approaches:

% 5a. Approach 1: Start with time series, then add static signals as time series
fprintf('  Approach 1: Time series with static signals as T=1 layers\n');

% First, write the growth series (T=100)
layer1_id = S.write_layer(X_default, 10);  % fs=10 Hz
fprintf('    ✓ Wrote growth series as layer %d (T=100)\n', layer1_id);

% Convert static signals to T=1 time series for consistency
x1_ts = reshape(x1, 1, length(x1));  % Make it 1×N (T=1)
x2_ts = reshape(x2, 1, length(x2));  % Make it 1×N (T=1)

% Note: These will fail because T dimensions don't match (1 vs 100)
% This is a limitation of the current BCT design
fprintf('    Note: Cannot mix T=1 and T=100 layers in same file\n');

% 5b. Approach 2: Create a new file for static signals only
fprintf('\n  Approach 2: Separate file for static signals\n');
static_file = fullfile(tempdir, 'sim_static.h5');
if exist(static_file, 'file')
    delete(static_file);
end

B_static = bct.bct.create(static_file);
S_static = bct.sim.sim(B_static);  % Will reuse the graph

% Write static signals as T=1 layers
layer_s1 = S_static.write_layer(x1, 10);
fprintf('    ✓ Wrote static Gaussian 1 as layer %d\n', layer_s1);

layer_s2 = S_static.write_layer(x2, 10);
fprintf('    ✓ Wrote static Gaussian 2 as layer %d\n', layer_s2);

layer_s3 = S_static.write_layer(x3_sum, 10);  % Multi-center sum
fprintf('    ✓ Wrote multi-center Gaussian as layer %d\n', layer_s3);

%% Step 6: Verify data in files
fprintf('\nStep 6: Verifying data in BCT files...\n');

% Check time series file
fprintf('  Time series file (growth data):\n');
if B.has('/signals/raw_stack')
    fprintf('    ✓ Raw stack exists\n');
    
    % Check layer axis
    if B.has('/axes/layer_id')
        layer_ids = B.read_axis('layer_id');
        fprintf('      - Layer IDs: %s\n', mat2str(layer_ids));
    end
    
    % Check time axis
    if B.has('/axes/time_s')
        time_axis = B.read_axis('time_s');
        fprintf('      - Time axis: %.3f to %.3f seconds (%d samples)\n', ...
                time_axis(1), time_axis(end), length(time_axis));
    end
    
    % Check sampling rate
    if B.has('/axes/fs_hz')
        fs_stored = B.read_axis('fs_hz');
        fprintf('      - Sampling rate: %.1f Hz\n', fs_stored);
    end
end

% Check static signals file
fprintf('  Static signals file:\n');
if B_static.has('/signals/raw_stack')
    fprintf('    ✓ Static raw stack exists\n');
    
    % Check layer axis
    if B_static.has('/axes/layer_id')
        layer_ids_static = B_static.read_axis('layer_id');
        fprintf('      - Layer IDs: %s\n', mat2str(layer_ids_static));
    end
    
    % Check time axis (should be T=1 for static signals)
    if B_static.has('/axes/time_s')
        time_axis_static = B_static.read_axis('time_s');
        fprintf('      - Time axis: %.3f seconds (%d sample)\n', ...
                time_axis_static(1), length(time_axis_static));
    end
end

%% Step 7: Read back and verify signals
fprintf('\nStep 7: Reading back signals for verification...\n');

% Read back the growth series (layer 1, 0-based indexing)
try
    X_readback = B.read_raw([1, T_def], [1, S.N], 0);  % layer 0 (first layer)
    X_readback = squeeze(X_readback);  % Remove layer dimension
    
    % Verify it matches
    max_error = max(abs(X_readback(:) - X_default(:)));
    fprintf('  ✓ Read back growth series successfully\n');
    fprintf('    - Maximum error: %.2e (should be ~0)\n', max_error);
    
    if max_error < 1e-6
        fprintf('    ✓ Perfect match!\n');
    else
        fprintf('    ⚠ Some numerical differences detected\n');
    end
catch ME
    fprintf('  ✗ Error reading back growth series: %s\n', ME.message);
end

% Read back static signals
try
    x1_readback = B_static.read_raw([1, 1], [1, S.N], 0);  % First static signal
    x1_readback = squeeze(x1_readback);
    
    max_error_static = max(abs(x1_readback(:) - x1(:)));
    fprintf('  ✓ Read back static signal 1 successfully\n');
    fprintf('    - Maximum error: %.2e (should be ~0)\n', max_error_static);
    
    if max_error_static < 1e-6
        fprintf('    ✓ Perfect match!\n');
    else
        fprintf('    ⚠ Some numerical differences detected\n');
    end
catch ME
    fprintf('  ✗ Error reading back static signal: %s\n', ME.message);
end

%% Step 8: Demonstrate coordinate-based centering (if coordinates available)
fprintf('\nStep 8: Testing coordinate-based operations...\n');

if B.has('/graph/coords')
    coords = B.read_coords();
    
    % Find coordinate centroid
    centroid = mean(double(coords), 1);
    fprintf('  ✓ Graph centroid coordinates: [%.2f, %.2f, %.2f]\n', centroid);
    
    % Generate Gaussian centered at coordinate centroid
    try
        x_coord = S.gaussian('center', centroid, 'center_type', 'coord', 'sigma', 5);
        fprintf('  ✓ Generated coordinate-centered Gaussian\n');
        fprintf('    - Signal range: [%.3f, %.3f]\n', min(x_coord), max(x_coord));
        
        % Find which node is closest to centroid
        distances = vecnorm(double(coords) - centroid, 2, 2);
        [~, closest_node] = min(distances);
        fprintf('    - Closest node to centroid: %d (signal=%.3f)\n', ...
                closest_node, x_coord(closest_node));
    catch ME
        fprintf('  ✗ Coordinate-based centering failed: %s\n', ME.message);
    end
else
    fprintf('  ! No coordinates available for coordinate-based operations\n');
    fprintf('    (This is expected for bunny graph in GSPBox without coordinate fix)\n');
end

%% Step 9: Performance and memory information
fprintf('\nStep 9: Performance summary...\n');

file_info = dir(demo_file);
fprintf('  ✓ BCT file size: %.1f KB\n', file_info.bytes / 1024);

% Show what datasets exist in the file
fprintf('  ✓ File contents:\n');
datasets_to_check = {
    '/graph/edges/coo_i', 'Graph edges (i indices)';
    '/graph/edges/coo_j', 'Graph edges (j indices)';
    '/graph/coords', 'Node coordinates';
    '/signals/raw_stack', 'Signal stack';
    '/axes/time_s', 'Time axis';
    '/axes/layer_id', 'Layer IDs';
    '/axes/node_id', 'Node IDs';
    '/axes/fs_hz', 'Sampling rate'
};

for i = 1:size(datasets_to_check, 1)
    path = datasets_to_check{i, 1};
    desc = datasets_to_check{i, 2};
    if B.has(path)
        fprintf('    ✓ %s: %s\n', desc, path);
    else
        fprintf('    - %s: %s (not present)\n', desc, path);
    end
end

%% Step 10: Cleanup and summary
fprintf('\nStep 10: Demo completion...\n');

fprintf('  ✓ Successfully demonstrated bct.sim.sim class functionality:\n');
fprintf('    • Automatic graph creation (bunny or fallback)\n');
fprintf('    • Static Gaussian signal generation\n');
fprintf('    • Growth time series simulation\n');
fprintf('    • Multi-layer signal storage in BCT format\n');
fprintf('    • Data verification and readback\n');

% Optional: Clean up the demo file
fprintf('\n  Clean up demo file? (y/n): ');
cleanup = input('', 's');
if lower(cleanup(1)) == 'y'
    delete(demo_file);
    fprintf('  ✓ Demo file deleted\n');
else
    fprintf('  ✓ Demo file kept at: %s\n', demo_file);
end

fprintf('\n=== Demo Complete ===\n');

%% Optional: Plotting (if desired)
% Uncomment the following section to create plots

% fprintf('\nGenerating plots...\n');
% 
% figure('Position', [100, 100, 1200, 800]);
% 
% % Plot 1: Graph structure
% subplot(2,3,1);
% if exist('coords', 'var') && ~isempty(coords)
%     gplot(double(G.W), double(coords(:,1:2)));
%     title('Graph Structure');
%     axis equal; grid on;
% else
%     spy(G.W);
%     title('Graph Adjacency');
% end
% 
% % Plot 2: Static Gaussian signals
% subplot(2,3,2);
% plot(1:S.N, [x1, x2]);
% title('Static Gaussian Signals');
% legend('Default', 'Custom', 'Location', 'best');
% xlabel('Node'); ylabel('Signal Amplitude');
% grid on;
% 
% % Plot 3: Growth series over time
% subplot(2,3,3);
% imagesc(X_default');
% title('Growth Time Series');
% xlabel('Time'); ylabel('Node');
% colorbar;
% 
% % Plot 4: Signal width growth
% subplot(2,3,4);
% plot(1:T_def, signal_widths);
% title('Signal Width Growth');
% xlabel('Time'); ylabel('Active Nodes');
% grid on;
% 
% % Plot 5: Time series at center node
% subplot(2,3,5);
% center_idx = 1; % or whatever center was used
% plot((0:T_def-1)/10, X_default(:, center_idx));
% title(sprintf('Signal at Node %d', center_idx));
% xlabel('Time (s)'); ylabel('Amplitude');
% grid on;
% 
% % Plot 6: Final signal distribution
% subplot(2,3,6);
% final_signal = X_default(end, :);
% stem(1:S.N, final_signal);
% title('Final Signal Distribution');
% xlabel('Node'); ylabel('Amplitude');
% grid on;
% 
% sgtitle('BCT Sim Class Demo Results');
% 
% fprintf('✓ Plots generated\n');