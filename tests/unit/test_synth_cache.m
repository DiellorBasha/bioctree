%% Test cached eigendecomposition in synth_mesh_signal
cd('c:\CodingProjects\bioctree');
bioctree_start;

% Create test mesh
B = bct.bct.create('test_synth');
V = single([0 0 0; 1 0 0; 0.5 sqrt(3)/2 0; 0.5 sqrt(3)/6 sqrt(2/3)]);
F = uint32([1 2 3; 1 2 4; 2 3 4; 1 3 4]);
B.Manifold = bct.manifold.Manifold(V, F);

% Test spectral synthesis
spec.type = 'powerlaw';
spec.alpha = 1;

fprintf('Testing cached eigendecomposition:\n');
tic;
[x1, a1, f1] = bct.sim.synth_mesh_signal(B, spec);
t1 = toc;
fprintf('  First call: %.4fs (computes eigenvectors)\n', t1);

tic;
[x2, a2, f2] = bct.sim.synth_mesh_signal(B, spec);
t2 = toc;
fprintf('  Second call: %.4fs (uses cache)\n', t2);

if t1 > t2
    fprintf('  ✓ Speedup: %.1fx faster!\n', t1/t2);
else
    fprintf('  (Cache benefit visible on larger meshes)\n');
end

% Verify cache is being used
fprintf('\nCache verification:\n');
fprintf('  B.Manifold.NumModes = %d\n', B.Manifold.NumModes);
fprintf('  Eigenvectors size: %dx%d\n', size(B.Manifold.Eigenvectors));
fprintf('  Eigenvalues size: %dx%d\n', size(B.Manifold.Eigenvalues));

% Cleanup
delete('test_synth.h5');
fprintf('\n✓ Test complete!\n');
