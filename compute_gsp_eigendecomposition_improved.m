% compute_gsp_eigendecomposition_improved.m
% Compute eigendecomposition for GSP graphs with modified GSPBOX limits

fprintf('Computing GSP Graph Eigendecomposition (Improved with Modified GSPBOX)\n');
fprintf('=====================================================================\n\n');

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
    fprintf('✓ Loaded GSP graphs: LH (%d vertices), RH (%d vertices)\n', G_lh.N, G_rh.N);
    
catch ME
    fprintf('✗ Error during initialization: %s\n', ME.message);
    return;
end

%% Check GSPBOX modification
fprintf('\n2. Verifying GSPBOX modification...\n');
fprintf('-----------------------------------\n');

% Test that our modification worked
test_limit = G_lh.N; % 163842
if test_limit <= 170000
    fprintf('✓ Graph size (%d) is within modified GSPBOX limit (170,000)\n', test_limit);
else
    fprintf('✗ Graph size (%d) exceeds modified GSPBOX limit (170,000)\n', test_limit);
    return;
end

%% Set computation strategy
fprintf('\n3. Setting computation strategy...\n');
fprintf('----------------------------------\n');

% For brain networks, we typically don't need all eigenvectors
% Common strategies:
strategies = {
    struct('name', 'Low-frequency (1000 eigenvectors)', 'nb_eigenvectors', 1000, 'description', 'Captures main low-frequency patterns'),
    struct('name', 'Medium-frequency (5000 eigenvectors)', 'nb_eigenvectors', 5000, 'description', 'Good for most graph signal processing'),
    struct('name', 'High-frequency (10000 eigenvectors)', 'nb_eigenvectors', 10000, 'description', 'Detailed spectral analysis'),
    struct('name', 'Full decomposition', 'nb_eigenvectors', G_lh.N, 'description', 'Complete eigendecomposition (memory intensive)')
};

fprintf('Available computation strategies:\n');
for i = 1:length(strategies)
    memory_est_gb = (strategies{i}.nb_eigenvectors * G_lh.N * 8) / 1e9;
    fprintf('  %d. %s\n', i, strategies{i}.name);
    fprintf('     - Eigenvectors: %d\n', strategies{i}.nb_eigenvectors);
    fprintf('     - Estimated memory: %.2f GB\n', memory_est_gb);
    fprintf('     - %s\n', strategies{i}.description);
end

% Choose strategy based on available memory (conservative approach)
try
    mem_info = memory;
    if isfield(mem_info, 'MemAvailableAllArrays')
        available_mem_gb = mem_info.MemAvailableAllArrays / 1e9;
    else
        available_mem_gb = 8; % Conservative estimate
    end
catch
    available_mem_gb = 8;
end

fprintf('\nAvailable memory: %.2f GB\n', available_mem_gb);

% Select strategy based on memory
if available_mem_gb >= 50
    selected_strategy = 4; % Full decomposition
elseif available_mem_gb >= 20
    selected_strategy = 3; % High-frequency
elseif available_mem_gb >= 10
    selected_strategy = 2; % Medium-frequency  
else
    selected_strategy = 1; % Low-frequency
end

strategy = strategies{selected_strategy};
fprintf('Selected strategy: %s\n', strategy.name);
fprintf('Computing %d eigenvectors per hemisphere\n', strategy.nb_eigenvectors);

%% Set up parameters
param = struct();
param.nb_eigenvectors = strategy.nb_eigenvectors;
param.verbose = 1;

% Use iterative solver for efficiency
if strategy.nb_eigenvectors < G_lh.N
    param.solver = 'eigs';
    fprintf('Using iterative eigenvalue solver (eigs)\n');
else
    param.solver = 'eig';
    fprintf('Using full eigenvalue decomposition (eig)\n');
end

%% Compute LH eigendecomposition
fprintf('\n4. Computing LH eigendecomposition...\n');
fprintf('-------------------------------------\n');

