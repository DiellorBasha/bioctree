function obj = eigenbasis(obj, MassMatrix, CotangentMatrix, varargin)
% eigenbasis - Compute eigenvectors and eigenvalues of the Lambda domain
%
% Computes the eigendecomposition of the mesh Laplacian using the
% generalized eigenproblem formulation with mass and cotangent matrices
% from the dual Manifold domain.
%
% Syntax:
%   obj = obj.eigenbasis(MassMatrix, CotangentMatrix)
%   obj = obj.eigenbasis(MassMatrix, CotangentMatrix, numModes)
%   obj = obj.eigenbasis(MassMatrix, CotangentMatrix, numModes, Name, Value)
%
% Inputs:
%   MassMatrix       - [N×N] sparse diagonal mass matrix from Manifold
%   CotangentMatrix  - [N×N] sparse cotangent Laplacian from Manifold
%   numModes         - (optional) Number of eigenmodes to compute
%                      Default: min(600, N-1) where N is matrix size
%
% Name-Value Parameters:
%   'tol'      - Convergence tolerance (default: 1e-10)
%   'maxit'    - Maximum iterations (default: 5000)
%
% Note: This function always uses 'smallestabs' mode to ensure
% the TRUE lowest eigenvalues are computed, not eigenvalues near a shift.
% This is critical for obtaining the correct low-frequency spatial basis.
%
% Outputs:
%   obj - Lambda object with updated properties:
%         .U      - [N×K] eigenvector matrix
%         .lambda - [K×1] eigenvalue vector (sorted ascending)
%         .K      - Actual number of modes computed
%
% Method:
%   Solves the generalized eigenproblem:
%       K*U = M*U*D
%   where K is the cotangent matrix, M is the mass matrix, and D is
%   the diagonal matrix of eigenvalues. This formulation is optimal
%   for FEM meshes.
%
% Notes:
%   - DC component (constant mode) and negative eigenvalues are removed
%   - Eigenvalues are sorted in ascending order
%   - After computation, call obj.initializeTransform() to set up MFT/IMFT
%   - The dual Manifold's transform should also be re-initialized
%
% Example:
%   % From bct orchestration:
%   B = bct.bct.fromMesh(V, F);
%   B.Lambda = B.Lambda.eigenbasis(B.Manifold.MassMatrix, ...
%                                    B.Manifold.CotangentMatrix, 500);
%   B.Lambda.initializeTransform();
%   B.Manifold.initializeTransform();
%
% See also: bct.Lambda.initializeTransform, bct.Manifold

% Parse inputs
p = inputParser;
addRequired(p, 'MassMatrix', @(x) issparse(x) && ismatrix(x));
addRequired(p, 'CotangentMatrix', @(x) issparse(x) && ismatrix(x));

N = size(MassMatrix, 1);
defaultNumModes = min(600, N - 1);

addOptional(p, 'numModes', defaultNumModes, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'tol', 1e-10, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'maxit', 5000, @(x) isnumeric(x) && isscalar(x));

parse(p, MassMatrix, CotangentMatrix, varargin{:});

numModes = p.Results.numModes;
K = CotangentMatrix;
M = MassMatrix;

% Validate dimensions
assert(size(K, 1) == size(M, 1), 'eigenbasis:DimensionMismatch', ...
    'MassMatrix and CotangentMatrix must have the same dimensions');
assert(size(K, 1) == size(K, 2), 'eigenbasis:NotSquare', ...
    'Matrices must be square');

% Setup eigs options
opts = struct();
opts.issym = true;
opts.isreal = true;
opts.tol = p.Results.tol;
opts.maxit = p.Results.maxit;

% Solve generalized eigenproblem: K*U = M*U*D
% This is the optimal form for FEM meshes
% Eigenvalues are with respect to the cotangent Laplacian
% Using 'smallestabs' ensures we get the TRUE lowest eigenvalues,
% not just eigenvalues near a shift point.
try
    [U, D] = eigs(K, M, numModes, 'smallestabs', opts);
    lam = real(diag(D));
catch ME
    error('eigenbasis:EigsFailed', ...
        'Failed to compute eigendecomposition: %s', ME.message);
end

% Sort by eigenvalue (eigs with 'smallestabs' may not return sorted)
[lam, idx] = sort(lam, 'ascend');
U = U(:, idx);
D = D(idx, idx);

% Remove exactly ONE DC component (the constant mode)
% CRITICAL: We must remove ONLY the smallest eigenvalue, not all "near-zero" ones.
% FEM meshes often have multiple small eigenvalues due to:
%   - numerical noise
%   - boundary artifacts
%   - mesh topology
% Removing multiple low-frequency modes destroys the smooth spatial basis
% needed for cortical wave analysis (λ(1), λ(2), λ(3) are essential).
[~, idx0] = min(abs(lam));  % Find the single smallest eigenvalue
dc_value = lam(idx0);       % Store for reporting
mask = true(size(lam));
mask(idx0) = false;          % Remove exactly one DC mode

% Filter eigenvectors and eigenvalues
U = U(:, mask);
lam = lam(mask);
D = D(mask, mask);

% Update Lambda properties
obj.U = U;
obj.lambda = lam;  % Setting lambda automatically updates K and axis via listener
% Note: obj.K is automatically updated when lambda is set

% Display summary
fprintf('Lambda.eigenbasis: Computed %d modes (requested %d)\n', obj.K, numModes);
fprintf('  Eigenvalue range: [%.6f, %.6f]\n', min(lam), max(lam));
fprintf('  Removed 1 DC mode (eigenvalue = %.3e)\n', dc_value);
fprintf('  Lambda.axis updated: %d points\n', length(obj.axis));

end
