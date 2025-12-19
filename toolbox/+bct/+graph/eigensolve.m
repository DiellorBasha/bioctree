function E = eigensolve(G, k)
%BCT.GRAPH.EIGENSOLVE Compute graph Laplacian eigenpairs
%
% Syntax:
%   E = bct.graph.eigensolve(G, k)
%
% Inputs:
%   G - bct.Graph object
%   k - Number of eigenpairs to compute
%
% Outputs:
%   E - bct.Eigenpairs object
%
% Description:
%   Computes the first k eigenpairs of the graph Laplacian using
%   MATLAB's eigs() for the generalized eigenvalue problem:
%   
%     L * u = λ * M * u
%   
%   where L is the graph Laplacian and M is the mass/degree matrix.
%
% See also: bct.Graph, bct.Eigenpairs, bct.eigenpairs.fromGraph

arguments
    G (1,1) bct.Graph
    k (1,1) {mustBePositive, mustBeInteger}
end

% Get Laplacian and degree matrix
L = G.Laplacian;
D = G.Degree;

% Ensure k is not larger than problem size
N = G.NumNodes;
k = min(k, N-1);

% Use identity as mass matrix for combinatorial Laplacian
% For normalized Laplacian, use D as mass matrix
switch G.LaplacianType
    case "combinatorial"
        M = speye(N);
    case {"normalized", "randomwalk"}
        M = D;
    otherwise
        M = speye(N);
end

% Solve generalized eigenvalue problem: L*u = λ*M*u
% Use 'smallestabs' to get smallest eigenvalues
try
    [evecs, evals] = eigs(L, M, k, 'smallestabs');
    evals = diag(evals);
catch ME
    warning('bct:graph:EigensolveWarning', ...
        'eigs failed with error: %s. Falling back to eig.', ME.message);
    
    % Fallback to full eigenvalue decomposition
    [evecs, evals] = eig(full(L), full(M));
    [evals, idx] = sort(diag(evals), 'ascend');
    evecs = evecs(:, idx);
    
    % Truncate to k modes
    evals = evals(1:k);
    evecs = evecs(:, 1:k);
end

% Sort by eigenvalue (should already be sorted, but ensure)
[evals, idx] = sort(evals, 'ascend');
evecs = evecs(:, idx);

% Ensure real (graph Laplacian is symmetric, eigenvalues should be real)
if ~isreal(evals)
    warning('bct:graph:ComplexEigenvalues', ...
        'Complex eigenvalues detected. Taking real part.');
    evals = real(evals);
end

if ~isreal(evecs)
    warning('bct:graph:ComplexEigenvectors', ...
        'Complex eigenvectors detected. Taking real part.');
    evecs = real(evecs);
end

% Create Eigenpairs object
E = bct.Eigenpairs( ...
    evals, ...
    evecs, ...
    M, ...
    'operator', "Graph Laplacian", ...
    'basis', string(G.LaplacianType), ...
    'manifoldID', G.Manifold.ID ...
);

end
