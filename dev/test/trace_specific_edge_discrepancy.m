%% Trace Specific Edge Discrepancy
% Deep dive into one high-discrepancy edge to find where computations diverge

clear; close all;

% Add paths
addpath(fullfile(pwd, '..', '..', 'external', 'bioelectromagnetism'));
addpath(genpath(fullfile(pwd, '..', '..', 'external', 'DECLab')));
addpath(genpath(fullfile(pwd, '..', '..', 'external', 'gptoolbox')));
addpath(fullfile(pwd, '..', '..', 'toolbox'));

%% Load Reference Data
jsonFile = 'C:\CodingProjects\potpourri3d-scripts\direction_field_data.json';
refData = jsondecode(fileread(jsonFile));

fprintf('=== ANALYZING SPECIFIC EDGE DISCREPANCY ===\n');

%% Load Mesh
fs5path = 'C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage5\surf\lh.pial';
[vertices, faces] = freesurfer_read_surf(fs5path);
faces = fliplr(faces); % Match current implementation
M = bct.Manifold(vertices, faces);

%% Target Edge Analysis
% Pick edge 171 (JS) which has largest discrepancy
% JS: v1=2731, v2=29, φ=-2.402786
% ML: Should find this edge and see what φ it computed

jsEdgeIdx = 171;
refEdge = refData.edgeIndex(jsEdgeIdx);
v1_js = refEdge.v1 + 1;  % 0-indexed -> 1-indexed
v2_js = refEdge.v2 + 1;
phi_js = refData.phi(jsEdgeIdx);

fprintf('\nJavaScript Edge %d:\n', jsEdgeIdx);
fprintf('  Vertices: (%d, %d)\n', v1_js, v2_js);
fprintf('  φ = %.6f\n', phi_js);

%% Find this edge in MATLAB
topo = M.topology();
edges = topo.edgeList.value;
edgeIdx_ml = find((edges(:,1) == v1_js & edges(:,2) == v2_js) | ...
                  (edges(:,1) == v2_js & edges(:,2) == v1_js));

if isempty(edgeIdx_ml)
    error('Edge not found in MATLAB mesh!');
end

% Check orientation
if edges(edgeIdx_ml,1) == v1_js && edges(edgeIdx_ml,2) == v2_js
    isFlipped = false;
    fprintf('\nMATLAB Edge %d (same orientation):\n', edgeIdx_ml);
else
    isFlipped = true;
    fprintf('\nMATLAB Edge %d (FLIPPED orientation):\n', edgeIdx_ml);
end
fprintf('  Vertices: (%d, %d)\n', edges(edgeIdx_ml,1), edges(edgeIdx_ml,2));

%% Compute MATLAB Connection
fprintf('\n=== COMPUTING MATLAB CONNECTION ===\n');

% Singularities (from JS data)
singularities = struct();
singularities.vertices = zeros(length(refData.singularities), 1);
singularities.weights = zeros(length(refData.singularities), 1);
for i = 1:length(refData.singularities)
    s = refData.singularities(i);
    singularities.vertices(i) = s.index + 1;  % 0-indexed -> 1-indexed
    singularities.weights(i) = s.weight;
end

% Get operators
ops = M.operators();
geom = M.geometry();

% Step 1: Gaussian curvature
K = geom.vertex.angleDefect.value;

% Step 2: Build RHS
rhs = -K;
for i = 1:length(singularities.vertices)
    v = singularities.vertices(i);
    rhs(v) = rhs(v) + 2*pi*singularities.weights(i);
end

% Step 3: Solve Poisson equation
L = ops.stiffness.value;  % Laplace-Beltrami operator
M_mass = ops.mass.value;
beta = L \ rhs;

% Step 4: Compute coexact part δβ = ⋆₁d₀β
d0 = ops.d0.value;  % Exterior derivative (vertex -> edge)
hd1 = ops.hd1.value;  % Hodge star *₁
delta_beta_edges = hd1 * (d0 * beta);

fprintf('  δβ computed on %d edges\n', length(delta_beta_edges));
fprintf('  Edge %d: δβ = %.6f\n', edgeIdx_ml, delta_beta_edges(edgeIdx_ml));

%% Compute on Halfedges
% Now lift to halfedges with orientation
halfedges = [topo.tailVertex.value, topo.headVertex.value];
nHalfedges = size(halfedges, 1);

% Build halfedge -> edge mapping
halfedge_to_edge = zeros(nHalfedges, 1);
halfedge_orientation = zeros(nHalfedges, 1); % +1 if he points same as edge, -1 if opposite

