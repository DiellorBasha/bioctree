%% Test d0 Sign Convention
% Check if d0 operator has opposite sign convention

clear; close all;

% Add paths
addpath(fullfile(pwd, '..', '..', 'external', 'bioelectromagnetism'));
addpath(genpath(fullfile(pwd, '..', '..', 'external', 'DECLab')));
addpath(genpath(fullfile(pwd, '..', '..', 'external', 'gptoolbox')));
addpath(fullfile(pwd, '..', '..', 'toolbox'));

fprintf('=== TESTING d0 SIGN CONVENTION ===\n');

%% Load Mesh
fs5path = 'C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage5\surf\lh.pial';
[vertices, faces] = freesurfer_read_surf(fs5path);
faces = fliplr(faces);
M = bct.Manifold(vertices, faces);

%% Get operators
ops = M.operators();
d0 = ops.d0.value;

%% Get topology
topo = M.topology();
edges = topo.edgeList.value;
nEdges = size(edges, 1);

%% Create test function on vertices
% Use coordinate x as test function
beta = double(vertices(:,1));

fprintf('\nTest function β = x-coordinate\n');
fprintf('  Range: [%.3f, %.3f]\n', min(beta), max(beta));

%% Compute d0β manually and with operator
manual = zeros(nEdges, 1);
for e = 1:nEdges
    v1 = edges(e,1);
    v2 = edges(e,2);
    manual(e) = beta(v2) - beta(v1);  % d0: β(tail) → β(head)
end

operator = d0 * beta;

%% Compare
fprintf('\nManual vs Operator (first 10 edges):\n');
fprintf(' Edge |     v1     v2 |      Manual     Operator |      Ratio\n');
fprintf('--------------------------------------------------------------\n');
for e = 1:10
    v1 = edges(e,1);
    v2 = edges(e,2);
    ratio = operator(e) / manual(e);
    fprintf('%5d | %6d %6d | %12.6f %12.6f | %10.3f\n', ...
        e, v1, v2, manual(e), operator(e), ratio);
end

%% Compute statistics
ratio = operator ./ manual;
ratio(isnan(ratio) | isinf(ratio)) = [];  % Remove NaN/Inf

fprintf('\nRatio statistics (operator / manual):\n');
fprintf('  Mean: %.6f\n', mean(ratio));
fprintf('  Std : %.6f\n', std(ratio));
fprintf('  Min : %.6f\n', min(ratio));
fprintf('  Max : %.6f\n', max(ratio));

if abs(mean(ratio) - 1.0) < 0.01
    fprintf('\n✓ PASS: d0 has CORRECT sign convention\n');
    fprintf('  d0β = β(v2) - β(v1) for edge (v1,v2)\n');
elseif abs(mean(ratio) + 1.0) < 0.01
    fprintf('\n✗ FAIL: d0 has OPPOSITE sign convention!\n');
    fprintf('  d0β = β(v1) - β(v2) instead of β(v2) - β(v1)\n');
    fprintf('  This explains the discrepancy with JavaScript!\n');
else
    fprintf('\n? UNCLEAR: Unexpected ratio pattern\n');
end
