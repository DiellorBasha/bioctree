%% Test Direction Field with Different Singularities
%
% Interactive script to test trivial connections and direction field
% visualization with user-specified singularities.

clear; close all;

%% Load mesh
fprintf('=== Direction Field Singularity Test ===\n\n');

fs4path='C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage5\surf\lh.pial'
[vertices, faces] = freesurfer_read_surf(fs4path);
M=bct.Manifold(vertices,faces);
Mf=M.flip;clear M; M=Mf;

M = bct.Manifold(vertices, faces);
Mf = M.flip;
clear M;
M = Mf;

fprintf('Mesh loaded: %d vertices, %d faces\n', size(M.Vertices,1), size(M.Faces,1));

%% Precompute geometry and topology
fprintf('Computing geometry and topology...\n');
topo = M.topology;
geom = M.geometry('includeDual', true);
ops = M.operators;
solvers = M.solvers;

% Euler characteristic
nV = size(M.Vertices, 1);
nE = size(M.Edges, 1);
nF = size(M.Faces, 1);
chi = nV - nE + nF;
genus = (2 - chi) / 2;

fprintf('Topology: χ=%d, genus=%.2f\n\n', chi, genus);

%% Test singularities
% antIdx = 6653;
% postIdx = 978;

% Alternative: Pick two vertices far apart
fprintf('Select singularity configuration:\n');
fprintf('  1. Default (vertices 6653, 978)\n');
fprintf('  2. Random vertices (far apart)\n');
fprintf('  3. Custom input\n');
choice = input('Choice [1]: ');
if isempty(choice), choice = 1; end

switch choice
    case 1
        antIdx = 6653;
        postIdx = 978;
        weights = [1, 1];
    case 2
        % Pick two vertices far apart
        dist = pdist2(M.Vertices, M.Vertices);
        [~, idx1] = max(sum(dist, 2));
        [~, idx2] = max(dist(idx1, :));
        antIdx = idx1;
        postIdx = idx2;
        weights = [1, 1];
        fprintf('Selected vertices: %d, %d\n', antIdx, postIdx);
    case 3
        antIdx = input('Enter first vertex index: ');
        postIdx = input('Enter second vertex index: ');
        weights = [1, 1];
end

fprintf('\nSingularities:\n');
fprintf('  Vertex %d (weight %d)\n', antIdx, weights(1));
fprintf('  Vertex %d (weight %d)\n', postIdx, weights(2));
fprintf('  Sum of weights: %d (should equal χ=%d)\n\n', sum(weights), chi);

% Save singularity indices for later use
singularityIndices = [antIdx, postIdx];
singularityWeights = weights;

if sum(weights) ~= chi
    warning('Gauss-Bonnet violated! Sum of weights ≠ χ');
end

%% Compute trivial connection
fprintf('Computing trivial connection...\n');
tic;
conn = M.connection('trivial', ...
    'singularities', [antIdx, postIdx], ...
    'weights', weights);
t_conn = toc;
fprintf('  Done in %.3f sec\n', t_conn);

% Check connection statistics
fprintf('  Connection range: [%.3f, %.3f] rad\n', ...
    min(conn.trivialConnection.value), max(conn.trivialConnection.value));
fprintf('  Non-zero count: %d / %d\n\n', ...
    sum(abs(conn.trivialConnection.value) > 1e-10), ...
    numel(conn.trivialConnection.value));

%% Compute combined transport
fprintf('Computing transport...\n');
tic;
trans = bct.manifold.connection.transport(M, conn, 'sign', 'minus');
t_trans = toc;
fprintf('  Done in %.3f sec\n', t_trans);
fprintf('  Formula: %s\n\n', trans.attributes.formula);

combinedTransport = trans.combinedTransport.value;

%% Propagate direction field
fprintf('Propagating direction field...\n');
tic;
result = bct.manifold.query.dual(M, combinedTransport, ...
    'seedFace', 1, ...
    'seedValue', 0, ...
    'wrap', false);
t_bfs = toc;

alpha_face = result.alpha_face;
fprintf('  Done in %.3f sec\n', t_bfs);
fprintf('  Angle range: [%.3f, %.3f] rad\n\n', ...
    min(alpha_face), max(alpha_face));

%% Verify singularities (closed loop integration)
fprintf('Verifying singularities (closed loop around each vertex):\n');

