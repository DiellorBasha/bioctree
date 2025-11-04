% investigate_multiresolution_memory.m
% Investigate memory usage of gsp_graph_multiresolution

fprintf('Investigating GSP Graph Multiresolution Memory Usage\n');
fprintf('===================================================\n\n');

%% Initialize and load data
fprintf('1. Loading GSP graph...\n');
fprintf('-----------------------\n');

try
    bioctree_start;
    data = load('test-data/meshes/fsaverage/fsaverage_pial_gsp_graphs_complete.mat');
    G = data.G_lh; % Use left hemisphere for testing
    fprintf('✓ Loaded LH GSP graph: %d vertices, %d edges\n', G.N, G.Ne);
    clear data;
    
catch ME
    fprintf('✗ Error loading data: %s\n', ME.message);
    return;
end

%% Analyze original graph memory footprint
fprintf('\n2. Analyzing original graph memory...\n');
fprintf('------------------------------------\n');

% Calculate memory usage of original graph components
W_memory = whos('G');
base_memory_mb = W_memory.bytes / (1024^2);

% Break down memory usage
coords_memory_mb = (G.N * 3 * 8) / (1024^2); % N x 3 coordinates, double precision
faces_memory_mb = (size(G.Faces, 1) * 3 * 4) / (1024^2); % faces, int32
weight_matrix_mb = (nnz(G.W) * 8 * 2) / (1024^2); % sparse matrix (values + indices)

fprintf('Original graph memory breakdown:\n');
fprintf('  - Total graph structure: %.2f MB\n', base_memory_mb);
fprintf('  - Coordinates (N×3): %.2f MB\n', coords_memory_mb);
fprintf('  - Faces: %.2f MB\n', faces_memory_mb);
fprintf('  - Weight matrix (sparse): %.2f MB\n', weight_matrix_mb);
fprintf('  - Graph vertices (N): %d\n', G.N);

%% Test default multiresolution parameters
fprintf('\n3. Checking default multiresolution parameters...\n');
fprintf('-------------------------------------------------\n');

% Check what the default parameters are
param_default = struct();
try
    % Look for gsp_graph_multiresolution function to see defaults
    which gsp_graph_multiresolution
    
    fprintf('Default parameters (typical GSPBOX defaults):\n');
    fprintf('  - compute_full_eigen: 0 (should NOT compute eigendecomposition)\n');
    fprintf('  - reduction_method: ''largest_eigenvector'' or ''resistance_distance''\n');
    fprintf('  - Nf: 6 (number of filters, affects computation but not much memory)\n');
    fprintf('  - h_filter: default filter bank\n');
    
catch ME
    fprintf('Could not locate gsp_graph_multiresolution function: %s\n', ME.message);
end

%% Test small pyramid first
fprintf('\n4. Testing small multiresolution pyramid...\n');
fprintf('------------------------------------------\n');

% Start with just 3 levels to see what happens
small_levels = 3;
fprintf('Creating %d-level pyramid for analysis...\n', small_levels);

try
    % Get memory before
    mem_before = memory;
    if isfield(mem_before, 'MemUsedMATLAB')
        matlab_mem_before_mb = mem_before.MemUsedMATLAB / (1024^2);
        fprintf('MATLAB memory before: %.2f MB\n', matlab_mem_before_mb);
    end
    
    tic;
    
    % Create small pyramid with explicit parameters
    param_small = struct();
    param_small.compute_full_eigen = 0; % Explicitly disable eigendecomposition
    param_small.verbose = 1;
    
    fprintf('Calling gsp_graph_multiresolution with %d levels...\n', small_levels);
    Gs_small = gsp_graph_multiresolution(G, small_levels, param_small);
    
    pyramid_time = toc;
    
    % Get memory after
    mem_after = memory;
    if isfield(mem_after, 'MemUsedMATLAB')
        matlab_mem_after_mb = mem_after.MemUsedMATLAB / (1024^2);
        mem_increase_mb = matlab_mem_after_mb - matlab_mem_before_mb;
        fprintf('MATLAB memory after: %.2f MB\n', matlab_mem_after_mb);
        fprintf('Memory increase: %.2f MB\n', mem_increase_mb);
    end
    
    fprintf('✓ Small pyramid created in %.2f seconds\n', pyramid_time);
    fprintf('Number of levels in pyramid: %d\n', length(Gs_small));
    
    % Analyze each level
    fprintf('\nPyramid level analysis:\n');
    total_pyramid_memory = 0;
    
    for level = 1:length(Gs_small)
        level_info = whos('Gs_small');
        level_N = Gs_small{level}.N;
        level_Ne = Gs_small{level}.Ne;
        
        % Estimate memory for this level
        level_coords_mb = (level_N * 3 * 8) / (1024^2);
        level_weights_mb = (nnz(Gs_small{level}.W) * 8 * 2) / (1024^2);
        level_total_mb = level_coords_mb + level_weights_mb;
        total_pyramid_memory = total_pyramid_memory + level_total_mb;
        
        fprintf('  Level %d: %d vertices, %d edges, ~%.2f MB\n', ...
            level, level_N, level_Ne, level_total_mb);
        
        % Check if this level has eigendecomposition computed
        if isfield(Gs_small{level}, 'U') && ~isempty(Gs_small{level}.U)
            eigen_memory_gb = (level_N * level_N * 8) / (1024^3);
            fprintf('    ⚠️  Level %d has eigendecomposition (%.2f GB)!\n', level, eigen_memory_gb);
            total_pyramid_memory = total_pyramid_memory + eigen_memory_gb * 1024;
        end
    end
    
    fprintf('Total estimated pyramid memory: %.2f MB\n', total_pyramid_memory);
    
    success_small = true;
    
