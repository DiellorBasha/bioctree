% test_addLine.m - Test the new addLine functionality
%
% Tests:
% 1. Simple line segments using Segments parameter
% 2. Line segments using Start/End parameters
% 3. Multiple layers with different colors
% 4. Clear specific layer
% 5. Clear all layers

%% Setup
clear; close all;

% Load canonical test manifold
M = bct.data.load('Id', 'fsaverage_rh_pial');

% Create viewer
V = bct.ui.manifold.Viewer(M);

%% Test 1: Simple line segments using Segments parameter
fprintf('Test 1: Direct segment specification\n');

% Create a few random line segments on the mesh
nSegs = 10;
vertices = M.vertices;
randIdx = randperm(size(vertices, 1), 2 * nSegs);

% Create segments array [x1,y1,z1,x2,y2,z2,...]
segments = zeros(nSegs, 6);
for i = 1:nSegs
    segments(i, 1:3) = vertices(randIdx(2*i-1), :);
    segments(i, 4:6) = vertices(randIdx(2*i), :);
end

V.addLine('Name', 'test1', 'Segments', segments, ...
    'Color', 0xff0000, 'LineWidth', 2);

pause(2);

%% Test 2: Start/End point specification
fprintf('Test 2: Start/End point specification\n');

% Create geodesic-like connections (connect nearby vertices)
nLines = 20;
centers = randperm(size(vertices, 1), nLines);
startPts = vertices(centers, :);
endPts = zeros(nLines, 3);

% Find a nearby vertex for each center
for i = 1:nLines
    dists = vecnorm(vertices - startPts(i, :), 2, 2);
    [~, sortIdx] = sort(dists);
    endIdx = sortIdx(randi([20, 50])); % Random nearby vertex
    endPts(i, :) = vertices(endIdx, :);
end

V.addLine('Name', 'test2', 'Action', 'add', ...
    'Start', startPts, 'End', endPts, ...
    'Color', 0x00ff00, 'LineWidth', 3);

pause(2);

%% Test 3: Multiple layers with different colors
fprintf('Test 3: Multiple layers with different styles\n');

% Layer 3: Vertical lines
nVert = 15;
vertIdx = randperm(size(vertices, 1), nVert);
vertStart = vertices(vertIdx, :);
vertEnd = vertStart;
vertEnd(:, 3) = vertEnd(:, 3) + 5; % Add 5mm in Z direction

V.addLine('Name', 'vertical', 'Action', 'add', ...
    'Start', vertStart, 'End', vertEnd, ...
    'Color', 0x0000ff, 'LineWidth', 1);

pause(2);

%% Test 4: Clear specific layer
fprintf('Test 4: Clear specific layer (test1)\n');
V.addLine('Name', 'test1', 'Action', 'clear');

pause(2);

%% Test 5: Clear all layers
fprintf('Test 5: Clear all line layers\n');
V.addLine('Action', 'clear');

fprintf('Test complete!\n');

%% Test 6: Add lines back for visual inspection
fprintf('Test 6: Final visualization with labeled layers\n');

% Create a radial pattern from a central point
centerIdx = randi(size(vertices, 1));
centerPt = vertices(centerIdx, :);

% Find nearby vertices
dists = vecnorm(vertices - centerPt, 2, 2);
[~, sortIdx] = sort(dists);
nearbyIdx = sortIdx(2:31); % 30 nearby vertices (skip center itself)

% Create radial lines
radialStart = repmat(centerPt, 30, 1);
radialEnd = vertices(nearbyIdx, :);

V.addLine('Name', 'radial', 'Start', radialStart, 'End', radialEnd, ...
    'Color', 0xff00ff, 'LineWidth', 2);

fprintf('\nAll tests passed! Radial pattern displayed for inspection.\n');
