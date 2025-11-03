function export_freesurfer_to_obj(pial_file, sphere_file, output_file, varargin)
%EXPORT_FREESURFER_TO_OBJ Export FreeSurfer surface to OBJ format with UV coordinates
%
% Usage:
%   export_freesurfer_to_obj(pial_file, sphere_file, output_file)
%   export_freesurfer_to_obj(pial_file, sphere_file, output_file, 'VertexColors', colors)
%   export_freesurfer_to_obj(pial_file, sphere_file, output_file, 'ScalarData', scalars)
%
% Inputs:
%   pial_file   - Path to pial/inflated surface file (e.g., 'lh.pial', 'lh.inflated')
%   sphere_file - Path to spherical registration file (e.g., 'lh.sphere.reg', 'lh.sphere')
%   output_file - Output OBJ file path
%   varargin    - Optional name-value pairs:
%                 'VertexColors', Nx3 RGB colors [0-1]
%                 'ScalarData', Nx1 scalar values
%                 'ColorMap', colormap for scalar data (default: 'viridis')
%
% FreeSurfer Spherical Parameterization:
%   - sphere_file provides the spherical coordinates for UV mapping
%   - pial_file provides the actual 3D geometry to render
%   - Both files must have the same vertex indexing (guaranteed by FreeSurfer)
%   - UV coordinates computed from sphere vertices as:
%     u = (atan2(y, x) / 2π) mod 1
%     v = asin(z)/π + 0.5

    % Parse optional arguments
    p = inputParser;
    addParameter(p, 'VertexColors', [], @(x) isempty(x) || (isnumeric(x) && size(x,2)==3));
    addParameter(p, 'ScalarData', [], @(x) isempty(x) || isnumeric(x));
    addParameter(p, 'ColorMap', 'viridis', @(x) ischar(x) || isstring(x));
    parse(p, varargin{:});
    
    vertex_colors = p.Results.VertexColors;
    scalar_data = p.Results.ScalarData;
    colormap_name = p.Results.ColorMap;
    
    fprintf('Loading FreeSurfer surfaces...\n');
    
    % Load pial surface (for geometry)
    fprintf('  Reading pial surface: %s\n', pial_file);
    [pial_vertices, pial_faces] = read_surf(pial_file);
    
    % Load sphere surface (for UV parameterization)
    fprintf('  Reading sphere surface: %s\n', sphere_file);
    [sphere_vertices, sphere_faces] = read_surf(sphere_file);
    
    % Verify vertex correspondence
    if size(pial_vertices, 1) ~= size(sphere_vertices, 1)
        error('Vertex count mismatch: pial=%d, sphere=%d', ...
              size(pial_vertices, 1), size(sphere_vertices, 1));
    end
    
    if size(pial_faces, 1) ~= size(sphere_faces, 1)
        error('Face count mismatch: pial=%d, sphere=%d', ...
              size(pial_faces, 1), size(sphere_faces, 1));
    end
    
    num_vertices = size(pial_vertices, 1);
    num_faces = size(pial_faces, 1);
    
    fprintf('  Loaded %d vertices, %d faces\n', num_vertices, num_faces);
    
    % Compute UV coordinates from sphere vertices
    fprintf('Computing UV coordinates from spherical parameterization...\n');
    [u, v] = compute_sphere_uv(sphere_vertices);
    
    % Handle vertex colors
    if ~isempty(scalar_data)
        if length(scalar_data) ~= num_vertices
            error('Scalar data length (%d) must match number of vertices (%d)', ...
                  length(scalar_data), num_vertices);
        end
        % Convert scalar data to colors
        vertex_colors = scalar_to_colors(scalar_data, colormap_name);
    end
    
    % Write OBJ file
    fprintf('Writing OBJ file: %s\n', output_file);
    write_obj_with_uv(pial_vertices, pial_faces, u, v, output_file, vertex_colors);
    
    fprintf('Successfully exported FreeSurfer surface to %s\n', output_file);
end

