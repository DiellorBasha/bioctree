%% Test fs2gsp with joint hemisphere processing
% Test the new joint processing functionality

clear; clc;

% Define paths
subject_dir = 'C:\CodingProjects\bioctree\test-data\freesurfer';
subject_name = 'fsaverage';

fprintf('=== Testing Joint Hemisphere Processing ===\n');

%% Test: Both hemispheres with joint centering (default behavior)
fprintf('\n--- Test: Both hemispheres with joint centering ---\n');
subject = fs2gsp(subject_dir, subject_name);

% Check that both hemispheres were processed
if isfield(subject.lh, 'pial_gsp') && isfield(subject.rh, 'pial_gsp')
    fprintf('✓ Both hemispheres processed successfully\n');
    
    % Check vertex counts
    lh_vertices = subject.lh.pial_gsp.N;
    rh_vertices = subject.rh.pial_gsp.N;
    fprintf('  LH: %d vertices\n', lh_vertices);
    fprintf('  RH: %d vertices\n', rh_vertices);
    
    % Check that mesh objects were created
    if isfield(subject.lh, 'pial_mat') && isfield(subject.rh, 'pial_mat')
        lh_mat_vertices = length(subject.lh.pial_mat.Vertices);
        rh_mat_vertices = length(subject.rh.pial_mat.Vertices);
        fprintf('  LH mesh: %d vertices\n', lh_mat_vertices);
        fprintf('  RH mesh: %d vertices\n', rh_mat_vertices);
    end
    
    % Check centering - both should be centered around origin
    lh_center = mean(subject.lh.pial_gsp.coords);
    rh_center = mean(subject.rh.pial_gsp.coords);
    fprintf('  LH center: [%.3f, %.3f, %.3f]\n', lh_center);
    fprintf('  RH center: [%.3f, %.3f, %.3f]\n', rh_center);
    
    % Both should be close to origin due to joint centering
    lh_dist_from_origin = norm(lh_center);
    rh_dist_from_origin = norm(rh_center);
    fprintf('  LH distance from origin: %.3f\n', lh_dist_from_origin);
    fprintf('  RH distance from origin: %.3f\n', rh_dist_from_origin);
    
    if lh_dist_from_origin < 10 && rh_dist_from_origin < 10
        fprintf('✓ Both hemispheres properly centered near origin\n');
    else
        fprintf('✗ Centering may not be working correctly\n');
    end
    
else
    fprintf('✗ Failed to process both hemispheres\n');
end

%% Test: Single hemisphere (should use original processing)
fprintf('\n--- Test: Single hemisphere processing ---\n');
subject_single = fs2gsp(subject_dir, subject_name, 'lh');

if isfield(subject_single.lh, 'pial_gsp') && ~isfield(subject_single.rh, 'pial_gsp')
    fprintf('✓ Single hemisphere processing works correctly\n');
    fprintf('  LH: %d vertices\n', subject_single.lh.pial_gsp.N);
else
    fprintf('✗ Single hemisphere processing failed\n');
end

%% Test: Different surface type
fprintf('\n--- Test: White matter surface with joint processing ---\n');
subject_white = fs2gsp(subject_dir, subject_name, 'both', 'white');

if isfield(subject_white.lh, 'white_gsp') && isfield(subject_white.rh, 'white_gsp')
    fprintf('✓ White matter surfaces processed successfully\n');
    fprintf('  LH white: %d vertices\n', subject_white.lh.white_gsp.N);
    fprintf('  RH white: %d vertices\n', subject_white.rh.white_gsp.N);
else
    fprintf('✗ White matter surface processing failed\n');
end

fprintf('\n=== Tests completed ===\n');