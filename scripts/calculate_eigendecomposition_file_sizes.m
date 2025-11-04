% calculate_eigendecomposition_file_sizes.m
% Calculate expected file sizes for different eigendecomposition strategies

fprintf('Eigendecomposition File Size Calculator\n');
fprintf('=======================================\n\n');

%% Load graph to get dimensions
try
    data = load('test-data/meshes/fsaverage/fsaverage_pial_gsp_graphs_complete.mat');
    G_lh = data.G_lh;
    N = G_lh.N; % Number of vertices
    fprintf('Graph dimensions: %d vertices per hemisphere\n', N);
catch ME
    fprintf('Error loading graph data: %s\n', ME.message);
    fprintf('Using default estimate: N = 163842\n');
    N = 163842;
end

%% Define different strategies
strategies = {
    struct('name', 'Low-frequency', 'nb_eigenvectors', 1000),
    struct('name', 'Medium-frequency', 'nb_eigenvectors', 5000),
    struct('name', 'High-frequency', 'nb_eigenvectors', 10000),
    struct('name', 'Extended', 'nb_eigenvectors', 25000),
    struct('name', 'Half decomposition', 'nb_eigenvectors', round(N/2)),
    struct('name', 'Full decomposition', 'nb_eigenvectors', N)
};

fprintf('\nFile Size Analysis for GSP Eigendecomposition\n');
fprintf('=============================================\n\n');

%% Calculate sizes for each strategy
for i = 1:length(strategies)
    strategy = strategies{i};
    k = strategy.nb_eigenvectors;
    
    fprintf('%d. %s (%d eigenvectors):\n', i, strategy.name, k);
    
    % Memory/storage components:
    % 1. Eigenvectors U: N x k matrix (double precision = 8 bytes)
    eigenvectors_bytes = N * k * 8;
    
    % 2. Eigenvalues e: k x 1 vector (double precision = 8 bytes)
    eigenvalues_bytes = k * 8;
    
    % 3. Original graph data (W, L, coords, faces, etc.) - estimate
    original_graph_bytes = N * N * 8 * 0.006 + N * 3 * 8 + N * 3 * 4; % Sparse W (~0.6% density), coords, faces
    
    % 4. Additional metadata and MATLAB overhead (~10% of data)
    overhead_factor = 1.1;
    
    % Total per hemisphere
    total_bytes_per_hemi = (eigenvectors_bytes + eigenvalues_bytes + original_graph_bytes) * overhead_factor;
    
    % Convert to human-readable units
    total_mb_per_hemi = total_bytes_per_hemi / (1024^2);
    total_gb_per_hemi = total_bytes_per_hemi / (1024^3);
    
    % For both hemispheres
    total_mb_both = total_mb_per_hemi * 2;
    total_gb_both = total_gb_per_hemi * 2;
    
    fprintf('   Per hemisphere:\n');
    fprintf('     - Eigenvectors (U): %.1f MB (%d x %d x 8 bytes)\n', eigenvectors_bytes/(1024^2), N, k);
    fprintf('     - Eigenvalues (e): %.3f MB (%d x 8 bytes)\n', eigenvalues_bytes/(1024^2), k);
    fprintf('     - Graph data: %.1f MB\n', original_graph_bytes/(1024^2));
    fprintf('     - Total per hemisphere: %.1f MB (%.3f GB)\n', total_mb_per_hemi, total_gb_per_hemi);
    
    fprintf('   Both hemispheres:\n');
    if total_gb_both >= 1
        fprintf('     - Combined file size: %.1f MB (%.2f GB)\n', total_mb_both, total_gb_both);
    else
        fprintf('     - Combined file size: %.1f MB\n', total_mb_both);
    end
    
    % Memory requirements during computation
    computation_memory_gb = (N * k * 8 * 2) / (1024^3); % U matrix + workspace
    fprintf('     - Memory during computation: %.2f GB\n', computation_memory_gb);
    
    % Estimated computation time (very rough estimate based on eigenvalue solver complexity)
    if k == N
        time_estimate_hours = (N^3) / (1e12); % Full eigendecomposition O(N^3)
    else
        time_estimate_hours = (N * k^2) / (1e11); % Iterative solver O(N*k^2)
    end
    
    if time_estimate_hours < 1
        fprintf('     - Estimated computation time: %.1f minutes\n', time_estimate_hours * 60);
    else
        fprintf('     - Estimated computation time: %.1f hours\n', time_estimate_hours);
    end
    
    fprintf('\n');
end

%% Current baseline for comparison
fprintf('Current baseline (without eigendecomposition):\n');
fprintf('==============================================\n');

% Check current file sizes
current_files = {
    'test-data/meshes/fsaverage/fsaverage_lh_pial_gsp_graph.mat',
    'test-data/meshes/fsaverage/fsaverage_rh_pial_gsp_graph.mat',
    'test-data/meshes/fsaverage/fsaverage_pial_gsp_graphs_complete.mat'
};

for i = 1:length(current_files)
    if exist(current_files{i}, 'file')
        file_info = dir(current_files{i});
        size_mb = file_info.bytes / (1024^2);
        fprintf('  - %s: %.1f MB\n', file_info.name, size_mb);
    end
end

%% Recommendations
fprintf('\nRecommendations:\n');
fprintf('================\n');

fprintf('For most graph signal processing applications:\n');
fprintf('  → Medium-frequency (5000 eigenvectors): Good balance of functionality vs. size\n');
fprintf('  → File size: ~%.0f MB per hemisphere, manageable computation time\n', strategies{2}.nb_eigenvectors * N * 8 / (1024^2) * 1.1);

fprintf('\nFor detailed spectral analysis:\n');
fprintf('  → High-frequency (10000 eigenvectors): Captures more spectral detail\n');
fprintf('  → File size: ~%.0f MB per hemisphere\n', strategies{3}.nb_eigenvectors * N * 8 / (1024^2) * 1.1);

fprintf('\nFull decomposition considerations:\n');
full_size_gb = (N * N * 8 * 1.1) / (1024^3);
fprintf('  → File size: %.1f GB per hemisphere (%.1f GB total)\n', full_size_gb, full_size_gb * 2);
fprintf('  → Memory requirement: %.1f GB during computation\n', (N * N * 8 * 2) / (1024^3));
fprintf('  → Very long computation time (potentially days)\n');
fprintf('  → Only recommended if you need the complete spectral representation\n');

fprintf('\nPractical choice:\n');
fprintf('  → Start with medium-frequency (5000) for testing\n');
fprintf('  → Upgrade to high-frequency (10000) if needed\n');
fprintf('  → Consider full decomposition only for final production analysis\n');

%% Storage space check
fprintf('\nStorage space analysis:\n');
fprintf('=======================\n');

% Check available disk space
try
    if ispc
        [status, result] = system('dir /-c');
    else
        [status, result] = system('df -h .');
    end
    
    if status == 0
        fprintf('Current directory disk space:\n');
        disp(result);
    else
        fprintf('Could not determine available disk space\n');
    end
catch
    fprintf('Could not check disk space\n');
end

fprintf('\n=== File Size Calculator Complete ===\n');