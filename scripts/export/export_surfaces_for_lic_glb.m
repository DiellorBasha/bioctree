%% Export FreeSurfer surfaces for LIC processing (GLB version)
% This script exports FreeSurfer surfaces to both OBJ and GLB formats
% GLB format embeds UV coordinates and can include LIC textures

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

fprintf('=== Exporting FreeSurfer Surfaces for LIC Processing (GLB Format) ===\n');

%% Load FreeSurfer subject data
fprintf('\nLoading FreeSurfer subject: %s\n', subject_name);
subject = in_fs_read_subject(subject_dir, subject_name);

%% Process left hemisphere
fprintf('\n--- Processing Left Hemisphere ---\n');

% Get surface data
V_pial = subject.lh.pial.vertices;
F_pial = subject.lh.pial.faces;
V_sphere = subject.lh.sphere.vertices;

% Compute UV coordinates from sphere
fprintf('Computing UV coordinates from sphere surface...\n');
uv_coords = compute_uv_from_sphere(V_sphere);
fprintf('UV range: u=[%.3f, %.3f], v=[%.3f, %.3f]\n', ...
        min(uv_coords(:,1)), max(uv_coords(:,1)), ...
        min(uv_coords(:,2)), max(uv_coords(:,2)));

% Compute vertex normals
fprintf('Computing vertex normals...\n');
normals = compute_vertex_normals(V_pial, F_pial);

% Export to GLB with UV coordinates
glb_file = fullfile(output_dir, 'lh_pial_with_uv.glb');
export_freesurfer_to_glb(V_pial, F_pial, glb_file, ...
                        'UVCoords', uv_coords, ...
                        'Normals', normals);

% Also export sphere for reference
sphere_glb_file = fullfile(output_dir, 'lh_sphere.glb');
export_freesurfer_to_glb(V_sphere, F_pial, sphere_glb_file, ...
                        'UVCoords', uv_coords, ...
                        'Normals', normals);

% Export with scalar data (curvature) as vertex colors
if isfield(subject.lh, 'curv') && ~isempty(subject.lh.curv.data)
    fprintf('Adding curvature data as vertex colors...\n');
    curv_data = subject.lh.curv.data;
    
    % Normalize curvature to [0,1] for colors
    curv_norm = (curv_data - min(curv_data)) / (max(curv_data) - min(curv_data));
    
    % Create colormap (blue for negative, red for positive curvature)
    colors = zeros(length(curv_norm), 3);
    colors(:,1) = curv_norm;  % Red channel
    colors(:,3) = 1 - curv_norm;  % Blue channel
    
    glb_curv_file = fullfile(output_dir, 'lh_pial_with_curvature.glb');
    export_freesurfer_to_glb(V_pial, F_pial, glb_curv_file, ...
                            'UVCoords', uv_coords, ...
                            'Normals', normals, ...
                            'Colors', colors, ...
                            'Scalars', curv_data);
end

%% Process right hemisphere
fprintf('\n--- Processing Right Hemisphere ---\n');

% Get surface data
V_pial_rh = subject.rh.pial.vertices;
F_pial_rh = subject.rh.pial.faces;
V_sphere_rh = subject.rh.sphere.vertices;

% Compute UV coordinates from sphere
uv_coords_rh = compute_uv_from_sphere(V_sphere_rh);
normals_rh = compute_vertex_normals(V_pial_rh, F_pial_rh);

% Export to GLB
glb_file_rh = fullfile(output_dir, 'rh_pial_with_uv.glb');
export_freesurfer_to_glb(V_pial_rh, F_pial_rh, glb_file_rh, ...
                        'UVCoords', uv_coords_rh, ...
                        'Normals', normals_rh);

%% Export combined bilateral mesh
fprintf('\n--- Creating Bilateral Mesh ---\n');

% Combine left and right hemispheres
nL = size(V_pial, 1);
V_bilateral = [V_pial; V_pial_rh];
F_bilateral = [F_pial; F_pial_rh + nL];  % Offset right hemisphere face indices

% Combine UV coordinates (offset RH to avoid overlap)
uv_bilateral = [uv_coords; uv_coords_rh + [0.5, 0]];  % Offset RH by 0.5 in U
uv_bilateral(:,1) = mod(uv_bilateral(:,1), 1.0);  % Wrap around

% Combine normals
normals_bilateral = [normals; normals_rh];

% Export bilateral GLB
bilateral_glb_file = fullfile(output_dir, 'bilateral_pial_with_uv.glb');
export_freesurfer_to_glb(V_bilateral, F_bilateral, bilateral_glb_file, ...
                        'UVCoords', uv_bilateral, ...
                        'Normals', normals_bilateral);

%% Save MATLAB data for Python processing
fprintf('\n--- Saving data for Python processing ---\n');

