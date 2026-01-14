function [header, L] = graphlaplacian(input, varargin)
%GRAPHLAPLACIAN Compute graph Laplacian matrix from manifold or adjacency matrix
%
% Syntax:
%   [header, L] = bct.manifold.operator.graphlaplacian(M)
%   [header, L] = bct.manifold.operator.graphlaplacian(A)
%   [header, L] = bct.manifold.operator.graphlaplacian(..., 'Type', laplacianType)
%
% Inputs:
%   M - bct.Manifold object
%   OR
%   A - [N×N] sparse adjacency matrix (symmetric, binary or weighted)
%
% Name-Value Arguments:
%   Type - "combinatorial" (default), "normalized", or "randomwalk"
%
% Outputs:
%   header - Struct with computation metadata
%   L      - [N×N] sparse graph Laplacian matrix
%
% Laplacian types:
%   - "combinatorial": L = D - A (unnormalized)
%   - "normalized":    L = I - D^(-1/2) * A * D^(-1/2) (symmetric normalized)
%   - "randomwalk":    L = I - D^(-1) * A (random walk normalized)
%
% Description:
%   Computes the graph Laplacian operator from the manifold's adjacency
%   structure. The graph Laplacian is a discrete analog of the Laplace-
%   Beltrami operator but operates on the graph topology rather than the
%   geometric embedding.
%
%   Unlike the FEM Laplace-Beltrami operator (stiffness matrix), the
%   graph Laplacian uses only topological connectivity without geometric
%   weighting (edge lengths, angles, etc.).
%
% Examples:
%   % Using Manifold object
%   M = bct.Manifold(V, F);
%   L = bct.manifold.operator.graphlaplacian(M);
%
%   % Using adjacency matrix directly
%   A = bct.manifold.topology.adjacency(V, F);
%   L = bct.manifold.operator.graphlaplacian(A);
%
%   % Normalized Laplacian for spectral clustering
%   L = bct.manifold.operator.graphlaplacian(M, 'Type', 'normalized');
%
%   % Random walk Laplacian from adjacency
%   L = bct.manifold.operator.graphlaplacian(A, 'Type', 'randomwalk');
%
% See also: bct.manifold.operator.laplacebeltrami, bct.manifold.operator.stiffness,
%           bct.manifold.topology.adjacency

% ----------------------------
% Parse inputs
% ----------------------------
if nargin == 0
    error('bct:manifold:operator:graphlaplacian:NoInput', ...
        'At least one input required: graphlaplacian(M) or graphlaplacian(A)');
end

% Determine input type and extract adjacency matrix
if isa(input, 'bct.Manifold')
    % Case: graphlaplacian(M, Name=Value...)
    A = input.adjacency();
    nameValueStart = 1;
elseif issparse(input) && ismatrix(input)
    % Case: graphlaplacian(A, Name=Value...)
    A = input;
    nameValueStart = 1;
    
    % Validate adjacency matrix
    if size(A, 1) ~= size(A, 2)
        error('bct:manifold:operator:graphlaplacian:InvalidAdjacency', ...
            'Adjacency matrix A must be square. Got [%d×%d].', size(A, 1), size(A, 2));
    end
    if ~issparse(A)
        warning('bct:manifold:operator:graphlaplacian:DenseAdjacency', ...
            'Adjacency matrix should be sparse for efficiency. Consider using sparse(A).');
    end
else
    error('bct:manifold:operator:graphlaplacian:InvalidInput', ...
        'Input must be either graphlaplacian(M) or graphlaplacian(A). Got %s.', class(input));
end

% Parse Name-Value pairs
p = inputParser;
p.addParameter('Type', 'combinatorial', @(x) ismember(x, ["combinatorial","normalized","randomwalk"]));
p.parse(varargin{nameValueStart:end});

laplacianType = char(p.Results.Type);
N = size(A, 1);

% Compute degree vector
d = full(sum(A, 2));

% Build Laplacian based on type
switch laplacianType
    case "combinatorial"
        % L = D - A (unnormalized graph Laplacian)
        D = spdiags(d, 0, N, N);
        L = D - A;
        
    case "normalized"
        % L = I - D^{-1/2} * A * D^{-1/2} (symmetric normalized)
        d(d == 0) = eps;  % avoid division by zero
        Dinv2 = spdiags(1./sqrt(d), 0, N, N);
        L = speye(N) - Dinv2 * A * Dinv2;
        
    case "randomwalk"
        % L = I - D^{-1} * A (random walk normalized)
        d(d == 0) = eps;  % avoid division by zero
        Dinv = spdiags(1./d, 0, N, N);
        L = speye(N) - Dinv * A;
end

% Build header
header = struct( ...
    'operator', 'graphlaplacian', ...
    'type', laplacianType, ...
    'nodes', N ...
);

end
