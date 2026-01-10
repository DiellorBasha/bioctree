function U = femGradient(femRep, f0)
%FEMGRADIENT Compute gradient using FEM (gptoolbox wrapper)
%
% Syntax:
%   U = bct.runtime.operators.femGradient(femRep, f0)
%
% Inputs:
%   femRep - FEM representation struct from Manifold.FEM()
%   f0     - [#V×1] scalar field on vertices
%
% Returns:
%   U - [#F×dim] face-based vector field
%
% Notes:
%   - Uses gptoolbox grad function
%   - Gradient matrix G is computed once and cached in femRep
%   - Matrix G has size [#F*dim × #V]
%
% See also: grad (gptoolbox), bct.runtime.operators.femDivergence

arguments
    femRep (1,1) struct
    f0 (:,1) double
end

% Check for gptoolbox
if exist("grad", "file") ~= 2
    error("bct:MissingDependency", ...
        ['gptoolbox not found on MATLAB path (grad function missing). ' ...
         'Add external/gptoolbox to your path.']);
end

% Lazy-compute gradient matrix if not cached
if isempty(femRep.G)
    femRep.G = grad(femRep.V, femRep.F);
end

% Apply gradient operator
g = femRep.G * f0;  % [#F*dim × 1]

% Reshape to face vector field
nF = size(femRep.F, 1);
dim = numel(g) / nF;
U = reshape(g, [nF, dim]);

end
