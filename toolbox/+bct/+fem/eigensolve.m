function E = eigensolve(FEM, k)
%EIGENSOLVE Compute eigenpairs of FEM Laplace-Beltrami operator
%
% Syntax:
%   E = bct.fem.eigensolve(FEM, k)
%
% Inputs:
%   FEM - bct.FEM object
%   k   - Number of eigenpairs to compute
%
% Outputs:
%   E - bct.Eigenpairs object
%
% Notes:
%   - Thin wrapper that adapts FEM semantics to bct.eigenpairs
%   - Delegates all spectral logic to bct.eigenpairs.fromFEM
%   - No duplication of solver logic
%   - Sets proper metadata (operator, basis, manifoldID)
%
% See also: bct.eigenpairs.fromFEM, bct.FEM.eigenpairs

arguments
    FEM (1,1) bct.FEM
    k   (1,1) {mustBeInteger, mustBePositive}
end

% Delegate to eigenpairs factory with proper FEM semantics
E = bct.eigenpairs.fromFEM(FEM, k, 'RemoveDC', true);

end
