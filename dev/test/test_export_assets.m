% TEST_EXPORT_ASSETS Test asset export for documentation
%
% Simple test: export manifold mesh with normals/tangents for three.js viewer

%% Setup
fprintf('\n=== Testing 3D Asset Export for Three.js ===\n\n');

% Load canonical test manifold
fprintf('Loading test manifold...\n');
mesh = bct.data.load(Dataset="fsaverage6", Hemi="rh", Surface="pial");
M = bct.Manifold(mesh);
fprintf('  Vertices: %d\n', M.numVertices());
fprintf('  Faces: %d\n', M.numFaces());

%% Export manifold with geometry for viewing
fprintf('\n--- Exporting Manifold ---\n');

% Export with normals and tangents (needed for three.js lighting/rendering)
bct.manifold.exportForDocs(M, 'fsaverage_rh_pial', ...
    'ExportNormals', true, ...
    'ExportTangents', true, ...
    'ExportTopology', false, ...
    'ExportMetric', false);

% Verify files exist
objPath = fullfile('docs', 'docs', 'assets', 'models', 'fsaverage_rh_pial.obj');
jsonPath = fullfile('docs', 'docs', 'assets', 'models', 'fsaverage_rh_pial.json');

assert(isfile(objPath), 'OBJ file not created');
assert(isfile(jsonPath), 'JSON file not created');

fprintf('✓ Export successful!\n');

%% Summary
fprintf('\n=== 3D Asset Export Complete ===\n');
fprintf('Files created:\n');
fprintf('  OBJ:  %s\n', objPath);
fprintf('  JSON: %s\n', jsonPath);
fprintf('\nReady for three.js viewer!\n');
