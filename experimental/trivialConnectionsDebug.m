%% ========================================================================
%  Debug / Verification: Trivial Connections + Transport + Dual Integration
%  Matches your current API:
%    geometry.face.transport -> [header, dTheta_numeric]
% ========================================================================

clear; clc;

addpath("toolbox\")
bct.start
fs4path='C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage5\surf\lh.pial'
[vertices, faces] = freesurfer_read_surf(fs4path);
M=bct.Manifold(vertices,faces);
Mf=M.flip;clear M; M=Mf;

topo    = M.topology;
geom = M.geometry('includeDual', true);

ops     = M.operators;

antIdx  = 6653;
postIdx = 978;

nV = size(M.Vertices,1);
nF = size(M.Faces,1);
nH = numel(topo.tailVertex.value);
nE = size(ops.d0.value,1);

fprintf('--- Mesh sizes ---\n');
fprintf('|V|=%d |F|=%d |E|=%d |H|=%d\n', nV,nF,nE,nH);

%% ------------------------------------------------------------------------
% 0) Topology invariants
% ------------------------------------------------------------------------
tail  = topo.tailVertex.value;
head  = topo.headVertex.value;
faceH = topo.face.value;
twinH = topo.twin.value;
FH    = topo.faceHalfedges.value;

fprintf('\n--- Topology checks ---\n');
fprintf('twin symmetry ok: %d / %d\n', nnz(twinH(twinH)==uint32((1:nH).')), nH);
fprintf('halfedges valid face: %d / %d\n', nnz(faceH>=1 & faceH<=nF), nH);
fprintf('halfedges with twin>0: %d / %d\n', nnz(twinH>0), nH);

validH = (twinH>0) & (faceH>0) & (faceH(double(twinH))>0);

%% ------------------------------------------------------------------------
% 1) Face frames orthonormality
% ------------------------------------------------------------------------
Nf = geom.face.normals.value;
t1 = geom.face.tangent1.value;
t2 = geom.face.tangent2.value;

fprintf('\n--- Face frame checks ---\n');
fprintf('Max |t1·t2| = %.3e\n', max(abs(sum(t1.*t2,2))));
fprintf('Max |t1·N|  = %.3e\n', max(abs(sum(t1.*Nf,2))));
fprintf('Max |t2·N|  = %.3e\n', max(abs(sum(t2.*Nf,2))));
fprintf('Max ||t1||-1= %.3e\n', max(abs(vecnorm(t1,2,2)-1)));
fprintf('Max ||t2||-1= %.3e\n', max(abs(vecnorm(t2,2,2)-1)));
fprintf('Max ||N||-1 = %.3e\n', max(abs(vecnorm(Nf,2,2)-1)));

%% ------------------------------------------------------------------------
% 2) geometry.face.transport (no-rotation) checks
% ------------------------------------------------------------------------
fprintf('\n--- transportNoRotation checks ---\n');
[~, dTheta_geom] = bct.manifold.geometry.face.transport(M);   % nH x 1
dTheta_geom = mod(dTheta_geom + pi, 2*pi) - pi;

dTw = dTheta_geom(double(twinH));
asym = mod(dTheta_geom + dTw + pi, 2*pi) - pi;
fprintf('Max |dTheta(h)+dTheta(twin(h))| = %.3e\n', max(abs(asym(validH))));

fprintf('dTheta stats: min=%.3g max=%.3g mean=%.3g std=%.3g\n', ...
    min(dTheta_geom), max(dTheta_geom), mean(dTheta_geom), std(dTheta_geom));

%% ------------------------------------------------------------------------
% 3) trivial connection checks (beta, phi_edge, phi_halfedge)
% ------------------------------------------------------------------------
fprintf('\n--- Trivial connection checks ---\n');

conn = M.connection('trivial', ...
    'singularities', [antIdx, postIdx], ...
    'weights', [1, 1]);

beta     = conn.beta.value;             % nV x 1
phi_edge = conn.phi_edge.value;         % nE x 1
phi_h    = conn.phi_halfedge.value;     % nH x 1

K = geom.vertex.angleDefect.value;      % nV x 1
fprintf('sum(K)=%.6f  (expect 4*pi=%.6f)\n', sum(K), 4*pi);

% singularity vector used by connection (preferred)
if isfield(conn,'singularityVec')
    s = conn.singularityVec.value;
else
    s = zeros(nV,1); s(antIdx)=1; s(postIdx)=1;
end
fprintf('sum(s)=%.6f (expect 2)\n', sum(s));

rhs = -K + 2*pi*s;
L = ops.stiffness.value;
res = L*beta - rhs;
fprintf('Poisson residual: ||L*beta-rhs||/||rhs|| = %.3e\n', norm(res)/max(norm(rhs),1e-12));

% phi_edge formula check
d0    = ops.d0.value;
star1 = ops.hd1.value;
phi_edge_ref = star1 * (d0 * beta);
fprintf('phi_edge match: ||phi_edge-⋆1 d0 beta||/||⋆1 d0 beta|| = %.3e\n', ...
    norm(phi_edge-phi_edge_ref)/max(norm(phi_edge_ref),1e-12));

