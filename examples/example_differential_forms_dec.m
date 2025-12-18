%EXAMPLE_DIFFERENTIAL_FORMS_DEC
%   Demonstrates differential calculus on manifolds using DEC
%
%   Workflow:
%   1. Create spectral Gaussian patch signal
%   2. Compute gradient using DEC
%   3. Compute divergence and curl
%   4. Perform Helmholtz-Hodge decomposition
%   5. Visualize all components

clearvars; clc;
bioctree_start;

%% Step 1: Setup and create signal
fprintf('=== Differential Forms using DEC ===\n\n');

% Load mesh
data = load('data/mesh/fsaverage_rh_pial.mat');
B = bct.bct.fromMesh(data.V, data.F);

fprintf('Mesh loaded:\n');
fprintf('  Vertices: %d\n', B.Manifold.N);
fprintf('  Faces: %d\n', size(B.Manifold.Faces, 1));

% Check DEC availability
if isempty(B.Manifold.DEC)
    error('DEC object not initialized. Check DECLab installation.');
end
fprintf('  DEC initialized: ✓\n');

% Create spectral Gaussian patch signal
fprintf('\n=== Creating Spectral Gaussian Signal ===\n');
source_vertex = 5000;
sigma = 20;

sig = bct.Signal.fromBrush(B.Manifold, ...
    'Category', 'patch', ...
    'Type', 'spectral', ...
    'Source', source_vertex, ...
    'Kernel', 'gaussian', ...
    'Sigma', sigma);

fprintf('Signal created:\n');
fprintf('  Type: Spectral Gaussian patch\n');
fprintf('  Source vertex: %d\n', source_vertex);
fprintf('  Sigma: %.1f\n', sigma);
fprintf('  Size: [%d × 1]\n', sig.N);

%% Step 2: Compute gradient
fprintf('\n=== Computing Gradient ===\n');

[gradW, gradW_unit, amplitude, phase] = sig.gradient();

fprintf('Gradient computed:\n');
fprintf('  gradW: [%d × 3] (face vectors)\n', size(gradW, 1));
fprintf('  Magnitude range: [%.4f, %.4f]\n', min(amplitude), max(amplitude));
fprintf('  Mean magnitude: %.4f\n', mean(amplitude));
fprintf('  Gradient cached in signal: ✓\n');

%% Step 3: Compute divergence and curl
fprintf('\n=== Computing Divergence and Curl ===\n');

divW = sig.divergence(gradW);
curlW = sig.curl(gradW);

fprintf('Divergence computed:\n');
fprintf('  divW: [%d × 1] (vertex scalar)\n', length(divW));
fprintf('  Range: [%.4f, %.4f]\n', min(divW), max(divW));
fprintf('  Mean: %.4e\n', mean(divW));

fprintf('\nCurl computed:\n');
fprintf('  curlW: [%d × 1] (vertex scalar)\n', length(curlW));
fprintf('  Range: [%.4f, %.4f]\n', min(curlW), max(curlW));
fprintf('  Mean: %.4e\n', mean(curlW));

%% Step 4: Helmholtz-Hodge decomposition
fprintf('\n=== Helmholtz-Hodge Decomposition ===\n');

[rotU_mag, divU_mag, harmU_mag, rotU, divU, harmU, scalarP, vectorP] = ...
    sig.hhdecomposition();

fprintf('Decomposition computed:\n');
fprintf('  Curl-free (rotational) component:\n');
fprintf('    Magnitude: [%d × 1] vertices\n', length(rotU_mag));
fprintf('    Range: [%.4f, %.4f]\n', min(rotU_mag), max(rotU_mag));
fprintf('    Vector field: [%d × 3] faces\n', size(rotU, 1));
fprintf('\n');
fprintf('  Divergence-free component:\n');
fprintf('    Magnitude: [%d × 1] vertices\n', length(divU_mag));
fprintf('    Range: [%.4f, %.4f]\n', min(divU_mag), max(divU_mag));
fprintf('    Vector field: [%d × 3] faces\n', size(divU, 1));
fprintf('\n');
fprintf('  Harmonic component:\n');
fprintf('    Magnitude: [%d × 1] vertices\n', length(harmU_mag));
fprintf('    Range: [%.4f, %.4f]\n', min(harmU_mag), max(harmU_mag));
fprintf('    Vector field: [%d × 3] faces\n', size(harmU, 1));

% Energy analysis
total_energy = sum(amplitude.^2);
rot_energy = sum(rotU_mag.^2);
div_energy = sum(divU_mag.^2);
harm_energy = sum(harmU_mag.^2);

fprintf('\nEnergy distribution:\n');
fprintf('  Total gradient energy: %.4e\n', total_energy);
fprintf('  Curl-free: %.2f%%\n', 100 * rot_energy / total_energy);
fprintf('  Divergence-free: %.2f%%\n', 100 * div_energy / total_energy);
fprintf('  Harmonic: %.2f%%\n', 100 * harm_energy / total_energy);

%% Step 5: Visualization
fprintf('\n=== Creating Visualizations ===\n');

V = B.Manifold.Vertices;
F = B.Manifold.Faces;

% Figure 1: Original signal and gradient amplitude
figure('Name', 'Signal and Gradient', 'Position', [100 100 1400 600]);

subplot(1, 3, 1);
trisurf(F, V(:,1), V(:,2), V(:,3), sig.Data, 'EdgeColor', 'none');
shading interp;
colormap(gca, 'jet');
colorbar;
axis equal tight off;
view([0 90]);
title('Original Signal (Spectral Gaussian)');

