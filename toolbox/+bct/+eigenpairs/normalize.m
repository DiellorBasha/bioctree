function U = normalize(U, M)
%NORMALIZE Enforce M-orthonormality of eigenvectors
%
% Syntax:
%   U_norm = bct.eigenpairs.normalize(U, M)
%
% Computes U such that U' * M * U = I
%
% Inputs:
%   U - [N×k] eigenvectors
%   M - [N×N] mass matrix
%
% Outputs:
%   U_norm - [N×k] M-orthonormal eigenvectors
%
% Notes:
%   - Normalizes each column such that u_k' * M * u_k = 1
%   - Does not orthogonalize (assumes input is already orthogonal)
%   - Use after eigensolvers to ensure strict orthonormality
%
% See also: bct.eigenpairs.validate

arguments
    U (:,:) double
    M (:,:) {mustBeSparse}
end

% Validate dimensions
N = size(M, 1);
assert(size(U, 1) == N, ...
    'bct:eigenpairs:DimensionMismatch', ...
    'U must have %d rows to match M', N);

% Normalize each eigenvector
k = size(U, 2);
for i = 1:k
    norm_i = sqrt(U(:,i)' * M * U(:,i));
    if norm_i < eps
        warning('bct:eigenpairs:ZeroNorm', ...
            'Eigenvector %d has near-zero norm. Skipping normalization.', i);
        continue;
    end
    U(:,i) = U(:,i) / norm_i;
end

end
