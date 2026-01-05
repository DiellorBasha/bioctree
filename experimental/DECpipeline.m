%% ========================================================================
% DIFFERENTIAL FORMS PIPELINE WITH STEP-BY-STEP VISUALIZATION
% ========================================================================
clearvars; clc;
bioctree_start;

%% Setup
% Get the default mesh path from bct.data
mesh = bct.data.load();  % Load default mesh struct
B = bct.manifold.load(mesh);  % Create Manifold object


V = B.Vertices;
F = B.Faces;
COM = B.centroids();  % Face centers
ssf = 15;  % Subsample factor for vectors
subsample = 1:ssf:size(COM,1);

%% Create viewer (ONCE)
% Create figure
  fig  = uifigure('Position', [100 100 1200 800]);
      gr = uigridlayout(fig, [1 1]);
      gr.RowHeight    = {'1x'};
      gr.ColumnWidth  = {'1x'};
      v = bct.ui.manifold.Viewer(gr);
fprintf('=== Differential Forms Pipeline ===\n\n');

%% ========================================================================
%  STEP 1: CREATE SPECTRAL GAUSSIAN SIGNAL
%  ========================================================================
fprintf('Step 1: Creating spectral Gaussian signal...\n');

sig = bct.Signal.fromBrush(B.Manifold, ...
    'Category', 'patch', ...
    'Type', 'spectral', ...
    'Source', 4500, ...
    'Kernel', 'gaussian', ...
    'Sigma', 5,...
    'Bandwidth', 100);
% params.source = 300;           % Source vertex (required!)
% params.kernel = 'gaussian';
% params.sigma = 15;
% params.bandwidth = 50;         % Use only first 50 modes
% 
% w = bct.brush.patch.spectral(fs6.Manifold, params);
% w=full(w);
% Create Signal object
%sig = bct.Signal(w, fs6.Manifold);
fprintf('  Source vertex: 300\n');
fprintf('  Sigma: 20\n');
fprintf('  Signal size: [%d × 1]\n', sig.N);

% === VISUALIZE: Original scalar field ===
viewer.setScalarField(sig.Data);
% viewer.setColormap('jet');
% viewer.showColorbar();
viewer.setTitle('Step 1: Spectral Gaussian Signal w(x)', 'FontSize', 14);



%% ========================================================================
%  STEP 2: COMPUTE GRADIENT
%  ========================================================================
fprintf('Step 2: Computing gradient ∇w...\n');

[gradW, gradW_unit, amplitude, phase] = sig.gradient();

fprintf('  Gradient: [%d × 3] face vectors\n', size(gradW, 1));
fprintf('  Magnitude range: [%.4f, %.4f]\n', min(amplitude), max(amplitude));
fprintf('  Mean magnitude: %.4f\n', mean(amplitude));

% Convert face amplitude to vertex for visualization
amplitude_vert = bct.operator.transform.faceVec2vertMag(B.Manifold, gradW);

% === VISUALIZE 2a: Gradient magnitude with vector field ===
viewer.setScalarField(amplitude_vert);
viewer.setColormap('parula');

viewer.showVectorField(...
    COM(subsample,:), ...
    gradW_unit(subsample,1), ...
    gradW_unit(subsample,2), ...
    gradW_unit(subsample,3), ...
    'Color', 'k', 'LineWidth', 1.2, 'AutoScale', 'on');

viewer.setTitle('Step 2a: Gradient |∇w| with direction field', 'FontSize', 14);

fprintf('  → Visualization 2a: Magnitude + vectors\n');
fprintf('Press any key to continue...\n\n');
pause;

% === VISUALIZE 2b: Gradient phase ===
% Convert face phase to vertex
phase_vert = accumarray(F(:), repmat(phase, 3, 1), [size(V,1), 1], @mean, 0);

viewer.setScalarField(phase_vert);
viewer.setColormap('hsv');
viewer.hideVectorField();
viewer.setTitle('Step 2b: Gradient phase ∠(∇w) in radians', 'FontSize', 14);

