function g = manifoldToMatlabGraph(M, varargin)
% manifoldToMatlabGraph - Convert Manifold to MATLAB graph object
%
% Syntax:
%   g = bct.io.convert.manifoldToMatlabGraph(M)
%   g = bct.io.convert.manifoldToMatlabGraph(M, 'Weighted', true)
%
% Inputs:
%   M - bct.Manifold object
%
% Name-Value Parameters:
%   'Weighted' - Compute edge weights from Euclidean edge lengths (default: false)
%
% Outputs:
%   g - MATLAB graph object (undirected)
%       If Weighted=true, g.Edges.Weight contains Euclidean edge lengths
%
% Example:
%   B = bct.bct.fromMesh(V, F);
%   
%   % Unweighted graph
%   g = bct.io.convert.manifoldToMatlabGraph(B.Manifold);
%   plot(g);
%   
%   % Weighted graph with edge lengths
%   gw = bct.io.convert.manifoldToMatlabGraph(B.Manifold, 'Weighted', true);
%   plot(gw, 'EdgeAlpha', 0.5);
%   shortestpath(gw, 1, 100);  % Uses edge lengths
%
% See also: graph, bct.Manifold

% Parse inputs
p = inputParser;
addRequired(p, 'M', @(x) isa(x, 'bct.Manifold'));
addParameter(p, 'Weighted', false, @(x) islogical(x) || isnumeric(x));
parse(p, M, varargin{:});

weighted = logical(p.Results.Weighted);

% Get adjacency matrix
A = M.adjacency();

if isempty(A)
    error('bct:MissingData', 'Cannot create graph: adjacency matrix is empty');
end

% Create undirected graph
g = graph(A);

% Add edge weights if requested
if weighted
    V = M.Vertices;
    
    if isempty(V)
        warning('bct:NoVertices', 'Cannot compute edge weights: Vertices are empty');
        return;
    end
    
    % Get edge list from graph
    E = g.Edges.EndNodes;
    
    % Compute Euclidean edge lengths
    edgeLengths = sqrt(sum((V(E(:,1),:) - V(E(:,2),:)).^2, 2));
    
    % Assign weights
    g.Edges.Weight = edgeLengths;
end

end