function [u, v] = compute_sphere_uv(sphere_vertices)
%COMPUTE_SPHERE_UV Compute UV coordinates from spherical vertices
%
% FreeSurfer spherical parameterization:
%   u = (atan2(y, x) / 2π) mod 1
%   v = asin(z)/π + 0.5

    x = sphere_vertices(:, 1);
    y = sphere_vertices(:, 2);
    z = sphere_vertices(:, 3);
    
    % Normalize to unit sphere (FreeSurfer spheres should already be normalized)
    norms = sqrt(x.^2 + y.^2 + z.^2);
    x = x ./ norms;
    y = y ./ norms;
    z = z ./ norms;
    
    % Clamp z values to valid range for asin to avoid NaN
    z = max(-1, min(1, z));
    
    % Compute UV coordinates
    u = mod(atan2(y, x) / (2 * pi), 1);  % [0, 1]
    v = asin(z) / pi + 0.5;              % [0, 1]
    
    % Handle numerical edge cases
    v = max(0, min(1, v));  % Clamp to [0, 1]
    
    fprintf('  UV range: u=[%.3f, %.3f], v=[%.3f, %.3f]\n', ...
            min(u), max(u), min(v), max(v));
end

function colors = scalar_to_colors(scalars, colormap_name)
%SCALAR_TO_COLORS Convert scalar values to RGB colors

    % Normalize scalars to [0, 1]
    scalar_min = min(scalars);
    scalar_max = max(scalars);
    
    if scalar_max > scalar_min
        scalars_norm = (scalars - scalar_min) / (scalar_max - scalar_min);
    else
        scalars_norm = zeros(size(scalars));
    end
    
    % Get colormap
    try
        cmap = colormap(colormap_name);
    catch
        warning('Unknown colormap %s, using viridis', colormap_name);
        cmap = viridis(256);
    end
    
    % Map to colors
    cmap_indices = round(scalars_norm * (size(cmap, 1) - 1)) + 1;
    cmap_indices = max(1, min(size(cmap, 1), cmap_indices));
    colors = cmap(cmap_indices, :);
end

function write_obj_with_uv(vertices, faces, u, v, filename, vertex_colors)
%WRITE_OBJ_WITH_UV Write OBJ file with UV coordinates and optional colors

    fid = fopen(filename, 'w');
    if fid == -1
        error('Could not open file %s for writing', filename);
    end
    
    try
        % Write header
        fprintf(fid, '# OBJ file exported from FreeSurfer surface\n');
        fprintf(fid, '# %d vertices, %d faces\n', size(vertices,1), size(faces,1));
        fprintf(fid, '# Includes UV coordinates from spherical parameterization\n');
        if ~isempty(vertex_colors)
            fprintf(fid, '# Includes vertex colors\n');
        end
        fprintf(fid, '\n');
        
        % Write vertices with optional colors
        fprintf('  Writing vertices...\n');
        if ~isempty(vertex_colors)
            for i = 1:size(vertices,1)
                fprintf(fid, 'v %.6f %.6f %.6f %.3f %.3f %.3f\n', ...
                        vertices(i,1), vertices(i,2), vertices(i,3), ...
                        vertex_colors(i,1), vertex_colors(i,2), vertex_colors(i,3));
            end
        else
            for i = 1:size(vertices,1)
                fprintf(fid, 'v %.6f %.6f %.6f\n', ...
                        vertices(i,1), vertices(i,2), vertices(i,3));
            end
        end
        
        fprintf(fid, '\n');
        
        % Write texture coordinates
        fprintf('  Writing UV coordinates...\n');
        for i = 1:length(u)
            fprintf(fid, 'vt %.6f %.6f\n', u(i), v(i));
        end
        
        fprintf(fid, '\n');
        
        % Write faces with UV indices (OBJ uses 1-based indexing)
        fprintf('  Writing faces...\n');
        for i = 1:size(faces,1)
            % Format: f v1/vt1 v2/vt2 v3/vt3
            fprintf(fid, 'f %d/%d %d/%d %d/%d\n', ...
                    faces(i,1), faces(i,1), ...
                    faces(i,2), faces(i,2), ...
                    faces(i,3), faces(i,3));
        end
        
    catch ME
        fclose(fid);
        rethrow(ME);
    end
    
    fclose(fid);
end

function [vertices, faces] = read_surf(filename)
%READ_SURF Read FreeSurfer surface file
%   Wrapper for FreeSurfer reading functions

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