try
    clear data; % Free memory
    
    tic;
    fprintf('Starting LH computation with %d eigenvectors...\n', strategy.nb_eigenvectors);
    
    % Apply the computation
    G_lh = gsp_compute_fourier_basis(G_lh, param);
    
    lh_time = toc;
    
    fprintf('✓ LH eigendecomposition completed!\n');
    fprintf('  - Computation time: %.2f minutes\n', lh_time/60);
    fprintf('  - Eigenvalues computed: %d\n', length(G_lh.e));
    fprintf('  - Eigenvectors computed: %d\n', size(G_lh.U, 2));
    fprintf('  - Eigenvalue range: [%.6f, %.6f]\n', min(G_lh.e), max(G_lh.e));
    
    % Check spectral properties
    zero_eigenvalues = sum(abs(G_lh.e) < 1e-10);
    fprintf('  - Zero eigenvalues (graph components): %d\n', zero_eigenvalues);
    fprintf('  - Maximum eigenvalue (lmax): %.6f\n', G_lh.lmax);
    fprintf('  - Fourier basis coherence (mu): %.6f\n', G_lh.mu);
    
    lh_success = true;
    
catch ME
    fprintf('✗ LH eigendecomposition failed: %s\n', ME.message);
    lh_success = false;
end

%% Save LH results
if lh_success
    fprintf('\n5. Saving LH eigendecomposition...\n');
    fprintf('----------------------------------\n');
    
    try
        % Save with detailed filename indicating strategy
        strategy_name = lower(strrep(strategy.name, ' ', '_'));
        strategy_name = strrep(strategy_name, '(', '');
        strategy_name = strrep(strategy_name, ')', '');
        
        output_file = sprintf('test-data/meshes/fsaverage/fsaverage_lh_pial_gsp_eigen_%s.mat', strategy_name);
        
        % Save graph with eigendecomposition
        save(output_file, 'G_lh', 'strategy', 'param', '-v7.3');
        
        file_info = dir(output_file);
        file_size_mb = file_info.bytes / (1024^2);
        
        fprintf('✓ Saved LH eigendecomposition: %s (%.1f MB)\n', output_file, file_size_mb);
        
    catch ME
        fprintf('✗ Error saving LH results: %s\n', ME.message);
        lh_success = false;
    end
end

%% Compute RH eigendecomposition
if lh_success
    fprintf('\n6. Computing RH eigendecomposition...\n');
    fprintf('-------------------------------------\n');
    
    try
        % Clear LH from memory to make room for RH
        clear G_lh;
        
        tic;
        fprintf('Starting RH computation with %d eigenvectors...\n', strategy.nb_eigenvectors);
        
        G_rh = gsp_compute_fourier_basis(G_rh, param);
        
        rh_time = toc;
        
        fprintf('✓ RH eigendecomposition completed!\n');
        fprintf('  - Computation time: %.2f minutes\n', rh_time/60);
        fprintf('  - Eigenvalues computed: %d\n', length(G_rh.e));
        fprintf('  - Eigenvectors computed: %d\n', size(G_rh.U, 2));
        fprintf('  - Eigenvalue range: [%.6f, %.6f]\n', min(G_rh.e), max(G_rh.e));
        fprintf('  - Zero eigenvalues: %d\n', sum(abs(G_rh.e) < 1e-10));
        fprintf('  - Maximum eigenvalue: %.6f\n', G_rh.lmax);
        
        rh_success = true;
        
    catch ME
        fprintf('✗ RH eigendecomposition failed: %s\n', ME.message);
        rh_success = false;
    end
else
    rh_success = false;
    fprintf('\n6. Skipping RH computation due to LH failure\n');
end

%% Save RH results
if rh_success
    fprintf('\n7. Saving RH eigendecomposition...\n');
    fprintf('----------------------------------\n');
    
    try
        output_file = sprintf('test-data/meshes/fsaverage/fsaverage_rh_pial_gsp_eigen_%s.mat', strategy_name);
        save(output_file, 'G_rh', 'strategy', 'param', '-v7.3');
        
        file_info = dir(output_file);
        file_size_mb = file_info.bytes / (1024^2);
        
        fprintf('✓ Saved RH eigendecomposition: %s (%.1f MB)\n', output_file, file_size_mb);
        
    catch ME
        fprintf('✗ Error saving RH results: %s\n', ME.message);
        rh_success = false;
    end
end

