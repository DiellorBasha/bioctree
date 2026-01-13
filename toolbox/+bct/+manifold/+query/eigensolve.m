function E = eigensolve(M, k, laplacianType)
%BCT.MANIFOLD.QUERY.EIGENSOLVE Compute graph Laplacian eigenpairs (lazy evaluation)
%
% Syntax:
%   E = bct.manifold.query.eigensolve(M, k)
%   E = bct.manifold.query.eigensolve(M, k, laplacianType)
%
% Inputs:
%   M             - bct.Manifold object
%   k             - Number of eigenpairs to compute
%   laplacianType - "combinatorial" (default) | "normalized" | "randomwalk"
%
% Outputs:
%   E - bct.Eigenpairs object (eigensolve deferred until Values/Vectors accessed)
%
% Description:
%   Creates a lazy Eigenpairs object for the graph Laplacian:
%   
%     L * u = λ * M * u
%   
%   where L is the graph Laplacian and M is the mass/degree matrix.
%   Computation is deferred until Values or Vectors are first accessed.
%
% See also: bct.Manifold, bct.Eigenpairs, bct.manifold.operator.graphlaplacian

arguments
    M (1,1) bct.Manifold
    k (1,1) {mustBePositive, mustBeInteger}
    laplacianType (1,1) string {mustBeMember(laplacianType, ...
        ["combinatorial","normalized","randomwalk"])} = "combinatorial"
end

% Get Laplacian and degree matrix
L = bct.manifold.operator.graphlaplacian(M, 'Type', laplacianType);
A = M.adjacency();
d = sum(A, 2);
N = size(A, 1);
D = spdiags(d, 0, N, N);

% Ensure k is not larger than problem size
k = min(k, N-1);

% Use identity as mass matrix for combinatorial Laplacian
% For normalized Laplacian, use D as mass matrix
switch laplacianType
    case "combinatorial"
        Mass = speye(N);
    case {"normalized", "randomwalk"}
        Mass = D;
    otherwise
        Mass = speye(N);
end

% Create lazy Eigenpairs object (no computation yet)
% Graph eigenpairs use 'smallestabs' strategy via EigsOpts
eigsOpts = struct();
eigsOpts.sigma = 'smallestabs';

E = bct.Eigenpairs( ...
    'K', L, ...
    'M', Mass, ...
    'numModes', k, ...
    'operator', "Graph Laplacian", ...
    'basis', string(laplacianType), ...
    'manifoldID', M.ID, ...
    'RemoveDC', false, ...
    'EigsOpts', eigsOpts ...
);

end
