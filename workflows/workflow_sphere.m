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
    data_struct.graph = G;  % Main graph structure (using "graph" field consistently)
    
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
    data_struct.graph = G;  % Graph structure (using "graph" field consistently)
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

%% Step 4: Check and create additional signal layers
fprintf('\nChecking for additional signal layers...\n');

% Check if multiple signal layers exist
additional_layers_exist = false;
if file_exists
    try
        % Check for signal layers (numbered format)
        info = h5info(output_filename, '/data/raw');
        layer_datasets = {};
        for i = 1:length(info.Datasets)
            dataset_name = info.Datasets(i).Name;
            if startsWith(dataset_name, 'signal_') && ~strcmp(dataset_name, 'signal')
                layer_datasets{end+1} = dataset_name;
            end
        end
        
        if ~isempty(layer_datasets)
            additional_layers_exist = true;
            fprintf('  ✓ Found %d additional signal layers: %s\n', ...
                length(layer_datasets), strjoin(layer_datasets, ', '));
        else
            fprintf('  ℹ No additional signal layers found\n');
        end
    catch
        fprintf('  ℹ Could not check for additional layers\n');
    end
end

if ~additional_layers_exist
    fprintf('\nGenerating patch signal layers with increasing sizes...\n');
    
    % Create 5 patch signals with increasingly larger patch sizes
    patch_sizes = [0.05, 0.10, 0.15, 0.20, 0.25];  % 5%, 10%, 15%, 20%, 25% of vertices
    patch_signals = cell(5, 1);
    patch_params_all = cell(5, 1);
    
    % Use the same center for all patches for consistency
    fprintf('  Finding optimal patch center...\n');
    [~, center_params] = generatePatchSignal(G, ...
        'patchSize', 0.15, 'patchCenter', 'auto', ...
        'patchValue', 1.0, 'backgroundValue', 0.0, ...
        'growthMode', 'none');
    common_center = center_params.patchCenter;
    fprintf('  ✓ Using vertex %d as common center\n', common_center);
    
    for i = 1:5
        fprintf('  Generating patch %d (size %.1f%%)...', i, patch_sizes(i)*100);
        
        [patch_signals{i}, patch_params_all{i}] = generatePatchSignal(G, ...
            'patchSize', patch_sizes(i), ...
            'patchCenter', common_center, ...  % Use same center
            'patchValue', 1.0, ...
            'backgroundValue', 0.0, ...
            'growthMode', 'none');
        
        active_vertices = sum(patch_signals{i} > 0.5);
        coverage = 100 * active_vertices / G.N;
        
        fprintf(' %d vertices (%.1f%% actual)\n', active_vertices, coverage);
    end
    
    fprintf('  ✓ Created %d patch signals with increasing sizes\n', length(patch_signals));
    
    % Prepare multi-layer data structure
    fprintf('\nAdding patch signal layers to HDF5...\n');
    
    % Load existing data or create new structure
    if signal_exists
        % Load existing signal to preserve it as layer 0 (baseline)
        existing_signal = h5read(output_filename, '/data/raw/signal');
        data_struct = struct();
        data_struct.graph = G;
        data_struct.X = existing_signal;  % Keep original signal as primary
    else
        % Use the first (smallest) patch as primary signal
        data_struct = struct();
        data_struct.graph = G;
        data_struct.X = patch_signals{1}(:);  % 5% patch as primary
        
        fprintf('  ✓ Using patch 1 (5%%) as primary signal: %s\n', mat2str(size(data_struct.X)));
    end
    
    % Add patch signals as named layers
    data_struct.X_layers = struct();
    
    for i = 1:5
        % Create descriptive layer names
        layer_name = sprintf('patch_%02d_pct', round(patch_sizes(i)*100));
        data_struct.X_layers.(layer_name) = patch_signals{i}(:);
        
        fprintf('  ✓ Added layer "%s": %d active vertices\n', ...
            layer_name, sum(patch_signals{i} > 0.5));
    end
    
    % Also add as numbered layers for easy access
    for i = 1:5
        field_name = sprintf('X%d', i);
        data_struct.(field_name) = patch_signals{i}(:);
    end
    
    % Update metadata to describe the patch layers
    data_struct.metadata.description = 'Bioctree icosphere with multi-scale patch signals';
    data_struct.metadata.creation_date = datestr(now);
    data_struct.metadata.signal_type = 'multi_scale_patches';
    data_struct.metadata.coordinate_system = 'cartesian_3d';
    
    % Add patch-specific metadata
    data_struct.metadata.patch_center_vertex = common_center;
    data_struct.metadata.patch_center_coords = G.coords(common_center, :);
    data_struct.metadata.num_patch_layers = length(patch_signals);
    
    % Add layer descriptions
    data_struct.metadata.signal_layers = struct();
    if signal_exists
        data_struct.metadata.signal_layers.primary = 'Original patch signal (preserved)';
    else
        data_struct.metadata.signal_layers.primary = sprintf('Patch signal %.0f%% coverage', patch_sizes(1)*100);
    end
    
    for i = 1:5
        layer_name = sprintf('patch_%02d_pct', round(patch_sizes(i)*100));
        actual_coverage = 100 * sum(patch_signals{i} > 0.5) / G.N;
        
        data_struct.metadata.signal_layers.(layer_name) = sprintf(...
            'Patch signal %.0f%% target, %.1f%% actual coverage, %d vertices', ...
            patch_sizes(i)*100, actual_coverage, sum(patch_signals{i} > 0.5));
    end
    
    % Save all layers to HDF5
    try
        success = outbct(output_filename, data_struct, ...
            'IncludeRaw', true, ...         % Include all signal data
            'IncludeSpectral', false, ...   % No spectral data yet
            'Compression', 6, ...
            'Verbose', true);
        
        if success
            fprintf('  ✓ Multi-scale patch signals added to HDF5!\n');
            fileInfo = dir(output_filename);
            fprintf('  ✓ Updated file size: %.2f KB\n', fileInfo.bytes / 1024);
            
            % Report patch layer details
            fprintf('  ✓ Patch signal layers stored:\n');
            fprintf('    - Primary signal: /data/raw/signal\n');
            
            for i = 1:5
                layer_name = sprintf('patch_%02d_pct', round(patch_sizes(i)*100));
                active_count = sum(patch_signals{i} > 0.5);
                actual_pct = 100 * active_count / G.N;
                fprintf('    - %s: %d vertices (%.1f%%)\n', layer_name, active_count, actual_pct);
            end
            
            fprintf('    - Numbered access: /data/raw/signal_001 through signal_005\n');
            fprintf('    - Common center: vertex %d at [%.3f, %.3f, %.3f]\n', ...
                common_center, G.coords(common_center, 1), G.coords(common_center, 2), G.coords(common_center, 3));
        else
            fprintf('  ✗ Multi-scale patch signal save failed\n');
        end
        
    catch ME
        fprintf('  ✗ Error adding signal layers: %s\n', ME.message);
    end
    
