% debug_face_indices.m
% Debug script to check face indices in our FreeSurfer data

fprintf('Debugging FreeSurfer face indices\n');
fprintf('=================================\n\n');

% Load the data
combined_data = load('test-data/meshes/fsaverage/fsaverage_pial_surfaces.mat');
subject = combined_data.subject;

% Check LH data
V_lh = subject.lh.pial.vertices;
F_lh = subject.lh.pial.faces;

fprintf('LH Pial Data:\n');
fprintf('  - Vertices: %d x %d\n', size(V_lh));
fprintf('  - Faces: %d x %d\n', size(F_lh));
fprintf('  - Min vertex index in faces: %d\n', min(F_lh(:)));
fprintf('  - Max vertex index in faces: %d\n', max(F_lh(:)));
fprintf('  - Number of vertices: %d\n', size(V_lh, 1));

% Check if indices are 0-based or 1-based
if min(F_lh(:)) == 0
    fprintf('  → Face indices are 0-based (FreeSurfer format)\n');
    fprintf('  → Need to add 1 for MATLAB indexing\n');
    F_lh_corrected = F_lh + 1;
else
    fprintf('  → Face indices are 1-based (MATLAB format)\n');
    F_lh_corrected = F_lh;
end

fprintf('\nCorrected LH face indices:\n');
fprintf('  - Min: %d, Max: %d\n', min(F_lh_corrected(:)), max(F_lh_corrected(:)));

% Check a few face examples
fprintf('\nFirst 5 faces (original):\n');
disp(F_lh(1:5, :));

fprintf('First 5 faces (corrected):\n');
disp(F_lh_corrected(1:5, :));

% Check RH data too
V_rh = subject.rh.pial.vertices;
F_rh = subject.rh.pial.faces;

fprintf('\nRH Pial Data:\n');
fprintf('  - Vertices: %d x %d\n', size(V_rh));
fprintf('  - Faces: %d x %d\n', size(F_rh));
fprintf('  - Min vertex index in faces: %d\n', min(F_rh(:)));
fprintf('  - Max vertex index in faces: %d\n', max(F_rh(:)));

% Test creating a simple surfaceMesh
fprintf('\nTesting surfaceMesh creation:\n');
try
    % Try with corrected indices
    test_mesh = surfaceMesh(V_lh, F_lh_corrected);
    fprintf('✓ Successfully created surfaceMesh with corrected indices\n');
    fprintf('  - Mesh vertices: %d\n', size(test_mesh.Vertices, 1));
    fprintf('  - Mesh faces: %d\n', size(test_mesh.Faces, 1));
    
    % Clean up
    clear test_mesh;
    
catch ME
    fprintf('✗ Error creating surfaceMesh: %s\n', ME.message);
end