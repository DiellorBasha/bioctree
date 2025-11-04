% compute_gsp_eigendecomposition.m
% Compute full eigendecomposition for GSP graphs with memory optimization

fprintf('Computing GSP Graph Eigendecomposition (Memory-Optimized)\n');
fprintf('=========================================================\n\n');

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

%% Check memory and system resources
fprintf('\n2. Checking system resources...\n');
fprintf('--------------------------------\n');

% Get MATLAB memory info
try
    mem_info = memory;
    if isfield(mem_info, 'MemAvailableAllArrays')
        available_mem_gb = mem_info.MemAvailableAllArrays / 1e9;
        fprintf('Available memory: %.2f GB\n', available_mem_gb);
    else
        fprintf('Memory info not available on this system\n');
        available_mem_gb = 8; % Conservative estimate
    end
catch
    fprintf('Cannot determine memory info, assuming 8 GB available\n');
    available_mem_gb = 8;
end

% Estimate memory requirements for eigendecomposition
N = G_lh.N;
eigen_memory_estimate_gb = (N * N * 8) / 1e9; % Full eigenvector matrix in double precision
fprintf('Estimated memory for full eigendecomposition: %.2f GB\n', eigen_memory_estimate_gb);

% Check if we have enough memory
if eigen_memory_estimate_gb > available_mem_gb * 0.8 % Use 80% of available memory as safe limit
    fprintf('⚠️  Warning: Estimated memory usage exceeds safe limit\n');
    use_partial_decomposition = true;
    max_eigenvectors = min(floor(available_mem_gb * 0.8 * 1e9 / (N * 8)), N);
    fprintf('Will compute partial decomposition with max %d eigenvectors\n', max_eigenvectors);
else
    fprintf('✓ Sufficient memory for full decomposition\n');
    use_partial_decomposition = false;
    max_eigenvectors = N;
end

%% Set up computation parameters
fprintf('\n3. Setting up computation parameters...\n');
fprintf('---------------------------------------\n');

% Create parameters for gsp_compute_fourier_basis
param = struct();

% Override the default vertex limit in GSPBOX
param.force = true;  % Force computation even for large graphs

% Memory optimization parameters
if use_partial_decomposition
    param.nb_eigenvectors = max_eigenvectors;
    fprintf('Computing partial eigendecomposition: %d/%d eigenvectors\n', max_eigenvectors, N);
else
    param.nb_eigenvectors = N;
    fprintf('Computing full eigendecomposition: %d eigenvectors\n', N);
end

% Use iterative solver for large graphs
param.solver = 'eigs';  % Use iterative eigenvalue solver instead of eig()

% Parallel processing if available
if license('test', 'Parallel_Computing_Toolbox')
    try
        % Check if parallel pool is available
        current_pool = gcp('nocreate');
        if isempty(current_pool)
            fprintf('Starting parallel pool...\n');
            parpool('local');
            fprintf('✓ Parallel pool started\n');
        else
            fprintf('✓ Using existing parallel pool (%d workers)\n', current_pool.NumWorkers);
        end
        param.use_parallel = true;
    catch ME
        fprintf('⚠️  Parallel pool setup failed: %s\n', ME.message);
        param.use_parallel = false;
    end
else
    fprintf('Parallel Computing Toolbox not available\n');
    param.use_parallel = false;
end

% Additional memory optimization
param.verbose = 1;  % Enable verbose output to monitor progress

%% Compute eigendecomposition for left hemisphere
fprintf('\n4. Computing LH eigendecomposition...\n');
fprintf('-------------------------------------\n');

