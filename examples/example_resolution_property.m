%% Example: Using Manifold.Resolution Property
% Demonstrates the Resolution property for getting spatial resolution metrics

clear all;
close all;

% Add toolbox to path
root = fileparts(pwd);
addpath(fullfile(root, 'toolbox'));

fprintf('=== Manifold.Resolution Property Example ===\n\n');

%% What is the Resolution property?
fprintf('The Resolution property provides spatial resolution information:\n');
fprintf('  • lambda_max  - Maximum eigenvalue [1/units²]\n');
fprintf('  • k           - Angular wavenumber [rad/units]\n');
fprintf('  • freq        - Spatial frequency [cycles/units]\n');
fprintf('  • wavelength  - Minimum wavelength [units]\n\n');

%% Example 1: Resolution without eigenvalues
fprintf('Example 1: Accessing Resolution before computing eigenvalues\n');
fprintf('-----------------------------------------------------------\n');

path = 'test-data/freesurfer/fsaverage/surf/lh.pial';

if ~isfile(path)
    fprintf('Error: Test data not found. Skipping example.\n');
    return;
end

B = bct.io.import.mesh(path);
fprintf('Loaded mesh: %d vertices, %d faces\n', B.Manifold.N, size(B.Manifold.F, 1));

R = B.Manifold.Resolution;
fprintf('\nResolution (before eigenvalues computed):\n');
fprintf('  lambda_max: %s\n', mat2str(R.lambda_max));
fprintf('  wavelength: %s\n', mat2str(R.wavelength));
fprintf('\n→ Returns empty fields when eigenvalues not computed\n\n');

%% Example 2: Resolution with computed eigenvalues
fprintf('Example 2: Resolution after computing Fourier basis\n');
fprintf('---------------------------------------------------\n');

% Check if gptoolbox is available
if exist('cotmatrix', 'file') == 2
    fprintf('Computing Fourier basis (600 modes)...\n');
    B.Manifold.meshFourier(600);
    
    fprintf('  Computed %d eigenmodes\n', B.Manifold.NumModes);
    fprintf('  Max eigenvalue: %.6f [1/mm²]\n', max(B.Manifold.Eigenvalues));
    
    R = B.Manifold.Resolution;
    
    fprintf('\nResolution metrics:\n');
    fprintf('  lambda_max:  %.6f [1/mm²]\n', R.lambda_max);
    fprintf('  k:           %.6f [rad/mm]\n', R.k);
    fprintf('  freq:        %.6f [cycles/mm]\n', R.freq);
    fprintf('  wavelength:  %.3f mm\n', R.wavelength);
    
    fprintf('\n→ The mesh can resolve spatial features down to ~%.1f mm\n', R.wavelength);
    
    %% Example 3: Using resolution for signal generation
    fprintf('\nExample 3: Using resolution for signal design\n');
    fprintf('---------------------------------------------\n');
    
    % Design a signal at 50% of maximum resolution
    target_wavelength = 2 * R.wavelength;
    target_freq = 1 / target_wavelength;
    
    fprintf('Target wavelength: %.3f mm (50%% of max resolution)\n', target_wavelength);
    fprintf('Target frequency: %.6f cycles/mm\n', target_freq);
    
    % Generate narrowband signal
    spec.type = 'narrowband';
    spec.f0 = target_freq;
    spec.bw_abs = target_freq * 0.1;  % 10% bandwidth
    
    B = bct.sim.synth_mesh_signal(B, spec, 'label', 'test_signal');
    
    fprintf('\nGenerated signal with:\n');
    fprintf('  Center frequency: %.6f cycles/mm\n', spec.f0);
    fprintf('  Bandwidth: %.6f cycles/mm\n', spec.bw_abs);
    fprintf('  Expected wavelength: %.3f mm\n', target_wavelength);
    
    fprintf('\n→ Signal safely within mesh resolution capability\n');
    
    %% Example 4: Visualize resolution limits
    fprintf('\nExample 4: Visualizing resolution on mesh\n');
    fprintf('-----------------------------------------\n');
    
    figure('Position', [100 100 1200 400]);
    
    % Panel 1: Generated signal
    subplot(1, 3, 1);
    trisurf(B.Manifold.F, B.Manifold.V(:,1), B.Manifold.V(:,2), B.Manifold.V(:,3), ...
        B.Signals(1).Data, 'EdgeColor', 'none');
    axis equal off;
    view(3);
    colorbar;
    title(sprintf('Signal at %.1f mm wavelength', target_wavelength));
    colormap(gca, 'parula');
    
    % Panel 2: Nyquist frequency indicator
    subplot(1, 3, 2);
    bar([R.wavelength, target_wavelength, 10]);
    set(gca, 'XTickLabel', {'Max Res', 'Signal', 'Coarse'});
    ylabel('Wavelength (mm)');
    title('Wavelength Comparison');
    grid on;
    
    % Panel 3: Text summary
    subplot(1, 3, 3);
    axis off;
    text(0.1, 0.9, 'Resolution Summary', 'FontSize', 14, 'FontWeight', 'bold');
    text(0.1, 0.75, sprintf('Mesh vertices: %d', B.Manifold.N));
    text(0.1, 0.65, sprintf('Eigenmodes: %d', B.Manifold.NumModes));
    text(0.1, 0.55, sprintf('Min wavelength: %.2f mm', R.wavelength));
    text(0.1, 0.45, sprintf('Max frequency: %.4f cyc/mm', R.freq));
    text(0.1, 0.30, 'Signal Properties:', 'FontWeight', 'bold');
    text(0.1, 0.20, sprintf('Wavelength: %.2f mm', target_wavelength));
    text(0.1, 0.10, sprintf('Well-resolved: %s', 'Yes'));
    
    sgtitle('Mesh Spatial Resolution Analysis', 'FontSize', 14, 'FontWeight', 'bold');
    
    fprintf('Visualization created.\n');
    
else
    fprintf('Skipped: gptoolbox not available for eigenvalue computation\n');
    fprintf('\nTo use this feature:\n');
    fprintf('  1. Install gptoolbox: https://github.com/alecjacobson/gptoolbox\n');
    fprintf('  2. Add to MATLAB path\n');
    fprintf('  3. Compute eigenvalues: B.Manifold.meshFourier(k)\n');
    fprintf('  4. Access resolution: R = B.Manifold.Resolution\n');
end

%% Summary
fprintf('\n=== Usage Summary ===\n\n');
fprintf('Quick access to spatial resolution:\n');
fprintf('  R = B.Manifold.Resolution;\n');
fprintf('  fprintf(''Min wavelength: %%.2f mm\\n'', R.wavelength);\n\n');

fprintf('Resolution tells you the finest spatial detail the mesh can represent.\n');
fprintf('Use it to:\n');
fprintf('  • Design signals within mesh capabilities\n');
fprintf('  • Validate simulation parameters\n');
fprintf('  • Compare mesh quality across subjects\n\n');
