%% Test Brainstorm Import Functionality
% This script demonstrates the Brainstorm import capabilities

clear; close all;

fprintf('=== Testing Brainstorm Import ===\n\n');

% Test 1: Create mock Brainstorm data for testing
fprintf('1. Creating mock Brainstorm anatomy file...\n');
test_dir = 'test-data/brainstorm_mock';
if ~exist(test_dir, 'dir')
    mkdir(test_dir);
end

anat_dir = fullfile(test_dir, 'anat', 'sub-001');
if ~exist(anat_dir, 'dir')
    mkdir(anat_dir);
end

% Create mock cortex mesh (simplified icosphere)
[V, F] = icosphere(2);  % Small test mesh
V = V * 100;  % Scale to mm

% Mock Brainstorm structure
bstMesh = struct();
bstMesh.Comment = 'cortex_642V';
bstMesh.Vertices = V;
bstMesh.Faces = F;
bstMesh.Color = [];
bstMesh.VertConn = [];
bstMesh.VertNormals = [];
bstMesh.Curvature = [];
bstMesh.SulciMap = [];
bstMesh.Atlas = struct('Name', 'Desikan-Killiany', 'Scouts', []);
bstMesh.iAtlas = 1;
bstMesh.tess2mri_interp = [];
bstMesh.Reg = struct();
bstMesh.History = {};

% Save low and high resolution versions
save(fullfile(anat_dir, 'tess_cortex_pial_low.mat'), '-struct', 'bstMesh');
fprintf('   ✓ Created: %s\n', fullfile(anat_dir, 'tess_cortex_pial_low.mat'));

bstMesh.Comment = 'cortex_642V_high';
save(fullfile(anat_dir, 'tess_cortex_pial_high.mat'), '-struct', 'bstMesh');
fprintf('   ✓ Created: %s\n\n', fullfile(anat_dir, 'tess_cortex_pial_high.mat'));

% Test 2: Import with protocol directory path (auto-detect)
fprintf('2. Testing protocol directory import (auto-detect)...\n');
try
    B1 = bct.io.import.mesh(test_dir);
    fprintf('   ✓ Success: %d vertices, %d faces\n', size(B1.Manifold.V,1), size(B1.Manifold.F,1));
    fprintf('   ✓ Manifold Type: %s\n\n', B1.Manifold.Type);
catch ME
    fprintf('   ✗ Failed: %s\n\n', ME.message);
end

% Test 3: Import with subject specification
fprintf('3. Testing with explicit subject...\n');
try
    B2 = bct.io.import.mesh(test_dir, 'Subject', 'sub-001');
    fprintf('   ✓ Success: %d vertices, %d faces\n\n', size(B2.Manifold.V,1), size(B2.Manifold.F,1));
catch ME
    fprintf('   ✗ Failed: %s\n\n', ME.message);
end

% Test 4: Import high resolution
fprintf('4. Testing high resolution import...\n');
try
    B3 = bct.io.import.mesh(test_dir, 'Resolution', 'high');
    fprintf('   ✓ Success: %d vertices, %d faces\n\n', size(B3.Manifold.V,1), size(B3.Manifold.F,1));
catch ME
    fprintf('   ✗ Failed: %s\n\n', ME.message);
end

% Test 5: Direct file path
fprintf('5. Testing direct file path...\n');
try
    direct_path = fullfile(anat_dir, 'tess_cortex_pial_low.mat');
    B4 = bct.io.import.mesh(direct_path);
    fprintf('   ✓ Success: %d vertices, %d faces\n\n', size(B4.Manifold.V,1), size(B4.Manifold.F,1));
catch ME
    fprintf('   ✗ Failed: %s\n\n', ME.message);
end

% Test 6: Import as graph type
fprintf('6. Testing graph-type Manifold import...\n');
try
    B5 = bct.io.import.graph(test_dir);
    fprintf('   ✓ Success: %d vertices, %d edges\n', size(B5.Manifold.V,1), height(B5.Manifold.Edges));
    fprintf('   ✓ Manifold Type: %s\n\n', B5.Manifold.Type);
catch ME
    fprintf('   ✗ Failed: %s\n\n', ME.message);
end

% Test 7: Auto-format detection
fprintf('7. Testing auto-format detection...\n');
try
    B6 = bct.io.import.mesh(fullfile(anat_dir, 'tess_cortex_pial_low.mat'));
    fprintf('   ✓ Auto-detected as Brainstorm\n');
    fprintf('   ✓ Loaded: %d vertices, %d faces\n\n', size(B6.Manifold.V,1), size(B6.Manifold.F,1));
catch ME
    fprintf('   ✗ Failed: %s\n\n', ME.message);
end

fprintf('=== All Brainstorm Import Tests Complete ===\n');

%% Visualization (optional)
if exist('B1', 'var') && ~isempty(B1)
    fprintf('\nVisualization available. Run: surfaceMeshShow(surfaceMesh(B1.Manifold.V, B1.Manifold.F))\n');
end