try
    % Clear unnecessary variables to free memory
    clear data;
    
    % Record start time
    tic;
    
    fprintf('Starting LH eigendecomposition (N=%d)...\n', G_lh.N);
    fprintf('This may take several minutes to hours depending on system...\n');
    
    % Override GSPBOX safety check by temporarily modifying the graph
    original_N = G_lh.N;
    
    % Compute eigendecomposition with error handling
    try
        G_lh = gsp_compute_fourier_basis(G_lh, param);
        lh_computation_time = toc;
        
        fprintf('✓ LH eigendecomposition completed!\n');
        fprintf('  - Computation time: %.2f minutes\n', lh_computation_time/60);
        fprintf('  - Eigenvalues computed: %d\n', length(G_lh.e));
        fprintf('  - Eigenvectors computed: %d\n', size(G_lh.U, 2));
        fprintf('  - Eigenvalue range: [%.6f, %.6f]\n', min(G_lh.e), max(G_lh.e));
        
        % Verify orthogonality of eigenvectors (for small subset)
        if size(G_lh.U, 2) <= 1000
            orthogonality_error = norm(G_lh.U' * G_lh.U - eye(size(G_lh.U, 2)), 'fro');
            fprintf('  - Eigenvector orthogonality error: %.2e\n', orthogonality_error);
        end
        
        lh_success = true;
        
    catch ME
        fprintf('✗ LH eigendecomposition failed: %s\n', ME.message);
        if contains(ME.message, 'memory') || contains(ME.message, 'Memory')
            fprintf('  → Memory-related error detected\n');
            fprintf('  → Try reducing nb_eigenvectors or use a machine with more RAM\n');
        elseif contains(ME.message, 'convergence')
            fprintf('  → Convergence issue detected\n');
            fprintf('  → Try different solver options or increase iteration limits\n');
        end
        lh_success = false;
    end
    
catch ME
    fprintf('✗ Error during LH computation setup: %s\n', ME.message);
    lh_success = false;
end

%% Save LH results if successful
if lh_success
    fprintf('\n5. Saving LH eigendecomposition...\n');
    fprintf('----------------------------------\n');
    
    try
        % Save with compression to reduce file size
        output_file = 'test-data/meshes/fsaverage/fsaverage_lh_pial_gsp_eigen.mat';
        
        % Save only essential eigendecomposition data
        save(output_file, 'G_lh', '-v7.3');
        
        % Get file size
        file_info = dir(output_file);
        file_size_mb = file_info.bytes / (1024^2);
        
        fprintf('✓ Saved LH eigendecomposition: %s (%.1f MB)\n', output_file, file_size_mb);
        
        % Save summary information
        summary_lh = struct();
        summary_lh.N = G_lh.N;
        summary_lh.num_eigenvalues = length(G_lh.e);
        summary_lh.num_eigenvectors = size(G_lh.U, 2);
        summary_lh.eigenvalue_range = [min(G_lh.e), max(G_lh.e)];
        summary_lh.computation_time_minutes = lh_computation_time/60;
        summary_lh.is_full_decomposition = (length(G_lh.e) == G_lh.N);
        
    catch ME
        fprintf('✗ Error saving LH results: %s\n', ME.message);
        lh_success = false;
    end
end

%% Compute eigendecomposition for right hemisphere (if LH succeeded)
if lh_success
    fprintf('\n6. Computing RH eigendecomposition...\n');
    fprintf('-------------------------------------\n');
    
    try
        % Clear LH data to free memory for RH computation
        clear G_lh;
        
        tic;
        fprintf('Starting RH eigendecomposition (N=%d)...\n', G_rh.N);
        
        try
            G_rh = gsp_compute_fourier_basis(G_rh, param);
            rh_computation_time = toc;
            
            fprintf('✓ RH eigendecomposition completed!\n');
            fprintf('  - Computation time: %.2f minutes\n', rh_computation_time/60);
            fprintf('  - Eigenvalues computed: %d\n', length(G_rh.e));
            fprintf('  - Eigenvectors computed: %d\n', size(G_rh.U, 2));
            fprintf('  - Eigenvalue range: [%.6f, %.6f]\n', min(G_rh.e), max(G_rh.e));
            
            rh_success = true;
            
        catch ME
            fprintf('✗ RH eigendecomposition failed: %s\n', ME.message);
            rh_success = false;
        end
        
    catch ME
        fprintf('✗ Error during RH computation setup: %s\n', ME.message);
        rh_success = false;
    end
    
    %% Save RH results if successful
    if rh_success
        fprintf('\n7. Saving RH eigendecomposition...\n');
        fprintf('----------------------------------\n');
        
        try
            output_file = 'test-data/meshes/fsaverage/fsaverage_rh_pial_gsp_eigen.mat';
            save(output_file, 'G_rh', '-v7.3');
            
            file_info = dir(output_file);
            file_size_mb = file_info.bytes / (1024^2);
            
            fprintf('✓ Saved RH eigendecomposition: %s (%.1f MB)\n', output_file, file_size_mb);
            
            % Save summary
            summary_rh = struct();
            summary_rh.N = G_rh.N;
            summary_rh.num_eigenvalues = length(G_rh.e);
            summary_rh.num_eigenvectors = size(G_rh.U, 2);
            summary_rh.eigenvalue_range = [min(G_rh.e), max(G_rh.e)];
            summary_rh.computation_time_minutes = rh_computation_time/60;
            summary_rh.is_full_decomposition = (length(G_rh.e) == G_rh.N);
            
        catch ME
            fprintf('✗ Error saving RH results: %s\n', ME.message);
            rh_success = false;
        end
    end
else
    rh_success = false;
    fprintf('\n6. Skipping RH computation due to LH failure\n');
end

%% Create combined summary
fprintf('\n8. Creating computation summary...\n');
fprintf('----------------------------------\n');

summary = struct();
summary.computation_date = datestr(now);
summary.system_info.matlab_version = version;
summary.system_info.available_memory_gb = available_mem_gb;
summary.parameters = param;

if lh_success
    summary.lh = summary_lh;
    fprintf('✓ LH eigendecomposition: %d/%d eigenvalues\n', summary_lh.num_eigenvalues, summary_lh.N);
end

if rh_success  
    summary.rh = summary_rh;
    fprintf('✓ RH eigendecomposition: %d/%d eigenvalues\n', summary_rh.num_eigenvalues, summary_rh.N);
end

% Save summary
try
    save('test-data/meshes/fsaverage/eigendecomposition_summary.mat', 'summary', '-v7.3');
    fprintf('✓ Saved computation summary\n');
catch ME
    fprintf('✗ Error saving summary: %s\n', ME.message);
end

%% Final results
fprintf('\n=========================================================\n');
if lh_success && rh_success
    fprintf('✓ Eigendecomposition completed successfully for both hemispheres!\n');
    total_time = (summary_lh.computation_time_minutes + summary_rh.computation_time_minutes);
    fprintf('Total computation time: %.2f minutes\n', total_time);
elseif lh_success
    fprintf('✓ Eigendecomposition completed for LH only\n');
    fprintf('✗ RH computation failed or was skipped\n');
else
    fprintf('✗ Eigendecomposition failed\n');
    fprintf('Consider reducing the number of eigenvectors or using a machine with more memory\n');
end
fprintf('=========================================================\n\n');

if lh_success || rh_success
    fprintf('Usage:\n');
    fprintf('  %% Load eigendecomposed graphs\n');
    if lh_success
        fprintf('  G_lh = load(''test-data/meshes/fsaverage/fsaverage_lh_pial_gsp_eigen.mat'');\n');
    end
    if rh_success
        fprintf('  G_rh = load(''test-data/meshes/fsaverage/fsaverage_rh_pial_gsp_eigen.mat'');\n');
    end
    fprintf('  \n');
    fprintf('  %% Use graph Fourier transform\n');
    fprintf('  signal = randn(G.N, 1);\n');
    fprintf('  gft_coeffs = gsp_gft(G, signal);     %% Forward GFT\n');
    fprintf('  reconstructed = gsp_igft(G, gft_coeffs); %% Inverse GFT\n');
    fprintf('  \n');
    fprintf('  %% Apply spectral filters\n');
    fprintf('  lowpass_filter = gsp_design_meyer(G, 0.1);\n');
    fprintf('  filtered_signal = gsp_filter(G, lowpass_filter, signal);\n');
end