else
    fprintf('\n✓ Additional signal layers already exist - no action needed\n');
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
    fprintf('✓ Created primary patch signal and added to HDF5\n');
    if exist('signal', 'var')
        fprintf('✓ Primary signal covers %.1f%% of surface\n', 100 * sum(signal > 0.5) / G.N);
    end
else
    fprintf('✓ Existing primary signal found\n');
end

if ~additional_layers_exist
    fprintf('✓ Created multi-scale patch signal layers:\n');
    for i = 1:5
        if exist('patch_signals', 'var') && ~isempty(patch_signals)
            active_count = sum(patch_signals{i} > 0.5);
            actual_pct = 100 * active_count / G.N;
            fprintf('  • Patch %d: %.0f%% target → %d vertices (%.1f%% actual)\n', ...
                i, patch_sizes(i)*100, active_count, actual_pct);
        else
            fprintf('  • Patch %d: %.0f%% target coverage\n', i, patch_sizes(i)*100);
        end
    end
    fprintf('✓ All patches centered at vertex %d\n', common_center);
    fprintf('✓ Total layers: 10+ signals in single HDF5 file\n');
else
    fprintf('✓ Multi-scale patch layers already exist\n');
end

fprintf('\nNext Steps:\n');
fprintf('• Analyze multi-scale patch interactions\n');
fprintf('• Implement temporal patch dynamics\n');
fprintf('• Add patch-based spectral analysis\n');
fprintf('• Compare signals across different scales\n');

fprintf('\n=== Icosphere Workflow Complete ===\n');

end