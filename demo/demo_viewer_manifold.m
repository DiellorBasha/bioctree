%% demo_viewer_manifold.m
% Demonstrates bct.ui.manifold.Viewer with bct.Manifold object integration
%
% This demo shows:
%   1. Loading mesh data from fsaverage
%   2. Creating a bct.Manifold object
%   3. Using setMesh with the Manifold object (includes pre-computed normals)
%   4. Comparing performance with and without pre-computed normals

%% Initialize
clear; close all; clc;

% Load mesh data
fprintf('Loading fsaverage right hemisphere mesh...\n');
meshFile = fullfile('data', 'mesh', 'fsaverage_rh_pial.mat');
if ~isfile(meshFile)
    error('Mesh file not found: %s', meshFile);
end
data = load(meshFile);
V = data.V;
F = data.F;
fprintf('  Loaded: %d vertices, %d faces\n', size(V,1), size(F,1));

%% Create Manifold object
fprintf('\nCreating bct.Manifold object...\n');
tic;
M = bct.Manifold(V, F);
tManifold = toc;
fprintf('  Manifold created in %.3f seconds\n', tManifold);

%% Test 1: setMesh with Manifold object (includes normals)
fprintf('\n=== TEST 1: setMesh(manifold) - with pre-computed normals ===\n');

% Create viewer
gr = groot;
v1 = bct.ui.manifold.Viewer(gr);
v1.HTMLComponent.Position = [10 10 800 600];

% Pre-compute normals
fprintf('Computing normals in MATLAB...\n');
tic;
N = M.normals();
tNormals = toc;
fprintf('  Normals computed in %.3f seconds (%d vertices)\n', tNormals, size(N,1));

% Set mesh with Manifold object
fprintf('Calling setMesh(manifold)...\n');
tic;
v1.setMesh(M);
tSetMesh1 = toc;
fprintf('  setMesh(manifold) completed in %.3f seconds\n', tSetMesh1);

% Wait for rendering and get logs
pause(2.0);
logs1 = v1.getLogs();
fprintf('\nJavaScript logs (with normals):\n%s\n', logs1);
v1.clearLogs();

%% Test 2: setMesh with V, F only (no normals - will compute in JavaScript)
fprintf('\n=== TEST 2: setMesh(V, F) - without normals (fallback) ===\n');

% Create second viewer
v2 = bct.ui.manifold.Viewer(gr);
v2.HTMLComponent.Position = [820 10 800 600];

% Set mesh without normals
fprintf('Calling setMesh(V, F)...\n');
tic;
v2.setMesh(V, F);
tSetMesh2 = toc;
fprintf('  setMesh(V, F) completed in %.3f seconds\n', tSetMesh2);

% Wait for rendering and get logs
pause(2.0);
logs2 = v2.getLogs();
fprintf('\nJavaScript logs (without normals, fallback computation):\n%s\n', logs2);
v2.clearLogs();

%% Test 3: setMesh with V, F, N (explicit normals)
fprintf('\n=== TEST 3: setMesh(V, F, N) - with explicit normals ===\n');

% Create third viewer
v3 = bct.ui.manifold.Viewer(gr);
v3.HTMLComponent.Position = [10 620 800 600];

% Set mesh with explicit normals
fprintf('Calling setMesh(V, F, N)...\n');
tic;
v3.setMesh(M.Vertices, M.Faces, N);  % Access properties directly
tSetMesh3 = toc;
fprintf('  setMesh(V, F, N) completed in %.3f seconds\n', tSetMesh3);

% Wait for rendering and get logs
pause(2.0);
logs3 = v3.getLogs();
fprintf('\nJavaScript logs (with explicit normals):\n%s\n', logs3);
v3.clearLogs();

%% Summary
fprintf('\n=== PERFORMANCE SUMMARY ===\n');
fprintf('Manifold creation:        %.3f s\n', tManifold);
fprintf('MATLAB normals computation: %.3f s\n', tNormals);
fprintf('setMesh(manifold):         %.3f s (MATLAB side)\n', tSetMesh1);
fprintf('setMesh(V, F):             %.3f s (MATLAB side, JS computes normals)\n', tSetMesh2);
fprintf('setMesh(V, F, N):          %.3f s (MATLAB side)\n', tSetMesh3);
fprintf('\nExpected: Test 1 & 3 should be faster in JavaScript (no normals computation)\n');
fprintf('          Test 2 will show warning and compute normals (~120ms for 163k vertices)\n');

%% Interactive mode
fprintf('\nViewers created. You can interact with them:\n');
fprintf('  v1 - Manifold object (pre-computed normals)\n');
fprintf('  v2 - V, F only (JavaScript fallback normals)\n');
fprintf('  v3 - V, F, N explicit (pre-computed normals)\n');
fprintf('\nType "return" to continue or close figures to exit.\n');
keyboard;
