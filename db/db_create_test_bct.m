function success = db_create_test_bct(outputPath, varargin)
% DB_CREATE_TEST_BCT Create standardized test BCT file for bioctree development
%
% ⚠️  DEPRECATED: This function is deprecated and will be removed in a future version.
% Use the BCT class system instead with bct.create() and write methods.
%
% This function creates the canonical test BCT file that serves as the standard
% test dataset for all bioctree functions and demos. The file contains an
% icosphere graph with multi-layer patch signals of varying sizes.
%
% Usage:
%   success = db_create_test_bct()
%   success = db_create_test_bct(outputPath)
%   success = db_create_test_bct(outputPath, 'param', value, ...)
%
% Inputs:
%   outputPath - Path for output BCT file (default: config.DataPath/test_bioctree_standard.h5)
%
% Parameters:
%   'IcosphereLevel'    - Subdivision level for icosphere (default: 3, ~642 vertices)
%   'Radius'            - Sphere radius (default: 1)
%   'NumLayers'         - Number of patch signal layers (default: 10)
%   'PatchSizeRange'    - [min_pct max_pct] patch size range (default: [0.05 0.85])
%   'TimeSteps'         - Number of temporal samples per layer (default: 100)
%   'SamplingRate'      - Temporal sampling rate in Hz (default: 100)
%   'Seed'              - Random seed for reproducibility (default: 42)
%   'Verbose'           - Display progress (default: true)
%   'Overwrite'         - Overwrite existing file (default: false)
%
% Outputs:
%   success - True if BCT file created successfully
%
% BCT File Contents:
%   - Icosphere graph structure with coordinates, adjacency, eigendecomposition
%   - 10 patch signal layers with increasing patch sizes (5% to 85%)
%   - Temporal dynamics (100 time steps per layer)
%   - Complete metadata for reproducibility
%   - Graph Fourier Transform coefficients
%   - Spatial and temporal indices
%
% Examples:
%   % Create standard test file
%   success = db_create_test_bct();
%
%   % Custom configuration
%   success = db_create_test_bct('my_test.h5', 'NumLayers', 5, 'IcosphereLevel', 2);
%
% See also: DB_LOAD_BCT_CONFIG, DB_CREATE_BCT_STRUCTURE, GENERATEPATCHSIGNAL

%% Parse Inputs
p = inputParser;
addOptional(p, 'outputPath', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'IcosphereLevel', 3, @(x) isnumeric(x) && x >= 1 && x <= 5);
addParameter(p, 'Radius', 1, @(x) isnumeric(x) && x > 0);
addParameter(p, 'NumLayers', 10, @(x) isnumeric(x) && x >= 1);
addParameter(p, 'PatchSizeRange', [0.05 0.85], @(x) length(x)==2 && all(x>0) && all(x<1) && x(1)<x(2));
addParameter(p, 'TimeSteps', 100, @(x) isnumeric(x) && x >= 1);
addParameter(p, 'SamplingRate', 100, @(x) isnumeric(x) && x > 0);
addParameter(p, 'Seed', 42, @(x) isnumeric(x));
addParameter(p, 'Verbose', true, @islogical);
addParameter(p, 'Overwrite', false, @islogical);
parse(p, outputPath, varargin{:});

% Extract parameters
outputPath = p.Results.outputPath;
ico_level = p.Results.IcosphereLevel;
radius = p.Results.Radius;
num_layers = p.Results.NumLayers;
patch_range = p.Results.PatchSizeRange;
T = p.Results.TimeSteps;
fs = p.Results.SamplingRate;
seed = p.Results.Seed;
verbose = p.Results.Verbose;
overwrite = p.Results.Overwrite;

% Issue deprecation warning
warning('bioctree:DeprecatedFunction', ...
    'db_create_test_bct is deprecated. Use BCT class: obj = bct.create(); obj.write_raw(); obj.write_graph()');

success = false;

%% Determine Output Path
if isempty(outputPath)
    try
        config = bioctree_config();
        outputPath = fullfile(config.DataPath, 'test_bioctree_standard.h5');
    catch
        outputPath = 'test_bioctree_standard.h5';
        if verbose
            fprintf('⚠ Could not load bioctree_config, using current directory\n');
        end
    end