for singIdx = singularityIndices
    % Get faces around vertex
    h_start = find(topo.tailVertex.value == singIdx, 1);
    if isempty(h_start)
        fprintf('  Vertex %d: No halfedge found!\n', singIdx);
        continue;
    end
    
    vFaces = [];
    h = h_start;
    for iter = 1:100
        f = topo.face.value(h);
        if f > 0
            vFaces(end+1) = f;
        end
        h = topo.next.value(topo.twin.value(h));
        if h == h_start
            break;
        end
    end
    
    % Manual cyclic walk
    totalRot = 0;
    FH = topo.faceHalfedges.value;
    for k = 1:length(vFaces)
        f1 = vFaces(k);
        f2 = vFaces(mod(k, length(vFaces)) + 1);
        hs = FH(f1, :);
        for j = 1:3
            h = hs(j);
            if topo.face.value(topo.twin.value(h)) == f2
                totalRot = totalRot + combinedTransport(h);
                break;
            end
        end
    end
    
    fprintf('  Vertex %d: %.3f rad (%.2f × 2π)\n', ...
        singIdx, totalRot, totalRot/(2*pi));
end
fprintf('\n');

%% Convert angles to 3D direction vectors
fprintf('Converting to 3D direction vectors...\n');
directionField = cos(alpha_face) .* geom.face.tangent1.value + ...
                 sin(alpha_face) .* geom.face.tangent2.value;

% Verify unit length
norms = vecnorm(directionField, 2, 2);
fprintf('  Vector norms: min=%.6f, max=%.6f, mean=%.6f\n', ...
    min(norms), max(norms), mean(norms));

% Compute field "fingerprint" to verify it's unique
fieldHash = sum(abs(directionField(:))) + 1000*mean(alpha_face);
fprintf('  Field fingerprint: %.6f (should change with different singularities)\n\n', fieldHash);

%% Visualize
fprintf('Creating visualization...\n');

viewer = bct.ui.show(M);
%%
% Direction field (Stride=1 to see all vectors and winding pattern)
viewer.addVector(directionField, ...
    'Support', 'face', ...
    'Positions', geom.face.centroids.value, ...
    'Normals', geom.face.normals.value, ...
    'Style', 'arrow', ...
    'Stride', 1, ...
    'LengthScale', 2.0, ...
    'Color', 0x0000ff, ...
    'LineWidth', 1.5);
%%
% Singularities
viewer.addPoint('Indices', singularityIndices, ...
    'Color', 0xff0000, ...
    'Radius', 5.0);

fprintf('\n=== Visualization Complete ===\n');
fprintf('Red spheres: singularities at vertices [%d, %d]\n', ...
    singularityIndices(1), singularityIndices(2));
fprintf('Blue arrows: direction field\n');
fprintf('Stride: 1 (showing ALL vectors)\n\n');

% Verify what was actually marked
fprintf('Singularity positions:\n');
fprintf('  Vertex %d at [%.2f, %.2f, %.2f]\n', ...
    singularityIndices(1), M.Vertices(singularityIndices(1), 1), ...
    M.Vertices(singularityIndices(1), 2), M.Vertices(singularityIndices(1), 3));
fprintf('  Vertex %d at [%.2f, %.2f, %.2f]\n', ...
    singularityIndices(2), M.Vertices(singularityIndices(2), 1), ...
    M.Vertices(singularityIndices(2), 2), M.Vertices(singularityIndices(2), 3));
fprintf('\n');

fprintf('To reduce density, change stride:\n');
fprintf('  viewer.setVector(directionField, ''Support'', ''face'', ...\n');
fprintf('    ''Positions'', geom.face.centroids.value, ...\n');
fprintf('    ''Normals'', geom.face.normals.value, ...\n');
fprintf('    ''Style'', ''arrow'', ''Stride'', 10, ''LengthScale'', 2.0);\n\n');

%% Diagnostics: check specific faces around singularities
fprintf('=== Diagnostics ===\n');
fprintf('Checking faces around first singularity (vertex %d):\n', singularityIndices(1));

% Get cyclic faces
h_start = find(topo.tailVertex.value == singularityIndices(1), 1);
vFaces = [];
h = h_start;
for iter = 1:100
    f = topo.face.value(h);
    if f > 0
        vFaces(end+1) = f;
    end
    h = topo.next.value(topo.twin.value(h));
    if h == h_start
        break;
    end
