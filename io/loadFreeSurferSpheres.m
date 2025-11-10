%% Load lh.sphere and rh.sphere from local FreeSurfer fsaverage data
% Modified version of fsaverage_web_and_gsp notebook to use local test-data

%% Setup paths and parameters
clear; clc;
addpath(genpath('.'));

% Use local FreeSurfer data instead of MNE download
subjects_dir = 'test-data/freesurfer';
subject = 'fsaverage';
surf_dir = fullfile(subjects_dir, subject, 'surf');

% Output directory
out_dir = 'external/out';
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

% Settings
hemispheres = {'lh', 'rh'};
surface = 'sphere';  % Use sphere surface for spherical mapping

fprintf('=== FreeSurfer Sphere Surface Loader ===\n');
fprintf('Source directory: %s\n', surf_dir);
fprintf('Output directory: %s\n', out_dir);
fprintf('Surface: %s\n', surface);

%% Process both hemispheres
for h = 1:length(hemispheres)
    hemi = hemispheres{h};
    fprintf('\n--- Processing %s hemisphere ---\n', upper(hemi));
    
    % Define file paths
    sphere_path = fullfile(surf_dir, sprintf('%s.%s', hemi, surface));
    thick_path = fullfile(surf_dir, sprintf('%s.thickness', hemi));
    curv_path = fullfile(surf_dir, sprintf('%s.curv', hemi));
    sulc_path = fullfile(surf_dir, sprintf('%s.sulc', hemi));
    
    % Check if files exist
    if ~exist(sphere_path, 'file')
        fprintf('❌ Missing sphere file: %s\n', sphere_path);
        continue;
    end
    
    fprintf('Loading surface files...\n');
    fprintf('  Sphere: %s\n', sphere_path);
    fprintf('  Thickness: %s\n', thick_path);
    fprintf('  Curvature: %s\n', curv_path);
    fprintf('  Sulc: %s\n', sulc_path);
    
    try
        % Load geometry using FreeSurfer format readers
        % Note: MATLAB doesn't have built-in FreeSurfer readers like Python's nibabel
        % We'll need to implement or use existing readers
        
        fprintf('Reading FreeSurfer surface geometry...\n');
        
        % Try using existing FreeSurfer readers if available
        if exist('read_surf', 'file')
            % Use FreeSurfer MATLAB tools if available
            [vertices, faces] = read_surf(sphere_path);
            fprintf('  ✓ Loaded using read_surf: %d vertices, %d faces\n', size(vertices, 1), size(faces, 1));
        elseif exist('freesurfer_read_surf', 'file')
            % Alternative FreeSurfer reader
            [vertices, faces] = freesurfer_read_surf(sphere_path);
            fprintf('  ✓ Loaded using freesurfer_read_surf: %d vertices, %d faces\n', size(vertices, 1), size(faces, 1));
        else
            fprintf('  ❌ No FreeSurfer surface reader found. Available options:\n');
            fprintf('     1. Install FreeSurfer MATLAB tools\n');
            fprintf('     2. Use Python nibabel via MATLAB-Python interface\n');
            fprintf('     3. Implement custom binary reader\n');
            
            % Try Python approach if available
            if exist('pyversion', 'file') && ~isempty(pyversion)
                fprintf('  Trying Python nibabel approach...\n');
                try
                    % Load using Python nibabel
                    py.importlib.import_module('nibabel');
                    py.importlib.import_module('numpy');
                    
                    % Read geometry
                    geometry = py.nibabel.freesurfer.read_geometry(sphere_path);
                    vertices_py = geometry{1};
                    faces_py = geometry{2};
                    
                    % Convert to MATLAB arrays
                    vertices = double(py.array.array('d', py.numpy.ndarray.flatten(vertices_py)));
                    vertices = reshape(vertices, [], 3);
                    faces = double(py.array.array('d', py.numpy.ndarray.flatten(faces_py)));
                    faces = reshape(faces, [], 3) + 1; % Convert to 1-based indexing
                    
                    fprintf('  ✓ Loaded using Python nibabel: %d vertices, %d faces\n', size(vertices, 1), size(faces, 1));
                    
                catch ME
                    fprintf('  ❌ Python approach failed: %s\n', ME.message);
                    continue;
                end
            else
                fprintf('  ❌ Python not available\n');
                continue;
            end
        end
        
        % Load morphometric data if readers are available
        thickness = [];
        curvature = [];
        sulc_data = [];
        
        if exist('read_curv', 'file')
            try
                if exist(thick_path, 'file')
                    thickness = read_curv(thick_path);
                    fprintf('  ✓ Loaded thickness: %d values\n', length(thickness));
                end
                if exist(curv_path, 'file')
                    curvature = read_curv(curv_path);
                    fprintf('  ✓ Loaded curvature: %d values\n', length(curvature));
                end
                if exist(sulc_path, 'file')
                    sulc_data = read_curv(sulc_path);
                    fprintf('  ✓ Loaded sulc: %d values\n', length(sulc_data));
                end
            catch ME
                fprintf('  ⚠️  Morphometric data loading failed: %s\n', ME.message);
            end
        else
            fprintf('  ⚠️  No FreeSurfer morphometric reader (read_curv) found\n');
        end
        
        % Analyze sphere properties
        fprintf('Analyzing sphere geometry...\n');
        sphere_center = mean(vertices, 1);
        radii = sqrt(sum(vertices.^2, 2));
        mean_radius = mean(radii);
        radius_std = std(radii);
        
        fprintf('  Center: [%.6f, %.6f, %.6f]\n', sphere_center);
        fprintf('  Mean radius: %.2f\n', mean_radius);
        fprintf('  Radius std: %.6f (variation: %.4f%%)\n', radius_std, radius_std/mean_radius*100);
        fprintf('  Radius range: %.2f - %.2f\n', min(radii), max(radii));
        
        % Save geometry data
        coords_file = fullfile(out_dir, sprintf('%s_sphere_coords.mat', hemi));
        faces_file = fullfile(out_dir, sprintf('%s_sphere_faces.mat', hemi));
        
        save(coords_file, 'vertices', '-v7.3');
        save(faces_file, 'faces', '-v7.3');
        
        fprintf('  ✓ Saved coordinates: %s\n', coords_file);
        fprintf('  ✓ Saved faces: %s\n', faces_file);
        
        % Save morphometric data if available
        if ~isempty(thickness)
            thick_file = fullfile(out_dir, sprintf('%s_thickness.mat', hemi));
            save(thick_file, 'thickness', '-v7.3');
            fprintf('  ✓ Saved thickness: %s\n', thick_file);
        end
        
        if ~isempty(curvature)
            curv_file = fullfile(out_dir, sprintf('%s_curvature.mat', hemi));
            save(curv_file, 'curvature', '-v7.3');
            fprintf('  ✓ Saved curvature: %s\n', curv_file);
        end
        
        if ~isempty(sulc_data)
            sulc_file = fullfile(out_dir, sprintf('%s_sulc.mat', hemi));
            save(sulc_file, 'sulc_data', '-v7.3');
            fprintf('  ✓ Saved sulc: %s\n', sulc_file);
        end
        
        % Create a simple mesh visualization
        fprintf('Creating visualization...\n');
        
        figure('Name', sprintf('%s Hemisphere Sphere', upper(hemi)), 'Position', [100, 100, 800, 600]);
        
        % Plot the sphere mesh
        subplot(2, 2, 1);
        trisurf(faces, vertices(:,1), vertices(:,2), vertices(:,3), 'EdgeColor', 'none', 'FaceColor', [0.8 0.8 0.8]);
        axis equal; lighting gouraud; camlight;
        title(sprintf('%s Sphere Surface', upper(hemi)));
        xlabel('X'); ylabel('Y'); zlabel('Z');
        
        % Plot radius variation
        subplot(2, 2, 2);
        trisurf(faces, vertices(:,1), vertices(:,2), vertices(:,3), radii, 'EdgeColor', 'none');
        axis equal; lighting gouraud; camlight; colorbar;
        title('Radius Variation');
        
        % Plot morphometric data if available
        if ~isempty(curvature)
            subplot(2, 2, 3);
            trisurf(faces, vertices(:,1), vertices(:,2), vertices(:,3), curvature, 'EdgeColor', 'none');
            axis equal; lighting gouraud; camlight; colorbar;
            title('Curvature');
        end
        
        if ~isempty(thickness)
            subplot(2, 2, 4);
            trisurf(faces, vertices(:,1), vertices(:,2), vertices(:,3), thickness, 'EdgeColor', 'none');
            axis equal; lighting gouraud; camlight; colorbar;
            title('Thickness');
        end
        
        % Save the figure
        fig_file = fullfile(out_dir, sprintf('%s_sphere_analysis.png', hemi));
        saveas(gcf, fig_file);
        fprintf('  ✓ Saved visualization: %s\n', fig_file);
        
        fprintf('✅ %s hemisphere processing completed successfully!\n', upper(hemi));
        
    catch ME
        fprintf('❌ Error processing %s hemisphere: %s\n', upper(hemi), ME.message);
        if ~isempty(ME.stack)
            fprintf('   Location: %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
        end
    end
end

%% Summary
fprintf('\n=== Processing Summary ===\n');
fprintf('FreeSurfer sphere surfaces processed from: %s\n', surf_dir);
fprintf('Output files saved to: %s\n', out_dir);
fprintf('Files generated:\n');

% List generated files
output_files = dir(fullfile(out_dir, '*sphere*'));
for i = 1:length(output_files)
    fprintf('  - %s\n', output_files(i).name);
end

fprintf('\n📋 Next Steps:\n');
fprintf('1. Use the saved .mat files in your bioctree workflows\n');
fprintf('2. Convert to BCT format if needed using enhanced schema\n');
fprintf('3. Apply graph signal processing to spherical data\n');
fprintf('4. Visualize with three.js using exported GLB format\n');

fprintf('\nSphere processing completed! 🎉\n');