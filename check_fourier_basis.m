%% Check Fourier Basis in HDF5 File
% Verify if the gftH5 function saved the Fourier basis

clear; close all; clc;

fprintf('=== Checking Fourier Basis in HDF5 File ===\n');

% Get file path
config = bioctree_config();
hdf5_file = fullfile(config.DataPath, 'bioctree_files', 'icosphere_patch_demo.h5');

fprintf('File: %s\n', hdf5_file);
fprintf('File exists: %s\n\n', string(exist(hdf5_file, 'file') == 2));

try
    % Load the data
    fprintf('1. Loading data structure...\n');
    data = inbct(hdf5_file);
    
    fprintf('   Data fields: %s\n', strjoin(fieldnames(data), ', '));
    
    % Check for graph structure
    fprintf('\n2. Checking graph structure...\n');
    if isfield(data, 'G')
        fprintf('   ✓ Graph G field found\n');
        fprintf('   G fields: %s\n', strjoin(fieldnames(data.G), ', '));
        
        % Check for Fourier basis components
        fprintf('\n3. Checking Fourier basis...\n');
        
        % Check eigenvectors (U)
        if isfield(data.G, 'U')
            fprintf('   ✓ Eigenvectors (U) found: %s\n', mat2str(size(data.G.U)));
            
            % Check if it's the identity or actual eigenvectors
            if size(data.G.U, 1) == size(data.G.U, 2)
                is_identity = max(max(abs(data.G.U - eye(size(data.G.U))))) < 1e-10;
                if is_identity
                    fprintf('   ⚠ U appears to be identity matrix (not computed)\n');
                else
                    fprintf('   ✓ U contains actual eigenvectors\n');
                    fprintf('   First few eigenvalues from U: [%.6f, %.6f, %.6f, ...]\n', ...
                        data.G.U(1,1), data.G.U(1,2), data.G.U(1,3));
                end
            end
        else
            fprintf('   ✗ No eigenvectors (U) field found\n');
        end
        
        % Check eigenvalues (e)
        if isfield(data.G, 'e')
            fprintf('   ✓ Eigenvalues (e) found: %d values\n', length(data.G.e));
            fprintf('   Eigenvalue range: [%.6f, %.6f]\n', min(data.G.e), max(data.G.e));
            
            % Show first few eigenvalues
            n_show = min(10, length(data.G.e));
            fprintf('   First %d eigenvalues: %s\n', n_show, ...
                mat2str(data.G.e(1:n_show)', 4));
        else
            fprintf('   ✗ No eigenvalues (e) field found\n');
        end
        
        % Check other GSP properties
        fprintf('\n4. Other GSP properties:\n');
        if isfield(data.G, 'lmax')
            fprintf('   ✓ lmax (spectrum bound): %.6f\n', data.G.lmax);
        end
        if isfield(data.G, 'N')
            fprintf('   ✓ N (vertices): %d\n', data.G.N);
        end
        if isfield(data.G, 'Ne')
            fprintf('   ✓ Ne (edges): %d\n', data.G.Ne);
        end
        
    else
        fprintf('   ✗ No G field found in data structure\n');
        
        % Check if it's in 'graph' field instead
        if isfield(data, 'graph')
            fprintf('   Found "graph" field instead of "G"\n');
            fprintf('   graph fields: %s\n', strjoin(fieldnames(data.graph), ', '));
        end
    end
    
    fprintf('\n=== Summary ===\n');
    has_eigenvectors = isfield(data, 'G') && isfield(data.G, 'U') && ...
        ~(max(max(abs(data.G.U - eye(size(data.G.U))))) < 1e-10);
    has_eigenvalues = isfield(data, 'G') && isfield(data.G, 'e');
    
    if has_eigenvectors && has_eigenvalues
        fprintf('✓ Fourier basis successfully saved to file!\n');
        fprintf('  - Eigenvectors: %s\n', mat2str(size(data.G.U)));
        fprintf('  - Eigenvalues: %d values\n', length(data.G.e));
        fprintf('  - Ready for future GFT computations\n');
    else
        fprintf('✗ Fourier basis not properly saved\n');
        if ~has_eigenvectors
            fprintf('  Missing or invalid eigenvectors\n');
        end
        if ~has_eigenvalues
            fprintf('  Missing eigenvalues\n');
        end
    end
    
catch ME
    fprintf('\n✗ Error loading or checking file:\n');
    fprintf('Error: %s\n', ME.message);
    if ~isempty(ME.stack)
        fprintf('Location: %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
    end
end