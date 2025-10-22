function workflow_sphere()
%% Bioctree Icosphere Graph Signal Processing Workflow
% This script manages an icosphere graph in HDF5 format.
% Step 1: Check if HDF5 file exists with graph data
% Step 2: If not, create icosphere and save graph to HDF5

%% Initialize Environment
close all; clc;

fprintf('=== Bioctree Icosphere Workflow ===\n');
fprintf('Date: %s\n\n', datestr(now));

%% Step 1: Check if HDF5 file exists with graph data
config = bioctree_config();
output_filename = fullfile(config.DataPath, 'bioctree_files', 'icosphere_patch_demo.h5');

fprintf('Checking for existing HDF5 file...\n');
fprintf('  Target file: %s\n', output_filename);

file_exists = exist(output_filename, 'file');
graph_exists = false;

if file_exists
    fprintf('  ✓ HDF5 file found\n');
    
    % Check if graph data exists in the file
    try
        info = h5info(output_filename);
        group_names = {info.Groups.Name};
        
        if any(contains(group_names, 'graph'))
            % Check if graph has coordinate data (key indicator)
            try
                coords = h5read(output_filename, '/graph/coordinates');
                N = size(coords, 1);
                graph_exists = true;
                fprintf('  ✓ Graph data found: %d vertices\n', N);
            catch
                fprintf('  ⚠ Graph group exists but coordinate data missing\n');
            end
        else
            fprintf('  ⚠ No graph group found in HDF5 file\n');
        end
    catch ME
        fprintf('  ✗ Error reading HDF5 file: %s\n', ME.message);
    end
else
    fprintf('  ℹ HDF5 file does not exist\n');
end

%% Step 2: Create graph if needed
if ~graph_exists
    fprintf('\nCreating new icosphere graph...\n');
    
    % Parameters for icosphere generation
    subdivision_level = 3;  % Number of subdivision iterations (3 = 642 vertices)
    radius = 1;            % Unit sphere
    laplacian_type = "cotangent";  % Use cotangent Laplacian for better geometry
    
    fprintf('  Generating icosphere with %d subdivisions...\n', subdivision_level);
    
    % Build the icosphere graph structure
    G = build_icosphere(subdivision_level, radius, 'laplacianType', laplacian_type);
    
    fprintf('  ✓ Generated icosphere with %d vertices and %d faces\n', ...
        G.N, size(G.F, 1));
    fprintf('  ✓ Graph has %d edges\n', G.Ne);
    fprintf('  ✓ Surface area: %.4f (theoretical: %.4f)\n', ...
        sum(G.vertexArea), 4*pi*radius^2);
    
    % Prepare minimal data structure for outbct (graph only)
    data_struct = struct();
    data_struct.G = G;  % Main graph structure
    
    % Add minimal metadata
    data_struct.metadata.description = 'Bioctree icosphere graph structure';
    data_struct.metadata.creation_date = datestr(now);
    data_struct.metadata.signal_type = 'graph_only';
    data_struct.metadata.coordinate_system = 'cartesian_3d';
    
    % Create output directory if needed
    [output_dir, ~, ~] = fileparts(output_filename);
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
        fprintf('  ✓ Created output directory: %s\n', output_dir);
    end
    
    % Save graph to HDF5
    fprintf('\nSaving graph to HDF5...\n');
    try
        success = outbct(output_filename, data_struct, ...
            'IncludeRaw', false, ...        % No signal data yet
            'IncludeSpectral', false, ...   % No spectral data yet
            'Compression', 6, ...
            'Verbose', true);
        
        if success
            fprintf('  ✓ Graph successfully saved to HDF5!\n');
            fileInfo = dir(output_filename);
            fprintf('  ✓ File size: %.2f KB\n', fileInfo.bytes / 1024);
        else
            fprintf('  ✗ Graph save failed\n');
        end
        
    catch ME
        fprintf('  ✗ Error saving graph: %s\n', ME.message);
    end
    
else
    fprintf('\n✓ Graph already exists in HDF5 file - no action needed\n');
    
    % Load the existing graph for signal processing
    % We need to rebuild the graph structure since we only stored basic info
    fprintf('  Rebuilding graph structure for signal processing...\n');
    subdivision_level = 3;  % Same parameters as creation
    radius = 1;
    laplacian_type = "cotangent";
    
    G = build_icosphere(subdivision_level, radius, 'laplacianType', laplacian_type);
    fprintf('  Loaded graph: %d vertices\n', G.N);
