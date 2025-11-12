% estimate_fourier_basis_sizes.m
% Estimate file sizes for different Fourier basis computation strategies

fprintf('Estimating Fourier Basis File Sizes\n');
fprintf('===================================\n\n');

%% Parameters
N = 163842; % Number of vertices in fsaverage hemispheres

fprintf('Graph parameters:\n');
fprintf('  - Vertices (N): %d\n', N);
fprintf('  - Estimated edges: ~%d (assuming triangular mesh)\n', N * 3);

%% Base graph size (without eigendecomposition)
fprintf('\n1. Base graph components (without eigendecomposition):\n');
fprintf('-----------------------------------------------------\n');

% Base components
coords_mb = (N * 3 * 8) / (1024^2); % coordinates (N x 3, double)
faces_mb = (N * 2 * 3 * 4) / (1024^2); % faces (~2N faces, 3 indices, int32)
weight_matrix_mb = (N * 6 * 8 * 2) / (1024^2); % sparse weight matrix (~6 neighbors per vertex)
laplacian_mb = weight_matrix_mb; % Laplacian similar size to weight matrix
misc_mb = 10; % Other fields, metadata

base_size_mb = coords_mb + faces_mb + weight_matrix_mb + laplacian_mb + misc_mb;

fprintf('  - Coordinates (N×3): %.1f MB\n', coords_mb);
fprintf('  - Faces (~2N×3): %.1f MB\n', faces_mb);
fprintf('  - Weight matrix (sparse): %.1f MB\n', weight_matrix_mb);
fprintf('  - Laplacian matrix: %.1f MB\n', laplacian_mb);
fprintf('  - Miscellaneous: %.1f MB\n', misc_mb);
fprintf('  - Total base graph: %.1f MB\n', base_size_mb);

%% Eigendecomposition size estimates
fprintf('\n2. Eigendecomposition size estimates:\n');
fprintf('------------------------------------\n');

strategies = {
    struct('name', 'No eigendecomposition', 'k', 0),
    struct('name', 'Low-frequency (1,000 eigenvectors)', 'k', 1000),
    struct('name', 'Medium-frequency (5,000 eigenvectors)', 'k', 5000),
    struct('name', 'High-frequency (10,000 eigenvectors)', 'k', 10000),
    struct('name', 'Very high-frequency (50,000 eigenvectors)', 'k', 50000),
    struct('name', 'Full eigendecomposition (all eigenvectors)', 'k', N)
};

fprintf('Storage requirements for different strategies:\n\n');

for i = 1:length(strategies)
    k = strategies{i}.k;
    
    if k == 0
        % No eigendecomposition
        eigenvalues_mb = 0;
        eigenvectors_mb = 0;
        total_mb = base_size_mb;
    else
        % k eigenvalues and eigenvectors
        eigenvalues_mb = (k * 8) / (1024^2); % eigenvalues (k x 1, double)
        eigenvectors_mb = (N * k * 8) / (1024^2); % eigenvectors (N x k, double)
        total_mb = base_size_mb + eigenvalues_mb + eigenvectors_mb;
    end
    
    total_gb = total_mb / 1024;
    
    fprintf('%s:\n', strategies{i}.name);
    if k > 0
        fprintf('  - Eigenvalues (%d): %.1f MB\n', k, eigenvalues_mb);
        fprintf('  - Eigenvectors (%d×%d): %.1f MB\n', N, k, eigenvectors_mb);
    end
    fprintf('  - Total file size: %.1f MB (%.2f GB)\n', total_mb, total_gb);
    
    % Memory requirements during computation
    if k > 0
        % During eigendecomposition, need temporary matrices
        temp_memory_gb = (N * N * 8) / (1024^3); % Full matrix for eig()
        if k < N
            temp_memory_gb = min(temp_memory_gb, (N * k * 8 * 3) / (1024^3)); % Iterative solver
        end
        fprintf('  - Peak memory during computation: ~%.1f GB\n', temp_memory_gb);
    end
    
    fprintf('\n');
end

%% Practical recommendations
fprintf('3. Practical recommendations:\n');
fprintf('-----------------------------\n');

