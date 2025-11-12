%% Export FreeSurfer surfaces to OBJ for LIC processing
% This script exports lh.pial and lh.sphere surfaces to OBJ format
% for use in the Python LIC pipeline

clear; clc;

% Define paths
subject_dir = 'C:\CodingProjects\bioctree\test-data\freesurfer';
subject_name = 'fsaverage';
output_dir = 'C:\CodingProjects\bioctree\output\lic_textures';

% Create output directory if it doesn't exist
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% Add required paths
addpath('io/in');
addpath('io/out');

fprintf('=== Exporting FreeSurfer Surfaces for LIC Processing ===\n');

%% Load FreeSurfer subject data
fprintf('\nLoading FreeSurfer subject: %s\n', subject_name);
subject = in_fs_read_subject(subject_dir, subject_name);

%% Export left hemisphere surfaces
fprintf('\n--- Exporting Left Hemisphere ---\n');

% Export pial surface (cortical geometry for rendering)
pial_file = fullfile(output_dir, 'lh_pial.obj');
export_freesurfer_to_obj(subject.lh.pial.vertices, subject.lh.pial.faces, pial_file);

% Export sphere surface (for UV parameterization)
sphere_file = fullfile(output_dir, 'lh_sphere.obj');
export_freesurfer_to_obj(subject.lh.sphere.vertices, subject.lh.sphere.faces, sphere_file);

% Also export inflated surface (alternative geometry)
inflated_file = fullfile(output_dir, 'lh_inflated.obj');
if isfield(subject.lh, 'orig')  % Use orig as proxy for inflated if available
    export_freesurfer_to_obj(subject.lh.orig.vertices, subject.lh.orig.faces, inflated_file);
    fprintf('Note: Using orig surface as inflated surface\n');
end

%% Export right hemisphere surfaces
fprintf('\n--- Exporting Right Hemisphere ---\n');

% Export pial surface
pial_file_rh = fullfile(output_dir, 'rh_pial.obj');
export_freesurfer_to_obj(subject.rh.pial.vertices, subject.rh.pial.faces, pial_file_rh);

% Export sphere surface
sphere_file_rh = fullfile(output_dir, 'rh_sphere.obj');
export_freesurfer_to_obj(subject.rh.sphere.vertices, subject.rh.sphere.faces, sphere_file_rh);

% Also export inflated surface
inflated_file_rh = fullfile(output_dir, 'rh_inflated.obj');
if isfield(subject.rh, 'orig')
    export_freesurfer_to_obj(subject.rh.orig.vertices, subject.rh.orig.faces, inflated_file_rh);
end

%% Verify vertex counts match between surfaces
fprintf('\n--- Verification ---\n');

% Check LH
lh_pial_verts = size(subject.lh.pial.vertices, 1);
lh_sphere_verts = size(subject.lh.sphere.vertices, 1);
fprintf('LH: Pial vertices = %d, Sphere vertices = %d', lh_pial_verts, lh_sphere_verts);
if lh_pial_verts == lh_sphere_verts
    fprintf(' ✓ Match\n');
else
    fprintf(' ✗ Mismatch!\n');
end

% Check RH
rh_pial_verts = size(subject.rh.pial.vertices, 1);
rh_sphere_verts = size(subject.rh.sphere.vertices, 1);
fprintf('RH: Pial vertices = %d, Sphere vertices = %d', rh_pial_verts, rh_sphere_verts);
if rh_pial_verts == rh_sphere_verts
    fprintf(' ✓ Match\n');
else
    fprintf(' ✗ Mismatch!\n');
end

%% Export some sample data for testing
fprintf('\n--- Exporting sample data ---\n');

% Export curvature data for potential use as scalar field
curv_lh = subject.lh.curv.data;
curv_rh = subject.rh.curv.data;

% Save as NPZ for Python
curv_file = fullfile(output_dir, 'curvature_data.mat');
save(curv_file, 'curv_lh', 'curv_rh');
fprintf('Saved curvature data to %s\n', curv_file);

% Export vertex normals if available (computed from surfaces)
V_lh = subject.lh.pial.vertices;
F_lh = subject.lh.pial.faces;

% Compute vertex normals for LH pial surface
fprintf('Computing vertex normals for LH pial surface...\n');
normals_lh = compute_vertex_normals(V_lh, F_lh);

% Save normals
normals_file = fullfile(output_dir, 'vertex_normals_lh.mat');
save(normals_file, 'normals_lh');
fprintf('Saved LH vertex normals to %s\n', normals_file);

fprintf('\n=== Export Complete ===\n');
fprintf('Files exported to: %s\n', output_dir);
fprintf('\nNext steps:\n');
fprintf('1. Run the Python LIC pipeline with the exported OBJ files\n');
fprintf('2. Use lh_pial.obj for geometry and lh_sphere.obj for UV mapping\n');
fprintf('3. The generated LIC texture can be applied in three.js\n');

%% Helper function to compute vertex normals
function normals = compute_vertex_normals(vertices, faces)
    % Compute vertex normals from face normals
    nv = size(vertices, 1);
    nf = size(faces, 1);
    
    % Initialize normals
    normals = zeros(nv, 3);
    
    % Compute face normals and accumulate to vertices
    for i = 1:nf
        v1 = vertices(faces(i,1), :);
        v2 = vertices(faces(i,2), :);
        v3 = vertices(faces(i,3), :);
        
        % Face normal
        fn = cross(v2 - v1, v3 - v1);
        
        % Add to each vertex of the face
        normals(faces(i,1), :) = normals(faces(i,1), :) + fn;
        normals(faces(i,2), :) = normals(faces(i,2), :) + fn;
        normals(faces(i,3), :) = normals(faces(i,3), :) + fn;
    end
    
    % Normalize
    norm_lengths = sqrt(sum(normals.^2, 2));
    normals = normals ./ (norm_lengths + eps);
end