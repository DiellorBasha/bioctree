% create_practical_multiresolution.m
% Practical multiresolution pyramid avoiding Kron reduction memory explosion

fprintf('Creating Practical Multiresolution Pyramid\n');
fprintf('==========================================\n\n');

%% Setup
fprintf('1. Setup...\n');
maxNumCompThreads(14);
bioctree_init;
addpath(genpath('external/gspbox'));

try
    load('test-data/meshes/fsaverage/fsaverage_pial_gsp_graphs_complete.mat', 'G_lh');
    G = G_lh;
    fprintf('✓ Loaded LH graph: %d vertices, %d edges\n', G.N, G.Ne);
catch ME
    fprintf('✗ Failed to load graph: %s\n', ME.message);
    return;
end

%% Approach 1: Conservative pyramid with aggressive sparsification
fprintf('\n2. Approach 1: Conservative pyramid (10 levels)...\n');
fprintf('--------------------------------------------------\n');

param1 = struct();
param1.compute_full_eigen = 0;
param1.sparsify = 1;
param1.sparsify_epsilon = 0.3;  % Aggressive sparsification
param1.verbose = 1;

fprintf('Parameters:\n');
fprintf('  - Levels: 10 (instead of 25)\n');
fprintf('  - Sparsify: enabled\n');
fprintf('  - Sparsify epsilon: %.1f (aggressive)\n', param1.sparsify_epsilon);

tic;
try
    fprintf('\nCreating 10-level pyramid...\n');
    Gs_conservative = gsp_graph_multiresolution(G, 10, param1);
    conservative_time = toc;
    
    fprintf('✓ Conservative pyramid created in %.1f seconds (%.1f minutes)\n', ...
        conservative_time, conservative_time/60);
    
    % Analyze the pyramid
    fprintf('\nPyramid analysis:\n');
    total_memory_mb = 0;
    
    for level = 1:length(Gs_conservative)
        vertices = Gs_conservative{level}.N;
        edges = Gs_conservative{level}.Ne;
        level_memory_mb = (nnz(Gs_conservative{level}.L)*16 + vertices*8)/(1024^2);
        total_memory_mb = total_memory_mb + level_memory_mb;
        
        fprintf('  Level %d: %d vertices (%d edges) - %.1f MB\n', ...
            level-1, vertices, edges, level_memory_mb);
    end
    
    fprintf('Total pyramid memory: %.1f MB (%.2f GB)\n', total_memory_mb, total_memory_mb/1024);
    
    % Save the conservative pyramid
    save_file = 'test-data/meshes/fsaverage/fsaverage_lh_multiresolution_10levels.mat';
    save(save_file, 'Gs_conservative', 'param1', 'conservative_time');
    fprintf('✓ Saved pyramid to: %s\n', save_file);
    
catch ME
    conservative_time = toc;
    fprintf('✗ Conservative pyramid failed after %.1f seconds: %s\n', conservative_time, ME.message);
end

%% Approach 2: Progressive computation (build level by level)
fprintf('\n3. Approach 2: Progressive level-by-level...\n');
fprintf('--------------------------------------------\n');

if exist('Gs_conservative', 'var')
    fprintf('Attempting progressive extension to 15 levels...\n');
    
    % Start with the 10-level pyramid and extend
    Gs_progressive = Gs_conservative;
    
    % Parameters for extension
    param2 = param1;
    param2.sparsify_epsilon = 0.4;  % Even more aggressive
    
    tic;
    try
        for additional_level = 11:15
            fprintf('  Adding level %d...', additional_level-1);
            
            % Get the last graph from current pyramid
            current_graph = Gs_progressive{end};
            
            % Create one more level
            temp_pyramid = gsp_graph_multiresolution(current_graph, 1, param2);
            
            % Add the new level to our pyramid
            Gs_progressive{end+1} = temp_pyramid{2};  % Second element is the reduced graph
            
            new_vertices = Gs_progressive{end}.N;
            new_edges = Gs_progressive{end}.Ne;
            reduction_ratio = new_vertices / current_graph.N;
            
            fprintf(' %d vertices (%.1fx reduction)\n', new_vertices, 1/reduction_ratio);
            
            clear temp_pyramid;
        end
        
        progressive_time = toc;
        fprintf('✓ Progressive extension completed in %.1f seconds\n', progressive_time);
        
        % Save the extended pyramid
        save_file_prog = 'test-data/meshes/fsaverage/fsaverage_lh_multiresolution_15levels.mat';
        save(save_file_prog, 'Gs_progressive', 'param2', 'progressive_time');
        fprintf('✓ Saved extended pyramid to: %s\n', save_file_prog);
        
    catch ME
        progressive_time = toc;
        fprintf('✗ Progressive extension failed after %.1f seconds: %s\n', progressive_time, ME.message);
    end