fprintf('  → Visualization 2b: Phase (orientation)\n');
fprintf('Press any key to continue...\n\n');
pause;

%% ========================================================================
%  STEP 3: COMPUTE DIVERGENCE AND CURL
%  ========================================================================
fprintf('Step 3: Computing divergence and curl...\n');

divW = sig.divergence(gradW);
curlW = sig.curl(gradW);

fprintf('  Divergence: [%d × 1] vertex scalars\n', length(divW));
fprintf('    Range: [%.4f, %.4f]\n', min(divW), max(divW));
fprintf('    Mean: %.4e\n', mean(divW));
fprintf('  Curl: [%d × 1] vertex scalars\n', length(curlW));
fprintf('    Range: [%.4f, %.4f]\n', min(curlW), max(curlW));
fprintf('    Mean: %.4e\n', mean(curlW));

% === VISUALIZE 3a: Divergence ===
viewer.setScalarField(divW);
viewer.setColormap('parula');
viewer.setColorLimits([-max(abs(divW)), max(abs(divW))]);
viewer.setTitle('Step 3a: Divergence ∇·(∇w)', 'FontSize', 14);

fprintf('  → Visualization 3a: Divergence (expansion/contraction)\n');
fprintf('Press any key to continue...\n\n');
pause;

% === VISUALIZE 3b: Curl ===
viewer.setScalarField(curlW);
viewer.setColormap('parula');
viewer.setColorLimits([-max(abs(curlW)), max(abs(curlW))]);
viewer.setTitle('Step 3b: Curl ∇×(∇w) - scalar vorticity', 'FontSize', 14);

fprintf('  → Visualization 3b: Curl (rotation)\n');
fprintf('Press any key to continue...\n\n');
pause;

%% ========================================================================
%  STEP 4: HELMHOLTZ-HODGE DECOMPOSITION
%  ========================================================================
fprintf('Step 4: Helmholtz-Hodge decomposition...\n');

[rotU_mag, divU_mag, harmU_mag, rotU, divU, harmU, scalarP, vectorP] = ...
    sig.hhdecomposition();

% Compute energy distribution
total_energy = sum(amplitude_vert.^2);
rot_energy = sum(rotU_mag.^2);
div_energy = sum(divU_mag.^2);
harm_energy = sum(harmU_mag.^2);

fprintf('  Decomposition complete:\n');
fprintf('    Curl-free: [%d × 1] vertex magnitudes\n', length(rotU_mag));
fprintf('    Divergence-free: [%d × 1] vertex magnitudes\n', length(divU_mag));
fprintf('    Harmonic: [%d × 1] vertex magnitudes\n', length(harmU_mag));
fprintf('\n');
fprintf('  Energy distribution:\n');
fprintf('    Total: %.4e\n', total_energy);
fprintf('    Curl-free: %.2f%%\n', 100 * rot_energy / total_energy);
fprintf('    Divergence-free: %.2f%%\n', 100 * div_energy / total_energy);
fprintf('    Harmonic: %.2f%%\n', 100 * harm_energy / total_energy);

% === VISUALIZE 4a: Full gradient field ===
viewer.setScalarField(amplitude_vert);
viewer.setColormap('parula');

gradW_norm = gradW ./ (vecnorm(gradW, 2, 2) + eps);
viewer.showVectorField(...
    COM(subsample,:), ...
    gradW_norm(subsample,1), ...
    gradW_norm(subsample,2), ...
    gradW_norm(subsample,3), ...
    'Color', 'k', 'LineWidth', 1);

viewer.setTitle('Step 4a: Full gradient field ∇w (100%)', 'FontSize', 14);

fprintf('  → Visualization 4a: Full gradient\n');
fprintf('Press any key to continue...\n\n');
pause;

% === VISUALIZE 4b: Curl-free component (∇ × U_rot = 0) ===
viewer.setScalarField(rotU_mag);
viewer.setColormap('parula');

