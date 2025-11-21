function G = toGspGraph(M)
% toGspGraph - Convert Manifold to GSPBox graph structure
%
% DEPRECATED: This function has been moved to bct.io.convert.manifoldToGspGraph
% This wrapper is provided for backward compatibility and will be removed in a future version.
%
% Syntax:
%   G = bct.manifold.toGspGraph(M)
%
% Please use instead:
%   G = bct.io.convert.manifoldToGspGraph(M)
%
% See also: bct.io.convert.manifoldToGspGraph

warning('bct:deprecated', ...
    'bct.manifold.toGspGraph is deprecated. Use bct.io.convert.manifoldToGspGraph instead.');

% Call new location
G = bct.io.convert.manifoldToGspGraph(M);

end