for he_idx = 1:nHalfedges
    he = halfedges(he_idx, :);
    he_v1 = he(1);
    he_v2 = he(2);
    
    % Find corresponding edge
    e_idx = find((edges(:,1) == he_v1 & edges(:,2) == he_v2) | ...
                 (edges(:,1) == he_v2 & edges(:,2) == he_v1), 1);
    
    if isempty(e_idx)
        error('Halfedge %d (%d->%d) has no corresponding edge!', he_idx, he_v1, he_v2);
    end
    
    halfedge_to_edge(he_idx) = e_idx;
    
    % Check orientation
    if edges(e_idx,1) == he_v1 && edges(e_idx,2) == he_v2
        halfedge_orientation(he_idx) = +1;
    else
        halfedge_orientation(he_idx) = -1;
    end
end

% Lift δβ to halfedges
phi_halfedges = zeros(nHalfedges, 1);
for he_idx = 1:nHalfedges
    e_idx = halfedge_to_edge(he_idx);
    orient = halfedge_orientation(he_idx);
    phi_halfedges(he_idx) = orient * delta_beta_edges(e_idx);
end

% Find halfedges corresponding to our target edge
he_indices = find(halfedge_to_edge == edgeIdx_ml);
fprintf('\nHalfedges for edge %d:\n', edgeIdx_ml);
for he_idx = he_indices'
    he = halfedges(he_idx, :);
    orient = halfedge_orientation(he_idx);
    phi_he = phi_halfedges(he_idx);
    fprintf('  HE %d: (%d->%d), orient=%+d, φ=%.6f\n', ...
            he_idx, he(1), he(2), orient, phi_he);
end

%% Compare with JavaScript
phi_ml = delta_beta_edges(edgeIdx_ml);
if isFlipped
    phi_ml = -phi_ml;  % Flip sign if edge orientation is opposite
end

fprintf('\n=== COMPARISON ===\n');
fprintf('JavaScript φ: %.6f\n', phi_js);
fprintf('MATLAB φ:     %.6f\n', phi_ml);
fprintf('Difference:   %.6f\n', abs(phi_js - phi_ml));

%% Detailed breakdown
fprintf('\n=== DETAILED BREAKDOWN ===\n');

% Check what JavaScript might be computing differently
% Let's examine the vertices and their neighborhoods

v1_pos = vertices(v1_js, :);
v2_pos = vertices(v2_js, :);
edge_vec = v2_pos - v1_pos;
edge_len = norm(edge_vec);

fprintf('Edge (%d, %d):\n', v1_js, v2_js);
fprintf('  Length: %.6f\n', edge_len);
fprintf('  v1 position: (%.3f, %.3f, %.3f)\n', v1_pos);
fprintf('  v2 position: (%.3f, %.3f, %.3f)\n', v2_pos);

% Check Gaussian curvature at endpoints
fprintf('  K(v1=%d): %.6f\n', v1_js, K(v1_js));
fprintf('  K(v2=%d): %.6f\n', v2_js, K(v2_js));

% Check β values
fprintf('  β(v1=%d): %.6f\n', v1_js, beta(v1_js));
fprintf('  β(v2=%d): %.6f\n', v2_js, beta(v2_js));
fprintf('  Δβ = β(v2) - β(v1): %.6f\n', beta(v2_js) - beta(v1_js));

% Check if d₀β matches what we expect
d0_beta_manual = beta(v2_js) - beta(v1_js);
d0_beta_operator = d0(edgeIdx_ml, :) * beta;
fprintf('  d₀β (manual): %.6f\n', d0_beta_manual);
fprintf('  d₀β (operator): %.6f\n', d0_beta_operator);

% Check Hodge star application
fprintf('  ⋆₁(d₀β): %.6f\n', delta_beta_edges(edgeIdx_ml));

%% Export this edge's data for manual inspection
edgeData = struct();
edgeData.jsIndex = jsEdgeIdx;
edgeData.mlIndex = edgeIdx_ml;
edgeData.v1 = v1_js;
edgeData.v2 = v2_js;
edgeData.isFlipped = isFlipped;
edgeData.phi_js = phi_js;
edgeData.phi_ml = delta_beta_edges(edgeIdx_ml);
edgeData.phi_ml_oriented = phi_ml;
edgeData.K_v1 = K(v1_js);
edgeData.K_v2 = K(v2_js);
edgeData.beta_v1 = beta(v1_js);
edgeData.beta_v2 = beta(v2_js);
edgeData.d0_beta = d0_beta_operator;
edgeData.star_d0_beta = delta_beta_edges(edgeIdx_ml);

fprintf('\n=== SAVED edgeData TO WORKSPACE ===\n');