fprintf('For brain network analysis:\n');
fprintf('• 1,000-5,000 eigenvectors: Usually sufficient for most applications\n');
fprintf('  - File size: ~%.1f-%.1f GB per hemisphere\n', ...
    (base_size_mb + (N*1000*8)/(1024^2))/1024, (base_size_mb + (N*5000*8)/(1024^2))/1024);
fprintf('  - Use cases: Spectral filtering, basic graph signal processing\n\n');

fprintf('• 10,000 eigenvectors: Good for detailed spectral analysis\n');
fprintf('  - File size: ~%.1f GB per hemisphere\n', (base_size_mb + (N*10000*8)/(1024^2))/1024);
fprintf('  - Use cases: High-resolution spectral analysis, detailed filtering\n\n');

fprintf('• Full eigendecomposition: Rarely needed, computationally expensive\n');
fprintf('  - File size: ~%.1f GB per hemisphere\n', (base_size_mb + (N*N*8)/(1024^2))/1024);
fprintf('  - Memory requirement: ~%.1f GB RAM during computation\n', (N*N*8)/(1024^3));
fprintf('  - Computation time: Hours to days\n\n');

%% Both hemispheres
fprintf('4. Both hemispheres (LH + RH):\n');
fprintf('------------------------------\n');

for i = 2:4 % Skip no-eigen and show practical options
    k = strategies{i}.k;
    single_hemisphere_mb = base_size_mb + (k * 8)/(1024^2) + (N * k * 8)/(1024^2);
    both_hemispheres_gb = (single_hemisphere_mb * 2) / 1024;
    
    fprintf('%s:\n', strategies{i}.name);
    fprintf('  - Both hemispheres: %.2f GB\n', both_hemispheres_gb);
    
    if both_hemispheres_gb < 1
        fprintf('  - Storage: ✓ Manageable\n');
    elseif both_hemispheres_gb < 10
        fprintf('  - Storage: ✓ Reasonable\n');
    elseif both_hemispheres_gb < 50
        fprintf('  - Storage: ⚠️  Large but feasible\n');
    else
        fprintf('  - Storage: ❌ Very large\n');
    end
    fprintf('\n');
end

%% Comparison with multiresolution
fprintf('5. Comparison with multiresolution pyramid:\n');
fprintf('-------------------------------------------\n');

% Estimate multiresolution pyramid size (25 levels)
pyramid_total_mb = 0;
current_N = N;

fprintf('Estimated 25-level multiresolution pyramid:\n');
for level = 1:25
    level_N = max(10, round(current_N * 0.5^(level-1)));
    level_base_mb = (level_N * 3 * 8 + level_N * 6 * 8 * 2) / (1024^2);
    pyramid_total_mb = pyramid_total_mb + level_base_mb;
    
    if level <= 5 || level == 25
        fprintf('  Level %d: %d vertices, %.1f MB\n', level, level_N, level_base_mb);
    elseif level == 6
        fprintf('  ...\n');
    end
end

pyramid_total_gb = pyramid_total_mb / 1024;
fprintf('Total multiresolution pyramid: %.2f GB (both hemispheres: %.2f GB)\n\n', ...
    pyramid_total_gb, pyramid_total_gb * 2);

%% Final recommendations
fprintf('6. Final recommendations:\n');
fprintf('-------------------------\n');

fprintf('For typical brain network analysis:\n');
fprintf('✓ Start with 1,000-5,000 eigenvectors per hemisphere\n');
fprintf('✓ File size: ~1-4 GB total for both hemispheres\n');
fprintf('✓ Computation time: Minutes to hours\n');
fprintf('✓ Sufficient for most graph signal processing tasks\n\n');

fprintf('For detailed spectral analysis:\n');
fprintf('✓ Use 10,000 eigenvectors per hemisphere\n');
fprintf('✓ File size: ~%.1f GB total for both hemispheres\n', ...
    (base_size_mb + (N*10000*8)/(1024^2))*2/1024);
fprintf('✓ Computation time: Hours\n');
fprintf('✓ Covers high-frequency details\n\n');

fprintf('Avoid full eigendecomposition unless absolutely necessary:\n');
fprintf('❌ File size: ~%.0f GB per hemisphere\n', (N*N*8)/(1024^3));
fprintf('❌ Memory requirement: ~%.0f GB RAM\n', (N*N*8)/(1024^3));
fprintf('❌ Computation time: Days\n');