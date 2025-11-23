% Comprehensive Bct Visualization Demo
% Demonstrates all visualization features with FreeSurfer mesh

clear; close all;

fprintf('\n');
fprintf('========================================\n');
fprintf('  Bct Visualization System Demo\n');
fprintf('========================================\n\n');

%% Initialize
bioctree_start;

%% Load FreeSurfer mesh
fprintf('Loading FreeSurfer mesh (rh.pial)...\n');
path = 'test-data\freesurfer\fsaverage\surf\rh.pial';
B = bct.io.import.mesh(path);
B.Time = bct.manifold.Time(100, 100);  % 1 sec @ 100 Hz
fprintf('  Vertices: %d\n', B.Manifold.N);
fprintf('  Time points: %d @ %d Hz\n\n', B.Time.T, B.Time.fs);

%% Create signals
fprintf('Creating test signals...\n');
N = B.Manifold.N;
V = B.Manifold.V;
T = B.Time.T;

% Signal 1: Spatial gradient (static)
sig1 = bct.Signal();
sig1.Data = V(:, 1);  % x-coordinate
sig1.Label = 'Spatial gradient (X)';
B.Signals(1) = sig1;

% Signal 2: Traveling wave (dynamic)
timeSignal = zeros(N, T);
for t = 1:T
    phase = 2*pi*5*t/T;  % 5 cycles
    timeSignal(:,t) = V(:,1) * cos(phase) + V(:,2) * sin(phase);
end
sig2 = bct.Signal();
sig2.Data = timeSignal;
sig2.Label = 'Traveling wave (5 Hz)';
B.Signals(2) = sig2;

fprintf('  Created %d signals\n\n', length(B.Signals));

%% Demonstration
fprintf('========================================\n');
fprintf('Visualization Demonstrations:\n');
fprintf('========================================\n\n');

fprintf('Demo 1: Basic mesh (gray colormap)\n');
fprintf('  Command: B.showMesh()\n');
B.showMesh();
pause(3);
close(B.Viewer.Parent);

fprintf('\nDemo 2: Mesh with custom colormap\n');
fprintf('  Command: B.showMesh(''ColorMap'', ''turbo'')\n');
B.showMesh('ColorMap', 'turbo');
pause(3);
close(B.Viewer.Parent);

fprintf('\nDemo 3: Static signal visualization\n');
fprintf('  Command: B.showSignal(1, ''ColorMap'', ''jet'')\n');
B.showSignal(1, 'ColorMap', 'jet');
pause(3);
close(B.Viewer.Parent);

fprintf('\nDemo 4: Time-varying signal at specific time point\n');
fprintf('  Command: B.showSignal(2, ''TimePoint'', 25, ''ColorMap'', ''parula'')\n');
B.showSignal(2, 'TimePoint', 25, 'ColorMap', 'parula');
pause(3);
close(B.Viewer.Parent);

fprintf('\nDemo 5: Wireframe visualization\n');
fprintf('  Command: B.showMesh(''WireFrame'', true)\n');
B.showMesh('WireFrame', true);
pause(3);
close(B.Viewer.Parent);

fprintf('\nDemo 6: Package function - bct.show.mesh\n');
fprintf('  Command: viewer = bct.show.mesh(B, ''ColorMap'', ''cool'')\n');
viewer = bct.show.mesh(B, 'ColorMap', 'cool');
pause(3);
close(viewer.Parent);

fprintf('\nDemo 7: Package function - bct.show.signal\n');
fprintf('  Command: viewer = bct.show.signal(B, 1, ''ColorMap'', ''hot'')\n');
viewer = bct.show.signal(B, 1, 'ColorMap', 'hot');
pause(3);
close(viewer.Parent);

fprintf('\nDemo 8: Direct visualizer with custom signal\n');
fprintf('  Command: viewer = bct.show.visualizer(B, ''SignalData'', customSignal)\n');
centroid = mean(V, 1);
customSignal = sqrt(sum((V - centroid).^2, 2));
viewer = bct.show.visualizer(B, 'SignalData', customSignal, 'ColorMap', 'viridis');
pause(3);
close(viewer.Parent);

%% Summary
fprintf('\n========================================\n');
fprintf('Summary\n');
fprintf('========================================\n\n');
fprintf('Successfully demonstrated:\n');
fprintf('  ✓ Basic mesh visualization\n');
fprintf('  ✓ Custom colormaps\n');
fprintf('  ✓ Static signal display\n');
fprintf('  ✓ Time-varying signal with time point selection\n');
fprintf('  ✓ Wireframe mode\n');
fprintf('  ✓ All three API levels:\n');
fprintf('    - Bct methods: B.showMesh(), B.showSignal()\n');
fprintf('    - Package functions: bct.show.mesh(), bct.show.signal()\n');
fprintf('    - Core visualizer: bct.show.visualizer()\n');
fprintf('\nMesh: %s\n', path);
fprintf('Vertices: %d\n', B.Manifold.N);
fprintf('Signals: %d\n', length(B.Signals));
fprintf('\n========================================\n');
fprintf('Demo complete!\n');
fprintf('========================================\n\n');