% phi_halfedge lift check
edgeH = topo.edge.value;
headV = topo.headVertex.value;
sgn = full(d0(sub2ind(size(d0), double(edgeH), double(headV))));
phi_h_ref = sgn .* phi_edge(double(edgeH));
fprintf('phi_halfedge lift match: ||phi_h-phi_h_ref||/||phi_h_ref|| = %.3e\n', ...
    norm(phi_h-phi_h_ref)/max(norm(phi_h_ref),1e-12));

% antisymmetry across twin
ph = mod(phi_h + pi, 2*pi) - pi;
ph_tw = ph(double(twinH));
asym_phi = mod(ph + ph_tw + pi, 2*pi) - pi;
fprintf('Max |phi(h)+phi(twin(h))| = %.3e\n', max(abs(asym_phi(validH))));

%% ------------------------------------------------------------------------
% 4) connection.transport checks (delta = dTheta - phi)
% ------------------------------------------------------------------------
fprintf('\n--- Connection transport checks ---\n');

trans = bct.manifold.connection.transport(M, conn);

delta = trans.delta_halfedge.value;
dTheta_conn = trans.dTheta_halfedge.value;
phi_conn    = trans.phi_halfedge.value;

% geometry transport consistency
fprintf('||dTheta_geom - dTheta_conn||/||dTheta_geom|| = %.3e\n', ...
    norm(dTheta_geom - dTheta_conn)/max(norm(dTheta_geom),1e-12));

% phi consistency
fprintf('||phi_h - phi_conn||/||phi_h|| = %.3e\n', ...
    norm(phi_h - phi_conn)/max(norm(phi_h),1e-12));

% delta formula consistency
delta_ref = mod((dTheta_geom - phi_h) + pi, 2*pi) - pi;
dd = mod((delta - delta_ref) + pi, 2*pi) - pi;
fprintf('delta match: max|delta-(dTheta-phi)| = %.3e, rms = %.3e\n', max(abs(dd(validH))), rms(dd(validH)));

% antisymmetry
dl = mod(delta + pi, 2*pi) - pi;
dl_tw = dl(double(twinH));
asym_delta = mod(dl + dl_tw + pi, 2*pi) - pi;
fprintf('Max |delta(h)+delta(twin(h))| = %.3e\n', max(abs(asym_delta(validH))));

%% ------------------------------------------------------------------------
% 5) dual integration + transport consistency check
% ------------------------------------------------------------------------
fprintf('\n--- Dual BFS integration checks ---\n');

result = bct.manifold.query.dual(M, delta, 'seedFace', 1, 'seedValue', 0, 'wrap', false);
alpha = result.alpha_face;

assigned = ~isnan(alpha);
fprintf('Assigned faces: %d / %d\n', nnz(assigned), nF);

fi = double(faceH);
fj = double(faceH(double(twinH)));
ok = validH & assigned(fi) & assigned(fj);

lhs = alpha(fj) - alpha(fi);
lhs = mod(lhs + pi, 2*pi) - pi;
rhs = mod(delta + pi, 2*pi) - pi;

err = mod((lhs - rhs) + pi, 2*pi) - pi;
fprintf('Transport consistency: median|err|=%.3e, 95%%|err|=%.3e, max|err|=%.3e\n', ...
    median(abs(err(ok))), prctile(abs(err(ok)),95), max(abs(err(ok))));

% build vectors (wrapped) for visualization
alphaW = mod(alpha + pi, 2*pi) - pi;
X = cos(alphaW).*t1 + sin(alphaW).*t2;
X = X ./ max(vecnorm(X,2,2), 1e-12);

tangErr = max(abs(sum(X .* Nf, 2)));
unitErr = max(abs(vecnorm(X,2,2) - 1));
fprintf('Vector field: Max |dot(X,N)|=%.3e, Max ||X||-1=%.3e\n', tangErr, unitErr);

fprintf('\nDone.\n');
%%


viewer = bct.ui.show(M);

% Test 1: Face normals (diagnostic - should be perpendicular to surface)
viewer.setVector(geom.face.normals.value, ...
    'Support', 'face', ...
    'Positions', geom.face.centroids.value, ...
    'Normals', [], ...  % Don't project - test raw normals
    'Style', 'line', ...
    'Stride', 1, ...
    'LengthScale', 5);
X=geom.face.tangent1.value;
% Test 2: Your direction field (without normal projection first)
viewer.setVector(X, ...
    'Support', 'face', ...
    'Positions', geom.face.centroids.value, ...
    'Normals', [], ...  % Try without projection first
    'Style', 'line', ...
    'Stride', 2, ...
    'LengthScale', 1);

viewer.setVector(X_face, ...
    'Support', 'face', ...
    'Positions', geom.face.centroids.value, ...
    'Normals', [], ...  % Try without projection first
    'Style', 'line', ...
    'Stride', 2, ...
    'LengthScale', 1.5);

