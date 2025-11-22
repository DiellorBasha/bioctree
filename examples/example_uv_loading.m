%% Example: UV Parametrization - Now Optional and On-Demand
% Demonstrates the new UV loading behavior (faster by default)

clear; clc;

path = 'test-data\freesurfer\fsaverage\surf\lh.pial';

%% Method 1: Fast import (UV not computed - DEFAULT)
fprintf('=== Method 1: Default Import (NO UV) ===\n');
tic;
B1 = bct.io.import.mesh(path);
t_default = toc;
fprintf('Import time: %.3f seconds\n', t_default);
fprintf('UV populated: %s\n', string(~isempty(B1.Manifold.UV)));
fprintf('Manifold has %d vertices\n\n', B1.Manifold.N);

%% Method 2: Compute UV later when needed
fprintf('=== Method 2: Compute UV Later ===\n');
tic;
B2 = bct.io.import.mesh(path);
t_import = toc;
fprintf('Import time: %.3f seconds\n', t_import);

% Now compute UV when needed
fprintf('Computing UV parametrization...\n');
tic;
B2.Manifold.computeUV(path);
t_uv = toc;
fprintf('UV computation time: %.3f seconds\n', t_uv);
fprintf('Total time: %.3f seconds\n', t_import + t_uv);
fprintf('UV populated: %s\n', string(~isempty(B2.Manifold.UV)));
fprintf('UV size: [%d × %d]\n\n', size(B2.Manifold.UV, 1), size(B2.Manifold.UV, 2));

%% Method 3: Enable UV during import (slower, but convenient)
fprintf('=== Method 3: Import with ComputeUV=true ===\n');
tic;
B3 = bct.io.import.mesh(path, 'ComputeUV', true);
t_with_uv = toc;
fprintf('Import time (with UV): %.3f seconds\n', t_with_uv);
fprintf('UV populated: %s\n', string(~isempty(B3.Manifold.UV)));
fprintf('UV size: [%d × %d]\n\n', size(B3.Manifold.UV, 1), size(B3.Manifold.UV, 2));

%% Compare timings
fprintf('=== Performance Summary ===\n');
fprintf('Default (no UV):     %.3f s ← FASTEST\n', t_default);
fprintf('Import + UV later:   %.3f s (%.3f + %.3f)\n', t_import + t_uv, t_import, t_uv);
fprintf('Import with UV:      %.3f s\n', t_with_uv);
fprintf('\nSpeedup (default vs with UV): %.1fx faster\n', t_with_uv / t_default);

%% Alternative: Use populateUV function directly
fprintf('\n=== Alternative: Direct populateUV call ===\n');
B4 = bct.io.import.mesh(path);
bct.io.import.populateUV(B4.Manifold, path);
fprintf('UV populated via populateUV: %s\n', string(~isempty(B4.Manifold.UV)));

%% Verify UV values are consistent
fprintf('\n=== Verification ===\n');
if ~isempty(B2.Manifold.UV) && ~isempty(B3.Manifold.UV)
    uv_diff = max(abs(B2.Manifold.UV(:) - B3.Manifold.UV(:)));
    fprintf('Max UV difference between methods: %.2e\n', uv_diff);
    if uv_diff < 1e-10
        fprintf('✓ UV values identical across methods\n');
    end
end

%% Example: Check UV before using
fprintf('\n=== Example: Using checkUV ===\n');
fprintf('B1 has UV: %s\n', string(B1.Manifold.checkUV(false)));  % Returns false, no warning
fprintf('B2 has UV: %s\n', string(B2.Manifold.checkUV(false)));  % Returns true

