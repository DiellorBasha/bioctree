function g = toMatlabGraph(M, directed)
% toMatlabGraph - Convert Manifold to MATLAB graph or digraph object
%
% Syntax:
%   g = bct.manifold.toMatlabGraph(M)
%   g = bct.manifold.toMatlabGraph(M, directed)
%
% Inputs:
%   M        - bct.manifold.Manifold object
%   directed - (optional) logical, if true creates digraph, else graph (default: false)
%
% Outputs:
%   g - MATLAB graph or digraph object
%
% Example:
%   B = bct.bct.fromMesh(V, F);
%   g = bct.manifold.toMatlabGraph(B.Manifold);
%   plot(g);
%
% See also: graph, digraph, bct.manifold.Manifold

% Validate input
if ~isa(M, 'bct.manifold.Manifold')
    error('bct:InvalidInput', 'Input must be a bct.manifold.Manifold object');
end

if nargin < 2 || isempty(directed)
    directed = false;
end

% Get adjacency matrix
A = M.adjacency();

if isempty(A)
    error('bct:MissingData', 'Cannot create graph: adjacency matrix is empty');
end

% Create appropriate graph type
if directed
    g = digraph(A);
else
    g = graph(A);
end

end
