function g = manifoldToMatlabGraph(M)
% manifoldToMatlabGraph - Convert Manifold to MATLAB graph object
%
% Syntax:
%   g = bct.io.convert.manifoldToMatlabGraph(M)
%
% Inputs:
%   M - bct.manifold.Manifold object
%
% Outputs:
%   g - MATLAB graph object (undirected)
%
% Example:
%   B = bct.bct.fromMesh(V, F);
%   g = bct.io.convert.manifoldToMatlabGraph(B.Manifold);
%   plot(g);
%
% See also: graph, bct.manifold.Manifold

% Validate input
if ~isa(M, 'bct.manifold.Manifold')
    error('bct:InvalidInput', 'Input must be a bct.manifold.Manifold object');
end

% Get adjacency matrix
A = M.adjacency();

if isempty(A)
    error('bct:MissingData', 'Cannot create graph: adjacency matrix is empty');
end

% Create undirected graph
g = graph(A);

end
