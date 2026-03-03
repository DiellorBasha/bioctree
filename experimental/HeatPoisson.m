
addpath("toolbox\")
bct.start
fs4path='C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage5\surf\lh.pial'
[vertices, faces] = freesurfer_read_surf(fs4path);
M=bct.Manifold(vertices,faces);
Mf=M.flip;clear M; M=Mf;
    topo = M.topology;
    geom = M.geometry;
    ops=M.operators;
    eigen=M.eigenmodes(1000);

% === Equivalent of the JS snippet (cotan Laplacian + mass + Cholesky + solve) ===
% JS: https://geometrycollective.github.io/geometry-processing-js/docs/index.html
%   A     = laplaceMatrix(...)
%   Mmass = massMatrix(...)
%   rhs   = Mmass * rho
%   llt   = A.chol()
%   phi   = llt.solvePositiveDefinite(rhs)


%% Heat Method (Crane et al.) — simple script, prefactor + reuse by default

% --- Setup ---
M = bct.Manifold();

ops  = M.operators;
geom = M.geometry;

nV = ops.mass.attributes.shape(1);   % or size(ops.mass.value,1)
nF = length(M.Faces);  % if exists; otherwise: length(geom.face.areas.value)

seed = 4841;                         % choose your source vertex (1..nV)

% --- Pull core matrices ---
Mass = ops.mass.value;               % nV x nV
L    = ops.stiffness.value;          % nV x nV  (cotan Laplacian / stiffness)

% Heat operator from bct (already chooses/records t_heat)
heat = bct.manifold.operator.heat(M);         % heat.value = Mass + t_heat * L
H    = heat.value;
t    = heat.attributes.t_heat;

% Gradient operator from bct (vertex scalar -> face tangent vector)
grad = bct.manifold.operator.gradient(M);
G    = grad.value;                   % (3*nF) x nV

Af = geom.face.areas.value;          % nF x 1 (face areas)

%% Step 0: build delta sources (vertex)
delta = zeros(nV,1);
delta(seed) = 1;

%% Step I: integrate heat flow for time t
% Discrete heat equation: (M + tL) u = M * delta
rhsHeat = Mass * delta;

% Prefactor once (reuse this for many seeds on same mesh + same t)
Hchol = decomposition(H, 'chol');
u = Hchol \ rhsHeat;                 % nV x 1

%% Step II: compute normalized vector field X = -∇u / |∇u|

gu = G * u;                 % (3*nF) x 1

ix1 = 1:3:numel(gu);
ix2 = ix1 + 1;
ix3 = ix1 + 2;

gn = sqrt( gu(ix1).^2 + gu(ix2).^2 + gu(ix3).^2 );
gn = max(gn, 1e-12);

Xvec = gu;                  % reuse storage
Xvec(ix1) = -Xvec(ix1) ./ gn;
Xvec(ix2) = -Xvec(ix2) ./ gn;
Xvec(ix3) = -Xvec(ix3) ./ gn;

%% Step III: solve Poisson for distance potential φ
% Use div(X) as the negative adjoint of grad under L2:
%   div(X) = -G' * (Af ⊗ I3) * X
Af = geom.face.areas.value;

y = Xvec;
y(ix1) = Af .* y(ix1);
y(ix2) = Af .* y(ix2);
y(ix3) = Af .* y(ix3);

rhsPoisson = -G.' * y;


% Poisson solve with pinned gauge (prefactor once, reuse)
pinnedVertex = 55;
poissonSolver = bct.manifold.solve.poisson(M, 'input',"rhs", 'pinnedVertex', pinnedVertex);

phi = poissonSolver.value(rhsPoisson);  % nV x 1

% Optional: shift so the seed is at 0 (distance is defined up to constant)
phi = phi - phi(seed);
viewer.setScalar(phi)
%% Done: phi is the heat-method geodesic distance (up to discretization error)
% You can visualize or sanity-check:
%   min(phi) should be ~0, phi(seed)=0, and phi increases away from seed.
viewer=bct.ui.show(M)
viewer.setScalar(phi)

%%





%% Heat Method (Crane et al.) — efficient script, prefactor + reuse

% --- Setup ---
M    = bct.Manifold();
ops  = M.operators;
geom = M.geometry;

Mass = ops.mass.value;          % nV x nV
L    = ops.stiffness.value;     % nV x nV

nV = size(Mass,1);
Af = geom.face.areas.value;     % nF x 1
nF = numel(Af);

% Gradient operator (vertex scalar -> stacked per-face 3D vectors)
grad = bct.manifold.operator.gradient(M);
G    = grad.value;              % (3*nF) x nV

% Heat operator (Mass + t*L)
heat = bct.manifold.operator.heat(M);
H    = heat.value;
t    = heat.attributes.t_heat;

% --- Prefactor once (reuse) ---
Hchol = decomposition(H, 'chol');

pinnedVertex  = 55;
poissonSolver = bct.manifold.solve.poisson(M, 'input',"rhs", 'pinnedVertex', pinnedVertex);

% --- Stride indices for stacked face vectors ---
ix1 = 1:3:(3*nF);
ix2 = ix1 + 1;
ix3 = ix1 + 2;

epsNorm = 1e-12;

%% =========================
% Choose seeds / sources
%% =========================
seed = 4841;   % single seed example
% seeds = [4841 4507 123];  % multi-seed example (uncomment)

%% ============================================
% Step I: Heat solve (M + tL) u = M * delta
% Efficient RHS construction options (no delta)
%% ============================================

% ---- Option 1 (fastest): Lumped/diagonal mass ----
% If Mass is diagonal (or you are OK using a lumped vector mass_diag):
% mass_diag = diag(Mass);   % do this once; for huge meshes you might cache it
% rhsHeat = zeros(nV,1);
% rhsHeat(seed) = mass_diag(seed);

% ---- Option 2 (general mass): column extraction ----
% Exact for any Mass: Mass * e_seed = Mass(:,seed)
rhsHeat = Mass(:, seed);

% ---- Option 3: multiple seeds in one shot (matrix RHS) ----
% RHSHeat = Mass(:, seeds);     % nV x K
% U      = Hchol \ RHSHeat;     % nV x K  (each column is u_k)
% u      = U(:,1);              % pick one if you want to continue single pipeline

% Solve heat (single RHS)
u = Hchol \ rhsHeat;            % nV x 1

%% ============================================
% Step II: X = -∇u / |∇u|   (stay stacked)
%% ============================================
tic
gu = G * u;                     % (3*nF) x 1

% per-face norms in stacked layout
gn = sqrt( gu(ix1).^2 + gu(ix2).^2 + gu(ix3).^2 );
gn = max(gn, epsNorm);

% normalize + flip sign, in-place (Xvec stacked)
Xvec = gu;                       % reuse storage
Xvec(ix1) = -Xvec(ix1) ./ gn;
Xvec(ix2) = -Xvec(ix2) ./ gn;
Xvec(ix3) = -Xvec(ix3) ./ gn;
toc

%% ============================================
% Step III: Poisson solve  L φ = div(X)
% div(X) = -G' * (Af ⊗ I3) * X   (no kron)
%% ============================================

% area-weight stacked vectors: y = (Af ⊗ I3) * Xvec
y = Xvec;
y(ix1) = Af .* y(ix1);
y(ix2) = Af .* y(ix2);
y(ix3) = Af .* y(ix3);

rhsPoisson = -G.' * y;           % nV x 1

phi = poissonSolver.value(rhsPoisson);

% shift gauge so seed is at 0 (optional but typical for "distance")
phi = phi - phi(seed);

%% ============================================
% Visualize
%% ============================================
%viewer = bct.ui.show(M);
viewer.setScalar(phi);
%%

F  = M.Faces;                     % nF x 3
V  = M.Vertices;           % nV x 3  (adjust if your path differs)
n  = geom.face.normals.value;     % nF x 3
Af = geom.face.areas.value;       % nF x 1
epsNorm = 1e-12;
%%
tic
i = F(:,1); j = F(:,2); k = F(:,3);

ui = u(i); uj = u(j); uk = u(k);

e_i = V(j,:) - V(k,:);            % (v_j - v_k)
e_j = V(k,:) - V(i,:);            % (v_k - v_i)
e_k = V(i,:) - V(j,:);            % (v_i - v_j)

% per-face gradient (nF x 3)
gradU = ( cross(n, e_i, 2).*ui + cross(n, e_j, 2).*uj + cross(n, e_k, 2).*uk ) ./ (2*Af);

% normalize and flip sign: X = -gradU / ||gradU||
gn = sqrt(sum(gradU.^2, 2));
gn = max(gn, epsNorm);
X  = -gradU ./ gn;                % nF x 3

% if you still want stacked (3*nF)x1:
Xvec = reshape(X.', [3*nF, 1]);
toc
%%

% --- Pull topology/geometry ---
topo = M.topology;
geom = M.geometry;
ops  = M.operators;

V  = M.Vertices;            % nV x 3
Af = geom.face.areas.value;        % nF x 1
Nf = geom.face.normals.value;      % nF x 3
nF = numel(Af);

% Halfedge arrays
tail = topo.tailVertex.value;      % nH x 1
head = topo.headVertex.value;      % nH x 1
faceH = topo.face.value;           % nH x 1
prevH = topo.prev.value;           % nH x 1
twinH = topo.twin.value;           % nH x 1
isB  = topo.isBoundary.value;      % nH x 1 logical
nH = numel(tail);

% Make face normals unit (JS uses faceNormal; typically unit)
nn = sqrt(sum(Nf.^2,2));
Nf_unit = Nf ./ max(nn, 1e-12);

% Edge vector for each halfedge: e = x_head - x_tail
E = V(head,:) - V(tail,:);         % nH x 3

% Heat solve (same as before)
Mass = ops.mass.value;
heat = bct.manifold.operator.heat(M);
H    = heat.value;
Hchol = decomposition(H, 'chol');

seed = 4841;
rhsHeat = Mass(:, seed);           % or diagonal/lumped option
u = Hchol \ rhsHeat;


heatSolver = bct.manifold.solve.heat(M);

% Solve heat diffusion from a single seed vertex
seed = 4841;
u = heatSolver.value(seed);  % [nV×1] heat diffusion field

%% ========== Step II (JS-style): compute X per face ==========
% JS: gradU_f = (1/(2A_f)) * Σ_{h in face} (n_f × e_h) * u(prevVertex(h))
% With standard halfedge conventions, prevVertex(h) is the tail of h.
u_tail = u(tail);                                  % nH x 1
Nh = Nf_unit(faceH,:);                             % nH x 3 (normal for each halfedge's face)
C = cross(Nh, E, 2);                               % nH x 3 (n × e)

% Weighted contributions per halfedge
Cx = C(:,1) .* u_tail;
Cy = C(:,2) .* u_tail;
Cz = C(:,3) .* u_tail;

% Accumulate to faces (sum around each face)
gradUx = accumarray(faceH, Cx, [nF 1], @sum, 0);
gradUy = accumarray(faceH, Cy, [nF 1], @sum, 0);
gradUz = accumarray(faceH, Cz, [nF 1], @sum, 0);

gradU = [gradUx, gradUy, gradUz] ./ (2*Af);        % nF x 3

% Normalize, then negate (X = - normalized gradU)
gn = sqrt(sum(gradU.^2,2));
gn = max(gn, 1e-12);
Xf = -gradU ./ gn;                                 % nF x 3

%% ========== Step III RHS (JS-style): compute div at vertices ==========
% Need cotan at halfedges/corners:
cot = geom.face.cotan.value;

% Make cot a nH x 1 vector matching halfedge order.
% If stored as nF x 3 (corners per face), flatten in face-halfedge order.
if ismatrix(cot) && size(cot,1)==nF && size(cot,2)==3
    % You need the mapping from (face,localCorner) to halfedge index.
    % If your bct provides topo.faceHalfedges.value (nF x 3), use it:
    FH = topo.faceHalfedges.value;                 % nF x 3 halfedge indices
    cotH = zeros(nH,1);
    cotH(FH(:,1)) = cot(:,1);
    cotH(FH(:,2)) = cot(:,2);
    cotH(FH(:,3)) = cot(:,3);
else
    % Assume already nH x 1 aligned with halfedges
    cotH = cot;
end

% For each halfedge h around vertex v: v is tail(h) (outgoing halfedge)
% Only interior halfedges contribute (JS: if !h.onBoundary)
mask = ~isB;

h = find(mask);
v = tail(h);                         % vertex index receiving contribution
f = faceH(h);                        % face index for X

% e1 = vector(h)
e1 = E(h,:);

% e2 = vector(h.prev.twin)
hp = prevH(h);
ht = twinH(hp);
e2 = V(head(ht),:) - V(tail(ht),:);

% cotTheta1 = cotan(h), cotTheta2 = cotan(h.prev)
cot1 = cotH(h);
cot2 = cotH(hp);

X = Xf(f,:);                         % nInt x 3

term = cot1 .* sum(e1 .* X, 2) + cot2 .* sum(e2 .* X, 2);  % nInt x 1

div = accumarray(v, 0.5 * term, [size(V,1) 1], @sum, 0);    % nV x 1

%% Poisson solve: L * phi = div (pinned gauge)
pinnedVertex = 55;
poissonSolver = bct.manifold.solve.poisson(M, 'input',"rhs", 'pinnedVertex', pinnedVertex);

phi = poissonSolver.value(-div);
phi = phi - phi(seed);

% Visualize
viewer = bct.ui.show(M);
%%
seedVertex=256
    solvers = bct.manifold.solve();  % No arguments - returns function handles
poisson = bct.manifold.solve.poisson(M);
heat = bct.manifold.solve.poisson(M);
distSolver = solvers.heatDistance(M);  % Pass M to the specific solver
%%
seed=111
phi = distSolver.value(seed);
viewer.setScalar(phi);


seeds = [100, 500, 1000];
PHI = solver.value(seeds);  % [nV×K] sparse - keep sparse!

% 1. Minimum distance (most common)
phi = min(PHI, [], 2);  % Still sparse [nV×1]
viewer.setScalar(full(phi));  % Only convert final result

% 2. Sum of distances
phi = sum(PHI, 2);  % Sparse [nV×1]
viewer.setScalar(full(phi));

% 3. Mean distance
phi = mean(PHI, 2);  % Sparse [nV×1]
viewer.setScalar(full(phi));

% 4. Weighted average (inverse distance weighting)
weights = spfun(@(x) 1./(1+x), PHI);  % Apply function to sparse nonzeros
phi = sum(weights, 2);  % Sparse sum
viewer.setScalar(full(phi));

% 5. Maximum distance
phi = max(PHI, [], 2);  % Sparse [nV×1]
viewer.setScalar(full(phi));