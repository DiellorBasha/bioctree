%% Diagnose Connection Computation Discrepancy
% This script traces through each step of the trivial connection computation
% to identify where MATLAB and JavaScript implementations diverge.

clear; close all;

% Add necessary paths
addpath(fullfile(pwd, '..', '..', 'external', 'bioelectromagnetism'));
addpath(genpath(fullfile(pwd, '..', '..', 'external', 'DECLab')));
addpath(genpath(fullfile(pwd, '..', '..', 'external', 'gptoolbox')));

%% Load Reference Data from JavaScript
jsonFile = 'C:\CodingProjects\potpourri3d-scripts\direction_field_data.json';
if ~exist(jsonFile, 'file')
    error('Reference JSON file not found: %s', jsonFile);
end

refData = jsondecode(fileread(jsonFile));
fprintf('=== REFERENCE DATA (JavaScript) ===\n');
fprintf('Singularities: %d\n', length(refData.singularities));
fprintf('Edges: %d\n', length(refData.phi));
fprintf('Faces: %d\n', length(refData.faceData));

%% Load Mesh
fprintf('\n=== LOADING MESH ===\n');
fs5path = 'C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage5\surf\lh.pial';
[vertices, faces] = freesurfer_read_surf(fs5path);
M = bct.Manifold(vertices, faces);
Mf = M.flip; 
clear M; 
M = Mf;

fprintf('Mesh: %d vertices, %d faces, %d edges\n', ...
    size(M.Vertices, 1), size(M.Faces, 1), size(M.Edges, 1));

%% Create Singularities (convert 0-based to 1-based)
singularities = zeros(size(M.Vertices, 1), 1);
for i = 1:length(refData.singularities)
    vIdx = refData.singularities(i).index + 1;  % 0-based -> 1-based
    weight = refData.singularities(i).weight;
    singularities(vIdx) = weight;
end

singIdx = find(singularities ~= 0);
fprintf('\nMATLAB Singularities:\n');
for i = 1:length(singIdx)
    fprintf('  Vertex %d: weight = %.2f\n', singIdx(i), singularities(singIdx(i)));
end

%% Step 1: Compute Gaussian Curvature (Angle Defect)
fprintf('\n=== STEP 1: GAUSSIAN CURVATURE ===\n');

% MATLAB computation
[~, K_matlab] = bct.manifold.geometry.vertex.angleDefect(M);

% Compute Euler characteristic: χ = V - E + F
nV = size(M.Vertices, 1);
nE = size(M.Edges, 1);
nF = size(M.Faces, 1);
eulerChar = nV - nE + nF;

fprintf('MATLAB Angle Defect:\n');
fprintf('  Sum K: %.10f\n', sum(K_matlab));
fprintf('  Expected (2π·χ): %.10f (χ=%d)\n', 2*pi*eulerChar, eulerChar);
fprintf('  Error: %.2e\n', abs(sum(K_matlab) - 2*pi*eulerChar));

% Check Gauss-Bonnet
GB_error = abs(sum(K_matlab) - 2*pi*eulerChar);
if GB_error < 1e-6
    fprintf('  ✓ Gauss-Bonnet satisfied\n');
else
    fprintf('  ✗ Gauss-Bonnet violated! Error = %.2e\n', GB_error);
end

%% Step 2: Build RHS for Poisson Equation
fprintf('\n=== STEP 2: POISSON RHS ===\n');

% RHS: -K + 2π·s
rhs_matlab = -K_matlab + 2*pi*singularities;

fprintf('RHS vector:\n');
fprintf('  Sum(-K): %.10f\n', sum(-K_matlab));
fprintf('  Sum(2π·s): %.10f\n', sum(2*pi*singularities));
fprintf('  Sum(rhs): %.10f\n', sum(rhs_matlab));
fprintf('  Expected: 0 (closed manifold)\n');
fprintf('  Error: %.2e\n', abs(sum(rhs_matlab)));

if abs(sum(rhs_matlab)) < 1e-6
    fprintf('  ✓ RHS has zero sum (valid for pinned solve)\n');
else
    fprintf('  ✗ RHS sum non-zero! Error = %.2e\n', abs(sum(rhs_matlab)));
end

%% Step 3: Solve Poisson Equation
fprintf('\n=== STEP 3: POISSON SOLVE ===\n');

