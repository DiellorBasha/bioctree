function G = toGspGraph(M)
% toGspGraph - Convert Manifold to GSPBox graph structure
%
% Syntax:
%   G = bct.manifold.toGspGraph(M)
%
% Inputs:
%   M - bct.manifold.Manifold object
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
%   G = bct.manifold.toGspGraph(B.Manifold);
%   G = gsp_compute_fourier_basis(G);
%
% See also: gsp_graph, bct.manifold.Manifold

% Validate input
if ~isa(M, 'bct.manifold.Manifold')
    error('bct:InvalidInput', 'Input must be a bct.manifold.Manifold object');
end

% Get adjacency matrix
A = M.adjacency();

if isempty(A)
    error('bct:MissingData', 'Cannot create GSP graph: adjacency matrix is empty');
end

% Convert to weighted adjacency (double precision for GSPBox)
W = double(A);

% Make symmetric if not already
W = max(W, W');

% Create GSP structure
G = struct();
G.W = W;
G.N = size(W, 1);

% Add coordinates if available
if ~isempty(M.V)
    G.coords = double(M.V);
end

% Try to estimate lmax if GSPBox is available
try
    G = gsp_estimate_lmax(G);
catch
    % GSPBox not available or estimation failed, continue without lmax
end

end
