function sm = toSurfaceMesh(M)
% toSurfaceMesh - Convert Manifold to MATLAB surfaceMesh object
%
% DEPRECATED: This function has been moved to bct.io.convert.manifoldToSurfaceMesh
% This wrapper is provided for backward compatibility and will be removed in a future version.
%
% Syntax:
%   sm = bct.manifold.toSurfaceMesh(M)
%
% Please use instead:
%   sm = bct.io.convert.manifoldToSurfaceMesh(M)
%
% See also: bct.io.convert.manifoldToSurfaceMesh

warning('bct:deprecated', ...
    'bct.manifold.toSurfaceMesh is deprecated. Use bct.io.convert.manifoldToSurfaceMesh instead.');

% Call new location
sm = bct.io.convert.manifoldToSurfaceMesh(M);

end
