% Test bct.show.visualizer function directly
% This tests the visualizer without needing full Bct object setup

clear; close all;

fprintf('Testing bct.show.visualizer\n');
fprintf('==========================\n\n');

% Add paths
addpath('external');
addpath('toolbox');

%% Test 1: Basic surfaceMesh visualization
fprintf('Test 1: Basic surfaceMesh...\n');
try
    [V, F] = icosphere(2);  % Simple icosphere
    sMesh = surfaceMesh(V, F);
    viewer = bct.show.visualizer(sMesh);
    fprintf('   PASS: Basic surfaceMesh rendered\n\n');
    pause(1);
    close(viewer.Parent);
catch ME
    fprintf('   FAIL: %s\n\n', ME.message);
end

%% Test 2: surfaceMesh with colormap
fprintf('Test 2: surfaceMesh with turbo colormap...\n');
try
    [V, F] = icosphere(2);
    sMesh = surfaceMesh(V, F);
    viewer = bct.show.visualizer(sMesh, 'ColorMap', 'turbo');
    fprintf('   PASS: Colormap applied\n\n');
    pause(1);
    close(viewer.Parent);
catch ME
    fprintf('   FAIL: %s\n\n', ME.message);
end

%% Test 3: surfaceMesh with signal data
fprintf('Test 3: surfaceMesh with custom signal data...\n');
try
    [V, F] = icosphere(2);
    N = size(V, 1);
    sMesh = surfaceMesh(V, F);
    
    % Create signal: distance from north pole
    signalData = sqrt(sum((V - [0 0 1]).^2, 2));
    
    viewer = bct.show.visualizer(sMesh, 'SignalData', signalData, 'ColorMap', 'jet');
    fprintf('   PASS: Signal data rendered with jet colormap\n\n');
    pause(1);
    close(viewer.Parent);
catch ME
    fprintf('   FAIL: %s\n\n', ME.message);
end

%% Test 4: Wireframe mode
fprintf('Test 4: Wireframe visualization...\n');
try
    [V, F] = icosphere(2);
    sMesh = surfaceMesh(V, F);
    viewer = bct.show.visualizer(sMesh, 'WireFrame', true, 'ColorMap', 'cool');
    fprintf('   PASS: Wireframe rendered\n\n');
    pause(1);
    close(viewer.Parent);
catch ME
    fprintf('   FAIL: %s\n\n', ME.message);
end

%% Test 5: Point cloud mode
fprintf('Test 5: Point cloud (VerticesOnly) visualization...\n');
try
    [V, F] = icosphere(2);
    sMesh = surfaceMesh(V, F);
    viewer = bct.show.visualizer(sMesh, 'VerticesOnly', true, 'ColorMap', 'hot');
    fprintf('   PASS: Point cloud rendered\n\n');
    pause(1);
    close(viewer.Parent);
catch ME
    fprintf('   FAIL: %s\n\n', ME.message);
end

%% Test 6: Centering
fprintf('Test 6: Mesh centering...\n');
try
    [V, F] = icosphere(2);
    V = V + [5, 10, -3];  % Offset mesh
    sMesh = surfaceMesh(V, F);
    viewer = bct.show.visualizer(sMesh, 'Center', true);
    fprintf('   PASS: Centered mesh rendered\n\n');
    pause(1);
    close(viewer.Parent);
catch ME
    fprintf('   FAIL: %s\n\n', ME.message);
end

fprintf('\nAll visualizer tests completed!\n');
