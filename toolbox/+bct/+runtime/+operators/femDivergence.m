function div0 = femDivergence(M, U)
%FEMDIVERGENCE Compute divergence using gptoolbox wrapper
%
% Syntax:
%   div0 = bct.runtime.operators.femDivergence(M, U)
%
% Inputs:
%   M - bct.Manifold object
%   U - [#F×dim] face-based vector field
%
% Returns:
%   div0 - [#V×1] scalar field on vertices
%
% Notes:
%   - Uses gptoolbox div function
%   - Divergence matrix D is computed on demand
%   - Matrix D has size [#V × #F*dim]
%
% See also: div (gptoolbox), bct.runtime.operators.femGradient

arguments
    M (1,1) bct.Manifold
    U (:,:) double
end

% Check for gptoolbox
if exist("div", "file") ~= 2
    error("bct:MissingDependency", ...
        ['gptoolbox not found on MATLAB path (div function missing). ' ...
         'Add external/gptoolbox to your path.']);
end

% Compute divergence matrix
D = div(M.Vertices, M.Faces);

% Ensure vector field is stacked [#F*dim × 1]
u = U(:);

% Apply divergence operator
div0 = D * u;  % [#V × 1]

end
