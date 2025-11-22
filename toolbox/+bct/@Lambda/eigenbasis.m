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
%   'sigma'    - Eigenvalue shift for eigs (default: 1e-6)
%   'tol'      - Convergence tolerance (default: 1e-10)
%   'maxit'    - Maximum iterations (default: 5000)
%   'mode'     - Eigenvalue selection: 'smallestabs' (default) or 'sm'
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
% See also: bct.Manifold.meshFourier, bct.Lambda.initializeTransform

% Parse inputs
p = inputParser;
addRequired(p, 'MassMatrix', @(x) issparse(x) && ismatrix(x));
addRequired(p, 'CotangentMatrix', @(x) issparse(x) && ismatrix(x));

N = size(MassMatrix, 1);
defaultNumModes = min(600, N - 1);

addOptional(p, 'numModes', defaultNumModes, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'sigma', 1e-6, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'tol', 1e-10, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'maxit', 5000, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'mode', 'smallestabs', @(x) ischar(x) || isstring(x));

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
try
    [U, D] = eigs(K, M, numModes, p.Results.sigma, opts);
    lam = real(diag(D));
catch ME
    error('eigenbasis:EigsFailed', ...
        'Failed to compute eigendecomposition: %s', ME.message);
end

% Sort by eigenvalue (eigs with 'smallestabs' may not return sorted)
if strcmp(p.Results.mode, 'smallestabs')
    [lam, idx] = sort(lam, 'ascend');
    U = U(:, idx);
    D = D(idx, idx);
end

% Remove DC component (constant mode) and negative eigenvalues
% DC mode is nearly constant across the mesh (λ ≈ 0)
% Negative eigenvalues can occur due to numerical issues
tol_dc = 1e-8;
mask = lam > tol_dc;

if sum(mask) == 0
    warning('eigenbasis:NoValidModes', ...
        'All eigenvalues below threshold. Using all modes.');
    mask = true(size(lam));
end

% Filter eigenvectors and eigenvalues
U = U(:, mask);
lam = lam(mask);
D = D(mask, mask);

% Update Lambda properties
obj.U = U;
obj.lambda = lam;
obj.K = size(U, 2);  % Actual number of modes after filtering

% Display summary
fprintf('Lambda.eigenbasis: Computed %d modes (requested %d)\n', obj.K, numModes);
fprintf('  Eigenvalue range: [%.6f, %.6f]\n', min(lam), max(lam));
fprintf('  Removed %d modes (DC and negative eigenvalues)\n', numModes - obj.K);

end
