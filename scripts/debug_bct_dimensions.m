%% Debug BCT write_raw_layers issue
clear; close all;

% Add bioctree to path if needed
if ~exist('bct.bct', 'class')
    addpath(genpath('.'));
end

fprintf('Debug: BCT write_raw_layers dimension issue\n');

% Create test file
test_file = fullfile(tempdir, 'debug_bct.h5');
if exist(test_file, 'file')
    delete(test_file);
end

B = bct.bct.create(test_file);

% Test 1: Simple case - create some test data
T = 1; N = 5; L = 1;
fprintf('Test dimensions: T=%d, N=%d, L=%d\n', T, N, L);

% Create test data
XLTN = single(rand(L, T, N));  % 1×1×5
fprintf('XLTN dimensions: %s\n', mat2str(size(XLTN)));

% Test what squeeze does
squeezed = squeeze(XLTN(1,:,:));
fprintf('squeeze(XLTN(1,:,:)) dimensions: %s\n', mat2str(size(squeezed)));
fprintf('Expected: %dx%d\n', T, N);

% Check if this is the issue
if isequal(size(squeezed), [T, N])
    fprintf('✓ Squeeze works correctly\n');
else
    fprintf('✗ Squeeze problem - got %s, expected %dx%d\n', mat2str(size(squeezed)), T, N);
    % Try to fix
    if isvector(squeezed) && numel(squeezed) == N
        fixed = reshape(squeezed, T, N);
        fprintf('Fixed with reshape: %s\n', mat2str(size(fixed)));
    end
end

% Test 2: Larger case
T = 100; N = 5; L = 1;
fprintf('\nTest 2 dimensions: T=%d, N=%d, L=%d\n', T, N, L);

XLTN2 = single(rand(L, T, N));  % 1×100×5
fprintf('XLTN2 dimensions: %s\n', mat2str(size(XLTN2)));

squeezed2 = squeeze(XLTN2(1,:,:));
fprintf('squeeze(XLTN2(1,:,:)) dimensions: %s\n', mat2str(size(squeezed2)));
fprintf('Expected: %dx%d\n', T, N);

if isequal(size(squeezed2), [T, N])
    fprintf('✓ Squeeze works correctly for larger case\n');
else
    fprintf('✗ Squeeze problem for larger case\n');
end

% Cleanup
delete(test_file);