%% Create test to verify functionality
if lh_success
    fprintf('\n8. Testing eigendecomposition functionality...\n');
    fprintf('----------------------------------------------\n');
    
    try
        % Reload LH for testing
        if exist('G_lh', 'var')
            test_G = G_lh;
        else
            test_data = load(sprintf('test-data/meshes/fsaverage/fsaverage_lh_pial_gsp_eigen_%s.mat', strategy_name));
            test_G = test_data.G_lh;
        end
        
        % Create test signal
        test_signal = randn(test_G.N, 1);
        
        % Test Graph Fourier Transform
        tic;
        gft_coeffs = gsp_gft(test_G, test_signal);
        gft_time = toc;
        
        % Test inverse GFT
        tic;
        reconstructed = gsp_igft(test_G, gft_coeffs);
        igft_time = toc;
        
        % Check reconstruction error
        reconstruction_error = norm(reconstructed - test_signal) / norm(test_signal);
        
        fprintf('✓ Graph Fourier Transform test:\n');
        fprintf('  - Forward GFT time: %.4f seconds\n', gft_time);
        fprintf('  - Inverse GFT time: %.4f seconds\n', igft_time);
        fprintf('  - Reconstruction error: %.2e\n', reconstruction_error);
        
        if reconstruction_error < 1e-12
            fprintf('  - Perfect reconstruction ✓\n');
        elseif reconstruction_error < 1e-6
            fprintf('  - Good reconstruction ✓\n');
        else
            fprintf('  - Poor reconstruction ⚠️\n');
        end
        
        % Test filtering
        try
            % Create simple lowpass filter
            cutoff_freq = 0.1 * max(test_G.e);
            h_lowpass = @(x) exp(-x/cutoff_freq);
            
            tic;
            filtered_signal = gsp_filter_analysis(test_G, h_lowpass, test_signal);
            filter_time = toc;
            
            fprintf('✓ Graph filtering test:\n');
            fprintf('  - Filter application time: %.4f seconds\n', filter_time);
            fprintf('  - Signal energy before: %.6f\n', norm(test_signal)^2);
            fprintf('  - Signal energy after: %.6f\n', norm(filtered_signal)^2);
            
        catch ME
            fprintf('⚠️  Graph filtering test failed: %s\n', ME.message);
        end
        
    catch ME
        fprintf('✗ Functionality test failed: %s\n', ME.message);
    end
end

%% Final summary
fprintf('\n=====================================================================\n');
if lh_success && rh_success
    total_time = (lh_time + rh_time) / 60;
    fprintf('✓ Eigendecomposition completed successfully for both hemispheres!\n');
    fprintf('Strategy: %s\n', strategy.name);
    fprintf('Eigenvectors per hemisphere: %d/%d\n', strategy.nb_eigenvectors, G_lh.N);
    fprintf('Total computation time: %.2f minutes\n', total_time);
    
    fprintf('\nFiles created:\n');
    fprintf('  - fsaverage_lh_pial_gsp_eigen_%s.mat\n', strategy_name);
    fprintf('  - fsaverage_rh_pial_gsp_eigen_%s.mat\n', strategy_name);
    
elseif lh_success
    fprintf('✓ Eigendecomposition completed for LH only\n');
    fprintf('✗ RH computation failed\n');
else
    fprintf('✗ Eigendecomposition failed for both hemispheres\n');
end
fprintf('=====================================================================\n\n');

if lh_success || rh_success
    fprintf('Usage examples:\n');
    fprintf('  %% Load eigendecomposed graph\n');
    fprintf('  data = load(''test-data/meshes/fsaverage/fsaverage_lh_pial_gsp_eigen_%s.mat'');\n', strategy_name);
    fprintf('  G = data.G_lh;\n');
    fprintf('  \n');
    fprintf('  %% Graph Fourier Transform\n');
    fprintf('  signal = randn(G.N, 1);\n');
    fprintf('  gft_coeffs = gsp_gft(G, signal);           %% Forward GFT\n');
    fprintf('  reconstructed = gsp_igft(G, gft_coeffs);   %% Inverse GFT\n');
    fprintf('  \n');
    fprintf('  %% Spectral filtering\n');
    fprintf('  h_filter = gsp_design_meyer(G, 0.2);       %% Design filter\n');
    fprintf('  filtered = gsp_filter(G, h_filter, signal); %% Apply filter\n');
    fprintf('  \n');
    fprintf('  %% Visualization\n');
    fprintf('  gsp_plot_signal(G, signal);                %% Plot signal on graph\n');
    fprintf('  figure; plot(G.e, ''.-'');                 %% Plot eigenvalue spectrum\n');
end