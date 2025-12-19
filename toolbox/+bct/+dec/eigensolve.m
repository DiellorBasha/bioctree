function E = eigensolve(DEC, formDegree, k, options)
%EIGENSOLVE Compute DEC eigenpairs for specified form degree
%
% Syntax:
%   E = bct.dec.eigensolve(DEC, formDegree, k)
%   E = bct.dec.eigensolve(DEC, formDegree, k, options)
%
% Inputs:
%   DEC        - bct.DEC object
%   formDegree - 0, 1, or 2 (form degree)
%   k          - Number of eigenpairs to compute
%   options    - Optional struct with fields:
%                * normalize - true (default) | false
%                * removeDC  - true | false (default)
%
% Returns:
%   E - bct.Eigenpairs object
%
% Notes:
%   - Delegates to bct.eigenpairs.solveGeneralized
%   - Uses appropriate Laplacian and Hodge star for form degree
%   - 0-form: vertex-based scalar eigenfunctions
%   - 1-form: edge-based vector eigenfunctions
%   - 2-form: face-based density eigenfunctions
%
% See also: bct.eigenpairs.solveGeneralized, bct.dec.laplacian0

arguments
    DEC (1,1) bct.DEC
    formDegree (1,1) {mustBeInteger, mustBeMember(formDegree, [0,1,2])}
    k (1,1) {mustBeInteger, mustBePositive}
    options.normalize (1,1) logical = true
    options.removeDC (1,1) logical = false
end

% Select Laplacian and inner product based on form degree
switch formDegree
    case 0
        L = bct.dec.laplacian0(DEC);
        M = bct.dec.star0(DEC);
        basisType = "DEC-0-form";
        operatorType = "DEC-Laplacian-0";
        
    case 1
        L = bct.dec.laplacian1(DEC);
        M = bct.dec.star1(DEC);
        basisType = "DEC-1-form";
        operatorType = "DEC-Laplacian-1";
        
    case 2
        L = bct.dec.laplacian2(DEC);
        M = bct.dec.star2(DEC);
        basisType = "DEC-2-form";
        operatorType = "DEC-Laplacian-2";
end

% Build metadata for Eigenpairs object
meta = struct();
meta.operator = operatorType;
meta.basis = basisType;
meta.formDegree = formDegree;
meta.backend = "DECLab";
meta.manifoldSize = size(DEC.Manifold.Vertices, 1);

% Delegate to bct.eigenpairs
E = bct.eigenpairs.solveGeneralized(L, M, k, meta);

% Post-processing
if options.normalize
    E = bct.eigenpairs.normalize(E, M);
end

if options.removeDC
    E = bct.eigenpairs.removeDC(E);
end

end
