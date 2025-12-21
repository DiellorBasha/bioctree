function U = normalize(U, M)
%NORMALIZE Enforce strict M-orthonormality of eigenvectors
%
% Syntax:
%   U = bct.eigenpairs.normalize(U, M)
%
% Computes U such that U' * M * U = I (within numerical tolerance).
%
% Inputs:
%   U - [N×k] eigenvectors (columns)
%   M - [N×N] mass matrix (sparse, symmetric positive definite or diagonal SPD)
%
% Outputs:
%   U - [N×k] M-orthonormal eigenvectors
%
% Notes:
%   - This routine enforces BOTH normalization and orthogonalization in the
%     M-inner-product by whitening with G = U'*(M*U).
%   - More robust than per-column scaling, especially when eigenvalues are
%     clustered or eigs returns partially converged vectors.
%
% See also: bct.eigenpairs.validate

arguments
    U (:,:) double
    M (:,:) {mustBeSparse}
end

% Validate dimensions
N = size(M, 1);
assert(size(M,2) == N, ...
    'bct:eigenpairs:DimensionMismatch', ...
    'M must be square.');

assert(size(U, 1) == N, ...
    'bct:eigenpairs:DimensionMismatch', ...
    'U must have %d rows to match M', N);

k = size(U,2);
if k == 0
    return;
end

% Compute Gram matrix in M-inner-product: G = U' M U
MU = M * U;                 % [N×k]
G  = U' * MU;               % [k×k]
G  = (G + G')/2;            % numerical symmetry guard

% Whitening: U <- U * G^{-1/2}
% Prefer Cholesky (fast) when G is SPD.
[R, p] = chol(G);

if p == 0
    % U' M U = I after U = U / R
    U = U / R;
else
    % Fallback: eigen-based inverse sqrt (more robust if G is near-singular)
    [Q,S] = eig(G);
    s = real(diag(S));

    % Clamp to avoid division by 0 / negative due to numerical noise
    smax = max(s);
    if smax <= 0
        warning('bct:eigenpairs:InvalidGram', ...
            'Gram matrix U''*M*U is not positive. Returning input U unchanged.');
        return;
    end

    tol = 1e-12 * smax;
    s(s < tol) = tol;

    invSqrtG = Q * diag(1 ./ sqrt(s)) * Q';
    U = U * invSqrtG;
end

% Optional sanity check (cheap; k is small)
Ierr = norm(U' * (M * U) - eye(k), 'fro');
if Ierr > 1e-8 * max(1,k)
    warning('bct:eigenpairs:OrthonormalityDrift', ...
        'Post-normalization U''*M*U deviates from I (fro err = %.3e).', Ierr);
end

end
