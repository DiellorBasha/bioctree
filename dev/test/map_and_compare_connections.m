%% Map and Compare Connection Values Correctly
% This script builds a proper edge mapping between JavaScript and MATLAB
% based on vertex pairs, then compares connection values

clear; close all;

% Add paths
addpath(fullfile(pwd, '..', '..', 'external', 'bioelectromagnetism'));
addpath(genpath(fullfile(pwd, '..', '..', 'external', 'DECLab')));
addpath(genpath(fullfile(pwd, '..', '..', 'external', 'gptoolbox')));
addpath(fullfile(pwd, '..', '..', 'toolbox'));

%% Load Reference Data
jsonFile = 'C:\CodingProjects\potpourri3d-scripts\direction_field_data.json';
refData = jsondecode(fileread(jsonFile));

fprintf('=== BUILDING EDGE MAPPING ===\n');

%% Load Mesh (with flip to match current implementation)
fs5path = 'C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage5\surf\lh.pial';
[vertices, faces] = freesurfer_read_surf(fs5path);
M = bct.Manifold(vertices, faces);
Mf = M.flip;
clear M;
M = Mf;

%% Compute Connection
singularities = zeros(size(M.Vertices, 1), 1);
for i = 1:length(refData.singularities)
    vIdx = refData.singularities(i).index + 1;
    weight = refData.singularities(i).weight;
    singularities(vIdx) = weight;
end

singIdx = find(singularities ~= 0);
fprintf('Computing MATLAB connection...\n');
conn = M.connection('trivial', 'singularities', singIdx);
phi_matlab_he = conn.trivialConnection.value;

%% Build Edge-to-Vertices Map for MATLAB
fprintf('Building MATLABedge map...\n');
matlabEdgeMap = containers.Map('KeyType', 'char', 'ValueType', 'any');

% Get topology to map halfedges
topo = M.topology();
tailVertex = topo.tailVertex.value;
headVertex = topo.headVertex.value;
edgeField = topo.edge.value;

for e = 1:size(M.Edges, 1)
    v1 = M.Edges(e, 1);
    v2 = M.Edges(e, 2);
    
    % Find halfedges for this edge
    he_indices = find(edgeField == e);
    
    if length(he_indices) ~= 2
        error('Edge %d should have exactly 2 halfedges, found %d', e, length(he_indices));
    end
    
    % Match halfedges to orientations
    he1 = he_indices(1);
    he2 = he_indices(2);
    
    % Determine which halfedge matches which orientation
    if tailVertex(he1) == v1 && headVertex(he1) == v2
        he_fwd = he1;  % (v1→v2)
        he_rev = he2;  % (v2→v1)
    else
        he_fwd = he2;  % (v1→v2)
        he_rev = he1;  % (v2→v1)
    end
    
    % Store with orientation-specific halfedge indices
    key_forward = sprintf('%d_%d', v1, v2);
    key_reverse = sprintf('%d_%d', v2, v1);
    
    value_forward = struct('edgeIdx', e, 'halfedgeIdx', he_fwd, 'v1', v1, 'v2', v2);
    value_reverse = struct('edgeIdx', e, 'halfedgeIdx', he_rev, 'v1', v2, 'v2', v1);
    
    matlabEdgeMap(key_forward) = value_forward;
    matlabEdgeMap(key_reverse) = value_reverse;
end

fprintf('MATLAB edge map size: %d entries\n', matlabEdgeMap.Count);

%% Map JavaScript Edges to MATLAB and Compare
fprintf('\n=== MAPPING JAVASCRIPT TO MATLAB EDGES ===\n');

mappedCount = 0;
unmappedCount = 0;
signMatches = 0;
signFlips = 0;

% Store all comparisons
comparisons = struct('jsIdx', {}, 'mlIdx', {}, 'jsV1', {}, 'jsV2', {}, ...
    'mlV1', {}, 'mlV2', {}, 'jsPhi', {}, 'mlPhi', {}, 'diff', {}, 'oriented', {});

for i = 1:length(refData.edgeIndex)
    refEdge = refData.edgeIndex(i);
    jsV1 = refEdge.v1 + 1;  % 0-based -> 1-based
    jsV2 = refEdge.v2 + 1;
    
    % Get phi value - edgeIndex array is 0-based, so i corresponds to edge i-1 in JS
    % which has index i in MATLAB (1-based)
    jsPhi = refData.phi(i);
    
    % Look up in MATLAB edge map
    key = sprintf('%d_%d', jsV1, jsV2);
    
    if isKey(matlabEdgeMap, key)
        mlEdge = matlabEdgeMap(key);
        mlIdx = mlEdge.edgeIdx;
        mlHeIdx = mlEdge.halfedgeIdx;
        mlV1 = mlEdge.v1;
        mlV2 = mlEdge.v2;
        mlPhi = phi_matlab_he(mlHeIdx);
        
        % Check orientation (should always match now due to lookup)
        if (mlV1 == jsV1 && mlV2 == jsV2)
            % Same orientation - comparison is direct
            oriented = true;
            diff = abs(mlPhi - jsPhi);
            signMatches = signMatches + 1;
        else
            % This shouldn't happen with the new map structure
            warning('Unexpected orientation mismatch at edge %d', i);
            oriented = false;
            diff = abs(mlPhi + jsPhi);
            signFlips = signFlips + 1;
        end
        
        % Store comparison
        comparisons(end+1) = struct('jsIdx', i, 'mlIdx', mlIdx, ...
            'jsV1', jsV1, 'jsV2', jsV2, 'mlV1', mlV1, 'mlV2', mlV2, ...
            'jsPhi', jsPhi, 'mlPhi', mlPhi, 'diff', diff, 'oriented', oriented);
        
        mappedCount = mappedCount + 1;
    else
        unmappedCount = unmappedCount + 1;
    end
