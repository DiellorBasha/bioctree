%% Test Edge Orientation Fix
% This script tests if we can fix the connection by accounting for
% edge orientation differences between JavaScript and MATLAB

clear; close all;

% Add paths
addpath(fullfile(pwd, '..', '..', 'external', 'bioelectromagnetism'));
addpath(genpath(fullfile(pwd, '..', '..', 'external', 'DECLab')));
addpath(genpath(fullfile(pwd, '..', '..', 'external', 'gptoolbox')));

%% Load Reference Data
jsonFile = 'C:\CodingProjects\potpourri3d-scripts\direction_field_data.json';
refData = jsondecode(fileread(jsonFile));

%% Load Mesh
fs5path = 'C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage5\surf\lh.pial';
[vertices, faces] = freesurfer_read_surf(fs5path);

%% Test 1: Load WITHOUT flip
fprintf('=== TEST 1: WITHOUT FLIP ===\n');
M1 = bct.Manifold(vertices, faces);

% Check first 10 edges
fprintf('\nFirst 10 edges (NO flip):\n');
for e = 1:10
    fprintf('  Edge %d: %d -> %d\n', e, M1.Edges(e,1), M1.Edges(e,2));
end

%% Test 2: Load WITH flip (current approach)
fprintf('\n=== TEST 2: WITH FLIP ===\n');
M2 = bct.Manifold(vertices, faces);
Mf = M2.flip;
clear M2;
M2 = Mf;

fprintf('\nFirst 10 edges (WITH flip):\n');
for e = 1:10
    fprintf('  Edge %d: %d -> %d\n', e, M2.Edges(e,1), M2.Edges(e,2));
end

%% Test 3: Compare with JavaScript edges
fprintf('\n=== TEST 3: COMPARE WITH JAVASCRIPT ===\n');
fprintf('\n%5s | %10s %10s | %10s %10s | %10s %10s | %s\n', ...
    'Edge', 'JS_v1', 'JS_v2', 'NoFlip_v1', 'NoFlip_v2', 'Flip_v1', 'Flip_v2', 'Match');
fprintf('%s\n', repmat('-', 1, 100));

matchesNoFlip = 0;
matchesFlip = 0;

for i = 1:min(20, length(refData.edgeIndex))
    refEdge = refData.edgeIndex(i);
    jsV1 = refEdge.v1 + 1;  % 0-based -> 1-based
    jsV2 = refEdge.v2 + 1;
    
    % Check if edge i matches
    matchStr = '';
    if i <= size(M1.Edges, 1)
        nf1 = M1.Edges(i, 1);
        nf2 = M1.Edges(i, 2);
        f1 = M2.Edges(i, 1);
        f2 = M2.Edges(i, 2);
        
        % Check NoFlip match
        if (nf1 == jsV1 && nf2 == jsV2) || (nf1 == jsV2 && nf2 == jsV1)
            matchesNoFlip = matchesNoFlip + 1;
            matchStr = [matchStr, 'NoFlip '];
        end
        
        % Check Flip match
        if (f1 == jsV1 && f2 == jsV2) || (f1 == jsV2 && f2 == jsV1)
            matchesFlip = matchesFlip + 1;
            matchStr = [matchStr, 'Flip '];
        end
        
        fprintf('%5d | %10d %10d | %10d %10d | %10d %10d | %s\n', ...
            i, jsV1, jsV2, nf1, nf2, f1, f2, matchStr);
    end
end

fprintf('\nMatching statistics (first 20 edges):\n');
fprintf('  NoFlip matches: %d/20\n', matchesNoFlip);
fprintf('  Flip matches: %d/20\n', matchesFlip);

%% Test 4: What if we DON'T flip?
fprintf('\n=== TEST 4: COMPUTE CONNECTION WITHOUT FLIP ===\n');

singularities = zeros(size(M1.Vertices, 1), 1);
for i = 1:length(refData.singularities)
    vIdx = refData.singularities(i).index + 1;
    weight = refData.singularities(i).weight;
    singularities(vIdx) = weight;
end

singIdx = find(singularities ~= 0);
fprintf('Computing connection on non-flipped mesh...\n');

conn1 = M1.connection('trivial', 'singularities', singIdx);
phi1_he = conn1.trivialConnection.value;

% Convert to edges
phi1_edge = zeros(size(M1.Edges, 1), 1);
for e = 1:size(M1.Edges, 1)
    he1 = 2*e - 1;
    phi1_edge(e) = phi1_he(he1);
end

fprintf('Connection φ range: [%.6f, %.6f]\n', min(phi1_edge), max(phi1_edge));

%% Test 5: Compare with JavaScript
fprintf('\n=== TEST 5: COMPARE CONNECTION VALUES (NO FLIP) ===\n');

refPhi = [refData.phi]';
fprintf('JavaScript φ range: [%.6f, %.6f]\n', min(refPhi), max(refPhi));
fprintf('MATLAB φ range: [%.6f, %.6f]\n', min(phi1_edge), max(phi1_edge));

fprintf('\nDetailed comparison (first 20 edges):\n');
fprintf('%5s | %10s %10s | %10s %10s | %12s %12s %12s\n', ...
    'Edge', 'JS_v1', 'JS_v2', 'ML_v1', 'ML_v2', 'JS_φ', 'ML_φ', 'Diff');
fprintf('%s\n', repmat('-', 1, 90));

totalDiff = 0;
for i = 1:min(20, length(refData.edgeIndex))
    refEdge = refData.edgeIndex(i);
    jsV1 = refEdge.v1 + 1;
    jsV2 = refEdge.v2 + 1;
    jsPhi = refData.phi(i+1);  % Arrays in struct are 0-indexed
    
    if i <= size(M1.Edges, 1)
        mlV1 = M1.Edges(i, 1);
        mlV2 = M1.Edges(i, 2);
        mlPhi = phi1_edge(i);
        
        % Check if orientation matches
        if (mlV1 == jsV1 && mlV2 == jsV2)
            % Same orientation
            diff = abs(mlPhi - jsPhi);
        elseif (mlV1 == jsV2 && mlV2 == jsV1)
            % Opposite orientation - flip sign
            diff = abs(mlPhi + jsPhi);
        else
            % Different edge entirely
            diff = NaN;
        end
        
        totalDiff = totalDiff + diff;
        
        fprintf('%5d | %10d %10d | %10d %10d | %12.6f %12.6f %12.6f\n', ...
            i, jsV1, jsV2, mlV1, mlV2, jsPhi, mlPhi, diff);
    end
end

fprintf('\nMean absolute difference: %.6f\n', totalDiff/20);

fprintf('\n=== CONCLUSION ===\n');
if matchesNoFlip > matchesFlip
    fprintf('✓ NO FLIP gives better edge ordering match (%d vs %d)\n', matchesNoFlip, matchesFlip);
    fprintf('  → Remove M.flip from data loading!\n');
else
    fprintf('  FLIP gives better edge ordering match (%d vs %d)\n', matchesFlip, matchesNoFlip);
    fprintf('  → Keep M.flip, but edge construction still differs\n');
end
