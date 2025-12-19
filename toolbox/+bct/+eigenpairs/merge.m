function E_merged = merge(E1, E2)
%MERGE Combine two Eigenpairs objects
%
% Syntax:
%   E_merged = bct.eigenpairs.merge(E1, E2)
%
% Combines eigenpairs from two objects, removing duplicates and sorting
%
% Inputs:
%   E1 - First bct.Eigenpairs object
%   E2 - Second bct.Eigenpairs object
%
% Outputs:
%   E_merged - New bct.Eigenpairs with combined modes
%
% Notes:
%   - Requires same manifold ID
%   - Removes duplicate eigenvalues (within tolerance)
%   - Re-sorts by ascending eigenvalue
%   - Validates orthonormality of result
%
% See also: bct.eigenpairs.validate

arguments
    E1 bct.Eigenpairs
    E2 bct.Eigenpairs
end

% Validate compatibility
assert(E1.ManifoldID == E2.ManifoldID, ...
    'bct:eigenpairs:IncompatibleManifolds', ...
    'Cannot merge eigenpairs from different manifolds');

assert(isequal(E1.MassMatrix, E2.MassMatrix), ...
    'bct:eigenpairs:IncompatibleMass', ...
    'Mass matrices must match');

% Combine eigenvalues and vectors
lambda = [E1.Values; E2.Values];
U = [E1.Vectors, E2.Vectors];

% Sort by eigenvalue
[lambda, idx] = sort(lambda, 'ascend');
U = U(:, idx);

% Remove duplicates (eigenvalues within tolerance)
tol = 1e-10;
[~, unique_idx] = uniquetol(lambda, tol);
lambda = lambda(unique_idx);
U = U(:, unique_idx);

% Construct merged object
E_merged = bct.Eigenpairs(lambda, U, E1.MassMatrix, ...
    'operator', E1.Operator, ...
    'basis', E1.Basis, ...
    'manifoldID', E1.ManifoldID);

fprintf('bct.eigenpairs.merge: %d + %d → %d modes\n', ...
    E1.numModes(), E2.numModes(), E_merged.numModes());

end
