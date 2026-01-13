function U = femGradient(M, f0)
%FEMGRADIENT Compute gradient using gptoolbox wrapper
%
% Syntax:
%   U = bct.runtime.operators.femGradient(M, f0)
%
% Inputs:
%   M  - bct.Manifold object
%   f0 - [#V×1] scalar field on vertices
%
% Returns:
%   U - [#F×dim] face-based vector field
%
% Notes:
%   - Uses gptoolbox grad function
%   - Gradient matrix G is computed on demand
%   - Matrix G has size [#F*dim × #V]
%
% See also: grad (gptoolbox), bct.runtime.operators.femDivergence

arguments
    M (1,1) bct.Manifold
    f0 (:,1) double
end

% Check for gptoolbox
if exist("grad", "file") ~= 2
    error("bct:MissingDependency", ...
        ['gptoolbox not found on MATLAB path (grad function missing). ' ...
         'Add external/gptoolbox to your path.']);
end

% Compute gradient matrix
G = grad(M.Vertices, M.Faces);

% Apply gradient operator
g = G * f0;  % [#F*dim × 1]

% Reshape to face vector field
nF = size(M.Faces, 1);
dim = numel(g) / nF;
U = reshape(g, [nF, dim]);

end
