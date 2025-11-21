function g = toMatlabGraph(M)
% toMatlabGraph - Convert Manifold to MATLAB graph object
%
% DEPRECATED: This function has been moved to bct.io.convert.manifoldToMatlabGraph
% This wrapper is provided for backward compatibility and will be removed in a future version.
%
% Syntax:
%   g = bct.manifold.toMatlabGraph(M)
%
% Please use instead:
%   g = bct.io.convert.manifoldToMatlabGraph(M)
%
% See also: bct.io.convert.manifoldToMatlabGraph

warning('bct:deprecated', ...
    'bct.manifold.toMatlabGraph is deprecated. Use bct.io.convert.manifoldToMatlabGraph instead.');

% Call new location
g = bct.io.convert.manifoldToMatlabGraph(M);

end
