% compute_gsp_multiresolution_pyramid.m
% Compute graph multiresolution pyramid for our FreeSurfer GSP graphs

fprintf('Computing GSP Graph Multiresolution Pyramid\n');
fprintf('===========================================\n\n');

%% Initialize system and load data
fprintf('1. Initializing system and loading data...\n');
fprintf('------------------------------------------\n');

try
    bioctree_start;
    fprintf('✓ Bioctree and GSPBOX initialized\n');
    
    % Load the GSP graphs
    data = load('test-data/meshes/fsaverage/fsaverage_pial_gsp_graphs_complete.mat');
    G_lh = data.G_lh;
    G_rh = data.G_rh;
    Gmesh_lh = data.Gmesh_lh;
    Gmesh_rh = data.Gmesh_rh;
    
    fprintf('✓ Loaded GSP graphs and surfaceMesh objects:\n');
    fprintf('  - LH: %d vertices, %d edges\n', G_lh.N, G_lh.Ne);
    fprintf('  - RH: %d vertices, %d edges\n', G_rh.N, G_rh.Ne);
    
catch ME
    fprintf('✗ Error during initialization: %s\n', ME.message);
    return;
end

%% Set up multiresolution parameters
fprintf('\n2. Setting up multiresolution parameters...\n');
fprintf('--------------------------------------------\n');

num_levels = 25;
fprintf('Target number of levels: %d\n', num_levels);

% Calculate expected sizes at each level
original_size = G_lh.N;
reduction_factor = 2; % Typical reduction factor per level
expected_sizes = zeros(num_levels, 1);
expected_sizes(1) = original_size;

for i = 2:num_levels
    expected_sizes(i) = max(10, round(expected_sizes(i-1) / reduction_factor));
end

fprintf('Expected graph sizes per level:\n');
fprintf('  Level  1: %d vertices (original)\n', expected_sizes(1));
fprintf('  Level  5: %d vertices\n', expected_sizes(5));
fprintf('  Level 10: %d vertices\n', expected_sizes(10));
fprintf('  Level 15: %d vertices\n', expected_sizes(15));
fprintf('  Level 20: %d vertices\n', expected_sizes(20));
fprintf('  Level 25: %d vertices (coarsest)\n', expected_sizes(end));

% Estimate memory requirements
total_vertices_all_levels = sum(expected_sizes);
memory_estimate_gb = (total_vertices_all_levels * original_size * 8) / 1e9; % For reduction operators
fprintf('\nEstimated memory for multiresolution: %.2f GB\n', memory_estimate_gb);

%% Compute LH multiresolution pyramid
fprintf('\n3. Computing LH multiresolution pyramid...\n');
fprintf('-------------------------------------------\n');

try
    clear data; % Free memory
    
    tic;
    fprintf('Starting LH multiresolution computation...\n');
    fprintf('This may take several minutes...\n');
    
    % Compute multiresolution pyramid
    [Gs_lh] = gsp_graph_multiresolution(G_lh, num_levels);
    
    lh_time = toc;
    
    fprintf('✓ LH multiresolution pyramid completed!\n');
    fprintf('  - Computation time: %.2f minutes\n', lh_time/60);
    fprintf('  - Number of levels created: %d\n', length(Gs_lh));
    
    % Display actual sizes at each level
    fprintf('  - Actual graph sizes per level:\n');
    for i = 1:min(length(Gs_lh), 10) % Show first 10 levels
        fprintf('    Level %2d: %6d vertices (%6d edges)\n', i, Gs_lh{i}.N, Gs_lh{i}.Ne);
    end
    if length(Gs_lh) > 10
        fprintf('    ...\n');
        for i = max(11, length(Gs_lh)-4):length(Gs_lh) % Show last few levels
            fprintf('    Level %2d: %6d vertices (%6d edges)\n', i, Gs_lh{i}.N, Gs_lh{i}.Ne);
        end
    end
    
    % Check reduction operators
    fprintf('  - Reduction operators:\n');
    total_operators = 0;
    for i = 1:length(Gs_lh)-1
        if isfield(Gs_lh{i}, 'mr') && isfield(Gs_lh{i}.mr, 'P')
            operator_size = nnz(Gs_lh{i}.mr.P);
            total_operators = total_operators + operator_size;
            if i <= 5 || i >= length(Gs_lh)-2
                fprintf('    Level %d->%d: %d nonzero entries\n', i, i+1, operator_size);
            end
        end
    end
    fprintf('    Total reduction operator entries: %d\n', total_operators);
    
    lh_success = true;
    