% Get Laplacian operator (stiffness matrix is the Laplacian)
ops = M.operators();
L = ops.stiffness.value;  % [nV×nV] Laplace-Beltrami operator (stiffness matrix)

fprintf('Laplacian matrix:\n');
fprintf('  Size: %d×%d\n', size(L, 1), size(L, 2));
fprintf('  Sparse: %d/%d (%.1f%%)\n', nnz(L), numel(L), 100*nnz(L)/numel(L));
fprintf('  Symmetric: %d\n', issymmetric(L));

% Pinned solve (pin first vertex to 0)
% Δβ = rhs with β(1) = 0
nV = size(M.Vertices, 1);
pinIdx = 1;

% Build reduced system
freeIdx = setdiff(1:nV, pinIdx);
L_reduced = L(freeIdx, freeIdx);
rhs_reduced = rhs_matlab(freeIdx);

% Solve
beta_reduced = L_reduced \ rhs_reduced;

% Expand back
beta_matlab = zeros(nV, 1);
beta_matlab(freeIdx) = beta_reduced;
beta_matlab(pinIdx) = 0;

fprintf('Scalar potential β:\n');
fprintf('  Min: %.6f\n', min(beta_matlab));
fprintf('  Max: %.6f\n', max(beta_matlab));
fprintf('  Mean: %.6f\n', mean(beta_matlab));
fprintf('  Pinned vertex %d: %.10f\n', pinIdx, beta_matlab(pinIdx));

% Verify solution
residual = L * beta_matlab - rhs_matlab;
fprintf('  Residual norm: %.2e\n', norm(residual));

%% Step 4: Compute Coexact Component (δβ = ⋆₁ d₀ β)
fprintf('\n=== STEP 4: COEXACT COMPONENT (δβ) ===\n');

% Get DEC operators
d0 = ops.d0.value;       % [nE×nV] exterior derivative (vertex -> edge)
hd1 = ops.hd1.value;     % [nE×nE] Hodge star ⋆₁

fprintf('DEC operators:\n');
fprintf('  d0 size: %d×%d (vertex->edge)\n', size(d0, 1), size(d0, 2));
fprintf('  hd1 size: %d×%d (edge Hodge star)\n', size(hd1, 1), size(hd1, 2));

% Compute δβ on edges
deltaBeta_edge = hd1 * (d0 * beta_matlab);

fprintf('Coexact δβ on edges:\n');
fprintf('  Min: %.6f\n', min(deltaBeta_edge));
fprintf('  Max: %.6f\n', max(deltaBeta_edge));
fprintf('  Mean: %.6f\n', mean(deltaBeta_edge));

%% Step 5: Lift to Halfedges
fprintf('\n=== STEP 5: LIFT TO HALFEDGES ===\n');

% Get edge->halfedge mapping
topo = M.topology();
edgeIndices = topo.edge.value;  % [nH×1] edge index for each halfedge

% Get orientation signs
% For each halfedge h, sign = +1 if h.tailVertex < h.headVertex, -1 otherwise
tailVertices = topo.tailVertex.value;
headVertices = topo.headVertex.value;
signs = ones(size(edgeIndices));
signs(tailVertices > headVertices) = -1;

% Lift edge values to halfedges with sign
deltaBeta_halfedge = signs .* deltaBeta_edge(edgeIndices);

fprintf('δβ on halfedges:\n');
fprintf('  Min: %.6f\n', min(deltaBeta_halfedge));
fprintf('  Max: %.6f\n', max(deltaBeta_halfedge));
fprintf('  Mean: %.6f\n', mean(deltaBeta_halfedge));

% Verify twin symmetry
twins = topo.twin.value;
twinErrors = [];
for h = 1:length(twins)
    if twins(h) > 0  % Not a boundary
        if abs(deltaBeta_halfedge(h) + deltaBeta_halfedge(twins(h))) > 1e-10
            twinErrors(end+1) = h;
        end
    end
end

if isempty(twinErrors)
    fprintf('  ✓ Twin halfedges have opposite signs (checked all)\n');
else
    fprintf('  ✗ Twin symmetry violated for %d halfedges!\n', length(twinErrors));
end

%% Step 6: Add Harmonic Component (γ)
fprintf('\n=== STEP 6: HARMONIC COMPONENT (γ) ===\n');

