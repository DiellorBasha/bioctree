function isValid = validate(E)
%VALIDATE Check Eigenpairs invariants
%
% Syntax:
%   isValid = bct.eigenpairs.validate(E)
%
% Checks:
%   1. Dimension consistency
%   2. M-orthonormality (U' * M * U = I)
%   3. Eigenvalue ordering
%
% Inputs:
%   E - bct.Eigenpairs object
%
% Outputs:
%   isValid - true if all checks pass, false otherwise
%
% Notes:
%   - Throws warnings for each failed check
%   - Returns false on first failure
%
% See also: bct.Eigenpairs

arguments
    E bct.Eigenpairs
end

isValid = true;
tol = 1e-8;

% Check dimension consistency
k = length(E.Values);
[N, k_vectors] = size(E.Vectors);
if k ~= k_vectors
    warning('bct:eigenpairs:DimensionMismatch', ...
        'Number of eigenvalues (%d) != number of eigenvectors (%d)', k, k_vectors);
    isValid = false;
    return;
end

% Check M-orthonormality
I_computed = E.Vectors' * E.MassMatrix * E.Vectors;
I_expected = eye(k);
err = norm(I_computed - I_expected, 'fro');
if err > tol
    warning('bct:eigenpairs:NotOrthonormal', ...
        'M-orthonormality error: %.3e (tolerance: %.3e)', err, tol);
    isValid = false;
    return;
end

% Check eigenvalue ordering
if any(diff(E.Values) < 0)
    warning('bct:eigenpairs:NotSorted', ...
        'Eigenvalues are not in ascending order');
    isValid = false;
    return;
end

% All checks passed
if isValid
    fprintf('bct.eigenpairs.validate: All checks passed ✓\n');
end

end
