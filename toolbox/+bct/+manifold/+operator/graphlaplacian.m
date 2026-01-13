function L = graphlaplacian(M, options)
%GRAPHLAPLACIAN Compute graph Laplacian matrix from manifold topology
%
% Syntax:
%   L = bct.manifold.operator.graphlaplacian(M)
%   L = bct.manifold.operator.graphlaplacian(M, 'Type', laplacianType)
%
% Inputs:
%   M - bct.Manifold object
%
% Name-Value Arguments:
%   Type - "combinatorial" (default), "normalized", or "randomwalk"
%
% Returns:
%   L - [N×N] sparse graph Laplacian matrix
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
%   % Combinatorial Laplacian
%   M = bct.Manifold(V, F);
%   L = bct.manifold.operator.graphlaplacian(M);
%
%   % Normalized Laplacian for spectral clustering
%   L = bct.manifold.operator.graphlaplacian(M, 'Type', 'normalized');
%
%   % Random walk Laplacian
%   L = bct.manifold.operator.graphlaplacian(M, 'Type', 'randomwalk');
%
% See also: bct.manifold.operator.laplacebeltrami, bct.manifold.operator.stiffness,
%           bct.manifold.topology.adjacency

arguments
    M (1,1) bct.Manifold
    options.Type (1,1) string {mustBeMember(options.Type, ...
        ["combinatorial","normalized","randomwalk"])} = "combinatorial"
end

% Get adjacency matrix from manifold topology
A = M.adjacency();
N = size(A, 1);

% Compute degree vector
d = full(sum(A, 2));

% Build Laplacian based on type
switch options.Type
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

end