rotU_norm = rotU ./ (vecnorm(rotU, 2, 2) + eps);
viewer.showVectorField(...
    COM(subsample,:), ...
    rotU_norm(subsample,1), ...
    rotU_norm(subsample,2), ...
    rotU_norm(subsample,3), ...
    'Color', 'k', 'LineWidth', 1);

viewer.setTitle(...
    sprintf('Step 4b: Curl-free component U_rot = ∇φ (%.1f%%)', ...
    100 * rot_energy / total_energy), 'FontSize', 14);

fprintf('  → Visualization 4b: Curl-free (irrotational)\n');
fprintf('      Derived from scalar potential φ\n');
fprintf('      ∇ × U_rot = 0\n');
fprintf('Press any key to continue...\n\n');
pause;

% === VISUALIZE 4c: Divergence-free component (∇ · U_div = 0) ===
viewer.setScalarField(divU_mag);
viewer.setColormap('parula');

divU_norm = divU ./ (vecnorm(divU, 2, 2) + eps);
viewer.showVectorField(...
    COM(subsample,:), ...
    divU_norm(subsample,1), ...
    divU_norm(subsample,2), ...
    divU_norm(subsample,3), ...
    'Color', 'k', 'LineWidth', 1);

viewer.setTitle(...
    sprintf('Step 4c: Divergence-free component U_div = ∇×ψ (%.1f%%)', ...
    100 * div_energy / total_energy), 'FontSize', 14);

fprintf('  → Visualization 4c: Divergence-free (solenoidal)\n');
fprintf('      Derived from vector potential ψ\n');
fprintf('      ∇ · U_div = 0\n');
fprintf('Press any key to continue...\n\n');
pause;

% === VISUALIZE 4d: Harmonic component (∇ × U_harm = 0 AND ∇ · U_harm = 0) ===
viewer.setScalarField(harmU_mag);
viewer.setColormap('parula');

harmU_norm = harmU ./ (vecnorm(harmU, 2, 2) + eps);
viewer.showVectorField(...
    COM(subsample,:), ...
    harmU_norm(subsample,1), ...
    harmU_norm(subsample,2), ...
    harmU_norm(subsample,3), ...
    'Color', 'k', 'LineWidth', 1);

viewer.setTitle(...
    sprintf('Step 4d: Harmonic component U_harm (%.1f%%)', ...
    100 * harm_energy / total_energy), 'FontSize', 14);

fprintf('  → Visualization 4d: Harmonic component\n');
fprintf('      Both curl-free AND divergence-free\n');
fprintf('      ∇ × U_harm = 0  AND  ∇ · U_harm = 0\n');

%% ========================================================================
%  SUMMARY
%  ========================================================================
fprintf('\n=== Pipeline Complete ===\n');
fprintf('\nComputed quantities:\n');
fprintf('  1. Signal w(x): [%d × 1] scalar field\n', sig.N);
fprintf('  2. Gradient ∇w: [%d × 3] vector field on faces\n', size(gradW,1));
fprintf('  3. Divergence ∇·(∇w): [%d × 1] scalar field\n', length(divW));
fprintf('  4. Curl ∇×(∇w): [%d × 1] scalar field\n', length(curlW));
fprintf('  5. HH Decomposition: ∇w = U_rot + U_div + U_harm\n');
fprintf('     - Curl-free: %.2f%% energy\n', 100 * rot_energy / total_energy);
fprintf('     - Divergence-free: %.2f%% energy\n', 100 * div_energy / total_energy);
fprintf('     - Harmonic: %.2f%% energy\n', 100 * harm_energy / total_energy);

fprintf('\nViewer remains interactive:\n');
fprintf('  - Click and drag to rotate\n');
fprintf('  - Scroll to zoom\n');
fprintf('  - Use keyboard shortcuts (Delete to clear selection)\n');

fprintf('\nAll computations use DEC (Discrete Exterior Calculus)\n');
fprintf('from the Manifold.DEC object.\n');