% example_sphere_sulc_usage.m - Example of using sphere and sulc data
%
% This example shows how to use the enhanced FreeSurfer reader
% to access spherical coordinate systems and sulcal depth data

clear; clc;

fprintf('Example: Using spherical surfaces and sulcal depth data\n\n');

% Add the enhanced reader to path
addpath('io/in');

% Configure to load sphere surfaces and morphometric data
params = struct();
params.surface_list = {'orig', 'pial', 'sphere', 'sphere.reg'};
params.curv_list = {'curv', 'thickness', 'sulc', 'area'};
params.annotation_list = {'aparc'};
params.verbose = 1;

% Load FreeSurfer subject data
try
    fprintf('Loading FreeSurfer data with sphere and sulc support...\n');
    subj = in_fs_read_subject('test-data\freesurfer', 'fsaverage', params);
    
    % Example 1: Access original and spherical surfaces
    fprintf('\n=== Accessing Surface Data ===\n');
    
    % Find surfaces by name
    lh_surfaces = subj.lh.surface;
    sphere_idx = [];
    orig_idx = [];
    
    for i = 1:length(lh_surfaces)
        if strcmp(lh_surfaces{i}.name, 'sphere')
            sphere_idx = i;
            fprintf('Found lh.sphere at index %d\n', i);
        elseif strcmp(lh_surfaces{i}.name, 'orig')
            orig_idx = i;
            fprintf('Found lh.orig at index %d\n', i);
        end
    end
    
    if ~isempty(sphere_idx) && ~isempty(orig_idx)
        sphere_surf = lh_surfaces{sphere_idx};
        orig_surf = lh_surfaces{orig_idx};
        
        fprintf('\nSphere surface: %d vertices, %d faces\n', ...
            size(sphere_surf.vertices,1), size(sphere_surf.faces,1));
        fprintf('Original surface: %d vertices, %d faces\n', ...
            size(orig_surf.vertices,1), size(orig_surf.faces,1));
        
        % Spherical coordinates are useful for:
        fprintf('\nSpherical coordinates can be used for:\n');
        fprintf('- Cortical unfolding and flattening\n');
        fprintf('- Inter-subject registration\n');
        fprintf('- Template mapping\n');
        fprintf('- Geodesic distance calculations\n');
    end
    
    % Example 2: Access morphometric data
    fprintf('\n=== Accessing Morphometric Data ===\n');
    
    lh_curv = subj.lh;
    
    % Check for different data types
    data_types = {'curv', 'sulc', 'thickness', 'area'};
    for i = 1:length(data_types)
        data_type = data_types{i};
        if isfield(lh_curv, data_type)
            data_values = lh_curv.(data_type).data;
            fprintf('Found %s data at index: subj.lh.%s.data\n', data_type, data_type);
            fprintf('  Values: %d, Range: %.3f to %.3f\n', ...
                length(data_values), min(data_values), max(data_values));
            
            % Special handling for different data types
            if strcmp(data_type, 'sulc')
                fprintf('  Sulcal depth interpretation:\n');
                fprintf('  - Positive values: Gyri (peaks)\n');
                fprintf('  - Negative values: Sulci (valleys)\n');
            elseif strcmp(data_type, 'area')
                total_area = sum(data_values);
                fprintf('  Total surface area: %.2f mm²\n', total_area);
                fprintf('  Area interpretation: surface area per vertex\n');
            elseif strcmp(data_type, 'thickness')
                mean_thickness = mean(data_values);
                fprintf('  Mean cortical thickness: %.2f mm\n', mean_thickness);
            end
            fprintf('\n');
        end
    end
    
    % Example 3: Combining sphere coordinates with morphometric data
    if ~isempty(sphere_idx) && isfield(subj.lh, 'sulc')
        fprintf('\n=== Combining Sphere and Morphometric Data ===\n');
        
        sphere_vertices = subj.lh.sphere.vertices;
        sphere_faces = subj.lh.sphere.faces;
        sulc_values = subj.lh.sulc.data;
        
        fprintf('Ready for visualization:\n');
        fprintf('- Sphere vertices: %dx%d\n', size(sphere_vertices));
        fprintf('- Sphere faces: %dx%d\n', size(sphere_faces));
        fprintf('- Sulc values: %dx%d\n', size(sulc_values));
        
        if isfield(subj.lh, 'area')
            area_values = subj.lh.area.data;
            fprintf('- Area values: %dx%d\n', size(area_values));
            
            % Correlate different morphometric measures
            if isfield(subj.lh, 'curv')
                curv_values = subj.lh.curv.data;
                area_curv_corr = corr(area_values, curv_values);
                area_sulc_corr = corr(area_values, sulc_values);
                fprintf('\nMorphometric correlations:\n');
                fprintf('  Area-Curvature correlation: r = %.3f\n', area_curv_corr);
                fprintf('  Area-Sulcal depth correlation: r = %.3f\n', area_sulc_corr);
            end
        end
        
        fprintf('\nVisualization example (MATLAB code):\n');
        fprintf('figure;\n');
        fprintf('patch(''vertices'', sphere_vertices, ''faces'', sphere_faces, ...\n');
        fprintf('      ''facecolor'', ''interp'', ''edgecolor'', ''none'', ...\n');
        fprintf('      ''FaceVertexCData'', sulc_values);\n');
        fprintf('colorbar; title(''Sulcal Depth on Spherical Surface'');\n');
        fprintf('axis equal; camlight;\n');
    end
    
    fprintf('\n=== Data Structure Summary ===\n');
    fprintf('Left hemisphere:\n');
    
    % Count loaded data types
    surface_count = 0;
    data_count = 0;
    
    surface_types = {'orig', 'pial', 'white', 'sphere', 'sphere_reg'};
    for i = 1:length(surface_types)
        if isfield(subj.lh, surface_types{i})
            surface_count = surface_count + 1;
        end
    end
    
    data_types = {'curv', 'thickness', 'sulc', 'area'};
    for i = 1:length(data_types)
        if isfield(subj.lh, data_types{i})
            data_count = data_count + 1;
        end
    end
    
    fprintf('  Surfaces: %d loaded\n', surface_count);
    fprintf('  Data types: %d loaded\n', data_count);
    
    if isfield(subj.lh, 'aparc')
        fprintf('  Annotations: 1 loaded\n');
    end
    
catch ME
    fprintf('Note: This example requires FreeSurfer test data\n');
    fprintf('Error: %s\n', ME.message);
    fprintf('\nTo use this code:\n');
    fprintf('1. Ensure test-data/freesurfer/fsaverage directory exists\n');
    fprintf('2. Place FreeSurfer surface files in surf/ subdirectory\n');
    fprintf('3. Include files: lh.orig, lh.sphere, lh.sphere.reg, lh.curv, lh.sulc\n');
end

fprintf('\nExample completed.\n');