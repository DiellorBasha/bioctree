function [header, Lconn] = connectionLaplacian(meshInput, transportAngles, varargin)
%CONNECTIONLAPLACIAN Assemble face-based connection Laplacian (complex Hermitian PSD)
%
% Syntax:
%   [header, Lconn] = bct.manifold.operator.connectionLaplacian(M, delta)
%   [header, Lconn] = bct.manifold.operator.connectionLaplacian(M, delta, 'WeightType', 'dec')
%
% Inputs:
%   M              - bct.Manifold object
%   transportAngles - [nH×1] Halfedge transport angles (radians)
%                     e.g., from combinedTransport = dTheta - phi
%
% Name-Value Arguments:
%   WeightType - 'dec' (default) | 'uniform'
%                Type of edge weights to use
%
% Outputs:
%   header - Structure with computation metadata
%   Lconn  - [nF×nF] Complex sparse Hermitian PSD matrix
%
% Description:
%   Assembles the face-based connection Laplacian for vector field
%   computation via the vector heat method. For each primal edge e
%   separating faces i and j with transport angle R_ij = exp(1i*delta):
%
%     L_ii += w_e
%     L_jj += w_e
%     L_ij += -w_e * R_ij
%     L_ji += -w_e * conj(R_ij)
%
%   Where w_e are edge weights (DEC weights = dual_length / primal_length)
%   and R_ij encodes the parallel transport rotation across the edge.
%
%   The resulting matrix is:
%   - Complex (encodes rotation in tangent spaces)
%   - Hermitian (L^H = L)
%   - Positive semi-definite (x^H L x >= 0 for all x)
%
% Examples:
%   % Get combined transport from connection
%   conn = M.connection('trivial', 'singularities', [100, 200]);
%   delta = conn.combinedTransport.value;
%   
%   % Assemble connection Laplacian
%   [~, Lconn] = bct.manifold.operator.connectionLaplacian(M, delta);
%   
%   % Use with face mass matrix for vector heat solve
%   Mf = M.massmatrix('type', 'face');
%   t = 0.01;
%   H = Mf.value + t * Lconn;
%
% See also: bct.manifold.connection, bct.manifold.operator.stiffness,
%           bct.field.generate.vectorHeat

% ----------------------------
% Parse inputs
% ----------------------------
p = inputParser;
p.FunctionName = 'bct.manifold.operator.connectionLaplacian';
p.addRequired('M', @(x) isa(x, 'bct.Manifold'));
p.addRequired('transportAngles', @(x) isnumeric(x) && isvector(x));
p.addParameter('WeightType', 'dec', @(x) ismember(x, ["dec", "uniform"]));
p.parse(meshInput, transportAngles, varargin{:});

M = p.Results.M;
delta = double(transportAngles(:));
weightType = string(p.Results.WeightType);

% ----------------------------
% Get topology
% ----------------------------
topo = M.topology();

nV = size(M.Vertices, 1);
nF = size(M.Faces, 1);
nH = numel(topo.face.value);
nE = size(M.Edges, 1);

% Validate input size
if numel(delta) ~= nH
    error('bct:operator:connectionLaplacian:InvalidSize', ...
        'transportAngles must be [nH×1] = [%d×1], got [%d×1]', nH, numel(delta));
end

faceH = topo.face.value;
twinH = topo.twin.value;
edgeH = topo.edge.value;

% ----------------------------
% Get edge weights
% ----------------------------
if weightType == "dec"
    geom = M.geometry('includeDual', true);
    wE = geom.edge.weights_dec.value;
elseif weightType == "uniform"
    wE = ones(nE, 1);
end

% ----------------------------
% Compute complex transport rotations
% ----------------------------
R_h = exp(1i * delta);  % [nH×1] complex unit rotations

% ----------------------------
% Assemble connection Laplacian
% ----------------------------

% Pick one representative halfedge per edge
% (Any consistent choice works; we use the first halfedge for each edge)
repH = accumarray(double(edgeH), (1:nH).', [nE 1], @(x)x(1), 0);

% Get valid edges (those with a representative halfedge)
eIdx = find(repH > 0);
h = repH(eIdx);
ht = double(twinH(h));

% Get faces on either side of the edge
i = double(faceH(h));      % Face on halfedge h
j = double(faceH(ht));     % Face on twin(h)

% Keep only edges with valid faces on both sides
okE = (ht > 0) & (i > 0) & (j > 0);
h = h(okE);
ht = ht(okE);
i = i(okE);
j = j(okE);
eIdx = eIdx(okE);

% Get edge weights and transport rotations
w = wE(eIdx);

% Keep only positive weights
keepW = (w > 0);
h = h(keepW);
i = i(keepW);
j = j(keepW);
w = w(keepW);

% Get transport rotations for these edges
Rij = R_h(h);          % i -> j transport
Rji = conj(Rij);       % j -> i transport

% Assemble sparse matrix
% Diagonal entries: L_ii += w_e, L_jj += w_e
% Off-diagonal: L_ij += -w_e * R_ij, L_ji += -w_e * conj(R_ij)
I = [i; j; i; j];
J = [i; j; j; i];
S = [w; w; -w .* Rij; -w .* Rji];

Lconn = sparse(I, J, S, nF, nF);

% ----------------------------
% Validate Hermitian property
% ----------------------------
hermErr = norm(Lconn - Lconn', 'fro') / max(norm(Lconn, 'fro'), 1e-12);

if hermErr > 1e-10
    warning('bct:operator:connectionLaplacian:NotHermitian', ...
        'Connection Laplacian Hermitian error: %.3e (expected < 1e-10)', hermErr);
end

% Numerically enforce Hermitian (average with conjugate transpose)
Lconn = (Lconn + Lconn') / 2;

% ----------------------------
% Create header with metadata
% ----------------------------
header = struct();
header.type = 'connectionLaplacian';
header.weightType = char(weightType);
header.numFaces = nF;
header.numEdges = nE;
header.numNonzeros = nnz(Lconn);
header.hermitianError = hermErr;
header.isComplex = true;
header.isHermitian = true;
header.isPSD = true;  % By construction (graph Laplacian with complex rotations)

end