end

% Check if file exists
if exist(outputPath, 'file') && ~overwrite
    if verbose
        fprintf('✓ Test BCT file already exists: %s\n', outputPath);
        fprintf('  Use ''Overwrite'', true to recreate\n');
    end
    success = true;
    return;
end

if verbose
    fprintf('=== Creating Standard Test BCT File ===\n');
    fprintf('Output file: %s\n', outputPath);
    fprintf('Configuration:\n');
    fprintf('  Icosphere level: %d\n', ico_level);
    fprintf('  Radius: %.2f\n', radius);
    fprintf('  Patch layers: %d\n', num_layers);
    fprintf('  Patch size range: %.1f%% - %.1f%%\n', patch_range(1)*100, patch_range(2)*100);
    fprintf('  Time steps: %d\n', T);
    fprintf('  Sampling rate: %.1f Hz\n', fs);
    fprintf('  Random seed: %d\n\n', seed);
end

%% Set Random Seed for Reproducibility
rng(seed);

try
    %% Step 1: Generate Icosphere Graph
    if verbose
        fprintf('Step 1: Creating icosphere graph...\n');
    end
    
    % Generate icosphere using build_icosphere
    G = build_icosphere(ico_level, radius);
    
    % Add temporal information
    G.jtv.T = T;
    G.jtv.fs = fs;
    G.jtv.dt = 1/fs;
    
    if verbose
        fprintf('  ✓ Icosphere created: %d vertices, %d faces\n', G.N, size(G.F, 1));
        fprintf('  ✓ Graph edges: %d\n', G.Ne);
        fprintf('  ✓ Surface area: %.4f (theoretical: %.4f)\n', ...
            sum(G.vertexArea), 4*pi*radius^2);
    end
    
    %% Step 2: Generate Multi-Layer Patch Signals
    if verbose
        fprintf('\nStep 2: Generating %d patch signal layers...\n', num_layers);
    end
    
    % Calculate patch sizes linearly spaced from min to max
    patch_sizes = linspace(patch_range(1), patch_range(2), num_layers);
    
    % Initialize signal matrix [N x T x num_layers]
    X = zeros(G.N, T, num_layers);
    layer_metadata = cell(num_layers, 1);
    
    for layer_idx = 1:num_layers
        current_patch_size = patch_sizes(layer_idx);
        
        if verbose
            fprintf('  Layer %d/%d: patch size %.1f%%...', layer_idx, num_layers, current_patch_size*100);
        end
        
        % Generate patch signal with temporal dynamics
        [layer_signal, layer_params] = generatePatchSignal(G, ...
            'patchSize', current_patch_size, ...
            'patchCenter', 'auto', ...
            'growthMode', 'grow', ...
            'growthRate', 0.1, ...  % Slow growth
            'patchValue', 1, ...
            'backgroundValue', 0, ...
            'seed', seed + layer_idx);  % Different seed per layer
        
        % Store signal
        X(:, :, layer_idx) = layer_signal;
        
        % Calculate actual patch size from signal
        actual_patch_size = sum(layer_signal(:, end) > 0);  % Count non-zero nodes in final time step
        
        % Store layer metadata
        layer_metadata{layer_idx} = struct(...
            'layer_id', layer_idx, ...
            'patch_size_pct', current_patch_size * 100, ...
            'patch_size_nodes', actual_patch_size, ...
            'patch_center_node', layer_params.patchCenter, ...
            'generation_params', layer_params);
        
        if verbose
            fprintf(' ✓ %d nodes\n', actual_patch_size);
        end
    end
    
    %% Step 3: Reshape for BCT format (combine layers into time dimension)
    if verbose
        fprintf('\nStep 3: Formatting data for BCT structure...\n');
    end
    
    % Reshape to [N x (T * num_layers)] - concatenate layers in time
    X_reshaped = reshape(X, G.N, T * num_layers);
    
    % Update temporal parameters
    G.jtv.T = T * num_layers;
    G.jtv.layer_info = layer_metadata;
    G.jtv.original_T_per_layer = T;
    G.jtv.num_layers = num_layers;
    
    if verbose
        fprintf('  ✓ Final signal size: [%d x %d]\n', size(X_reshaped));
        fprintf('  ✓ Total temporal samples: %d (%d per layer)\n', G.jtv.T, T);
    end
    
    %% Step 4: Prepare Data Structure for BCT Export
    if verbose
        fprintf('\nStep 4: Preparing analysis data structure...\n');
    end
    
    data_struct = struct();
    
    % Graph structure
    data_struct.graph = G;
    
    % Signal data
    data_struct.X = X_reshaped;
    
    % Metadata
    data_struct.metadata = struct();
    data_struct.metadata.description = 'Standard Bioctree test dataset with multi-layer patch signals';
    data_struct.metadata.creation_date = datestr(now);
    data_struct.metadata.signal_type = 'multi_layer_patch';
    data_struct.metadata.coordinate_system = 'cartesian_3d';
    data_struct.metadata.generation_seed = seed;
    data_struct.metadata.icosphere_level = ico_level;
    data_struct.metadata.sphere_radius = radius;
    data_struct.metadata.patch_layers = num_layers;
    data_struct.metadata.patch_size_range = patch_range;
    data_struct.metadata.time_steps_per_layer = T;
    data_struct.metadata.sampling_rate = fs;
    data_struct.metadata.layer_metadata = layer_metadata;
    
    if verbose
        fprintf('  ✓ Data structure prepared\n');
        fprintf('  ✓ Signal memory usage: %.2f MB\n', ...
            numel(X_reshaped) * 8 / 1024 / 1024);  % Assuming double precision
    end
    
    %% Step 5: Create Output Directory
    [output_dir, ~, ~] = fileparts(outputPath);
    if ~isempty(output_dir) && ~exist(output_dir, 'dir')
        mkdir(output_dir);
        if verbose
            fprintf('  ✓ Created output directory: %s\n', output_dir);
        end
    end
    
    % Issue deprecation warning
    warning('DB_CREATE_TEST_BCT:Deprecated', ['db_create_test_bct() is deprecated. ' ...
        'Use BCT class methods: bct.create() and bct object methods for data creation.']);
    
    %% Step 6: Export to BCT File using BCT class
    if verbose
        fprintf('\nStep 5: Exporting to BCT file...\n');
    end
    
    try
        % Create BCT file and add data using BCT class
        bct_obj = bct.create(outputPath);
        bct_obj.addGraph(data_struct.graph);
        bct_obj.addSignal(data_struct.X, 'signal');
        bct_obj.addSignal(data_struct.Xhat_gft, 'gft_coeffs');
        bct_obj.addMetadata(data_struct.metadata);
        
        % Add signal layers if they exist
        if isfield(data_struct, 'X_layers')
            layer_names = fieldnames(data_struct.X_layers);
            for i = 1:length(layer_names)
                bct_obj.addSignal(data_struct.X_layers.(layer_names{i}), layer_names{i});
            end
        end
        
        success = exist(outputPath, 'file') ~= 0;
    catch ME
        if verbose
            fprintf('✗ Error creating BCT file: %s\n', ME.message);
        end
        success = false;
    end
    
    if success
        fileInfo = dir(outputPath);
        if verbose
            fprintf('✓ Standard test BCT file created successfully!\n');
            fprintf('  File: %s\n', outputPath);
            fprintf('  Size: %.2f MB\n', fileInfo.bytes / 1024 / 1024);
            fprintf('  Contains: %d-vertex icosphere with %d patch signal layers\n', ...
                G.N, num_layers);
            fprintf('\nThis file is now the standard test dataset for bioctree functions.\n');
        end
    else
        if verbose
            fprintf('✗ Failed to create test BCT file\n');
        end
    end
    
catch ME
    if verbose
        fprintf('✗ Error creating test BCT file: %s\n', ME.message);
        fprintf('   Stack trace:\n');
        for i = 1:length(ME.stack)
            fprintf('     %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
        end
    end
    success = false;
end

end