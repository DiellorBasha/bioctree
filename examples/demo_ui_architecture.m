%% Test bct.ui.show() with registry/runtime architecture
% This script tests the complete UI architecture:
% - Registry/runtime dispatch
% - Inspector selection
% - bct.ui.show() entrypoint
% - Data adapters and render primitives

clearvars; close all;

%% 1. Load mesh data
fprintf('Loading mesh data...\n');
meshFile = 'data/mesh/fsaverage_rh_pial.mat';
if ~isfile(meshFile)
    error('Mesh file not found: %s', meshFile);
end
data = load(meshFile);

%% 2. Create Manifold object
fprintf('Creating Manifold...\n');
M = bct.Manifold(data.V, data.F);

%% 3. Test inspector registry
fprintf('\n=== Testing Inspector Registry ===\n');
defs = bct.registry.ui.inspectors();
fprintf('Registered inspectors:\n');
for i = 1:numel(defs)
    fprintf('  %s: %s (supports: %s)\n', ...
        defs(i).Id, defs(i).Class, strjoin(defs(i).Supports, ', '));
end

%% 4. Test runtime dispatch
fprintf('\n=== Testing Runtime Dispatch ===\n');
try
    [factory, def] = bct.runtime.ui.resolveInspector(M);
    fprintf('Selected inspector: %s (%s)\n', def.Id, def.Class);
    fprintf('  Priority: %g\n', def.Priority);
    fprintf('  Tags: %s\n', strjoin(def.Tags, ', '));
catch ME
    fprintf('ERROR in dispatch: %s\n', ME.message);
    rethrow(ME);
end

%% 5. Test listInspectors
fprintf('\n=== Testing Inspector Discovery ===\n');
tbl = bct.ui.listInspectors();
disp(tbl);

%% 6. Test bct.ui.show() - standalone
fprintf('\n=== Testing bct.ui.show() (standalone) ===\n');
try
    [comp1, fig1] = bct.ui.show(M, "Title", "BCT Test - Standalone");
    fprintf('Created standalone viewer:\n');
    fprintf('  Component: %s\n', class(comp1));
    fprintf('  Figure: %s\n', class(fig1));
    
    % Verify root layout
    root = fig1.Children;
    if isa(root, 'matlab.ui.container.GridLayout')
        fprintf('  ✓ Root uigridlayout created correctly\n');
    else
        warning('Expected root GridLayout, got %s', class(root));
    end
catch ME
    fprintf('ERROR in show(): %s\n', ME.message);
    rethrow(ME);
end

%% 7. Test bct.ui.viewer() - embedded
fprintf('\n=== Testing bct.ui.viewer() (embedded) ===\n');
try
    fig2 = uifigure('Name', 'BCT Test - Embedded');
    grid = uigridlayout(fig2, [1 2]);
    grid.ColumnWidth = {'1x', '1x'};
    
    comp2a = bct.ui.viewer(M, grid);
    comp2b = bct.ui.viewer(M, grid);
    
    fprintf('Created embedded viewers:\n');
    fprintf('  Left pane: %s\n', class(comp2a));
    fprintf('  Right pane: %s\n', class(comp2b));
    fprintf('  ✓ Two inspectors in same grid\n');
catch ME
    fprintf('ERROR in viewer(): %s\n', ME.message);
    rethrow(ME);
end

%% 8. Test data adapters
fprintf('\n=== Testing Data Adapters ===\n');
try
    % Scalar overlay test
    scalarData = randn(size(M.Vertices, 1), 1);
    cdata = bct.ui.data.scalarToVertexCData(scalarData, M.Vertices, ...
        "Colormap", "parula", "Normalize", true);
    fprintf('scalarToVertexCData:\n');
    fprintf('  Input: [%d×1] scalar\n', numel(scalarData));
    fprintf('  Output: [%d×3] RGB\n', size(cdata, 1));
    fprintf('  RGB range: [%.3f, %.3f]\n', min(cdata(:)), max(cdata(:)));
    
    % Vector sampling test
    vectorData = randn(size(M.Vertices, 1), 3);
    [X, Y, Z, U, V, W] = bct.ui.data.sampleVectors(vectorData, M.Vertices, ...
        "SampleRate", 0.05, "SampleMethod", "uniform");
    fprintf('\nsampleVectors:\n');
    fprintf('  Input: [%d×3] vectors\n', size(vectorData, 1));
    fprintf('  Output: %d sampled vectors\n', numel(X));
    fprintf('  ✓ Data adapters functional\n');
catch ME
    fprintf('ERROR in data adapters: %s\n', ME.message);
    rethrow(ME);
end

%% 9. Test render primitives
fprintf('\n=== Testing Render Primitives ===\n');
try
    fig3 = uifigure('Name', 'BCT Test - Render Primitives');
    ax = uiaxes(fig3);
    
    % Test ensurePatch
    h = bct.ui.render.ensurePatch(ax, M.Vertices, M.Faces, ...
        "FaceColor", [0.6 0.6 0.6], ...
        "EdgeColor", "none", ...
        "FaceLighting", "gouraud");
    fprintf('ensurePatch:\n');
    fprintf('  Created patch with %d vertices, %d faces\n', ...
        size(M.Vertices, 1), size(M.Faces, 1));
    
    % Test updatePatchVertexRGB
    bct.ui.render.updatePatchVertexRGB(h, cdata);
    fprintf('  Applied RGB overlay\n');
    
    % Test ensureQuiver
    if numel(X) > 0
        hq = bct.ui.render.ensureQuiver(ax, X, Y, Z, U, V, W, ...
            "Color", [1 1 1], "LineWidth", 1.5);
        fprintf('  Created quiver with %d vectors\n', numel(X));
    end
    
    view(ax, 3);
    axis(ax, 'equal');
    fprintf('  ✓ Render primitives functional\n');
catch ME
    fprintf('ERROR in render primitives: %s\n', ME.message);
    rethrow(ME);
end

%% 10. Summary
fprintf('\n=== Test Summary ===\n');
fprintf('✓ Registry/runtime dispatch\n');
fprintf('✓ bct.ui.show() entrypoint\n');
fprintf('✓ bct.ui.viewer() embedded usage\n');
fprintf('✓ bct.ui.data.* adapters\n');
fprintf('✓ bct.ui.render.* primitives\n');
fprintf('\nAll UI architecture components functional!\n');
