% Test BCT integration with Manifold object
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
    else
        fprintf('\n✗ Manifold object is empty\n');
    end
    
    % Test dependent properties still work
    fprintf('\nTesting dependent properties:\n');
    fprintf('  B.Vertices size: [%d x %d]\n', size(B.Vertices));
    fprintf('  B.Faces size: [%d x %d]\n', size(B.Faces));
    fprintf('  B.mesh class: %s\n', class(B.mesh));
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

%% Test 4: Backward compatibility - dependent properties
fprintf('\n\nTest 4: Testing backward compatibility...\n');
fprintf('  B2.Vertices delegates to Manifold.V: %s\n', ...
    mat2str(isequal(B2.Vertices, B2.Manifold.V)));
fprintf('  B2.Faces delegates to Manifold.F: %s\n', ...
    mat2str(isequal(B2.Faces, B2.Manifold.F)));

%% Test 5: Visualize eigenmode
if B2.Manifold.NumModes > 0
    fprintf('\n\nTest 5: Visualizing eigenmode...\n');
    figure('Name', 'BCT Manifold - First Eigenmode');
    trisurf(B2.Faces, B2.Vertices(:,1), B2.Vertices(:,2), B2.Vertices(:,3), ...
        B2.Manifold.Eigenvectors(:,1), 'EdgeColor', 'none');
    axis equal off;
    colorbar;
    title(sprintf('Mode 1 (\\lambda = %.4f)', B2.Manifold.Eigenvalues(1)));
    view(3); lighting gouraud; camlight;
    fprintf('✓ Visualization complete\n');
end

fprintf('\n\nAll tests completed!\n');
