function E = fromFEM(FEM, numModes, options)
%FROMFEM Create Eigenpairs from FEM representation (lazy evaluation)
%
% Syntax:
%   E = bct.eigenpairs.fromFEM(FEM, k)
%   E = bct.eigenpairs.fromFEM(FEM, k, 'RemoveDC', true)
%
% Constructs a lazy Eigenpairs object that defers eigensolve until needed.
% Eigendecomposition of Laplace-Beltrami operator via FEM:
%   Stiffness * U = Mass * U * Λ
%
% Inputs:
%   FEM      - bct.FEM object
%   numModes - Number of eigenmodes to compute
%
% Optional Parameters:
%   RemoveDC  - Remove DC (constant) mode (default: true)
%   EigsOpts  - Additional options passed to eigs (struct)
%
% Outputs:
%   E - bct.Eigenpairs object (eigensolve deferred until Values/Vectors accessed)
%
% Notes:
%   - Uses smallest-magnitude eigenvalues ('SM')
%   - Enforces M-orthonormality via bct.eigenpairs.normalize
%   - DC mode (if present) is removed by default
%   - Eigenvalues sorted in ascending order
%   - Computation is LAZY: only runs when Values or Vectors are accessed
%
% Example:
%   M = bct.Manifold(struct('V', V, 'F', F));
%   fem = M.FEM();
%   E = bct.eigenpairs.fromFEM(fem, 100);  % Instantaneous (no eigensolve yet)
%   vals = E.Values;                       % Now eigensolve runs
%
% See also: bct.eigenpairs.solveGeneralized, bct.eigenpairs.normalize

arguments
    FEM        bct.FEM
    numModes   (1,1) {mustBeInteger, mustBePositive}
    options.RemoveDC  (1,1) logical = true
    options.EigsOpts  struct = struct()
end

% Extract variational forms from FEM
K = FEM.Stiffness;
M = FEM.Mass;
manifoldID = FEM.Manifold.ID;

% Construct lazy Eigenpairs object (no computation yet)
E = bct.Eigenpairs(...
    'K', K, ...
    'M', M, ...
    'numModes', numModes, ...
    'operator', "Laplace-Beltrami", ...
    'basis', "P1-FEM", ...
    'manifoldID', manifoldID, ...
    'RemoveDC', options.RemoveDC, ...
    'EigsOpts', options.EigsOpts);
end
