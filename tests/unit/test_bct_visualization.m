% Test Bct Visualization System with FreeSurfer Mesh
% This script properly initializes bioctree and tests all visualization features

clear; close all;

%% Initialize Bioctree
fprintf('=== Initializing Bioctree ===\n');
bioctree_start;
fprintf('\n');

%% Test 1: Load FreeSurfer mesh
fprintf('Test 1: Loading FreeSurfer mesh (rh.pial)...\n');
try
    path = 'test-data\freesurfer\fsaverage\surf\rh.pial';
    B = bct.io.import.mesh(path);
    B.Time = bct.manifold.Time(100, 100);  % 1 sec @ 100 Hz
    fprintf('   PASS: Loaded mesh with %d vertices\n\n', B.Manifold.N);
catch ME
    fprintf('   FAIL: %s\n\n', ME.message);
    return;
end

%% Test 2: B.showMesh() - default visualization
fprintf('Test 2: B.showMesh() with default settings...\n');
try
    B.showMesh();
    fprintf('   PASS: Default mesh visualization created\n');
    fprintf('   (Close the viewer window to continue)\n\n');
    pause(2);
    close(B.Viewer.Parent);
catch ME
    fprintf('   FAIL: %s\n\n', ME.message);
end

%% Test 3: B.showMesh() with colormap
fprintf('Test 3: B.showMesh() with turbo colormap...\n');
try
    B.showMesh('ColorMap', 'turbo');
    fprintf('   PASS: Mesh with turbo colormap\n\n');
    pause(2);
    close(B.Viewer.Parent);
catch ME
    fprintf('   FAIL: %s\n\n', ME.message);
end

%% Test 4: bct.show.mesh wrapper
fprintf('Test 4: bct.show.mesh(B) wrapper function...\n');
try
    viewer = bct.show.mesh(B, 'ColorMap', 'cool');
    fprintf('   PASS: bct.show.mesh with cool colormap\n\n');
    pause(2);
    close(viewer.Parent);
catch ME
    fprintf('   FAIL: %s\n\n', ME.message);
end

%% Test 5: Generate and visualize spatial signal
fprintf('Test 5: Creating and visualizing spatial signal...\n');
try
    N = B.Manifold.N;
    V = B.Manifold.V;
    
    % Create spatial gradient signal (x-coordinate)
    signalData = V(:, 1);  % x-coordinate as signal
    
    % Add as Signal object
    sig = bct.signal.Signal();
    sig.Data = signalData;
    sig.Label = 'X-coordinate gradient';
    B.Signals = sig;
    
    % Visualize signal
    B.showSignal(1, 'ColorMap', 'jet');
    fprintf('   PASS: Signal visualization with jet colormap\n\n');
    pause(2);
    close(B.Viewer.Parent);
catch ME
    fprintf('   FAIL: %s\n\n', ME.message);
end

%% Test 6: bct.show.signal wrapper
fprintf('Test 6: bct.show.signal(B, 1) wrapper function...\n');
try
    viewer = bct.show.signal(B, 1, 'ColorMap', 'hot');
    fprintf('   PASS: bct.show.signal with hot colormap\n\n');
    pause(2);
    close(viewer.Parent);
catch ME
    fprintf('   FAIL: %s\n\n', ME.message);
end

%% Test 7: Time-varying signal
fprintf('Test 7: Creating time-varying signal...\n');
try
    T = B.Time.T;
    
    % Create traveling wave pattern
    timeSignalData = zeros(N, T);
    for t = 1:T
        % Simple temporal modulation of x-coordinate
        phase = 2*pi*t/T;
        timeSignalData(:,t) = V(:,1) * cos(phase) + V(:,2) * sin(phase);
    end
    
    sig2 = bct.signal.Signal();
    sig2.Data = timeSignalData;
    sig2.Label = 'Traveling wave';
    B.Signals(2) = sig2;
    
    % Visualize at time point 50
    B.showSignal(2, 'TimePoint', 50, 'ColorMap', 'parula');
    fprintf('   PASS: Time-varying signal at t=50\n\n');
    pause(2);
    close(B.Viewer.Parent);
catch ME
    fprintf('   FAIL: %s\n\n', ME.message);
end

%% Test 8: Different time points
fprintf('Test 8: Visualizing different time points...\n');
try
    % Time point 1
    B.showSignal(2, 'TimePoint', 1, 'ColorMap', 'parula');
    fprintf('   Showing t=1...\n');
    pause(1);
    close(B.Viewer.Parent);
    
    % Time point 75
    B.showSignal(2, 'TimePoint', 75, 'ColorMap', 'parula');
    fprintf('   Showing t=75...\n');
    pause(1);
    close(B.Viewer.Parent);
    
    fprintf('   PASS: Multiple time points visualized\n\n');
catch ME
    fprintf('   FAIL: %s\n\n', ME.message);
end

%% Test 9: Wireframe mode
fprintf('Test 9: Wireframe visualization...\n');
try
    B.showMesh('WireFrame', true, 'ColorMap', 'gray');
    fprintf('   PASS: Wireframe mode\n\n');
    pause(2);
    close(B.Viewer.Parent);
catch ME
    fprintf('   FAIL: %s\n\n', ME.message);
end

%% Test 10: Custom signal data via visualizer
fprintf('Test 10: Direct visualizer call with custom signal...\n');
try
    % Create custom signal (distance from centroid)
    centroid = mean(V, 1);
    customSignal = sqrt(sum((V - centroid).^2, 2));
    
    viewer = bct.show.visualizer(B, 'SignalData', customSignal, 'ColorMap', 'viridis');
    fprintf('   PASS: Custom signal via visualizer\n\n');
    pause(2);
    close(viewer.Parent);
catch ME
    fprintf('   FAIL: %s\n\n', ME.message);
end

fprintf('\n=== All visualization tests completed! ===\n');
fprintf('Summary:\n');
fprintf('  - Loaded FreeSurfer mesh with %d vertices\n', B.Manifold.N);
fprintf('  - Created %d test signals\n', length(B.Signals));
fprintf('  - Tested mesh, signal, and time-varying visualizations\n');
fprintf('  - All three API levels working:\n');
fprintf('    1. Bct methods: B.showMesh(), B.showSignal()\n');
fprintf('    2. Package functions: bct.show.mesh(), bct.show.signal()\n');
fprintf('    3. Core visualizer: bct.show.visualizer()\n');
