%% Test enhanced fs2gsp function with both hemispheres and surface selection
% Test the new fs2gsp function that processes both hemispheres by default

clear; clc;

% Define paths
subject_dir = 'C:\CodingProjects\bioctree\test-data\freesurfer';
subject_name = 'fsaverage';

fprintf('=== Testing Enhanced fs2gsp Function ===\n');

%% Test 1: Default behavior (both hemispheres, pial surface)
fprintf('\n--- Test 1: Default (both hemispheres, pial) ---\n');
subject1 = fs2gsp(subject_dir, subject_name);

% Check results
if isfield(subject1.lh, 'pial_gsp') && isfield(subject1.lh, 'pial_mat')
    fprintf('✓ LH pial GSP graph created: %d vertices, %d faces\n', ...
            subject1.lh.pial_gsp.N, size(subject1.lh.pial_gsp.Faces, 1));
    fprintf('✓ LH pial mesh object created: %d vertices, %d faces\n', ...
            length(subject1.lh.pial_mat.Vertices), length(subject1.lh.pial_mat.Faces));
else
    fprintf('✗ LH pial processing failed\n');
end

if isfield(subject1.rh, 'pial_gsp') && isfield(subject1.rh, 'pial_mat')
    fprintf('✓ RH pial GSP graph created: %d vertices, %d faces\n', ...
            subject1.rh.pial_gsp.N, size(subject1.rh.pial_gsp.Faces, 1));
    fprintf('✓ RH pial mesh object created: %d vertices, %d faces\n', ...
            length(subject1.rh.pial_mat.Vertices), length(subject1.rh.pial_mat.Faces));
else
    fprintf('✗ RH pial processing failed\n');
end

%% Test 2: Single hemisphere (lh only)
fprintf('\n--- Test 2: Single hemisphere (lh only) ---\n');
subject2 = fs2gsp(subject_dir, subject_name, 'lh');

if isfield(subject2.lh, 'pial_gsp')
    fprintf('✓ LH only processing successful\n');
else
    fprintf('✗ LH only processing failed\n');
end

if isfield(subject2.rh, 'pial_gsp')
    fprintf('✗ RH should not be processed\n');
else
    fprintf('✓ RH correctly skipped\n');
end

%% Test 3: Different surface (white matter)
fprintf('\n--- Test 3: White matter surface ---\n');
subject3 = fs2gsp(subject_dir, subject_name, 'lh', 'white');

if isfield(subject3.lh, 'white_gsp') && isfield(subject3.lh, 'white_mat')
    fprintf('✓ LH white matter GSP graph created: %d vertices, %d faces\n', ...
            subject3.lh.white_gsp.N, size(subject3.lh.white_gsp.Faces, 1));
else
    fprintf('✗ LH white matter processing failed\n');
end

%% Test 4: Both hemispheres, white surface
fprintf('\n--- Test 4: Both hemispheres, white surface ---\n');
subject4 = fs2gsp(subject_dir, subject_name, 'both', 'white');

if isfield(subject4.lh, 'white_gsp') && isfield(subject4.rh, 'white_gsp')
    fprintf('✓ Both hemispheres white matter processed\n');
    fprintf('  LH: %d vertices, RH: %d vertices\n', ...
            subject4.lh.white_gsp.N, subject4.rh.white_gsp.N);
else
    fprintf('✗ Both hemispheres white matter processing failed\n');
end

fprintf('\n=== All tests completed ===\n');