%% Test UV Parametrization from FreeSurfer Spherical Registration
% Tests automatic loading of .sphere.reg and computation of UV coordinates

clear all;
close all;

% Add toolbox to path
root = fileparts(pwd);
addpath(fullfile(root, 'toolbox'));

fprintf('=== Testing UV Parametrization Import ===\n\n');

%% Test 1: Check if test data exists
fprintf('Test 1: Checking for FreeSurfer test data...\n');

% Example paths (adjust based on your actual test data location)
test_paths = {
    fullfile('test-data', 'freesurfer', 'fsaverage', 'surf', 'lh.pial');
    fullfile('test-data', 'freesurfer', 'fsaverage', 'surf', 'rh.pial');
};

available_paths = {};
for i = 1:length(test_paths)
    if isfile(test_paths{i})
        available_paths{end+1} = test_paths{i};
        fprintf('  ✓ Found: %s\n', test_paths{i});
    else
        fprintf('  ✗ Not found: %s\n', test_paths{i});
    end
end

if isempty(available_paths)
    fprintf('\n  Note: No FreeSurfer test data found. Skipping tests.\n');
    fprintf('  Expected location: test-data/freesurfer/fsaverage/surf/\n\n');
    return;
end

fprintf('\n');

%% Test 2: Test findSphereReg function
fprintf('Test 2: Testing findSphereReg helper function...\n');

test_surf_path = available_paths{1};
sphere_reg_path = bct.io.import.findSphereReg(test_surf_path);

if ~isempty(sphere_reg_path)
    fprintf('  ✓ Found sphere.reg: %s\n', sphere_reg_path);
    fprintf('    File exists: %s\n', string(isfile(sphere_reg_path)));
else
    fprintf('  ✗ No sphere.reg found for: %s\n', test_surf_path);
end

fprintf('\n');

%% Test 3: Test UV computation from sphere
fprintf('Test 3: Testing computeUVFromSphere...\n');

if ~isempty(sphere_reg_path) && isfile(sphere_reg_path)
    try
        % Load sphere.reg
        sphere_raw = bct.io.in.readFreeSurferSurf(sphere_reg_path);
        fprintf('  Sphere vertices: %d\n', size(sphere_raw.V, 1));
        
        % Compute UV
        UV = bct.io.import.computeUVFromSphere(sphere_raw.V);
        
        fprintf('  ✓ UV computed: [%d × %d]\n', size(UV, 1), size(UV, 2));
        fprintf('    U range: [%.4f, %.4f]\n', min(UV(:,1)), max(UV(:,1)));
        fprintf('    V range: [%.4f, %.4f]\n', min(UV(:,2)), max(UV(:,2)));
        
        % Verify UV is in [0, 1] range
        assert(all(UV(:,1) >= 0 & UV(:,1) <= 1), 'U coordinates out of range');
        assert(all(UV(:,2) >= 0 & UV(:,2) <= 1), 'V coordinates out of range');
        fprintf('  ✓ UV coordinates within [0, 1] range\n');
        
    catch ME
        fprintf('  ✗ Error: %s\n', ME.message);
    end
else
    fprintf('  Skipped (no sphere.reg file)\n');
end

fprintf('\n');

%% Test 4: Test full import pipeline
fprintf('Test 4: Testing full import pipeline with UV...\n');

try
    B = bct.io.import.mesh(test_surf_path);
    
    fprintf('  ✓ Mesh imported\n');
    fprintf('    Vertices: %d\n', B.Manifold.N);
    fprintf('    Faces: %d\n', size(B.Manifold.F, 1));
    
    if ~isempty(B.Manifold.UV)
        fprintf('  ✓ UV parametrization loaded\n');
        fprintf('    UV dimensions: [%d × %d]\n', size(B.Manifold.UV, 1), size(B.Manifold.UV, 2));
        fprintf('    U range: [%.4f, %.4f]\n', min(B.Manifold.UV(:,1)), max(B.Manifold.UV(:,1)));
        fprintf('    V range: [%.4f, %.4f]\n', min(B.Manifold.UV(:,2)), max(B.Manifold.UV(:,2)));
        
        % Verify dimensions match
        assert(size(B.Manifold.UV, 1) == B.Manifold.N, 'UV dimensions mismatch');
        fprintf('  ✓ UV dimensions match vertex count\n');
    else
        fprintf('  Note: No UV parametrization (sphere.reg not found)\n');
    end
    
catch ME
    fprintf('  ✗ Error: %s\n', ME.message);
end

fprintf('\n');

%% Test 5: Visualize UV parametrization
if exist('B', 'var') && ~isempty(B.Manifold.UV)
    fprintf('Test 5: Visualizing UV parametrization...\n');
    
    try
        figure('Position', [100 100 1200 500]);
        
        % Panel 1: 3D mesh with UV as color
        subplot(1, 3, 1);
        trisurf(B.Manifold.F, B.Manifold.V(:,1), B.Manifold.V(:,2), B.Manifold.V(:,3), ...
            B.Manifold.UV(:,1), 'EdgeColor', 'none');
        axis equal off;
        view(3);
        colorbar;
        title('3D Mesh colored by U coordinate');
        colormap(gca, 'parula');
        
        subplot(1, 3, 2);
        trisurf(B.Manifold.F, B.Manifold.V(:,1), B.Manifold.V(:,2), B.Manifold.V(:,3), ...
            B.Manifold.UV(:,2), 'EdgeColor', 'none');
        axis equal off;
        view(3);
        colorbar;
        title('3D Mesh colored by V coordinate');
        colormap(gca, 'parula');
        
        % Panel 3: 2D UV space
        subplot(1, 3, 3);
        trisurf(B.Manifold.F, B.Manifold.UV(:,1), B.Manifold.UV(:,2), ...
            zeros(size(B.Manifold.UV, 1), 1), 'EdgeColor', [0.5 0.5 0.5], 'FaceAlpha', 0.5);
        view(2);
        axis equal tight;
        xlabel('U');
        ylabel('V');
        title('UV Parametrization Space');
        grid on;
        
        sgtitle('FreeSurfer Spherical Registration → UV Parametrization', ...
            'FontSize', 12, 'FontWeight', 'bold');
        
        fprintf('  ✓ Visualization created\n');
        
    catch ME
        fprintf('  ✗ Visualization error: %s\n', ME.message);
    end
end

fprintf('\n');

%% Summary
fprintf('=== Summary ===\n\n');
fprintf('Implementation:\n');
fprintf('  • Added UV property to Manifold class\n');
fprintf('  • Extended bct.io.import.mesh to auto-load .sphere.reg\n');
fprintf('  • Created findSphereReg helper to locate sphere files\n');
fprintf('  • Created computeUVFromSphere for UV calculation\n\n');

fprintf('Algorithm:\n');
fprintf('  theta = atan2(y, x)      // Azimuthal angle [-π, π]\n');
fprintf('  phi   = acos(z)          // Polar angle [0, π]\n');
fprintf('  u = (theta + π) / (2π)   // Normalize to [0, 1]\n');
fprintf('  v = phi / π              // Normalize to [0, 1]\n\n');

fprintf('Usage:\n');
fprintf('  path = ''test-data/freesurfer/fsaverage/surf/lh.pial'';\n');
fprintf('  B = bct.io.import.mesh(path);\n');
fprintf('  UV = B.Manifold.UV;  // [N × 2] UV coordinates\n\n');

