function topo = topology(M, varargin)
%TOPOLOGY Compute all topological properties of a manifold
%
% Syntax:
%   topo = bct.manifold.topology(M)
%   topo = bct.manifold.topology(V, F)
%
% Inputs:
%   M - bct.Manifold object
%   V - [N×3] vertex coordinates (can be empty [] for pure topology)
%   F - [M×3] face connectivity (1-indexed)
%
% Outputs:
%   topo - Structure with fields:
%     .edges     - [nE×2] Unique undirected edges
%     .adjacency - [N×N] Sparse binary adjacency matrix
%     .halfedge  - Halfedge data structure with navigation pointers
%
% Description:
%   Convenience function that computes all topological properties of a
%   manifold in a single call. Results are returned in a structure for
%   easy access. Topology is coordinate-free and depends only on face
%   connectivity F.
%
% Examples:
%   % Compute all topology
%   M = bct.Manifold(V, F);
%   topo = bct.manifold.topology(M);
%   
%   % Access individual properties
%   E = topo.edges;          % [nE×2] edge list
%   A = topo.adjacency;      % [N×N] adjacency matrix
%   he = topo.halfedge;      % Halfedge structure
%   
%   % Navigate mesh using halfedge
%   h = 1;  % First halfedge
%   next_h = topo.halfedge.next(h);
%   twin_h = topo.halfedge.twin(h);
%   
%   % From V, F directly
%   topo = bct.manifold.topology(V, F);
%
% See also: bct.manifold.topology.edges, bct.manifold.topology.adjacency,
%           bct.manifold.topology.halfedge, bct.manifold.geometry

% Parse inputs
if nargin == 1
    % Single argument: Manifold object
    if isa(M, 'bct.Manifold')
        V = M.Vertices;
        F = M.Faces;
        nV = M.numVertices();
    else
        error('bct:manifold:topology:InvalidInput', ...
            'Single argument must be a bct.Manifold object');
    end
elseif nargin == 2
    % Two arguments: V, F
    V = M;  % First arg is V
    F = varargin{1};
    
    % Validate inputs
    if ~isnumeric(F) || size(F, 2) ~= 3
        error('bct:manifold:topology:InvalidFaces', ...
            'Faces must be M×3 numeric array');
    end
    
    % V can be empty for pure topology, or [nV×3] coordinates
    if isempty(V)
        nV = max(F(:));
    elseif isnumeric(V)
        nV = size(V, 1);
    else
        error('bct:manifold:topology:InvalidVertices', ...
            'Vertices must be empty [] or N×3 numeric array');
    end
else
    error('bct:manifold:topology:InvalidNumArgs', ...
        'Expected 1 (Manifold) or 2 (V, F) input arguments');
end

% Compute all topology properties
topo = struct();

% Edges - unique undirected edges
topo.edges = bct.manifold.topology.edges(F);

% Adjacency - binary connectivity matrix
topo.adjacency = bct.manifold.topology.adjacency(F, nV);

% Halfedge - comprehensive navigation structure
topo.halfedge = bct.manifold.topology.halfedge(V, F);

end
