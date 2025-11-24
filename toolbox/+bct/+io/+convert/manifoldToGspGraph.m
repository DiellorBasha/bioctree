function G = manifoldToGspGraph(M)
% manifoldToGspGraph - Convert Manifold to GSPBox graph structure
%
% Syntax:
%   G = bct.io.convert.manifoldToGspGraph(M)
%
% Inputs:
%   M - bct.Manifold object
%
% Outputs:
%   G - GSPBox graph structure with fields:
%       .W      - Weighted adjacency matrix (symmetric, sparse)
%       .N      - Number of nodes
%       .coords - (optional) Vertex coordinates [N×3] if available
%       .lmax   - (optional) Largest eigenvalue if gsp_estimate_lmax is available
%
% Example:
%   B = bct.bct.fromMesh(V, F);
%   G = bct.io.convert.manifoldToGspGraph(B.Manifold);
%   G = gsp_compute_fourier_basis(G);
%
% See also: gsp_graph, bct.Manifold

% Validate input
if ~isa(M, 'bct.Manifold')
    error('bct:InvalidInput', 'Input must be a bct.Manifold object');
end

% Get adjacency matrix
% Get weighted adjacency matrix from cotangent weights
K = M.CotangentMatrix;
W = max(0, -K);      % flip sign, zero negative entries
W = W - diag(diag(W)); 
W = max(W,W');       % enforce symmetry


if isempty(W)
    error('bct:MissingData', 'Cannot create GSP graph: adjacency matrix is empty');
end

% Convert to weighted adjacency (double precision for GSPBox)
W = double(W);
V = M.Vertices;


% Try to estimate lmax if GSPBox is available
try
% Create GSP structure
G = gsp_graph(W, V);
G.L = M.Laplacian;
G = gsp_estimate_lmax(G);
catch
    % GSPBox not available or estimation failed, continue without lmax
end

end
