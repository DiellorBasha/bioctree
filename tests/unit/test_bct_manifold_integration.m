% Test BCT integration with Manifold object
bioctree_start
clear; close all;

%% Test 1: Create BCT from FreeSurfer mesh
fprintf('Test 1: Loading FreeSurfer mesh...\n');
path = 'test-data\freesurfer\fsaverage\surf\lh.pial';

if exist(path, 'file')
    B = bct.io.import.mesh(path);
    
    fprintf('BCT object created:\n');
    fprintf('  N (vertices): %d\n', B.N);
    fprintf('  F (faces): %d\n', B.F);
    
    % Check if Manifold exists
    if ~isempty(B.Manifold)
        fprintf('\n✓ Manifold object created successfully!\n');
        fprintf('  Manifold.Type: %s\n', B.Manifold.Type);
        fprintf('  Manifold V size: [%d x %d]\n', size(B.Manifold.V));
        fprintf('  Manifold F size: [%d x %d]\n', size(B.Manifold.F));
        fprintf('  Manifold.N: %d\n', B.Manifold.N);
    else
        fprintf('\n✗ Manifold object is empty\n');
    end
else
    fprintf('FreeSurfer test data not found, skipping Test 1\n');
end

%% Test 2: Create BCT from simple icosphere
fprintf('\n\nTest 2: Creating BCT from icosphere...\n');
[V, F] = icosphere(3);

B2 = bct.bct.fromMesh(V, F);

fprintf('BCT object created from icosphere:\n');
fprintf('  N (vertices): %d\n', B2.N);
fprintf('  F (faces): %d\n', B2.F);

if ~isempty(B2.Manifold)
    fprintf('\n✓ Manifold object created successfully!\n');
    fprintf('  Manifold.Type: %s\n', B2.Manifold.Type);
    fprintf('  Manifold V size: [%d x %d]\n', size(B2.Manifold.V));
    fprintf('  Manifold F size: [%d x %d]\n', size(B2.Manifold.F));
else
    fprintf('\n✗ Manifold object is empty\n');
end

%% Test 3: Compute mesh Fourier basis via Manifold
fprintf('\n\nTest 3: Computing mesh Fourier basis...\n');
try
    [U, lam] = B2.Manifold.meshFourier(200);
    fprintf('✓ Computed %d Fourier modes\n', B2.Manifold.NumModes);
    fprintf('  Eigenvalue range: [%.6f, %.6f]\n', min(lam), max(lam));
    fprintf('  LaplacianType: %s\n', B2.Manifold.LaplacianType);
    fprintf('  MassMatrix size: [%d x %d]\n', size(B2.Manifold.MassMatrix));
catch ME
    fprintf('✗ Error computing Fourier basis: %s\n', ME.message);
end

%% Test 4: Test conversion functions
fprintf('\n\nTest 4: Testing conversion functions...\n');
sm = bct.io.convert.manifoldToSurfaceMesh(B2.Manifold);
fprintf('  surfaceMesh: %d vertices, %d faces\n', size(sm.Vertices,1), size(sm.Faces,1));
g = bct.io.convert.manifoldToMatlabGraph(B2.Manifold);
fprintf('  MATLAB graph: %d nodes, %d edges\n', numnodes(g), numedges(g));
Gsp = bct.io.convert.manifoldToGspGraph(B2.Manifold);
fprintf('  GSP graph: N=%d, W is %dx%d\n', Gsp.N, size(Gsp.W,1), size(Gsp.W,2));

%% Test 5: Visualize eigenmode
if B2.Manifold.NumModes > 0
    fprintf('\n\nTest 5: Visualizing eigenmode...\n');
    figure('Name', 'BCT Manifold - First Eigenmode');
    trisurf(B2.Manifold.F, B2.Manifold.V(:,1), B2.Manifold.V(:,2), B2.Manifold.V(:,3), ...
        B2.Manifold.Eigenvectors(:,1), 'EdgeColor', 'none');
    axis equal off;
    colorbar;
    title(sprintf('Mode 1 (\\lambda = %.4f)', B2.Manifold.Eigenvalues(1)));
    view(3); lighting gouraud; camlight;
    fprintf('✓ Visualization complete\n');
end

%% Test 6: Test Time property
fprintf('\n\nTest 6: Testing Time property...\n');
% Time property should be empty by default
if isempty(B2.Manifold.Time)
    fprintf('✓ Time property is empty by default\n');
else
    fprintf('✗ Time property should be empty by default\n');
end

% Create a Manifold with Time information
fprintf('Creating Manifold with Time property...\n');
M = bct.manifold.Manifold(V, F);
M.Time = bct.manifold.Time(1000, 250);  % 1000 time points at 250 Hz

if ~isempty(M.Time)
    fprintf('✓ Time property set successfully\n');
    fprintf('  T: %d time points\n', M.Time.T);
    fprintf('  fs: %.2f Hz\n', M.Time.fs);
    fprintf('  Duration: %.4f seconds\n', M.Time.get_duration());
    fprintf('  Nyquist: %.2f Hz\n', M.Time.get_nyquist_freq());
else
    fprintf('✗ Failed to set Time property\n');
end

fprintf('\n\nAll tests completed!\n');

