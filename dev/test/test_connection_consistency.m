%% Test Connection Consistency - Diagnose trivial connection issues
%
% This script verifies:
% 1. Singularity sum matches topology (Gauss-Bonnet)
% 2. Combined transport is closed (path independent)
% 3. Loop integration around singularities

clear; close all;

%% Load manifold
M = bct.data.load('Id', 'fsaverage_rh_pial');
nV = size(M.vertices, 1);
nF = size(M.faces, 1);

% Get topology
topo = M.topology();
geom = M.geometry();

fprintf('Mesh: %d vertices, %d faces\n', nV, nF);

%% Test 1: Check Euler characteristic
chi = nV - size(topo.edges.value, 1) + nF;
fprintf('\nTest 1: Topology\n');
fprintf('  Euler characteristic χ = V - E + F = %d\n', chi);
fprintf('  Expected for sphere: χ = 2\n');

if chi ~= 2
    warning('Mesh is not topologically a sphere! χ ≠ 2');
end

%% Test 2: Gauss-Bonnet verification
K = geom.vertex.angleDefect.value;  % Gaussian curvature
totalK = sum(K);
expectedK = 2 * pi * chi;

fprintf('\nTest 2: Gauss-Bonnet\n');
fprintf('  ∫K dA = %.6f\n', totalK);
fprintf('  2π·χ  = %.6f\n', expectedK);
fprintf('  Difference: %.2e\n', abs(totalK - expectedK));

if abs(totalK - expectedK) > 1e-6
    warning('Gauss-Bonnet not satisfied! Mesh may have issues.');
end

%% Test 3: Compute connection with two singularities
% Pick two vertices far apart
singIdx = [6653, 978];
singWeights = [1, 1];
totalSingularityIndex = sum(singWeights);

fprintf('\nTest 3: Trivial Connection\n');
fprintf('  Singularities: [%d, %d]\n', singIdx(1), singIdx(2));
fprintf('  Weights: [%d, %d]\n', singWeights(1), singWeights(2));
fprintf('  Total singularity index: %d\n', totalSingularityIndex);

if totalSingularityIndex ~= chi
    warning('Singularity sum (%d) ≠ χ (%d). Field will not be consistent!', ...
        totalSingularityIndex, chi);
end

conn = M.connection('trivial', 'singularities', singIdx, 'weights', singWeights);

%% Test 4: Check combined transport closure
trans = bct.manifold.connection.transport(M, conn);
combined = trans.combinedTransport.value;  % [nH×1]

fprintf('\nTest 4: Transport Closure\n');

% For each face, sum the transport around its boundary
% For exact forms: ∑(around face) combined(h) should ≈ 0
FH = topo.faceHalfedges.value;  % [nF×3]
faceClosure = zeros(nF, 1);

for f = 1:nF
    hs = FH(f, :);  % Halfedges around face
    faceClosure(f) = sum(combined(hs));
end

fprintf('  Face closure errors:\n');
fprintf('    Mean: %.2e\n', mean(faceClosure));
fprintf('    Max:  %.2e\n', max(abs(faceClosure)));
fprintf('    Std:  %.2e\n', std(faceClosure));

if max(abs(faceClosure)) > 1e-6
    warning('Combined transport is NOT closed! Expect inconsistent field.');
end

%% Test 5: Check if connection is actually coexact
% For coexact connection: d(phi) should have zero curl
% This means: for each face, the boundary integral should be small

phi_h = conn.trivialConnection.value;
phiClosure = zeros(nF, 1);

for f = 1:nF
    hs = FH(f, :);
    phiClosure(f) = sum(phi_h(hs));
end

fprintf('\nTest 5: Connection Coexactness\n');
fprintf('  Connection closure around faces:\n');
fprintf('    Mean: %.2e\n', mean(phiClosure));
fprintf('    Max:  %.2e\n', max(abs(phiClosure)));

% For a truly coexact connection from d(beta), closure should be zero

%% Test 6: BFS propagation consistency check
fprintf('\nTest 6: BFS Propagation\n');

% Propagate from different seed faces
seedFaces = [1, 100, 500, 1000];
alpha_results = zeros(nF, numel(seedFaces));

for i = 1:numel(seedFaces)
    result = bct.manifold.query.dual(M, combined, ...
        'seedFace', seedFaces(i), 'seedValue', 0, 'wrap', true);
    alpha_results(:, i) = result.alpha_face;
end

% Check if different seeds give same results (modulo constant shift)
fprintf('  Testing different seed faces:\n');
for i = 2:numel(seedFaces)
    % Find a face reachable from both seeds
    validFaces = ~isnan(alpha_results(:, 1)) & ~isnan(alpha_results(:, i));
    if sum(validFaces) > 0
        % Compute offset needed to align
        testFace = find(validFaces, 1);
        offset = alpha_results(testFace, 1) - alpha_results(testFace, i);
        
        % Check if all faces differ by same constant
        diff = alpha_results(validFaces, 1) - (alpha_results(validFaces, i) + offset);
        maxDiff = max(abs(diff));
        
        fprintf('    Seed %d vs Seed %d: max difference = %.2e\n', ...
            seedFaces(1), seedFaces(i), maxDiff);
        
        if maxDiff > 1e-6
            warning('Different seeds give DIFFERENT fields! BFS is path-dependent.');
        end
    end
end

%% Test 7: Visualize singularity locations
fprintf('\nTest 7: Singularity Locations\n');
V = M.vertices;
for i = 1:numel(singIdx)
    fprintf('  Singularity %d: vertex %d at [%.2f, %.2f, %.2f]\n', ...
        i, singIdx(i), V(singIdx(i), 1), V(singIdx(i), 2), V(singIdx(i), 3));
end

%% Summary
fprintf('\n=== SUMMARY ===\n');
if chi == 2
    fprintf('✓ Topology is sphere (χ=2)\n');
else
    fprintf('✗ Topology issue: χ=%d\n', chi);
end

if abs(totalK - expectedK) < 1e-6
    fprintf('✓ Gauss-Bonnet satisfied\n');
else
    fprintf('✗ Gauss-Bonnet violated\n');
end

if totalSingularityIndex == chi
    fprintf('✓ Singularity sum matches topology\n');
else
    fprintf('✗ Singularity sum ≠ χ\n');
end

if max(abs(faceClosure)) < 1e-6
    fprintf('✓ Combined transport is closed\n');
else
    fprintf('✗ Combined transport NOT closed\n');
end

fprintf('\nConclusion: ');
if max(abs(faceClosure)) > 1e-6
    fprintf('The combined transport is not path-independent!\n');
    fprintf('This means the BFS propagation will give WRONG results.\n');
    fprintf('You need a different algorithm (e.g., Poisson solve on faces).\n');
else
    fprintf('Transport appears consistent. Issue may be elsewhere.\n');
end
