function [E, edge_id] = edges(varargin)
%EDGES Extract unique undirected edges from triangular faces with canonical indexing
%
% Syntax:
%   E = bct.manifold.topology.edges(M)
%   E = bct.manifold.topology.edges(F)
%   [E, edge_id] = bct.manifold.topology.edges(...)
%
% Inputs:
%   M - bct.Manifold object
%   F - [M×3] face connectivity (1-indexed)
%
% Outputs:
%   E       - [nE×2] matrix of unique undirected edges (sorted vertex pairs)
%   edge_id - [3*nF×1] vector mapping each face-edge to its edge ID (optional)
%             Organized as: [F(:,[1 2]); F(:,[2 3]); F(:,[3 1])]
%             This provides canonical edge indexing for all mesh components
%
% Description:
%   Extracts all unique undirected edges from a triangular mesh. Each row
%   represents an edge as a pair of vertex indices. Edges are sorted so
%   that (i,j) and (j,i) are treated as the same edge.
%
%   When the second output is requested, returns a mapping from each directed
%   face-edge (in the canonical stacking order) to its undirected edge ID.
%   This ensures consistent edge indexing across all topology functions.
%
%   This function is coordinate-free - it operates on face connectivity alone.
%
% Examples:
%   % Get unique edges only
%   M = bct.Manifold(V, F);
%   E = bct.manifold.topology.edges(M);
%
%   % Get edges with canonical indexing
%   [E, edge_id] = bct.manifold.topology.edges(F);
%   
%   % edge_id(1:nF) corresponds to edges F(:,[1 2])
%   % edge_id(nF+1:2*nF) corresponds to edges F(:,[2 3])
%   % edge_id(2*nF+1:3*nF) corresponds to edges F(:,[3 1])
%
%   % Number of unique edges
%   nEdges = size(E, 1);
%
% See also: bct.manifold.topology.adjacency, bct.manifold.topology.halfedge

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
    if nargout > 1
        edge_id = zeros(0, 1);
    end
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
edges_sorted = sort(edges, 2);

% Get unique edges with indexing
if nargout > 1
    % Return mapping from face-edges to unique edges
    [E, ~, edge_id] = unique(edges_sorted, 'rows', 'stable');
else
    % Only return unique edges
    E = unique(edges_sorted, 'rows');
end

end

