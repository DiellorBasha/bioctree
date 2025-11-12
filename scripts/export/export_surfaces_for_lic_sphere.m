%% Export FreeSurfer surfaces to OBJ format with proper spherical UV mapping
% This script exports FreeSurfer cortical surfaces to OBJ format with 
% UV coordinates computed from spherical registration.
%
% FreeSurfer workflow:
% - Uses lh.sphere.reg (or lh.sphere) for UV parameterization
% - Uses lh.pial (or lh.inflated) for rendering geometry
% - Both surfaces have matching vertex indices
%
% UV parameterization from sphere coordinates:
%   u = (atan2(y, x) / 2π) mod 1
%   v = asin(z)/π + 0.5

clear; clc;

%% Configuration
FREESURFER_DIR = 'test-data/freesurfer/fsaverage/surf';
OUTPUT_DIR = 'output/lic_textures';

% Ensure output directory exists
if ~exist(OUTPUT_DIR, 'dir')
    mkdir(OUTPUT_DIR);
end

% Add FreeSurfer I/O functions to path
addpath('io/in');
addpath('io/out');

fprintf('=== FreeSurfer to OBJ Export with Spherical UV Mapping ===\n\n');

%% Process Left Hemisphere
fprintf('Processing Left Hemisphere...\n');

% File paths
lh_pial_file = fullfile(FREESURFER_DIR, 'lh.pial');
lh_sphere_file = fullfile(FREESURFER_DIR, 'lh.sphere.reg');
if ~exist(lh_sphere_file, 'file')
    lh_sphere_file = fullfile(FREESURFER_DIR, 'lh.sphere');
end
lh_curv_file = fullfile(FREESURFER_DIR, 'lh.curv');

% Check if files exist
if ~exist(lh_pial_file, 'file')
    error('Left hemisphere pial file not found: %s', lh_pial_file);
end
if ~exist(lh_sphere_file, 'file')
    error('Left hemisphere sphere file not found: %s', lh_sphere_file);
end

% Load curvature data if available
lh_curvature = [];
if exist(lh_curv_file, 'file')
    fprintf('  Loading curvature data: %s\n', lh_curv_file);
    lh_curvature = in_fs_read_curv(lh_curv_file);
end

% Export to OBJ with spherical UV mapping
lh_output_file = fullfile(OUTPUT_DIR, 'lh_pial_with_uv.obj');
fprintf('  Exporting LH to OBJ: %s\n', lh_output_file);

export_freesurfer_to_obj(lh_pial_file, lh_sphere_file, lh_output_file, ...
                        'ScalarData', lh_curvature);

fprintf('  ✓ Left hemisphere exported successfully\n\n');

%% Process Right Hemisphere
fprintf('Processing Right Hemisphere...\n');

% File paths
rh_pial_file = fullfile(FREESURFER_DIR, 'rh.pial');
rh_sphere_file = fullfile(FREESURFER_DIR, 'rh.sphere.reg');
if ~exist(rh_sphere_file, 'file')
    rh_sphere_file = fullfile(FREESURFER_DIR, 'rh.sphere');
end
rh_curv_file = fullfile(FREESURFER_DIR, 'rh.curv');

% Check if files exist
if ~exist(rh_pial_file, 'file')
    error('Right hemisphere pial file not found: %s', rh_pial_file);
end
if ~exist(rh_sphere_file, 'file')
    error('Right hemisphere sphere file not found: %s', rh_sphere_file);
end

% Load curvature data if available
rh_curvature = [];
if exist(rh_curv_file, 'file')
    fprintf('  Loading curvature data: %s\n', rh_curv_file);
    rh_curvature = in_fs_read_curv(rh_curv_file);
end

% Export to OBJ with spherical UV mapping
rh_output_file = fullfile(OUTPUT_DIR, 'rh_pial_with_uv.obj');
fprintf('  Exporting RH to OBJ: %s\n', rh_output_file);

export_freesurfer_to_obj(rh_pial_file, rh_sphere_file, rh_output_file, ...
                        'ScalarData', rh_curvature);

fprintf('  ✓ Right hemisphere exported successfully\n\n');

%% Export Additional Data for Python Pipeline
fprintf('Exporting additional data for Python pipeline...\n');

% Load surfaces for additional exports
fprintf('  Loading surface data...\n');
[lh_pial_vertices, lh_pial_faces] = read_surf(lh_pial_file);
[lh_sphere_vertices, ~] = read_surf(lh_sphere_file);