end

fprintf('Faces in cyclic order:\n');
for k = 1:length(vFaces)
    f = vFaces(k);
    fprintf('  %d. Face %d: α=%.3f rad (%.1f°)\n', ...
        k, f, alpha_face(f), rad2deg(alpha_face(f)));
end
fprintf('\n');

% Check manual transport between consecutive faces
fprintf('Transport between consecutive faces:\n');
FH = topo.faceHalfedges.value;
for k = 1:length(vFaces)
    f1 = vFaces(k);
    f2 = vFaces(mod(k, length(vFaces)) + 1);
    hs = FH(f1, :);
    for j = 1:3
        h = hs(j);
        if topo.face.value(topo.twin.value(h)) == f2
            fprintf('  %d->%d: combined=%.3f, geo=%.3f, conn=%.3f\n', ...
                f1, f2, ...
                combinedTransport(h), ...
                trans.geometricTransport.value(h), ...
                trans.connectionTransport.value(h));
            break;
        end
    end
end

%% Check for abrupt direction changes
fprintf('\n=== Checking for discontinuities ===\n');

% Find neighboring faces
faceNeighbors = topo.faceNeighbors.value;

% Check vector continuity
discontinuities = [];
for f1 = 1:nF
    neighbors = faceNeighbors(f1, :);
    for k = 1:length(neighbors)
        f2 = neighbors(k);
        if f2 > 0 && f2 ~= f1
            % Dot product of direction vectors
            dotProd = dot(directionField(f1, :), directionField(f2, :));
            
            % Vectors should be similar (dot product close to ±1)
            % Negative means 180° flip (acceptable for line field)
            if abs(dotProd) < 0.5  % Large angle difference
                discontinuities(end+1, :) = [f1, f2, dotProd];
            end
        end
    end
end

if ~isempty(discontinuities)
    fprintf('Found %d face pairs with large angle differences:\n', size(discontinuities, 1));
    fprintf('(Showing first 10)\n');
    for k = 1:min(10, size(discontinuities, 1))
        fprintf('  Face %d <-> Face %d: dot product = %.3f (angle=%.1f°)\n', ...
            discontinuities(k, 1), discontinuities(k, 2), ...
            discontinuities(k, 3), rad2deg(acos(abs(discontinuities(k, 3)))));
    end
else
    fprintf('No major discontinuities found!\n');
end
fprintf('\n');
%%

% Pick two neighboring faces from the cycle
f1 = 17388;
f2 = 7929;

v1 = directionField(f1, :);
v2 = directionField(f2, :);

fprintf('Face %d: α=%.3f, vector=[%.3f, %.3f, %.3f]\n', ...
    f1, alpha_face(f1), v1(1), v1(2), v1(3));
fprintf('Face %d: α=%.3f, vector=[%.3f, %.3f, %.3f]\n', ...
    f2, alpha_face(f2), v2(1), v2(2), v2(3));
fprintf('Dot product: %.3f (angle=%.1f°)\n', ...
    dot(v1, v2), rad2deg(acos(abs(dot(v1, v2)))));

%%

% Find the halfedge connecting 17388 -> 7929
FH = topo.faceHalfedges.value;
hs = FH(17388, :);
for j = 1:3
    h = hs(j);
    if topo.face.value(topo.twin.value(h)) == 7929
        fprintf('Direct edge 17388->7929 via halfedge %d:\n', h);
        fprintf('  α[17388] = %.3f\n', alpha_face(17388));
        fprintf('  Combined transport = %.3f\n', combinedTransport(h));
        fprintf('  Expected α[7929] = %.3f + %.3f = %.3f\n', ...
            alpha_face(17388), combinedTransport(h), ...
            alpha_face(17388) + combinedTransport(h));
        fprintf('  Actual α[7929] = %.3f\n', alpha_face(7929));
        fprintf('  ERROR = %.3f rad (%.1f°)\n', ...
            alpha_face(7929) - (alpha_face(17388) + combinedTransport(h)), ...
            rad2deg(alpha_face(7929) - (alpha_face(17388) + combinedTransport(h))));
        
        % Now check if the VECTORS would be continuous
        % Manually transport the vector from 17388 to 7929
        fprintf('\nManual vector transport check:\n');
        
        % Current vector in face 17388
        v1 = directionField(17388, :);
        fprintf('  Vector in 17388: [%.3f, %.3f, %.3f]\n', v1(1), v1(2), v1(3));
        
        % What angle SHOULD 7929 have for continuity?
        alpha_correct = alpha_face(17388) + combinedTransport(h);
        v_correct = cos(alpha_correct) * geom.face.tangent1.value(7929,:) + ...
                    sin(alpha_correct) * geom.face.tangent2.value(7929,:);
        fprintf('  Correct vector in 7929: [%.3f, %.3f, %.3f]\n', ...
            v_correct(1), v_correct(2), v_correct(3));
        
        % Actual vector in 7929
        v2 = directionField(7929, :);
        fprintf('  Actual vector in 7929: [%.3f, %.3f, %.3f]\n', v2(1), v2(2), v2(3));
        
        fprintf('  Dot(v1, v_correct) = %.3f\n', dot(v1, v_correct));
        fprintf('  Dot(v1, v_actual) = %.3f\n', dot(v1, v2));
    end