% Save vertex data
vertex_data_file = fullfile(output_dir, 'freesurfer_vertex_data.mat');
save(vertex_data_file, 'V_pial', 'F_pial', 'V_sphere', 'uv_coords', 'normals', ...
     'V_pial_rh', 'F_pial_rh', 'V_sphere_rh', 'uv_coords_rh', 'normals_rh', ...
     'V_bilateral', 'F_bilateral', 'uv_bilateral', 'normals_bilateral');
fprintf('Saved vertex data to %s\n', vertex_data_file);

% Save curvature and other scalar data
if isfield(subject.lh, 'curv')
    scalar_data.lh_curvature = subject.lh.curv.data;
end
if isfield(subject.rh, 'curv')
    scalar_data.rh_curvature = subject.rh.curv.data;
end
if isfield(subject.lh, 'thickness')
    scalar_data.lh_thickness = subject.lh.thickness.data;
end
if isfield(subject.rh, 'thickness')
    scalar_data.rh_thickness = subject.rh.thickness.data;
end
if isfield(subject.lh, 'area')
    scalar_data.lh_area = subject.lh.area.data;
end
if isfield(subject.rh, 'area')
    scalar_data.rh_area = subject.rh.area.data;
end

scalar_data_file = fullfile(output_dir, 'freesurfer_scalar_data.mat');
save(scalar_data_file, 'scalar_data');
fprintf('Saved scalar data to %s\n', scalar_data_file);

%% Verification
fprintf('\n--- Verification ---\n');

% Check file sizes
files = {
    'lh_pial_with_uv.glb'
    'rh_pial_with_uv.glb'
    'bilateral_pial_with_uv.glb'
    'lh_sphere.glb'
};

if exist('glb_curv_file', 'var')
    files{end+1} = 'lh_pial_with_curvature.glb';
end

for i = 1:length(files)
    filepath = fullfile(output_dir, files{i});
    if exist(filepath, 'file')
        info = dir(filepath);
        fprintf('✓ %s: %.2f MB\n', files{i}, info.bytes / 1024 / 1024);
    else
        fprintf('✗ %s: Not found\n', files{i});
    end
end

% Check vertex counts
fprintf('\nVertex counts:\n');
fprintf('LH: %d vertices, %d faces\n', size(V_pial, 1), size(F_pial, 1));
fprintf('RH: %d vertices, %d faces\n', size(V_pial_rh, 1), size(F_pial_rh, 1));
fprintf('Bilateral: %d vertices, %d faces\n', size(V_bilateral, 1), size(F_bilateral, 1));

fprintf('\n=== GLB Export Complete ===\n');
fprintf('Files exported to: %s\n', output_dir);

fprintf('\nNext steps:\n');
fprintf('1. Run Python LIC pipeline with GLB files:\n');
fprintf('   python generate_lic_texture_glb.py\n');
fprintf('2. GLB files can be loaded directly in three.js with UV coordinates\n');
fprintf('3. LIC textures can be embedded in GLB or loaded separately\n');

%% Helper functions
function uv_coords = compute_uv_from_sphere(sphere_vertices)
    % Compute UV coordinates from spherical surface using FreeSurfer convention
    % 
    % FreeSurfer spherical parameterization:
    %   u = (atan2(y, x) / 2π) mod 1
    %   v = asin(z)/π + 0.5
    %
    % This maps the sphere to a texture where:
    % - u=0 corresponds to -π longitude (negative x-axis)
    % - u=0.5 corresponds to 0 longitude (positive x-axis)  
    % - v=0 corresponds to -π/2 latitude (south pole)
    % - v=1 corresponds to +π/2 latitude (north pole)
    
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
    
    % Handle numerical edge cases for poles
    v = max(0, min(1, v));  % Clamp to [0, 1]
    
    uv_coords = [u, v];
end

function normals = compute_vertex_normals(vertices, faces)
    % Compute vertex normals from surface mesh
    nv = size(vertices, 1);
    normals = zeros(nv, 3);
    
    % Accumulate face normals to vertices
    for i = 1:size(faces, 1)
        v1 = vertices(faces(i,1), :);
        v2 = vertices(faces(i,2), :);
        v3 = vertices(faces(i,3), :);
        
        % Face normal
        fn = cross(v2 - v1, v3 - v1);
        
        % Add to each vertex
        normals(faces(i,1), :) = normals(faces(i,1), :) + fn;
        normals(faces(i,2), :) = normals(faces(i,2), :) + fn;
        normals(faces(i,3), :) = normals(faces(i,3), :) + fn;
    end
    
    % Normalize
    norm_lengths = sqrt(sum(normals.^2, 2));
    normals = normals ./ (norm_lengths + eps);
end