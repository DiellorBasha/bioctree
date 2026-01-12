function [U, lambda] = solve(K, M, numModes, options)
%SOLVE Solve generalized eigenproblem K*u = λ*M*u
%
% Syntax:
%   [U, lambda] = bct.manifold.eigen.solve(K, M, k)
%   [U, lambda] = bct.manifold.eigen.solve(K, M, k, 'EigsOpts', opts)
%
% Inputs:
%   K        - [N×N] sparse stiffness/operator matrix
%   M        - [N×N] sparse mass matrix
%   numModes - Number of eigenmodes to compute
%
% Optional Parameters:
%   EigsOpts - Additional options passed to eigs (struct)
%
% Outputs:
%   U      - [N×k] eigenvectors
%   lambda - [k×1] eigenvalues (sorted ascending)
%
% Notes:
%   - Uses smallest-magnitude eigenvalues ('SM')
%   - Enforces real and symmetric operator assumptions
%   - Warns on partial convergence but continues
%   - Returns eigenvalues in ascending order
%   - Identical implementation to bct.eigenpairs.solveGeneralized
%
% See also: eigs, bct.manifold.eigen.normalize

arguments
    K        (:,:) {mustBeSparse}
    M        (:,:) {mustBeSparse}
    numModes (1,1) {mustBeInteger, mustBePositive}
    options.EigsOpts struct = struct()
end

% Validate dimensions
N = size(M, 1);
assert(size(K,1) == N && size(K,2) == N, ...
    'bct:manifold:eigen:DimensionMismatch', ...
    'K and M must be square and same size.');

% Enforce FEM invariants on eigs options
eigsOpts = options.EigsOpts;
eigsOpts.isreal = true;  % FEM operators are real
%eigsOpts.issym  = true;  % Symmetric

% Solve generalized eigenproblem: K*u = λ*M*u
% Use 'SM' (smallest magnitude) for spectral problems
try
    [U, D, flag] = eigs(K, M, numModes, 'SM', eigsOpts);
catch ME
    error('bct:manifold:eigen:EigsFailed', ...
        'Eigendecomposition failed: %s', ME.message);
end

if flag ~= 0
    warning('bct:manifold:eigen:PartialConvergence', ...
        'eigs did not fully converge (flag = %d). Low modes may still be valid.', flag);
end

% Extract eigenvalues (real part for numerical safety)
lambda = real(diag(D));

% Sort in ascending order
[lambda, idx] = sort(lambda, 'ascend');
U = U(:, idx);

end
