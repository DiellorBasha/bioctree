%% Test Resolution property after class reload
% Force MATLAB to reload class definitions
clear classes;

% Import mesh
path = 'test-data\freesurfer\fsaverage\surf\lh.pial';
B = bct.io.import.mesh(path);

% Display manifold
fprintf('\n=== Manifold ===\n');
disp(B.Manifold);

% Test getLambdaMaxFull method
fprintf('\n=== Testing getLambdaMaxFull ===\n');
lambda_max = B.Manifold.getLambdaMaxFull();
fprintf('lambda_max_full: %.4e\n', lambda_max);

% Display Resolution object
fprintf('\n=== Resolution Object ===\n');
R = B.Manifold.Resolution;
disp(R);

% Access resolution properties
fprintf('\n=== Resolution Properties ===\n');
fprintf('L_min: %.4f %s\n', R.L_min, R.Units.toString());
fprintf('lambda_max: %.4e\n', R.lambda_max);
fprintf('f_max: %.4f cycles/%s\n', R.f_max, R.Units.toString());
fprintf('k_max: %.4f rad/%s\n', R.k_max, R.Units.toString());