end

%%
% For the edge 17388->7929, which halfedge are we using?
h_17388_to_7929 = 58348;

fprintf('\nHalfedge %d analysis:\n', h_17388_to_7929);
fprintf('  Tail vertex: %d\n', topo.tailVertex.value(h_17388_to_7929));
fprintf('  Head vertex: %d\n', topo.headVertex.value(h_17388_to_7929));
fprintf('  Face (this h): %d\n', topo.face.value(h_17388_to_7929));
fprintf('  Face (twin h): %d\n', topo.face.value(topo.twin.value(h_17388_to_7929)));
% Check tangent frames at both faces
t1_17388 = geom.face.tangent1.value(17388, :);
t2_17388 = geom.face.tangent2.value(17388, :);
n_17388 = geom.face.normals.value(17388, :);

t1_7929 = geom.face.tangent1.value(7929, :);
t2_7929 = geom.face.tangent2.value(7929, :);
n_7929 = geom.face.normals.value(7929, :);

fprintf('\nTangent frames:\n');
fprintf('Face 17388:\n');
fprintf('  t1 = [%.3f, %.3f, %.3f]\n', t1_17388(1), t1_17388(2), t1_17388(3));
fprintf('  t2 = [%.3f, %.3f, %.3f]\n', t2_17388(1), t2_17388(2), t2_17388(3));
fprintf('  n  = [%.3f, %.3f, %.3f]\n', n_17388(1), n_17388(2), n_17388(3));

fprintf('Face 7929:\n');
fprintf('  t1 = [%.3f, %.3f, %.3f]\n', t1_7929(1), t1_7929(2), t1_7929(3));
fprintf('  t2 = [%.3f, %.3f, %.3f]\n', t2_7929(1), t2_7929(2), t2_7929(3));
fprintf('  n  = [%.3f, %.3f, %.3f]\n', n_7929(1), n_7929(2), n_7929(3));

% The transport should account for frame rotation
% Manually compute what the transport SHOULD be
h = 58348;
edge_vec = M.Vertices(topo.headVertex.value(h), :) - M.Vertices(topo.tailVertex.value(h), :);
edge_vec = edge_vec / norm(edge_vec);

theta_17388 = atan2(dot(edge_vec, t2_17388), dot(edge_vec, t1_17388));
theta_7929 = atan2(dot(edge_vec, t2_7929), dot(edge_vec, t1_7929));

dTheta_manual = -theta_17388 + theta_7929;
fprintf('\nManual transport computation:\n');
fprintf('  theta in face 17388: %.3f rad\n', theta_17388);
fprintf('  theta in face 7929: %.3f rad\n', theta_7929);
fprintf('  dTheta (manual): %.3f rad\n', dTheta_manual);
fprintf('  dTheta (computed): %.3f rad\n', trans.geometricTransport.value(h));
fprintf('  Match: %s\n', isequal(round(dTheta_manual, 6), round(trans.geometricTransport.value(h), 6)));

%%

% Trace back the BFS path to face 7929
fprintf('\nBFS path to face 7929:\n');
f = 7929;
path = [];
for iter = 1:100
    path(end+1) = f;
    parent = result.parentFace(f);
    if parent == 0 || parent == f
        fprintf('  ROOT: Face %d\n', f);
        break;
    end
    h = result.parentHalfedge(f);
    fprintf('  Face %d <- Face %d (h=%d, transport=%.3f, α[%d]=%.3f)\n', ...
        f, parent, h, combinedTransport(h), parent, alpha_face(parent));
    f = parent;