end

%% Step 3: Check and create patch signal
fprintf('\nChecking for patch signal data...\n');

signal_exists = false;
if file_exists
    try
        % Check if signal data exists
        signal_data = h5read(output_filename, '/data/raw/signal');
        signal_exists = true;
        fprintf('  ✓ Patch signal found: %s\n', mat2str(size(signal_data)));
    catch
        fprintf('  ℹ No patch signal data found\n');
    end
else
    fprintf('  ℹ No HDF5 file - signal will be created\n');
end

if ~signal_exists
    fprintf('\nGenerating patch signal...\n');
    
    % Parameters for patch generation
    patch_size = 0.15;        % 15% of vertices
    patch_center = 'auto';    % Automatically find center
    patch_value = 1.0;        % Signal value inside patch
    background_value = 0.0;   % Signal value outside patch
    
    % Generate the patch signal (static, no temporal dimension)
    [signal, patch_params] = generatePatchSignal(G, ...
        'patchSize', patch_size, ...
        'patchCenter', patch_center, ...
        'patchValue', patch_value, ...
        'backgroundValue', background_value, ...
        'growthMode', 'none');  % Static patch
    
    fprintf('  ✓ Generated patch signal\n');
    fprintf('  ✓ Patch size: %d vertices (%.1f%% of surface)\n', ...
        sum(signal > 0.5), 100 * sum(signal > 0.5) / G.N);
    fprintf('  ✓ Patch center: vertex %d\n', patch_params.patchCenter);
    fprintf('  ✓ Signal range: [%.3f, %.3f]\n', min(signal), max(signal));
    
    % Prepare data structure for signal addition
    fprintf('\nAdding signal to HDF5 file...\n');
    
    % Create minimal data structure with graph and signal
    data_struct = struct();
    data_struct.G = G;  % Graph structure
    data_struct.X = signal(:);  % Signal as column vector [N x 1]
    
    % Add signal metadata
    data_struct.metadata.description = 'Bioctree icosphere with patch signal';
    data_struct.metadata.creation_date = datestr(now);
    data_struct.metadata.signal_type = 'static_patch';
    data_struct.metadata.coordinate_system = 'cartesian_3d';
    
    % Add patch parameters to metadata
    data_struct.metadata.patch_size = patch_size;
    data_struct.metadata.patch_center = patch_params.patchCenter;
    data_struct.metadata.patch_value = patch_value;
    data_struct.metadata.background_value = background_value;
    
    % Save updated data to HDF5
    try
        success = outbct(output_filename, data_struct, ...
            'IncludeRaw', true, ...         % Include signal data now
            'IncludeSpectral', false, ...   % No spectral data yet
            'Compression', 6, ...
            'Verbose', true);
        
        if success
            fprintf('  ✓ Patch signal successfully added to HDF5!\n');
            fileInfo = dir(output_filename);
            fprintf('  ✓ Updated file size: %.2f KB\n', fileInfo.bytes / 1024);
        else
            fprintf('  ✗ Signal save failed\n');
        end
        
    catch ME
        fprintf('  ✗ Error adding signal: %s\n', ME.message);
    end
    
else
    fprintf('\n✓ Patch signal already exists - no action needed\n');
end

%% Summary
fprintf('\n=== Workflow Summary ===\n');
if ~graph_exists
    fprintf('✓ Created new icosphere graph with %d vertices\n', G.N);
    fprintf('✓ Saved graph structure to HDF5 format\n');
else
    fprintf('✓ Existing graph found and loaded\n');
end

if ~signal_exists
    fprintf('✓ Created patch signal and added to HDF5\n');
    fprintf('✓ Signal covers %.1f%% of surface\n', 100 * sum(signal > 0.5) / G.N);
else
    fprintf('✓ Existing patch signal found - ready for analysis\n');
end

fprintf('\nNext Steps:\n');
fprintf('• Add signal generation functionality\n');
fprintf('• Implement temporal dynamics\n');
fprintf('• Add spectral analysis capabilities\n');

fprintf('\n=== Icosphere Workflow Complete ===\n');

end