% Compute and save UV coordinates separately (for compatibility)
fprintf('  Computing UV coordinates...\n');
[u, v] = compute_sphere_uv(lh_sphere_vertices);
lh_uv_coords = [u, v];

uv_file = fullfile(OUTPUT_DIR, 'lh_uv_coords.npz');
% Save as .mat for MATLAB compatibility, Python will also read
save(fullfile(OUTPUT_DIR, 'lh_uv_coords.mat'), 'lh_uv_coords');

% Compute and save vertex normals
fprintf('  Computing vertex normals...\n');
lh_normals = compute_vertex_normals(lh_pial_vertices, lh_pial_faces);
save(fullfile(OUTPUT_DIR, 'vertex_normals_lh.mat'), 'lh_normals');

% Save curvature if available
if ~isempty(lh_curvature)
    save(fullfile(OUTPUT_DIR, 'lh_curvature.mat'), 'lh_curvature');
end

fprintf('  ✓ Additional data exported\n\n');

%% Summary
fprintf('=== Export Complete ===\n');
fprintf('Files exported to: %s\n', OUTPUT_DIR);
fprintf('\nGenerated files:\n');
fprintf('- lh_pial_with_uv.obj: Left hemisphere with embedded UV coordinates\n');
fprintf('- rh_pial_with_uv.obj: Right hemisphere with embedded UV coordinates\n');
fprintf('- lh_uv_coords.mat: UV coordinates for Python compatibility\n');
fprintf('- vertex_normals_lh.mat: Vertex normals\n');
if ~isempty(lh_curvature)
    fprintf('- lh_curvature.mat: Curvature data\n');
end

fprintf('\nNext steps:\n');
fprintf('1. Run Python LIC generation: python generate_lic_texture.py\n');
fprintf('2. Or run trimesh pipeline: python generate_lic_texture_trimesh.py\n');
fprintf('3. Load OBJ files with UV coordinates in three.js\n');

%% Helper Functions
function [u, v] = compute_sphere_uv(sphere_vertices)
    % Compute UV coordinates from spherical vertices using FreeSurfer convention
    x = sphere_vertices(:, 1);
    y = sphere_vertices(:, 2);
    z = sphere_vertices(:, 3);
    
    % Normalize to unit sphere (FreeSurfer spheres should already be normalized)
    norm_factor = sqrt(x.^2 + y.^2 + z.^2);
    x = x ./ norm_factor;
    y = y ./ norm_factor;
    z = z ./ norm_factor;
    
    % FreeSurfer spherical to UV mapping
    u = mod(atan2(y, x) / (2 * pi), 1);  % [0, 1]
    v = asin(z) / pi + 0.5;              % [0, 1]
    
    % Handle numerical edge cases
    v = max(0, min(1, v));  % Clamp to [0, 1]
end

function normals = compute_vertex_normals(vertices, faces)
    % Compute vertex normals from mesh
    num_vertices = size(vertices, 1);
    normals = zeros(num_vertices, 3);
    
    % Accumulate face normals to vertices
    for i = 1:size(faces, 1)
        v1 = vertices(faces(i, 1), :);
        v2 = vertices(faces(i, 2), :);
        v3 = vertices(faces(i, 3), :);
        
        % Face normal (unnormalized)
        face_normal = cross(v2 - v1, v3 - v1);
        
        % Add to vertex normals
        normals(faces(i, 1), :) = normals(faces(i, 1), :) + face_normal;
        normals(faces(i, 2), :) = normals(faces(i, 2), :) + face_normal;
        normals(faces(i, 3), :) = normals(faces(i, 3), :) + face_normal;
    end
    
    % Normalize
    norms = sqrt(sum(normals.^2, 2));
    normals = normals ./ (norms + eps);
end

function [vertices, faces] = read_surf(filename)
    % Read FreeSurfer surface file - wrapper function
    if exist('read_surf.m', 'file') == 2
        % Use FreeSurfer's read_surf if available
        [vertices, faces] = read_surf(filename);
    else
        % Use our custom reader
        addpath('../in');  % Add FreeSurfer readers path
        [vertices, faces] = in_fs_read_surf(filename);
    end
    
    % Ensure faces are 1-based
    if min(faces(:)) == 0
        faces = faces + 1;
    end
end