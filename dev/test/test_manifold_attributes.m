%% Test Manifold.Attributes structure
clear; clc;

fprintf('Testing Manifold schema structure...\n\n');

% Load manifold
M = bct.data.load('Dataset', 'fsaverage6', 'Hemi', 'rh', 'Surface', 'pial');
fprintf('Loaded manifold: %d vertices\n\n', size(M.Vertices, 1));

% Check what Attributes contains
fprintf('M.Attributes fields:\n');
if isfield(M, 'Attributes')
    disp(M.Attributes)
else
    fprintf('  ERROR: No Attributes field!\n');
end

% Try to write
fprintf('\nAttempting write...\n');
zarrPath = 'test_debug.zarr';
if isfolder(zarrPath)
    rmdir(zarrPath, 's');
end

try
    schema = M.Attributes;
    fprintf('Schema type: %s\n', class(schema));
    fprintf('Schema is struct: %d\n', isstruct(schema));
    
    bct.file.zarr.writeFromSchema(zarrPath, schema, 'manifold');
    fprintf('✓ Write successful!\n');
catch ME
    fprintf('✗ Error: %s\n', ME.message);
    fprintf('  Stack:\n');
    for i = 1:length(ME.stack)
        fprintf('    %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
end

% Cleanup
if isfolder(zarrPath)
    rmdir(zarrPath, 's');
end
