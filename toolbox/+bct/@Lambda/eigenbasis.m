function obj = eigenbasis(obj, MassMatrix, CotangentMatrix, numModes, opts)
% eigenbasis - FEM-invariant Laplace–Beltrami eigenbasis
%
% Computes the low-frequency eigenbasis of a FEM cotangent Laplacian
% using the generalized eigenproblem:
%
%     K * U = M * U * D
%
% This implementation enforces FEM correctness invariants while allowing
% solver options (opts) to be provided by a higher-level policy.
%
% Inputs:
%   MassMatrix       - [N×N] sparse FEM mass matrix
%   CotangentMatrix  - [N×N] sparse cotangent Laplacian
%   numModes         - Number of eigenmodes to compute (before DC removal)
%   opts             - (optional) eigs options struct (policy-level)
%
% Outputs:
%   obj.U      - [N×(K-1)] eigenvectors (DC removed)
%   obj.lambda - [(K-1)×1] eigenvalues (ascending, DC removed)
%
% Notes:
%   - Exactly ONE DC mode is always removed
%   - Eigenpairs are sorted explicitly
%   - Uses smallest-magnitude eigenvalues (correct for FEM)
%   - FEM invariants are enforced regardless of opts
%
% See also: eigs

% -------------------------
% Input validation
% -------------------------
arguments
    obj
    MassMatrix       (:,:) {mustBeSparse}
    CotangentMatrix (:,:) {mustBeSparse}
    numModes (1,1)   {mustBeInteger, mustBePositive}
    opts struct      = struct()
end

N = size(MassMatrix,1);

assert(size(CotangentMatrix,1) == N && size(CotangentMatrix,2) == N, ...
    'eigenbasis:DimensionMismatch', ...
    'MassMatrix and CotangentMatrix must be square and same size.');

% -------------------------
% Enforce FEM invariants on opts
% -------------------------
% These are NOT policy choices and must never be overridden.
opts.isreal = true;

% issym is ignored in matrix mode, but we set it for documentation
% and future operator-mode compatibility.
opts.issym  = true;

% -------------------------
% Solve generalized eigenproblem
% -------------------------
% IMPORTANT:
% Use 'SM' (smallest magnitude), NOT 'smallestabs'
% for generalized FEM problems.
try
    [U, D, flag] = eigs(CotangentMatrix, MassMatrix, numModes, 'SM', opts);
catch ME
    error('eigenbasis:EigsFailed', ...
        'FEM eigendecomposition failed: %s', ME.message);
end

if flag ~= 0
    warning('eigenbasis:PartialConvergence', ...
        'eigs did not fully converge (flag = %d). Low modes may still be valid.', flag);
end

lam = real(diag(D));

% -------------------------
% Explicit sorting
% -------------------------
[lam, idx] = sort(lam, 'ascend');
U = U(:, idx);

% -------------------------
% Remove exactly ONE DC mode
% -------------------------
[~, idx0] = min(abs(lam));   % DC eigenvalue
dc_value  = lam(idx0);

mask = true(size(lam));
mask(idx0) = false;

U   = U(:, mask);
lam = lam(mask);

% -------------------------
% Update object state
% -------------------------
obj.U      = U;
obj.lambda = lam;   % triggers dependent properties / listeners

% -------------------------
% Reporting
% -------------------------
fprintf('Lambda.eigenbasis (FEM):\n');
fprintf('  Requested modes      : %d\n', numModes);
fprintf('  Retained modes       : %d\n', obj.K);
fprintf('  Removed DC eigenvalue: %.3e\n', dc_value);
fprintf('  Eigenvalue range     : [%.6f, %.6f]\n', min(lam), max(lam));

end