subplot(1, 3, 2);
% Convert face amplitude to vertex for visualization
amplitude_vert = bct.operator.transform.faceVec2vertMag(B.Manifold, gradW);
trisurf(F, V(:,1), V(:,2), V(:,3), amplitude_vert, 'EdgeColor', 'none');
shading interp;
colormap(gca, 'hot');
colorbar;
axis equal tight off;
view([0 90]);
title('Gradient Amplitude');

subplot(1, 3, 3);
% Show gradient direction using quiver on subsampled mesh
% Subsample for clarity
subsample_factor = 20;
face_centers = (V(F(:,1), :) + V(F(:,2), :) + V(F(:,3), :)) / 3;
subsample_idx = 1:subsample_factor:size(face_centers, 1);

trisurf(F, V(:,1), V(:,2), V(:,3), amplitude_vert, 'EdgeColor', 'none', 'FaceAlpha', 0.3);
hold on;
quiver3(face_centers(subsample_idx, 1), ...
        face_centers(subsample_idx, 2), ...
        face_centers(subsample_idx, 3), ...
        gradW_unit(subsample_idx, 1), ...
        gradW_unit(subsample_idx, 2), ...
        gradW_unit(subsample_idx, 3), ...
        0.5, 'r', 'LineWidth', 1.5);
hold off;
colormap(gca, 'hot');
axis equal tight off;
view([0 90]);
title('Gradient Vector Field (subsampled)');

% Figure 2: Divergence and Curl
figure('Name', 'Divergence and Curl', 'Position', [150 150 1000 500]);

subplot(1, 2, 1);
trisurf(F, V(:,1), V(:,2), V(:,3), divW, 'EdgeColor', 'none');
shading interp;
colormap(gca, 'RdBu');
colorbar;
caxis([-max(abs(divW)), max(abs(divW))]);  % Symmetric colormap
axis equal tight off;
view([0 90]);
title('Divergence (∇·∇w)');

subplot(1, 2, 2);
trisurf(F, V(:,1), V(:,2), V(:,3), curlW, 'EdgeColor', 'none');
shading interp;
colormap(gca, 'RdBu');
colorbar;
caxis([-max(abs(curlW)), max(abs(curlW))]);  % Symmetric colormap
axis equal tight off;
view([0 90]);
title('Curl (∇×∇w)');

% Figure 3: Helmholtz-Hodge Decomposition
figure('Name', 'Helmholtz-Hodge Decomposition', 'Position', [200 200 1600 500]);

subplot(1, 4, 1);
trisurf(F, V(:,1), V(:,2), V(:,3), amplitude_vert, 'EdgeColor', 'none');
shading interp;
colormap(gca, 'hot');
colorbar;
axis equal tight off;
view([0 90]);
title('Total Gradient');

subplot(1, 4, 2);
trisurf(F, V(:,1), V(:,2), V(:,3), rotU_mag, 'EdgeColor', 'none');
shading interp;
colormap(gca, 'hot');
colorbar;
axis equal tight off;
view([0 90]);
title(sprintf('Curl-Free (%.1f%%)', 100 * rot_energy / total_energy));

subplot(1, 4, 3);
trisurf(F, V(:,1), V(:,2), V(:,3), divU_mag, 'EdgeColor', 'none');
shading interp;
colormap(gca, 'hot');
colorbar;
axis equal tight off;
view([0 90]);
title(sprintf('Divergence-Free (%.1f%%)', 100 * div_energy / total_energy));

subplot(1, 4, 4);
trisurf(F, V(:,1), V(:,2), V(:,3), harmU_mag, 'EdgeColor', 'none');
shading interp;
colormap(gca, 'hot');
colorbar;
axis equal tight off;
view([0 90]);
title(sprintf('Harmonic (%.1f%%)', 100 * harm_energy / total_energy));

%% Summary
fprintf('\n=== Summary ===\n');
fprintf('\nComplete differential calculus workflow:\n\n');

fprintf('1. CREATE SIGNAL:\n');
fprintf('   sig = bct.Signal.fromBrush(B.Manifold, ...\n');
fprintf('       ''Category'', ''patch'', ''Type'', ''spectral'', ...\n');
fprintf('       ''Source'', %d, ''Kernel'', ''gaussian'', ''Sigma'', %.1f);\n\n', ...
    source_vertex, sigma);

fprintf('2. COMPUTE GRADIENT:\n');
fprintf('   [gradW, gradW_unit, amplitude, phase] = sig.gradient();\n');
fprintf('   → Returns [M×3] face vectors, cached in signal\n\n');

fprintf('3. COMPUTE DIVERGENCE & CURL:\n');
fprintf('   divW = sig.divergence(gradW);\n');
fprintf('   curlW = sig.curl(gradW);\n');
fprintf('   → Returns [N×1] vertex scalars\n\n');

fprintf('4. HELMHOLTZ-HODGE DECOMPOSITION:\n');
fprintf('   [rotU_mag, divU_mag, harmU_mag, rotU, divU, harmU] = ...\n');
fprintf('       sig.hhdecomposition();\n');
fprintf('   → Decomposes gradient into curl-free, divergence-free, harmonic\n');
fprintf('   → Results cached for efficiency\n\n');

fprintf('All operations use the DEC (Discrete Exterior Calculus) object\n');
fprintf('from the Manifold for accurate differential geometry!\n');

fprintf('\nDone!\n');
