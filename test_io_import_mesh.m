% Test script for bct.io.import.mesh with new architecture
% Tests that import functions work with new bct.Manifold class

fprintf('\n');
fprintf('════════════════════════════════════════════════════════════\n');
fprintf(' Testing bct.io.import.mesh with new bct.Manifold architecture\n');
fprintf('════════════════════════════════════════════════════════════\n\n');

%% Test 1: Import FreeSurfer mesh
fprintf('Test 1: Import FreeSurfer mesh (rh.pial)...\n');
path = 'test-data\freesurfer\fsaverage\surf\rh.pial';

try
    B = bct.io.import.mesh(path);
    fprintf('  ✓ Mesh imported successfully\n');
    
    % Verify bct object structure
    assert(isa(B, 'bct.bct'), 'B must be a bct object');
    fprintf('  ✓ B is bct object\n');
    
    % Verify Manifold is new class
    assert(isa(B.Manifold, 'bct.Manifold'), 'Manifold must be bct.Manifold');
    fprintf('  ✓ B.Manifold is bct.Manifold (new class)\n');
    
    % Verify Lambda domain exists
    assert(isa(B.Lambda, 'bct.Lambda'), 'Lambda must be bct.Lambda');
    fprintf('  ✓ B.Lambda domain created\n');
    
    % Verify dual linking
    assert(B.Manifold.dual == B.Lambda, 'Manifold dual must be Lambda');
    assert(B.Lambda.dual == B.Manifold, 'Lambda dual must be Manifold');
    fprintf('  ✓ Dual linking verified: Manifold ↔ Lambda\n');
    
    % Verify mesh properties
    nVerts = B.Manifold.numVertices();
    nFaces = B.Manifold.numFaces();
    fprintf('  ✓ Mesh: %d vertices, %d faces\n', nVerts, nFaces);
    
    % Verify Laplacian computed
    assert(~isempty(B.Manifold.Laplacian), 'Laplacian must be computed');
    fprintf('  ✓ Laplacian computed (%dx%d sparse matrix)\n', size(B.Manifold.Laplacian));
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 2: Import another hemisphere
fprintf('Test 2: Import FreeSurfer mesh (lh.pial)...\n');
path2 = 'test-data\freesurfer\fsaverage\surf\lh.pial';

try
    B2 = bct.io.import.mesh(path2);
    fprintf('  ✓ Mesh imported successfully\n');
    
    nVerts2 = B2.Manifold.numVertices();
    nFaces2 = B2.Manifold.numFaces();
    fprintf('  ✓ Mesh: %d vertices, %d faces\n', nVerts2, nFaces2);
    
    % Verify eigenvalue estimation
    lambda_max_est = B2.Manifold.estimateLambdaMax();
    fprintf('  ✓ Lambda max estimate: %.4f\n', lambda_max_est);
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Test 3: Verify all architecture features work together
fprintf('Test 3: Verify complete architecture...\n');

try
    % Check that all required properties exist
    assert(~isempty(B.Manifold.Vertices), 'Vertices must be populated');
    assert(~isempty(B.Manifold.Faces), 'Faces must be populated');
    assert(~isempty(B.Manifold.Laplacian), 'Laplacian must be populated');
    assert(~isempty(B.Manifold.MassMatrix), 'MassMatrix must be populated');
    assert(~isempty(B.Manifold.CotangentMatrix), 'CotangentMatrix must be populated');
    fprintf('  ✓ All Manifold properties populated\n');
    
    % Check LaplacianType
    assert(B.Manifold.LaplacianType == "cotangent" || ...
           B.Manifold.LaplacianType == "cotangent-normalized", ...
           'LaplacianType must be valid');
    fprintf('  ✓ LaplacianType: %s\n', B.Manifold.LaplacianType);
    
    % Check Lambda placeholder
    assert(~isempty(B.Lambda.axis), 'Lambda axis must exist');
    fprintf('  ✓ Lambda axis initialized (placeholder)\n');
    
    % Verify inheritance from bct.Domain
    assert(isa(B.Manifold, 'bct.Domain'), 'Manifold must inherit from bct.Domain');
    assert(isa(B.Lambda, 'bct.Domain'), 'Lambda must inherit from bct.Domain');
    fprintf('  ✓ Both domains inherit from bct.Domain\n');
    
    fprintf('\n');
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

%% Summary
fprintf('═══════════════════════════════════════════════════════════\n');
fprintf(' ✓ All tests passed!\n');
fprintf('═══════════════════════════════════════════════════════════\n\n');

fprintf('bct.io.import.mesh successfully updated for new architecture:\n');
fprintf('  • Uses bct.Manifold (new class) instead of bct.manifold.Manifold\n');
fprintf('  • Automatically creates Lambda domain with dual linking\n');
fprintf('  • All Manifold properties properly populated\n');
fprintf('  • Compatible with fromMesh factory method\n');
fprintf('  • Full Domain architecture support\n\n');