catch ME
    fprintf('✗ LH multiresolution computation failed: %s\n', ME.message);
    fprintf('Error details: %s\n', ME.message);
    if ~isempty(ME.stack)
        fprintf('At: %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
    end
    lh_success = false;
end

%% Save LH multiresolution pyramid
if lh_success
    fprintf('\n4. Saving LH multiresolution pyramid...\n');
    fprintf('---------------------------------------\n');
    
    try
        output_file = 'test-data/meshes/fsaverage/fsaverage_lh_pial_gsp_multiresolution.mat';
        
        % Save the multiresolution pyramid and original mesh
        save(output_file, 'Gs_lh', 'Gmesh_lh', 'num_levels', '-v7.3');
        
        file_info = dir(output_file);
        file_size_mb = file_info.bytes / (1024^2);
        
        fprintf('✓ Saved LH multiresolution pyramid: %s (%.1f MB)\n', output_file, file_size_mb);
        
        % Save summary info
        summary_lh = struct();
        summary_lh.num_levels = length(Gs_lh);
        summary_lh.computation_time_minutes = lh_time/60;
        summary_lh.original_vertices = G_lh.N;
        summary_lh.coarsest_vertices = Gs_lh{end}.N;
        summary_lh.total_reduction_operators = total_operators;
        
        % Create level summary
        level_summary = struct();
        for i = 1:length(Gs_lh)
            level_summary(i).level = i;
            level_summary(i).vertices = Gs_lh{i}.N;
            level_summary(i).edges = Gs_lh{i}.Ne;
            if i < length(Gs_lh) && isfield(Gs_lh{i}, 'mr') && isfield(Gs_lh{i}.mr, 'P')
                level_summary(i).reduction_operator_entries = nnz(Gs_lh{i}.mr.P);
            else
                level_summary(i).reduction_operator_entries = 0;
            end
        end
        summary_lh.levels = level_summary;
        
    catch ME
        fprintf('✗ Error saving LH results: %s\n', ME.message);
        lh_success = false;
    end
end

%% Compute RH multiresolution pyramid
if lh_success
    fprintf('\n5. Computing RH multiresolution pyramid...\n');
    fprintf('-------------------------------------------\n');
    
    try
        % Clear LH pyramid to free memory for RH computation
        clear Gs_lh G_lh;
        
        tic;
        fprintf('Starting RH multiresolution computation...\n');
        
        [Gs_rh] = gsp_graph_multiresolution(G_rh, num_levels);
        
        rh_time = toc;
        
        fprintf('✓ RH multiresolution pyramid completed!\n');
        fprintf('  - Computation time: %.2f minutes\n', rh_time/60);
        fprintf('  - Number of levels created: %d\n', length(Gs_rh));
        
        % Display sizes
        fprintf('  - Actual graph sizes per level:\n');
        for i = 1:min(length(Gs_rh), 5) % Show first 5 levels
            fprintf('    Level %2d: %6d vertices (%6d edges)\n', i, Gs_rh{i}.N, Gs_rh{i}.Ne);
        end
        if length(Gs_rh) > 5
            fprintf('    ...\n');
            fprintf('    Level %2d: %6d vertices (%6d edges)\n', length(Gs_rh), Gs_rh{end}.N, Gs_rh{end}.Ne);
        end
        
        rh_success = true;
        
    catch ME
        fprintf('✗ RH multiresolution computation failed: %s\n', ME.message);
        rh_success = false;
    end
else
    rh_success = false;
    fprintf('\n5. Skipping RH computation due to LH failure\n');
end

%% Save RH multiresolution pyramid
if rh_success
    fprintf('\n6. Saving RH multiresolution pyramid...\n');
    fprintf('---------------------------------------\n');
    
    try
        output_file = 'test-data/meshes/fsaverage/fsaverage_rh_pial_gsp_multiresolution.mat';
        save(output_file, 'Gs_rh', 'Gmesh_rh', 'num_levels', '-v7.3');
        
        file_info = dir(output_file);
        file_size_mb = file_info.bytes / (1024^2);
        
        fprintf('✓ Saved RH multiresolution pyramid: %s (%.1f MB)\n', output_file, file_size_mb);
        
        % Save RH summary
        summary_rh = struct();
        summary_rh.num_levels = length(Gs_rh);
        summary_rh.computation_time_minutes = rh_time/60;
        summary_rh.original_vertices = G_rh.N;
        summary_rh.coarsest_vertices = Gs_rh{end}.N;
        
    catch ME
        fprintf('✗ Error saving RH results: %s\n', ME.message);
        rh_success = false;
    end
end

%% Test multiresolution functionality
if lh_success
    fprintf('\n7. Testing multiresolution functionality...\n');
    fprintf('--------------------------------------------\n');
    
    try
        % Reload LH pyramid for testing
        if ~exist('Gs_lh', 'var')
            test_data = load('test-data/meshes/fsaverage/fsaverage_lh_pial_gsp_multiresolution.mat');
            Gs_lh = test_data.Gs_lh;
        end
        
        % Test signal on original graph
        original_signal = randn(Gs_lh{1}.N, 1);
        
        % Test multiresolution analysis
        fprintf('Testing multiresolution signal analysis:\n');
        
        % Project signal through pyramid levels
        pyramid_signals = cell(length(Gs_lh), 1);
        pyramid_signals{1} = original_signal;
        
        % Analyze signal at different resolutions
        tic;
        for level = 1:min(5, length(Gs_lh)-1) % Test first 5 levels
            if isfield(Gs_lh{level}, 'mr') && isfield(Gs_lh{level}.mr, 'P')
                % Project to next level
                pyramid_signals{level+1} = Gs_lh{level}.mr.P' * pyramid_signals{level};
                
                energy_ratio = norm(pyramid_signals{level+1})^2 / norm(pyramid_signals{level})^2;
                fprintf('  Level %d->%d: %d->%d vertices, energy ratio: %.4f\n', ...
                    level, level+1, Gs_lh{level}.N, Gs_lh{level+1}.N, energy_ratio);
            end
        end
        analysis_time = toc;
        
        fprintf('✓ Multiresolution analysis completed in %.4f seconds\n', analysis_time);
        
        % Test reconstruction
        if length(pyramid_signals) >= 3
            tic;
            % Reconstruct from level 3 back to original
            reconstructed = pyramid_signals{3};
            for level = 3:-1:2
                if isfield(Gs_lh{level-1}, 'mr') && isfield(Gs_lh{level-1}.mr, 'P')
                    reconstructed = Gs_lh{level-1}.mr.P * reconstructed;
                end
            end
            
            reconstruction_time = toc;
            reconstruction_error = norm(reconstructed - original_signal) / norm(original_signal);
            
            fprintf('✓ Reconstruction test:\n');
            fprintf('  - Reconstruction time: %.4f seconds\n', reconstruction_time);
            fprintf('  - Reconstruction error: %.2e\n', reconstruction_error);
        end
        
    catch ME
        fprintf('✗ Multiresolution functionality test failed: %s\n', ME.message);
    end
end

%% Create combined summary and save
fprintf('\n8. Creating multiresolution summary...\n');
fprintf('--------------------------------------\n');

summary = struct();
summary.computation_date = datestr(now);
summary.target_levels = num_levels;

if lh_success
    summary.lh = summary_lh;
    fprintf('✓ LH multiresolution: %d levels, coarsest %d vertices\n', ...
        summary_lh.num_levels, summary_lh.coarsest_vertices);
end

if rh_success
    summary.rh = summary_rh;
    fprintf('✓ RH multiresolution: %d levels, coarsest %d vertices\n', ...
        summary_rh.num_levels, summary_rh.coarsest_vertices);
end

try
    save('test-data/meshes/fsaverage/multiresolution_summary.mat', 'summary', '-v7.3');
    fprintf('✓ Saved multiresolution summary\n');
catch ME
    fprintf('✗ Error saving summary: %s\n', ME.message);
end

%% Final results
fprintf('\n===========================================\n');
if lh_success && rh_success
    total_time = (summary_lh.computation_time_minutes + summary_rh.computation_time_minutes);
    fprintf('✓ Multiresolution pyramids completed for both hemispheres!\n');
    fprintf('Total computation time: %.2f minutes\n', total_time);
    fprintf('Files created:\n');
    fprintf('  - fsaverage_lh_pial_gsp_multiresolution.mat\n');
    fprintf('  - fsaverage_rh_pial_gsp_multiresolution.mat\n');
elseif lh_success
    fprintf('✓ Multiresolution pyramid completed for LH only\n');
    fprintf('✗ RH computation failed\n');
else
    fprintf('✗ Multiresolution computation failed\n');
end
fprintf('===========================================\n\n');

if lh_success || rh_success
    fprintf('Usage examples:\n');
    fprintf('  %% Load multiresolution pyramid\n');
    fprintf('  data = load(''test-data/meshes/fsaverage/fsaverage_lh_pial_gsp_multiresolution.mat'');\n');
    fprintf('  Gs = data.Gs_lh;  %% Cell array of graphs at different resolutions\n');
    fprintf('  \n');
    fprintf('  %% Access different resolution levels\n');
    fprintf('  G_original = Gs{1};     %% Original full resolution\n');
    fprintf('  G_coarse = Gs{end};     %% Coarsest resolution\n');
    fprintf('  G_mid = Gs{10};         %% Mid-level resolution\n');
    fprintf('  \n');
    fprintf('  %% Multiresolution signal analysis\n');
    fprintf('  signal = randn(G_original.N, 1);\n');
    fprintf('  coarse_signal = Gs{1}.mr.P'' * signal;  %% Project to coarser level\n');
    fprintf('  reconstructed = Gs{1}.mr.P * coarse_signal;  %% Reconstruct\n');
    fprintf('  \n');
    fprintf('  %% Visualization at different scales\n');
    fprintf('  gsp_plot_signal(Gs{1}, signal);    %% Full resolution\n');
    fprintf('  gsp_plot_signal(Gs{5}, coarse_signal); %% Coarser resolution\n');
    fprintf('  \n');
    fprintf('  %% Multiresolution filtering and wavelets\n');
    fprintf('  %% (Enables efficient multiscale analysis)\n');
end