% test_visualization_scenarios.m
% Integration test for three visualization scenarios:
% 1. Manifold without signal (default grey)
% 2. Signal on Manifold domain (scalar field)
% 3. Signal on Joint Manifold-Time domain

clearvars;
close all;

fprintf('═══════════════════════════════════════════════════════════\n');
fprintf(' Testing Visualization Scenarios\n');
fprintf('═══════════════════════════════════════════════════════════\n\n');

% Initialize bioctree
% Get to bioctree root and run startup
rootDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
cd(rootDir);
bioctree_start;

%% Test Setup: Load test mesh
fprintf('[Setup] Loading test mesh...\n');
B = bct_fsaverage('rh');  % 163,842 vertices
fprintf('  ✓ Loaded mesh with %d vertices\n\n', B.Manifold.N);

%% Scenario 1: Visualize Manifold without signal (grey mesh)
fprintf('Scenario 1: Manifold without signal (default grey)\n');
fprintf('───────────────────────────────────────────────────────────\n');

try
    % Create viewer with default grey mesh
    B.showMesh();
    
    % Verify viewer was created
    assert(~isempty(B.Viewer), 'Viewer should be created');
    assert(isa(B.Viewer, 'images.ui.graphics3d.Viewer3D'), 'Viewer should be Viewer3D object');
    
    fprintf('  ✓ Grey mesh displayed successfully\n');
    fprintf('  ✓ Viewer type: %s\n', class(B.Viewer));
    fprintf('  ✓ Background color: [%.1f %.1f %.1f]\n', B.Viewer.BackgroundColor);
    
    % Close viewer
    close(B.Viewer.Parent);
    pause(0.5);
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

fprintf('\n');

%% Scenario 2: Signal on Manifold domain (scalar field)
fprintf('Scenario 2: Signal on Manifold domain (scalar field)\n');
fprintf('───────────────────────────────────────────────────────────\n');

try
    % Create random signal on Manifold [N×1]
    signalData = randn(B.Manifold.N, 1);
    S_manifold = bct.Signal(B.Manifold, signalData, 'Random Scalar Field');
    
    fprintf('  Signal created:\n');
    fprintf('    Domain: %s\n', S_manifold.Domain.name);
    fprintf('    Size: [%d × %d]\n', size(S_manifold.Data));
    fprintf('    Label: %s\n', S_manifold.Label);
    
    % Visualize using showSignal
    B.showSignal(S_manifold, 'ColorMap', 'turbo');
    
    % Verify visualization
    assert(~isempty(B.Viewer), 'Viewer should be created');
    assert(isa(B.Viewer, 'images.ui.graphics3d.Viewer3D'), 'Viewer should be Viewer3D object');
    
    fprintf('  ✓ Signal visualized successfully\n');
    fprintf('  ✓ Colormap: turbo\n');
    
    % Close viewer
    close(B.Viewer.Parent);
    pause(0.5);
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

fprintf('\n');

%% Scenario 3: Signal on Joint Manifold-Time domain
fprintf('Scenario 3: Signal on Joint Manifold-Time domain\n');
fprintf('───────────────────────────────────────────────────────────\n');

try
    % Create Time domain
    T = 50;  % 50 time points
    fs = 100;  % 100 Hz
    B.Time = bct.Time(T, fs);
    
    fprintf('  Time domain created:\n');
    fprintf('    Time points: %d\n', B.Time.N);
    fprintf('    Sampling rate: %d Hz\n', B.Time.fs);
    
    % Create Joint Manifold-Time domain
    B = B.createJoint('Manifold', 'Time');
    dims = B.Joint.N;
    
    fprintf('  Joint domain created:\n');
    fprintf('    Type: %s\n', B.Joint.Domain);
    fprintf('    Dimensions: [%d × %d]\n', dims(1), dims(2));
    fprintf('    Total points: %d\n', prod(dims));
    
    % Create spatiotemporal signal [N × T]
    signalData_st = randn(dims);
    S_joint = bct.Signal(B.Joint, signalData_st, 'Spatiotemporal Signal');
    
    fprintf('  Spatiotemporal signal created:\n');
    fprintf('    Domain: %s\n', S_joint.Domain.Domain);
    fprintf('    Size: [%d × %d]\n', size(S_joint.Data));
    fprintf('    Label: %s\n', S_joint.Label);
    
    % Visualize time point 25
    timePoint = 25;
    B.showSignal(S_joint, 'TimePoint', timePoint, 'ColorMap', 'parula');
    
    % Verify visualization
    assert(~isempty(B.Viewer), 'Viewer should be created');
    assert(isa(B.Viewer, 'images.ui.graphics3d.Viewer3D'), 'Viewer should be Viewer3D object');
    
    fprintf('  ✓ Time point %d visualized successfully\n', timePoint);
    fprintf('  ✓ Colormap: parula\n');
    
    % Test different time points
    fprintf('\n  Testing multiple time points...\n');
    for t = [1, 10, 25, 40, 50]
        B.showSignal(S_joint, 'TimePoint', t, 'ColorMap', 'jet');
        fprintf('    ✓ Time point %d rendered\n', t);
        close(B.Viewer.Parent);
        pause(0.2);
    end
    
catch ME
    fprintf('  ✗ FAILED: %s\n', ME.message);
    rethrow(ME);
end

fprintf('\n');

%% Summary
fprintf('═══════════════════════════════════════════════════════════\n');
fprintf(' ✓ All visualization scenarios passed!\n');
fprintf('═══════════════════════════════════════════════════════════\n\n');

fprintf('Verified functionality:\n');
fprintf('  ✓ Scenario 1: Grey mesh without signal\n');
fprintf('  ✓ Scenario 2: Scalar field on Manifold domain\n');
fprintf('  ✓ Scenario 3: Spatiotemporal signal on Joint domain\n\n');

fprintf('Visualization API validated:\n');
fprintf('  • B.showMesh()                        - Display grey mesh\n');
fprintf('  • B.showSignal(S_manifold)            - Display Manifold signal\n');
fprintf('  • B.showSignal(S_joint, ''TimePoint'', t) - Display Joint signal at time t\n');
fprintf('  • Colormap support: ''grey'', ''parula'', ''turbo'', ''jet'', etc.\n\n');
