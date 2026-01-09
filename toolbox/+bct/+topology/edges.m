function E = edges(varargin)
%EDGES Extract unique undirected edges from triangular faces
%
% Syntax:
%   E = bct.topology.edges(M)
%   E = bct.topology.edges(F)
%
% Inputs:
%   M - bct.Manifold object
%   F - [M×3] face connectivity (1-indexed)
%
% Outputs:
%   E - [nE×2] matrix of vertex indices forming edges
%
% Description:
%   Extracts all unique undirected edges from a triangular mesh. Each row
%   represents an edge as a pair of vertex indices. Edges are sorted so
%   that (i,j) and (j,i) are treated as the same edge.
%
%   This function is coordinate-free - it operates on face connectivity alone.
%
% Examples:
%   % From Manifold object
%   M = bct.Manifold(V, F);
%   E = bct.topology.edges(M);
%
%   % From faces directly
%   E = bct.topology.edges(F);
%
%   % Number of edges
%   nEdges = size(E, 1);
%
% See also: bct.topology.adjacency, bct.topology.halfedge

% Parse inputs
if nargin == 1
    if isa(varargin{1}, 'bct.Manifold')
        % Manifold object
        M = varargin{1};
        F = M.Faces;
    elseif isnumeric(varargin{1})
        % Face connectivity matrix
        F = varargin{1};
    else
        error('bct:topology:edges:InvalidInput', ...
            'Input must be a bct.Manifold object or face connectivity matrix');
    end
else
    error('bct:topology:edges:InvalidNumArgs', ...
        'Expected 1 input argument: (M) or (F)');
end

% Validate faces
if isempty(F)
    E = zeros(0, 2);
    return;
end

if ~isnumeric(F) || size(F, 2) ~= 3
    error('bct:topology:edges:InvalidFaces', ...
        'Faces must be M×3 numeric array');
end

% Extract all edges from triangular faces
% Each triangle has three edges: (v1,v2), (v2,v3), (v3,v1)
edges = [F(:,[1 2]); F(:,[2 3]); F(:,[3 1])];

% Sort each edge so that (i,j) and (j,i) become the same
edges = sort(edges, 2);

% Get unique edges
E = unique(edges, 'rows');

end