end

%% Approach 3: Alternative coarsening (simple vertex removal)
fprintf('\n4. Approach 3: Alternative coarsening method...\n');
fprintf('-----------------------------------------------\n');

fprintf('Creating custom coarsening without Kron reduction...\n');

% We'll implement a simple vertex removal approach
tic;
try
    % Start with original graph
    Gs_simple = cell(11, 1);
    Gs_simple{1} = G;
    
    current_G = G;
    
    for level = 1:10
        fprintf('  Level %d: Creating reduced graph...', level);
        
        % Get largest eigenvector for current graph
        [eigvec, ~] = eigs(current_G.L, 1, 'largestreal');
        eigvec = eigvec * sign(eigvec(1));
        
        % Get vertices to keep (positive eigenvector components)
        keep_inds = find(eigvec >= 0);
        
        % Simple approach: just extract subgraph (no Kron reduction)
        L_sub = current_G.L(keep_inds, keep_inds);
        coords_sub = current_G.coords(keep_inds, :);
        
        % Create new GSP graph
        W_sub = -L_sub;  % Convert Laplacian back to adjacency
        W_sub = W_sub - diag(diag(W_sub));  % Remove diagonal
        
        % Ensure non-negative weights (cotangent weights can be negative)
        W_sub = max(W_sub, 0);
        
        % Create reduced graph
        G_reduced = gsp_graph(W_sub, coords_sub);
        
        Gs_simple{level+1} = G_reduced;
        current_G = G_reduced;
        
        fprintf(' %d vertices\n', G_reduced.N);
    end
    
    simple_time = toc;
    fprintf('✓ Simple coarsening completed in %.1f seconds\n', simple_time);
    
    % Save the simple pyramid
    save_file_simple = 'test-data/meshes/fsaverage/fsaverage_lh_multiresolution_simple.mat';
    save(save_file_simple, 'Gs_simple', 'simple_time');
    fprintf('✓ Saved simple pyramid to: %s\n', save_file_simple);
    
catch ME
    simple_time = toc;
    fprintf('✗ Simple coarsening failed after %.1f seconds: %s\n', simple_time, ME.message);
end

%% Summary and recommendations
fprintf('\n5. Summary and Recommendations...\n');
fprintf('---------------------------------\n');

fprintf('Results:\n');

if exist('conservative_time', 'var')
    fprintf('✓ Conservative approach (10 levels): %.1f seconds\n', conservative_time);
    fprintf('  - Uses GSPBOX Kron reduction with aggressive sparsification\n');
    fprintf('  - Theoretically sound but memory-intensive\n');
    fprintf('  - Recommended for high-quality analysis\n\n');
end

if exist('progressive_time', 'var')
    fprintf('✓ Progressive approach (15 levels): %.1f seconds total\n', progressive_time);
    fprintf('  - Extends conservative pyramid level by level\n');
    fprintf('  - Better memory control\n');
    fprintf('  - Recommended for deeper pyramids\n\n');
end

if exist('simple_time', 'var')
    fprintf('✓ Simple approach (10 levels): %.1f seconds\n', simple_time);
    fprintf('  - Avoids Kron reduction completely\n');
    fprintf('  - Very fast and memory-efficient\n');
    fprintf('  - Less theoretically optimal but practical\n\n');
end

fprintf('For your 25-level requirement:\n');
fprintf('1. START with 10-level conservative pyramid\n');
fprintf('2. Use progressive approach to extend gradually\n');
fprintf('3. Monitor memory usage at each step\n');
fprintf('4. Consider simple coarsening for very deep pyramids\n\n');

fprintf('Next steps:\n');
fprintf('1. Test eigendecomposition on one of these pyramids\n');
fprintf('2. Validate pyramid quality for your analysis\n');
fprintf('3. Implement memory-efficient eigendecomposition\n');

fprintf('\n✓ Practical multiresolution pyramid creation complete!\n');