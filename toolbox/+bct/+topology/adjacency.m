function A = adjacency(varargin)
%ADJACENCY Compute binary adjacency matrix from faces
%
% Syntax:
%   A = bct.topology.adjacency(M)
%   A = bct.topology.adjacency(F)
%   A = bct.topology.adjacency(F, nV)
%
% Inputs:
%   M  - bct.Manifold object
%   F  - [M×3] face connectivity (1-indexed)
%   nV - Number of vertices (optional, inferred from max(F(:)) if not provided)
%
% Outputs:
%   A - [N×N] sparse logical adjacency matrix (symmetric, no self-loops)
%
% Description:
%   Computes binary vertex adjacency matrix from triangular faces. Two vertices
%   are adjacent if they share an edge. The resulting matrix is symmetric with
%   no self-loops.
%
%   This function is coordinate-free - it operates on face connectivity alone.
%
% Examples:
%   % From Manifold object
%   M = bct.Manifold(V, F);
%   A = bct.topology.adjacency(M);
%
%   % From faces directly (infer nV)
%   A = bct.topology.adjacency(F);
%
%   % From faces with explicit vertex count
%   A = bct.topology.adjacency(F, nV);
%
%   % Check connectivity
%   nNeighbors = full(sum(A, 2));  % Degree of each vertex
%
% See also: bct.topology.edges, bct.topology.halfedge

% Parse inputs
if nargin == 1
    if isa(varargin{1}, 'bct.Manifold')
        % Manifold object
        M = varargin{1};
        F = M.Faces;
        N = size(M.Vertices, 1);
    elseif isnumeric(varargin{1})
        % Face connectivity matrix (infer nV)
        F = varargin{1};
        if isempty(F)
            error('bct:topology:adjacency:EmptyFaces', ...
                'Cannot infer vertex count from empty face matrix');
        end
        N = max(F(:));
    else
        error('bct:topology:adjacency:InvalidInput', ...
            'Input must be a bct.Manifold object or face connectivity matrix');
    end
    
elseif nargin == 2
    % Face connectivity + explicit vertex count
    F = varargin{1};
    N = varargin{2};
    
    if ~isnumeric(F)
        error('bct:topology:adjacency:InvalidFaces', ...
            'First argument must be face connectivity matrix');
    end
    if ~isscalar(N) || N < 1 || N ~= floor(N)
        error('bct:topology:adjacency:InvalidVertexCount', ...
            'Second argument must be positive integer vertex count');
    end
    
else
    error('bct:topology:adjacency:InvalidNumArgs', ...
        'Expected 1 or 2 input arguments: (M), (F), or (F, nV)');
end

% Handle empty faces
if isempty(F)
    A = sparse(N, N);
    return;
end

% Validate faces
if ~isnumeric(F) || size(F, 2) ~= 3
    error('bct:topology:adjacency:InvalidFaces', ...
        'Faces must be M×3 numeric array');
end

% Extract unique edges from faces
e = unique(sort([F(:,[1 2]); F(:,[2 3]); F(:,[3 1])], 2), 'rows');

% Build symmetric adjacency matrix
A = sparse(e(:,1), e(:,2), true, N, N);
A = A + A.';                % Make symmetric
A = A - diag(diag(A));      % Remove self-loops
A = spones(A) > 0;          % Binary adjacency

end