% For genus 0, γ = 0
% Genus g = (2 - χ) / 2 for closed orientable surfaces
genus = (2 - eulerChar) / 2;
fprintf('Genus: %d\n', genus);

if genus == 0
    gamma_halfedge = zeros(size(deltaBeta_halfedge));
    fprintf('  γ = 0 (genus 0 surface)\n');
else
    fprintf('  ⚠ Genus > 0: harmonic component not implemented!\n');
    gamma_halfedge = zeros(size(deltaBeta_halfedge));
end

%% Step 7: Final Connection φ = δβ + γ
fprintf('\n=== STEP 7: FINAL CONNECTION (φ = δβ + γ) ===\n');

phi_matlab_halfedge = deltaBeta_halfedge + gamma_halfedge;

fprintf('Connection φ on halfedges:\n');
fprintf('  Min: %.6f\n', min(phi_matlab_halfedge));
fprintf('  Max: %.6f\n', max(phi_matlab_halfedge));
fprintf('  Mean: %.6f\n', mean(phi_matlab_halfedge));

% Convert to edge representation (use first halfedge of each edge)
phi_matlab_edge = zeros(size(M.Edges, 1), 1);
for e = 1:size(M.Edges, 1)
    he1 = 2*e - 1;  % First halfedge
    phi_matlab_edge(e) = phi_matlab_halfedge(he1);
end

%% Step 8: Compare with JavaScript Reference
fprintf('\n=== STEP 8: COMPARISON WITH JAVASCRIPT ===\n');

% Extract reference phi values
refPhi = [refData.phi]';

fprintf('Comparing edge φ values:\n');
fprintf('  JavaScript range: [%.6f, %.6f]\n', min(refPhi), max(refPhi));
fprintf('  MATLAB range: [%.6f, %.6f]\n', min(phi_matlab_edge), max(phi_matlab_edge));

% Map JavaScript edges to MATLAB edges
% JavaScript edgeIndex gives vertex pairs, need to match to MATLAB edges
fprintf('\nDetailed edge comparison (first 20 edges):\n');
fprintf('  %5s | %10s %10s | %10s %10s | %10s | %s\n', ...
    'Edge', 'JS_v1', 'JS_v2', 'ML_v1', 'ML_v2', 'JS_φ', 'ML_φ', 'Diff');
fprintf('  %s\n', repmat('-', 1, 90));

for i = 1:min(20, length(refData.edgeIndex))
    refEdge = refData.edgeIndex(i);
    jsV1 = refEdge.v1 + 1;  % Convert to 1-based
    jsV2 = refEdge.v2 + 1;
    jsPhi = refData.phi(i+1);  % Arrays in struct are 0-indexed
    
    % Find matching MATLAB edge
    matlabEdgeIdx = find((M.Edges(:,1) == jsV1 & M.Edges(:,2) == jsV2) | ...
                         (M.Edges(:,1) == jsV2 & M.Edges(:,2) == jsV1));
    
    if ~isempty(matlabEdgeIdx)
        matlabPhi = phi_matlab_edge(matlabEdgeIdx(1));
        diff = abs(matlabPhi - jsPhi);
        mlV1 = M.Edges(matlabEdgeIdx(1), 1);
        mlV2 = M.Edges(matlabEdgeIdx(1), 2);
        
        % Check if sign flip needed
        signFlip = '';
        if abs(matlabPhi + jsPhi) < abs(matlabPhi - jsPhi)
            signFlip = '(sign?)';
        end
        
        fprintf('  %5d | %10d %10d | %10d %10d | %10.6f %10.6f | %10.6f %s\n', ...
            i, jsV1, jsV2, mlV1, mlV2, jsPhi, matlabPhi, diff, signFlip);
    else
        fprintf('  %5d | %10d %10d | NOT FOUND\n', i, jsV1, jsV2);
    end
end

%% Step 9: Check Edge Ordering
fprintf('\n=== STEP 9: EDGE ORDERING ANALYSIS ===\n');