end

fprintf('\nMapping statistics:\n');
fprintf('  Mapped edges: %d/%d\n', mappedCount, length(refData.edgeIndex));
fprintf('  Unmapped edges: %d\n', unmappedCount);
fprintf('  Same orientation: %d\n', signMatches);
fprintf('  Opposite orientation: %d\n', signFlips);

%% Analyze Differences
fprintf('\n=== ANALYZING CONNECTION DIFFERENCES ===\n');

diffs = [comparisons.diff];
fprintf('Difference statistics:\n');
fprintf('  Min: %.6e\n', min(diffs));
fprintf('  Max: %.6e\n', max(diffs));
fprintf('  Mean: %.6e\n', mean(diffs));
fprintf('  Median: %.6e\n', median(diffs));
fprintf('  Std: %.6e\n', std(diffs));

% Find largest discrepancies
[sortedDiffs, sortIdx] = sort(diffs, 'descend');

fprintf('\nLargest discrepancies (top 10):\n');
fprintf('%5s | %8s | %10s %10s | %12s %12s | %12s | %s\n', ...
    'JSIdx', 'MLIdx', 'v1', 'v2', 'JS_φ', 'ML_φ', 'Diff', 'Orient');
fprintf('%s\n', repmat('-', 1, 95));

for i = 1:min(10, length(sortIdx))
    c = comparisons(sortIdx(i));
    orientStr = 'same';
    if ~c.oriented
        orientStr = 'flipped';
    end
    fprintf('%5d | %8d | %10d %10d | %12.6f %12.6f | %12.6e | %s\n', ...
        c.jsIdx, c.mlIdx, c.jsV1, c.jsV2, c.jsPhi, c.mlPhi, c.diff, orientStr);
end

fprintf('\nSmallest discrepancies (bottom 10):\n');
fprintf('%5s | %8s | %10s %10s | %12s %12s | %12s | %s\n', ...
    'JSIdx', 'MLIdx', 'v1', 'v2', 'JS_φ', 'ML_φ', 'Diff', 'Orient');
fprintf('%s\n', repmat('-', 1, 95));

for i = length(sortIdx):-1:max(1, length(sortIdx)-9)
    c = comparisons(i);
    orientStr = 'same';
    if ~c.oriented
        orientStr = 'flipped';
    end
    fprintf('%5d | %8d | %10d %10d | %12.6f %12.6f | %12.6e | %s\n', ...
        c.jsIdx, c.mlIdx, c.jsV1, c.jsV2, c.jsPhi, c.mlPhi, c.diff, orientStr);
end

%% Check if differences are within tolerance
fprintf('\n=== TOLERANCE CHECK ===\n');

tol_exact = 1e-6;
tol_good = 1e-3;
tol_ok = 1e-2;

exactMatches = sum(diffs < tol_exact);
goodMatches = sum(diffs < tol_good);
okMatches = sum(diffs < tol_ok);

fprintf('Matches within tolerance:\n');
fprintf('  Exact (< %.0e): %d/%d (%.1f%%)\n', tol_exact, exactMatches, mappedCount, 100*exactMatches/mappedCount);
fprintf('  Good (< %.0e):  %d/%d (%.1f%%)\n', tol_good, goodMatches, mappedCount, 100*goodMatches/mappedCount);
fprintf('  OK (< %.0e):    %d/%d (%.1f%%)\n', tol_ok, okMatches, mappedCount, 100*okMatches/mappedCount);

%% Final Verdict
fprintf('\n====== FINAL VERDICT ======\n');

if mean(diffs) < 1e-3
    fprintf('✅ EXCELLENT MATCH!\n');
    fprintf('   Mean difference: %.2e\n', mean(diffs));
    fprintf('   The implementations are equivalent (within numerical precision).\n');
    fprintf('   Differences are likely due to:\n');
    fprintf('   - Floating point precision\n');
    fprintf('   - Edge orientation conventions\n');
elseif mean(diffs) < 1e-2
    fprintf('✅ GOOD MATCH\n');
    fprintf('   Mean difference: %.2e\n', mean(diffs));
    fprintf('   Minor discrepancies detected, but implementations are fundamentally correct.\n');
else
    fprintf('❌ SIGNIFICANT DIFFERENCES\n');
    fprintf('   Mean difference: %.2e\n', mean(diffs));
    fprintf('   The implementations diverge. Possible causes:\n');
    fprintf('   - Different formulas or algorithms\n');
    fprintf('   - Different operator implementations (Hodge star, exterior derivative)\n');
    fprintf('   - Bugs in one or both implementations\n');
end
