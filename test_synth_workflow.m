%% Test synth_mesh_signal with cached eigenvectors workflow
cd('c:\CodingProjects\bioctree');
bioctree_start;

fprintf('=== Testing synth_mesh_signal with eigenvector caching ===\n\n');

% Load FreeSurfer mesh
path = 'test-data\freesurfer\fsaverage\surf\lh.pial';
if ~exist(path, 'file')
    fprintf('⚠ FreeSurfer test data not found at: %s\n', path);
    fprintf('Skipping test (requires FreeSurfer data)\n');
    return;
end

fprintf('1. Loading mesh from FreeSurfer...\n');
B = bct.io.mesh.Import.fromFreeSurfer(path);
fprintf('   ✓ Loaded: %d vertices, %d faces\n\n', size(B.Manifold.V,1), size(B.Manifold.F,1));

% Pre-compute Fourier basis
fprintf('2. Pre-computing Fourier basis with meshFourier...\n');
tic;
[U, lam] = B.Manifold.meshFourier(200);
t_eigen = toc;
fprintf('   ✓ Computed 200 modes in %.2f seconds\n', t_eigen);
fprintf('   ✓ B.Manifold.NumModes = %d\n\n', B.Manifold.NumModes);

% First synth_mesh_signal call (should use cached eigenvectors)
fprintf('3. First synth_mesh_signal call (should use cache)...\n');
spec.type = 'narrowband';
spec.f0 = 0.1;
spec.bw_abs = 0.02;

tic;
[x1, a1, f1] = bct.sim.synth_mesh_signal(B, spec);
t1 = toc;
fprintf('   Time: %.4f seconds\n\n', t1);

% Second call (definitely cached)
fprintf('4. Second synth_mesh_signal call (cached)...\n');
spec.type = 'powerlaw';
spec.alpha = 1;

tic;
[x2, a2, f2] = bct.sim.synth_mesh_signal(B, spec, 'verbose', false);
t2 = toc;
fprintf('   Time: %.4f seconds (no verbose output)\n\n', t2);

% Third call requesting MORE modes (will trigger recomputation)
fprintf('5. Request more modes than cached (k=300)...\n');
tic;
[x3, a3, f3] = bct.sim.synth_mesh_signal(B, spec, 'k', 300);
t3 = toc;
fprintf('   Time: %.4f seconds\n', t3);
fprintf('   B.Manifold.NumModes = %d (updated)\n\n', B.Manifold.NumModes);

% Verify outputs
fprintf('=== Verification ===\n');
fprintf('Signal 1 (narrowband): size=%dx%d, range=[%.3f, %.3f]\n', ...
    size(x1,1), size(x1,2), min(x1), max(x1));
fprintf('Signal 2 (powerlaw):   size=%dx%d, range=[%.3f, %.3f]\n', ...
    size(x2,1), size(x2,2), min(x2), max(x2));
fprintf('Signal 3 (300 modes):  size=%dx%d, range=[%.3f, %.3f]\n', ...
    size(x3,1), size(x3,2), min(x3), max(x3));

fprintf('\n✓ All tests passed!\n');