% Check if edge ordering matches
edgeOrderMatches = 0;
edgeOrderDiffers = 0;
for i = 1:min(100, length(refData.edgeIndex))
    refEdge = refData.edgeIndex(i);
    jsV1 = refEdge.v1 + 1;
    jsV2 = refEdge.v2 + 1;
    
    % Check if MATLAB edge i has same vertices
    if size(M.Edges, 1) >= i
        mlV1 = M.Edges(i, 1);
        mlV2 = M.Edges(i, 2);
        
        if (mlV1 == jsV1 && mlV2 == jsV2) || (mlV1 == jsV2 && mlV2 == jsV1)
            edgeOrderMatches = edgeOrderMatches + 1;
        else
            edgeOrderDiffers = edgeOrderDiffers + 1;
        end
    end
end

fprintf('Edge ordering comparison (first 100 edges):\n');
fprintf('  Matching order: %d/100\n', edgeOrderMatches);
fprintf('  Different order: %d/100\n', edgeOrderDiffers);

if edgeOrderMatches > 90
    fprintf('  → Edge ordering is CONSISTENT\n');
else
    fprintf('  → Edge ordering is DIFFERENT (this may explain discrepancies)\n');
end

%% Step 10: Holonomy Check Around Singularities
fprintf('\n=== STEP 10: HOLONOMY VERIFICATION ===\n');

for i = 1:length(singIdx)
    v = singIdx(i);
    weight = singularities(v);
    
    % Get neighboring halfedges around vertex
    % Use one-ring to compute holonomy
    A = M.adjacency();
    neighbors = find(A(:, v));
    
    % Approximate holonomy by summing connection around vertex
    % This is approximate - proper holonomy requires face loop
    holonomy_approx = 0;
    for j = 1:length(neighbors)
        vn = neighbors(j);
        % Find edge connecting v to vn
        eIdx = find((M.Edges(:,1) == v & M.Edges(:,2) == vn) | ...
                    (M.Edges(:,1) == vn & M.Edges(:,2) == v));
        if ~isempty(eIdx)
            % Find halfedge v->vn
            he = find(tailVertices == v & headVertices == vn);
            if ~isempty(he)
                holonomy_approx = holonomy_approx + phi_matlab_halfedge(he(1));
            end
        end
    end
    
    expected_holonomy = 2*pi*weight;
    fprintf('Singularity at vertex %d (weight=%.2f):\n', v, weight);
    fprintf('  Approximate holonomy: %.6f rad (%.3f × 2π)\n', ...
        holonomy_approx, holonomy_approx/(2*pi));
    fprintf('  Expected: %.6f rad (%.3f × 2π)\n', ...
        expected_holonomy, weight);
    fprintf('  Error: %.6f rad\n', abs(holonomy_approx - expected_holonomy));
end

%% Summary
fprintf('\n====== DIAGNOSTIC SUMMARY ======\n');
fprintf('1. Gauss-Bonnet: ');
if GB_error < 1e-6
    fprintf('✓ PASS\n');
else
    fprintf('✗ FAIL (error=%.2e)\n', GB_error);
end

fprintf('2. RHS zero sum: ');
if abs(sum(rhs_matlab)) < 1e-6
    fprintf('✓ PASS\n');
else
    fprintf('✗ FAIL (error=%.2e)\n', abs(sum(rhs_matlab)));
end

fprintf('3. Poisson residual: ');
if norm(residual) < 1e-6
    fprintf('✓ PASS\n');
else
    fprintf('✗ FAIL (norm=%.2e)\n', norm(residual));
end

fprintf('4. Twin symmetry: ');
if isempty(twinErrors)
    fprintf('✓ PASS\n');
else
    fprintf('✗ FAIL (%d violations)\n', length(twinErrors));
end

fprintf('5. Edge ordering: ');
if edgeOrderMatches > 90
    fprintf('✓ CONSISTENT\n');
else
    fprintf('⚠ DIFFERENT (may need remapping)\n');
end

fprintf('\n');
fprintf('Connection value comparison:\n');
fprintf('  JavaScript φ range: [%.6f, %.6f]\n', min(refPhi), max(refPhi));
fprintf('  MATLAB φ range:     [%.6f, %.6f]\n', min(phi_matlab_edge), max(phi_matlab_edge));

% Find if there's a systematic difference
ratio = phi_matlab_edge ./ refPhi;
fprintf('  Mean ratio (ML/JS): %.6f\n', mean(ratio(~isnan(ratio) & ~isinf(ratio))));
fprintf('  Std ratio:          %.6f\n', std(ratio(~isnan(ratio) & ~isinf(ratio))));
