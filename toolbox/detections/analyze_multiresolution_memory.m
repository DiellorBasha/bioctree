% analyze_multiresolution_memory.m
% Analyze why graph multiresolution creates large memory footprint

fprintf('Analyzing Graph Multiresolution Memory Usage\n');
fprintf('============================================\n\n');

%% Load our graph data
try
    data = load('test-data/meshes/fsaverage/fsaverage_pial_gsp_graphs_complete.mat');
    G = data.G_lh;  % Use left hemisphere as example
    fprintf('✓ Loaded GSP graph: %d vertices, %d edges\n', G.N, G.Ne);
catch ME
    fprintf('✗ Error loading graph: %s\n', ME.message);
    return;
end

%% Calculate memory usage for original graph
fprintf('\n1. Original Graph Memory Analysis\n');
fprintf('---------------------------------\n');

% Calculate memory for key components
W_memory = numel(G.W) * 8; % Weight matrix (sparse, but let's estimate full)
W_sparse_memory = nnz(G.W) * 8 * 3; % Sparse: values + 2 index arrays
L_memory = numel(G.L) * 8; % Laplacian matrix
coords_memory = numel(G.coords) * 8; % Coordinates
faces_memory = numel(G.Faces) * 4; % Face indices (int32)

fprintf('Original graph components:\n');
fprintf('  - Weight matrix W (full): %.2f GB\n', W_memory / 1e9);
fprintf('  - Weight matrix W (sparse): %.2f MB\n', W_sparse_memory / 1e6);
fprintf('  - Laplacian matrix L: %.2f GB\n', L_memory / 1e9);
fprintf('  - Coordinates: %.2f MB\n', coords_memory / 1e6);
fprintf('  - Faces: %.2f MB\n', faces_memory / 1e6);

% Total for original graph (using sparse representation)
original_memory = W_sparse_memory + W_sparse_memory + coords_memory + faces_memory;
fprintf('  - Total original graph: %.2f MB\n', original_memory / 1e6);

%% Estimate multiresolution pyramid memory
fprintf('\n2. Multiresolution Pyramid Memory Estimation\n');
fprintf('--------------------------------------------\n');

num_levels = 25;
fprintf('Estimating memory for %d-level pyramid:\n\n', num_levels);

total_pyramid_memory = 0;
total_vertices = 0;

% Each level typically reduces vertices by ~factor of 2-4
reduction_factors = [1, 2, 3, 4]; % Different possible reduction rates
fprintf('Level-by-level analysis:\n');

for reduction_factor = reduction_factors
    fprintf('\nReduction factor %.1f (vertices reduced by %.1fx per level):\n', reduction_factor, reduction_factor);
    
    pyramid_memory = 0;
    pyramid_vertices = 0;
    
    for level = 1:num_levels
        % Calculate vertices at this level
        vertices_at_level = round(G.N / (reduction_factor^(level-1)));
        if vertices_at_level < 10
            vertices_at_level = 10; % Minimum pyramid size
        end
        
        % Estimate memory for this level
        % Each level needs: W, L, coordinates, coarsening operators
        W_level = vertices_at_level^2 * 8; % Full matrix estimate
        W_sparse_level = vertices_at_level * 6 * 8 * 3; % Sparse (avg degree ~6)
        coords_level = vertices_at_level * 3 * 8;
        
        % Coarsening operators (interpolation matrices)
        if level > 1
            prev_vertices = round(G.N / (reduction_factor^(level-2)));
            interpolation_memory = prev_vertices * vertices_at_level * 8;
        else
            interpolation_memory = 0;
        end
        
        level_memory = W_sparse_level + coords_level + interpolation_memory;
        pyramid_memory += level_memory;
        pyramid_vertices += vertices_at_level;
        
        if level <= 10 || level % 5 == 0 % Show first 10 levels and every 5th
            fprintf('  Level %2d: %8d vertices, %6.2f MB\n', level, vertices_at_level, level_memory/1e6);
        end
    end
    
    fprintf('  Total for pyramid: %.2f GB (%d total vertices across levels)\n', 
            pyramid_memory/1e9, pyramid_vertices);
end

%% Why multiresolution is memory-intensive
fprintf('\n3. Why Multiresolution Creates Large Memory Footprint\n');
fprintf('-----------------------------------------------------\n');

fprintf('The multiresolution pyramid is memory-intensive because:\n\n');

fprintf('1. MULTIPLE GRAPH COPIES:\n');
fprintf('   - Each level stores a complete graph structure\n');
fprintf('   - 25 levels = 25 different graphs in memory\n');
fprintf('   - Even coarser levels can be substantial\n\n');

fprintf('2. COARSENING OPERATORS:\n');
fprintf('   - Interpolation matrices between levels\n');
fprintf('   - Each matrix: (vertices_fine × vertices_coarse)\n');
fprintf('   - For our case: potentially 163K × 80K = 13 billion entries\n\n');

fprintf('3. FULL GRAPH STRUCTURES:\n');
fprintf('   - Each level needs: W, L, coordinates, topology\n');
fprintf('   - Adjacency matrices grow as O(N²) with vertices\n');
fprintf('   - Even at reduced resolution, matrices are large\n\n');

fprintf('4. INTERMEDIATE COMPUTATION DATA:\n');
fprintf('   - Temporary matrices during coarsening\n');
fprintf('   - Eigendecomposition data for some levels\n');
fprintf('   - Graph clustering and pooling operators\n\n');

%% Memory breakdown for our specific case
fprintf('4. Memory Breakdown for Our Brain Mesh\n');
fprintf('--------------------------------------\n');

fprintf('Original mesh: %d vertices (FreeSurfer fsaverage)\n', G.N);
fprintf('25-level pyramid estimated components:\n\n');

% Conservative estimate assuming average 50K vertices per level
avg_vertices_per_level = 50000;
num_matrices_per_level = 4; % W, L, interpolation, etc.
matrix_memory_per_level = avg_vertices_per_level^2 * 8; % Dense estimate

fprintf('Conservative estimate:\n');
fprintf('  - Average vertices per level: %d\n', avg_vertices_per_level);
fprintf('  - Matrix memory per level: %.2f GB\n', matrix_memory_per_level/1e9);
fprintf('  - Total for %d levels: %.2f GB\n', num_levels, num_levels * matrix_memory_per_level/1e9);

fprintf('\nOptimistic estimate (sparse matrices):\n');
sparse_factor = 0.001; % 0.1% sparsity
sparse_matrix_memory = matrix_memory_per_level * sparse_factor;
fprintf('  - Sparse matrix memory per level: %.2f MB\n', sparse_matrix_memory/1e6);
fprintf('  - Total for %d levels: %.2f GB\n', num_levels, num_levels * sparse_matrix_memory/1e9);

%% Recommendations
fprintf('\n5. Recommendations to Reduce Memory Usage\n');
fprintf('-----------------------------------------\n');

fprintf('To reduce memory footprint:\n\n');

fprintf('1. REDUCE NUMBER OF LEVELS:\n');
fprintf('   - Use 10-15 levels instead of 25\n');
fprintf('   - Each level reduction saves significant memory\n');
fprintf('   - 10 levels: ~40GB, 15 levels: ~60GB\n\n');

fprintf('2. INCREASE COARSENING RATE:\n');
fprintf('   - Use reduction factor of 4-8 instead of 2\n');
fprintf('   - Faster convergence to small graphs\n');
fprintf('   - Fewer intermediate levels\n\n');

fprintf('3. LAZY COMPUTATION:\n');
fprintf('   - Compute levels on-demand\n');
fprintf('   - Store only essential levels\n');
fprintf('   - Use disk-based storage for large levels\n\n');

fprintf('4. SPECIFIC LEVELS ONLY:\n');
fprintf('   - Compute only levels needed for analysis\n');
fprintf('   - Skip unnecessary intermediate levels\n');
fprintf('   - Focus on specific resolution ranges\n\n');

fprintf('5. ALTERNATIVE APPROACHES:\n');
fprintf('   - Graph wavelets (more memory efficient)\n');
fprintf('   - Spectral clustering instead of spatial coarsening\n');
fprintf('   - Patch-based analysis\n\n');

%% Practical example
fprintf('6. Practical Example for Our Use Case\n');
fprintf('-------------------------------------\n');

practical_levels = 12;
practical_reduction = 3;

fprintf('Recommended settings for brain mesh analysis:\n');
fprintf('  - Number of levels: %d\n', practical_levels);
fprintf('  - Reduction factor: %d\n', practical_reduction);

practical_memory = 0;
for level = 1:practical_levels
    vertices_level = round(G.N / (practical_reduction^(level-1)));
    if vertices_level < 100
        vertices_level = 100;
    end
    level_memory = vertices_level * 6 * 8 * 3; % Sparse matrix
    practical_memory += level_memory;
    
    if level <= 5
        fprintf('  Level %d: %d vertices\n', level, vertices_level);
    end
end

fprintf('  ...\n');
fprintf('  Estimated total memory: %.2f GB\n', practical_memory/1e9);

fprintf('\nThis provides good multiresolution analysis while keeping\n');
fprintf('memory usage manageable for most systems.\n');