function sm = manifoldToSurfaceMesh(M)
% manifoldToSurfaceMesh - Convert Manifold to MATLAB surfaceMesh object
%
% Syntax:
%   sm = bct.io.convert.manifoldToSurfaceMesh(M)
%
% Inputs:
%   M - bct.manifold.Manifold object (must be of type "mesh")
%
% Outputs:
%   sm - MATLAB surfaceMesh object for visualization and analysis
%
% Example:
%   B = bct.bct.fromMesh(V, F);
%   sm = bct.io.convert.manifoldToSurfaceMesh(B.Manifold);
%   surfaceMeshShow(sm);
%
% See also: surfaceMesh, bct.manifold.Manifold

% Validate input
if ~isa(M, 'bct.manifold.Manifold')
    error('bct:InvalidInput', 'Input must be a bct.manifold.Manifold object');
end

if M.Type ~= "mesh"
    error('bct:InvalidManifoldType', 'Manifold must be of type "mesh", got "%s"', M.Type);
end

% Check for required data
if isempty(M.V) || isempty(M.F)
    error('bct:MissingData', 'Manifold must have both vertices (V) and faces (F)');
end

% Create surfaceMesh object
sm = surfaceMesh(M.V, M.F);

end