end

% Verify the accumulated transport along the BFS path
fprintf('\nTotal accumulated transport from root to 7929:\n');
fprintf('  Final α[7929] = %.3f\n', alpha_face(7929));
fprintf('  Root α[1] = %.3f\n', alpha_face(1));
fprintf('  Total change = %.3f rad (%.2f × 2π)\n', ...
    alpha_face(7929) - alpha_face(1), (alpha_face(7929) - alpha_face(1))/(2*pi));

%%

% For direction fields, check alignment up to ±180°
v1 = directionField(17388, :);
v2 = directionField(7929, :);
v_correct = cos(1.536) * geom.face.tangent1.value(7929,:) + ...
            sin(1.536) * geom.face.tangent2.value(7929,:);

fprintf('Alignment check (line field allows ±180° flip):\n');
fprintf('  |dot(v1, v2)|        = %.3f\n', abs(dot(v1, v2)));
fprintf('  |dot(v1, v_correct)| = %.3f\n', abs(dot(v1, v_correct)));
fprintf('  Should be close to 1.0 for continuity\n');

% Also check if using angle difference of exactly 2π fixes it
alpha_2pi_corrected = alpha_face(7929) + 2*pi;
v_2pi = cos(alpha_2pi_corrected) * geom.face.tangent1.value(7929,:) + ...
        sin(alpha_2pi_corrected) * geom.face.tangent2.value(7929,:);
fprintf('  |dot(v1, v_2pi)|     = %.3f (after adding 2π to angle)\n', abs(dot(v1, v_2pi)));

%%

% Compute field using ONLY geometric transport (no connection)
result_geo_only = bct.manifold.query.dual(M, trans.geometricTransport.value, ...
    'seedFace', 1, 'seedValue', 0, 'wrap', false);

% Test on a patch
testPatch = [1000:1005];

fprintf('\nTest geometric transport only (no connection):\n');
for k = 1:length(testPatch)-1
    f1 = testPatch(k);
    f2 = testPatch(k+1);
    
    % Find edge between them
    FH = topo.faceHalfedges.value;
    hs = FH(f1, :);
    found = false;
    for j = 1:3
        h = hs(j);
        if topo.face.value(topo.twin.value(h)) == f2
            % Use ONLY geometric transport
            alpha_geo_f1 = result_geo_only.alpha_face(f1);
            alpha_geo_f2 = result_geo_only.alpha_face(f2);
            geo_trans = trans.geometricTransport.value(h);
            
            v1_geo = cos(alpha_geo_f1) * geom.face.tangent1.value(f1,:) + ...
                     sin(alpha_geo_f1) * geom.face.tangent2.value(f1,:);
            v2_geo = cos(alpha_geo_f2) * geom.face.tangent1.value(f2,:) + ...
                     sin(alpha_geo_f2) * geom.face.tangent2.value(f2,:);
            
            fprintf('  %d->%d: geo=%.3f, Δα=%.3f, |dot|=%.3f\n', ...
                f1, f2, geo_trans, alpha_geo_f2-alpha_geo_f1, abs(dot(v1_geo, v2_geo)));
            found = true;
            break;
        end
    end
    if ~found
        fprintf('  %d and %d are not neighbors!\n', f1, f2);
    end
end

% Now try direct neighbors that definitely share an edge
fprintf('\nDirect neighbor test:\n');
f_test = 1000;
FH = topo.faceHalfedges.value;
neighbors = topo.faceNeighbors.value(f_test, :);
for nb = neighbors'
    if nb > 0
        % Find connecting halfedge
        hs = FH(f_test, :);
        for j = 1:3
            h = hs(j);
            if topo.face.value(topo.twin.value(h)) == nb
                alpha_1 = result_geo_only.alpha_face(f_test);
                alpha_2 = result_geo_only.alpha_face(nb);
                geo_t = trans.geometricTransport.value(h);
                
                v1 = cos(alpha_1) * geom.face.tangent1.value(f_test,:) + ...
                     sin(alpha_1) * geom.face.tangent2.value(f_test,:);
                v2 = cos(alpha_2) * geom.face.tangent1.value(nb,:) + ...
                     sin(alpha_2) * geom.face.tangent2.value(nb,:);
                
                fprintf('  Face %d -> %d: geo=%.3f, |dot|=%.3f\n', ...
                    f_test, nb, geo_t, abs(dot(v1, v2)));
                break;
            end
        end
    end
