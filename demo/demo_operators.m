%DEMO_OPERATORS Demonstration of BCT operator system
%
% This demo shows how to use the new operator registry/runtime system
% for accessing DEC and FEM operators in a unified way.
%
% Key concepts:
%   - Operator Registry: Defines what operators exist
%   - Runtime Context: Specifies available representations
%   - Bound Operators: Functions ready to use with specific representations
%   - Hierarchical IDs: "gradient.dec", "gradient.fem", etc.
%
% See also: bct.registry.operators, bct.runtime.operators

clearvars; close all; clc;

fprintf('╔══════════════════════════════════════════════════════════╗\n');
fprintf('║         BCT OPERATOR SYSTEM DEMONSTRATION                ║\n');
fprintf('╚══════════════════════════════════════════════════════════╝\n\n');

%% 1. Load Test Mesh
fprintf('[1/6] Loading test mesh...\n');

% Load fsaverage right hemisphere pial surface
data = load('data/mesh/fsaverage_rh_pial.mat');
M = bct.Manifold(data.V, data.F);

fprintf('      Vertices: %d\n', M.numVertices());
fprintf('      Faces: %d\n', M.numFaces());

%% 2. Explore the Operator Registry
fprintf('\n[2/6] Exploring operator registry...\n');

% Get all operator definitions
specs = bct.registry.operators.defs();

fprintf('      Available operators:\n');
for id = keys(specs)
    spec = specs(id);
    fprintf('        • %s (%s domain)\n', id, spec.domain);
end

%% 3. Create a Test Signal
fprintf('\n[3/6] Creating test signal on vertices...\n');

% Create a smooth test function (Gaussian bump)
center = [0, 0, 50];  % Coordinates in mm
sigma = 30;           % Width in mm

distances = sqrt(sum((M.Vertices - center).^2, 2));
f0 = exp(-distances.^2 / (2*sigma^2));

fprintf('      Signal: Gaussian bump centered at (%.1f, %.1f, %.1f)\n', ...
    center(1), center(2), center(3));
fprintf('      Range: [%.4f, %.4f]\n', min(f0), max(f0));

%% 4. Using DEC Operators
fprintf('\n[4/6] Using DEC operators...\n');

% Create DEC context
ctx_dec = bct.runtime.context(M, 'DEC', true);
ops_dec = bct.runtime.operators.dictionary(ctx_dec);

fprintf('      Available DEC operators: %d\n', numel(keys(ops_dec)));

% Compute gradient using DEC
if isKey(ops_dec, "gradient.dec")
    gradFn = ops_dec("gradient.dec");
    gradF_dec = gradFn(f0);
    fprintf('      ✓ Gradient computed: [%d×%d] face vectors\n', ...
        size(gradF_dec, 1), size(gradF_dec, 2));
else
    fprintf('      ⚠ DEC gradient not available (DECLab required)\n');
end

% Compute divergence using DEC
if isKey(ops_dec, "divergence.dec") && exist('gradF_dec', 'var')
    divFn = ops_dec("divergence.dec");
    divGradF_dec = divFn(gradF_dec);
    fprintf('      ✓ Divergence computed: [%d×1] vertex scalars\n', ...
        length(divGradF_dec));
    
    % Check Laplacian relationship: div(grad(f)) = Δf
    fprintf('      Laplacian error: %.2e (should be small)\n', ...
        norm(divGradF_dec - (-f0)) / norm(f0));
end

%% 5. Using FEM Operators
fprintf('\n[5/6] Using FEM operators...\n');

% Create FEM context
ctx_fem = bct.runtime.context(M, 'FEM', true);
ops_fem = bct.runtime.operators.dictionary(ctx_fem);

fprintf('      Available FEM operators: %d\n', numel(keys(ops_fem)));

% Compute gradient using FEM
if isKey(ops_fem, "gradient.fem")
    gradFn_fem = ops_fem("gradient.fem");
    gradF_fem = gradFn_fem(f0);
    fprintf('      ✓ Gradient computed: [%d×%d] sparse matrix\n', ...
        size(gradF_fem, 1), size(gradF_fem, 2));
    
    % Apply gradient matrix
    gradValues = gradF_fem * f0;
    fprintf('      Gradient range: [%.4f, %.4f]\n', ...
        min(gradValues), max(gradValues));
else
    fprintf('      ⚠ FEM gradient not available (gptoolbox required)\n');
end

%% 6. Backward Compatibility
fprintf('\n[6/6] Testing backward compatibility...\n');

% Old deprecated IDs still work but issue warnings
fprintf('      Using deprecated ID "dec_gradient"...\n');
if isKey(ops_dec, "dec_gradient")
    gradFn_old = ops_dec("dec_gradient");
    fprintf('      ✓ Old ID works (but deprecated)\n');
else
    fprintf('      Note: Deprecated IDs added via resolveAlias()\n');
end

%% Summary
fprintf('\n╔══════════════════════════════════════════════════════════╗\n');
fprintf('║                        SUMMARY                           ║\n');
fprintf('╠══════════════════════════════════════════════════════════╣\n');
fprintf('║  Registry System:                                        ║\n');
fprintf('║    • Hierarchical IDs: gradient.dec, gradient.fem        ║\n');
fprintf('║    • Dependency metadata for external toolboxes          ║\n');
fprintf('║    • Backward compatible with old IDs (deprecated)       ║\n');
fprintf('║                                                          ║\n');
fprintf('║  Runtime System:                                         ║\n');
fprintf('║    • Context-aware operator filtering                    ║\n');
fprintf('║    • Automatic representation binding                    ║\n');
fprintf('║    • Clean function signatures (hide representations)    ║\n');
fprintf('║                                                          ║\n');
fprintf('║  Usage Pattern:                                          ║\n');
fprintf('║    1. specs = bct.registry.operators.defs()              ║\n');
fprintf('║    2. ctx = bct.runtime.context(M, ''DEC'', true)          ║\n');
fprintf('║    3. ops = bct.runtime.operators.dictionary(ctx)        ║\n');
fprintf('║    4. gradFn = ops("gradient.dec")                       ║\n');
fprintf('║    5. result = gradFn(input)                             ║\n');
fprintf('╚══════════════════════════════════════════════════════════╝\n');

%% Visualization (optional)
if exist('gradF_dec', 'var')
    fprintf('\n[Optional] Visualizing results with bct.ui...\n');
    
    % Create UI inspector
    [inspector, fig] = bct.ui.show(M);
   
    % Show original signal as scalar field
    inspector.setScalarField(f0);  
    % Compute face centers for quiver positions using bct.manifold
    faceCenters = bct.manifold.centroids(M);
    
    % Display gradient vectors as quiver plot
    % gradF_dec is [numFaces × 3] array of gradient vectors on faces
    inspector.showVectorField(faceCenters, ...
        gradF_dec(:,1), gradF_dec(:,2), gradF_dec(:,3), ...
        'Color', 'w', 'LineWidth', 1.5, 'AutoScale', 'on');
    
    fprintf('      ✓ Gradient vectors displayed as quiver plot\n');
    fprintf('      ✓ Single UI window showing scalar field + vectors\n');
end

fprintf('\n✓ Demo complete!\n\n');
