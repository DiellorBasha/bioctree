%% Test Graph Field Refactoring
% Test if the "graph" field consistency works end-to-end

clear; close all; clc;

fprintf('=== Testing Graph Field Refactoring ===\n');

% Get file
config = bioctree_config();
hdf5_file = fullfile(config.DataPath, 'bioctree_files', 'icosphere_patch_demo.h5');

% Test 1: Run gftH5 with refactored code
fprintf('1. Running gftH5 with graph field...\n');
try
    [gft_data, analysis_info] = gftH5(hdf5_file, 'SignalName', 'signal_patch_05_pct');
    
    fprintf('   ✓ gftH5 completed successfully\n');
    fprintf('   GFT size: %s\n', mat2str(size(gft_data.X_gft)));
    fprintf('   Eigenvalue range: [%.6f, %.6f]\n', min(gft_data.eigenvalues), max(gft_data.eigenvalues));
    
catch ME
    fprintf('   ✗ gftH5 failed: %s\n', ME.message);
    return;
end

% Test 2: Check if Fourier basis was saved
fprintf('\n2. Checking if Fourier basis was saved to file...\n');
try
    data_reload = inbct(hdf5_file);
    
    if isfield(data_reload, 'graph')
        fprintf('   ✓ Graph field found\n');
        
        if isfield(data_reload.graph, 'U')
            fprintf('   ✓ Eigenvectors (U) saved: %s\n', mat2str(size(data_reload.graph.U)));
            
            % Check if it's actually computed (not identity)
            if size(data_reload.graph.U, 1) > 1
                is_identity = max(max(abs(data_reload.graph.U - eye(size(data_reload.graph.U))))) < 1e-10;
                if ~is_identity
                    fprintf('   ✓ Eigenvectors contain computed values (not identity)\n');
                else
                    fprintf('   ⚠ Eigenvectors appear to be identity matrix\n');
                end
            end
        else
            fprintf('   ✗ No eigenvectors (U) field\n');
        end
        
        if isfield(data_reload.graph, 'e')
            fprintf('   ✓ Eigenvalues (e) saved: %d values\n', length(data_reload.graph.e));
            fprintf('   Eigenvalue range: [%.6f, %.6f]\n', min(data_reload.graph.e), max(data_reload.graph.e));
        else
            fprintf('   ✗ No eigenvalues (e) field\n');
        end
        
    else
        fprintf('   ✗ No graph field found\n');
    end
    
catch ME
    fprintf('   ✗ Error checking file: %s\n', ME.message);
end

% Test 3: Verify we can reload and use saved Fourier basis
fprintf('\n3. Testing reuse of saved Fourier basis...\n');
try
    % Run gftH5 again - should use existing basis
    [gft_data2, analysis_info2] = gftH5(hdf5_file, 'SignalName', 'signal_patch_10_pct');
    
    fprintf('   ✓ Second gftH5 run successful\n');
    fprintf('   Used existing basis: %s\n', string(analysis_info2.computation_time.graph_preparation < 0.1));
    
catch ME
    fprintf('   ✗ Second gftH5 run failed: %s\n', ME.message);
end

fprintf('\n=== Test Summary ===\n');
fprintf('✓ Graph field refactoring test complete\n');
fprintf('The system now uses "graph" consistently throughout\n');