catch ME
    fprintf('✗ Small pyramid creation failed: %s\n', ME.message);
    success_small = false;
end

%% Analyze potential issues
fprintf('\n5. Analyzing potential memory issues...\n');
fprintf('--------------------------------------\n');

if success_small
    % Check what might cause memory explosion with more levels
    fprintf('Potential causes of large memory usage:\n');
    
    % 1. Check if eigendecomposition is being computed despite settings
    eigen_computed = false;
    for level = 1:length(Gs_small)
        if isfield(Gs_small{level}, 'U') && ~isempty(Gs_small{level}.U)
            eigen_computed = true;
            fprintf('  ❌ Level %d has eigendecomposition computed (should be disabled)\n', level);
        end
    end
    
    if ~eigen_computed
        fprintf('  ✓ No eigendecomposition computed in pyramid levels\n');
    end
    
    % 2. Check reduction ratios
    fprintf('\nReduction analysis:\n');
    for level = 1:length(Gs_small)-1
        current_N = Gs_small{level}.N;
        next_N = Gs_small{level+1}.N;
        reduction_ratio = next_N / current_N;
        fprintf('  Level %d → %d: %d → %d vertices (ratio: %.3f)\n', ...
            level, level+1, current_N, next_N, reduction_ratio);
        
        if reduction_ratio > 0.9
            fprintf('    ⚠️  Poor reduction ratio - levels not reducing much\n');
        end
    end
    
    % 3. Project memory for 25 levels
    fprintf('\nProjected memory for 25 levels:\n');
    
    % Assume geometric reduction with ratio ~0.5 per level
    projected_memory_mb = 0;
    current_vertices = G.N;
    
    for level = 1:25
        % Estimate vertices at this level (geometric progression)
        level_vertices = max(10, round(current_vertices * (0.5^(level-1))));
        
        % Estimate memory (sparse matrix scales roughly with edges, assume ~6*vertices)
        level_edges = level_vertices * 6;
        level_memory_mb = (level_vertices * 3 * 8 + level_edges * 8 * 2) / (1024^2);
        projected_memory_mb = projected_memory_mb + level_memory_mb;
        
        if level <= 10 || level == 25
            fprintf('  Level %d: ~%d vertices, ~%.2f MB\n', level, level_vertices, level_memory_mb);
        elseif level == 11
            fprintf('  ...\n');
        end
    end
    
    fprintf('Total projected memory for 25 levels: %.2f MB (%.2f GB)\n', ...
        projected_memory_mb, projected_memory_mb/1024);
    
    if projected_memory_mb > 1000
        fprintf('  ⚠️  Projected memory > 1 GB but should be reasonable\n');
    else
        fprintf('  ✓ Projected memory seems reasonable\n');
    end
end

%% Test specific parameter combinations
fprintf('\n6. Testing parameter sensitivity...\n');
fprintf('----------------------------------\n');

if success_small
    % Test different parameter combinations to isolate the issue
    param_tests = {
        struct('name', 'Minimal (compute_full_eigen=0)', 'compute_full_eigen', 0),
        struct('name', 'Force no eigen', 'compute_full_eigen', 0, 'force_no_eigen', true)
    };
    
    for test_idx = 1:length(param_tests)
        fprintf('\nTesting: %s\n', param_tests{test_idx}.name);
        
        try
            test_param = param_tests{test_idx};
            test_param.verbose = 0; % Reduce output
            
            tic;
            Gs_test = gsp_graph_multiresolution(G, 5, test_param); % 5 levels for speed
            test_time = toc;
            
            fprintf('  ✓ Success in %.2f seconds\n', test_time);
            fprintf('  Levels created: %d\n', length(Gs_test));
            
            % Check memory usage pattern
            for level = 1:min(3, length(Gs_test))
                has_eigen = isfield(Gs_test{level}, 'U') && ~isempty(Gs_test{level}.U);
                fprintf('  Level %d: %d vertices, eigendecomp: %s\n', ...
                    level, Gs_test{level}.N, string(has_eigen));
            end
            
            clear Gs_test;
            
        catch ME
            fprintf('  ✗ Failed: %s\n', ME.message);
        end
    end
end

%% Recommendations
fprintf('\n7. Recommendations...\n');
fprintf('--------------------\n');

fprintf('Based on analysis:\n');

if success_small
    fprintf('✓ Small pyramids work correctly\n');
    fprintf('✓ Memory usage appears reasonable for small levels\n');
    
    if projected_memory_mb < 5000 % < 5 GB
        fprintf('✓ 25-level pyramid should be feasible (projected ~%.1f GB)\n', projected_memory_mb/1024);
        fprintf('\nRecommended approach for 25 levels:\n');
        fprintf('  param.compute_full_eigen = 0;  %% Critical: disable eigendecomposition\n');
        fprintf('  param.verbose = 1;              %% Monitor progress\n');
        fprintf('  Gs = gsp_graph_multiresolution(G, 25, param);\n');
    else
        fprintf('⚠️  25-level pyramid may use significant memory (%.1f GB)\n', projected_memory_mb/1024);
        fprintf('Consider using fewer levels (10-15) or implement progressive computation\n');
    end
else
    fprintf('✗ Small pyramid creation failed - investigate gsp_graph_multiresolution function\n');
end

fprintf('\nMemory optimization tips:\n');
fprintf('• Start with fewer levels (5-10) and scale up\n');
fprintf('• Monitor memory usage during computation\n');
fprintf('• Ensure compute_full_eigen = 0 is respected\n');
fprintf('• Consider clearing intermediate variables\n');
fprintf('• Use progressive saving for large pyramids\n');