end

%%

% Simpler test - just get first valid neighbor
f_test = 1000;
FH = topo.faceHalfedges.value;
hs = FH(f_test, :);

fprintf('\nConnection indexing for face %d:\n', f_test);
for j = 1:3
    h = hs(j);
    ht = topo.twin.value(h);
    nb = topo.face.value(ht);
    
    if nb > 0
        fprintf('\nNeighbor via halfedge %d:\n', h);
        fprintf('  This face: %d, Neighbor: %d\n', f_test, nb);
        fprintf('  Geometric transport (h=%d): %.3f\n', h, trans.geometricTransport.value(h));
        fprintf('  Geometric transport (twin=%d): %.3f\n', ht, trans.geometricTransport.value(ht));
        fprintf('  Connection transport (h=%d): %.3f\n', h, trans.connectionTransport.value(h));
        fprintf('  Connection transport (twin=%d): %.3f\n', ht, trans.connectionTransport.value(ht));
        fprintf('  Combined (h=%d): %.3f\n', h, combinedTransport(h));
        fprintf('  Combined (twin=%d): %.3f\n', ht, combinedTransport(ht));
        
        % Check signs
        fprintf('\n  Sign check:\n');
        if abs(trans.geometricTransport.value(h) + trans.geometricTransport.value(ht)) < 0.001
            fprintf('    Geometric: ✓ opposite signs\n');
        else
            fprintf('    Geometric: ✗ NOT opposite (sum=%.3f)\n', ...
                trans.geometricTransport.value(h) + trans.geometricTransport.value(ht));
        end
        
        if abs(trans.connectionTransport.value(h) + trans.connectionTransport.value(ht)) < 0.001
            fprintf('    Connection: ✓ opposite signs\n');
        else
            fprintf('    Connection: ✗ NOT opposite (sum=%.3f)\n', ...
                trans.connectionTransport.value(h) + trans.connectionTransport.value(ht));
        end
    end
end

%%

% Test combined transport on same patch
fprintf('\nTest COMBINED transport (geo - conn) on same faces:\n');
for j = 1:3
    h = hs(j);
    ht = topo.twin.value(h);
    nb = topo.face.value(ht);
    
    if nb > 0
        % Use combined transport (what we actually use for direction field)
        alpha_1 = alpha_face(f_test);
        alpha_2 = alpha_face(nb);
        comb_t = combinedTransport(h);
        
        v1 = cos(alpha_1) * geom.face.tangent1.value(f_test,:) + ...
             sin(alpha_1) * geom.face.tangent2.value(f_test,:);
        v2 = cos(alpha_2) * geom.face.tangent1.value(nb,:) + ...
             sin(alpha_2) * geom.face.tangent2.value(nb,:);
        
        fprintf('  Face %d -> %d:\n', f_test, nb);
        fprintf('    Combined transport: %.3f\n', comb_t);
        fprintf('    Angle difference: %.3f (should match!)\n', alpha_2 - alpha_1);
        fprintf('    Error: %.6f\n', abs((alpha_2 - alpha_1) - comb_t));
        fprintf('    Vector alignment |dot|: %.3f\n', abs(dot(v1, v2)));
    end
end

%%

% Try seeding near first singularity
facesNearSing = find(any(M.Faces == singularityIndices(1), 2));
seedNearSing = facesNearSing(1);

fprintf('\nRetrying with seed near singularity (face %d):\n', seedNearSing);
result_new = bct.manifold.query.dual(M, combinedTransport, ...
    'seedFace', seedNearSing, ...
    'seedValue', 0, ...
    'wrap', false);

alpha_new = result_new.alpha_face;
dirField_new = cos(alpha_new) .* geom.face.tangent1.value + ...
               sin(alpha_new) .* geom.face.tangent2.value;

% Test same faces
v1_new = dirField_new(1000, :);
v2_new = dirField_new(11003, :);
fprintf('  New alignment 1000->11003: |dot| = %.3f\n', abs(dot(v1_new, v2_new)));