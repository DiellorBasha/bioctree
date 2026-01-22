%% Minimal test for writeFromSchema
clear; clc;

fprintf('Testing bct.file.zarr.writeFromSchema...\n');

% Create simple schema
schema = struct();
schema.Attributes = struct();
schema.Attributes.name = 'test';

% Test function exists
fprintf('Checking if function exists...\n');
which bct.file.zarr.writeFromSchema

% Try to call it
fprintf('Calling function...\n');
try
    bct.file.zarr.writeFromSchema('test_minimal.zarr', schema, 'test');
    fprintf('✓ Function called successfully!\n');
catch ME
    fprintf('✗ Error: %s\n', ME.message);
    fprintf('  Identifier: %s\n', ME.identifier);
end

% Cleanup
if isfolder('test_minimal.zarr')
    rmdir('test_minimal.zarr', 's');
end
