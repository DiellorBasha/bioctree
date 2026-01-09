function div0 = femDivergence(femRep, U)
%FEMDIVERGENCE Compute divergence using FEM (gptoolbox wrapper)
%
% Syntax:
%   div0 = bct.runtime.operators.femDivergence(femRep, U)
%
% Inputs:
%   femRep - FEM representation struct from Manifold.FEM()
%   U      - [#F×dim] face-based vector field
%
% Returns:
%   div0 - [#V×1] scalar field on vertices
%
% Notes:
%   - Uses gptoolbox div function
%   - Divergence matrix D is computed once and cached in femRep
%   - Matrix D has size [#V × #F*dim]
%
% See also: div (gptoolbox), bct.runtime.operators.femGradient

arguments
    femRep (1,1) struct
    U (:,:) double
end

% Check for gptoolbox
if exist("div", "file") ~= 2
    error("bct:MissingDependency", ...
        ['gptoolbox not found on MATLAB path (div function missing). ' ...
         'Add external/gptoolbox to your path.']);
end

% Lazy-compute divergence matrix if not cached
if isempty(femRep.D)
    femRep.D = div(femRep.V, femRep.F);
end

% Ensure vector field is stacked [#F*dim × 1]
u = U(:);

% Apply divergence operator
div0 = femRep.D * u;  % [#V × 1]

end
