function sm = manifoldToSurfaceMesh(M)
% manifoldToSurfaceMesh - Convert Manifold to MATLAB surfaceMesh object
%
% Syntax:
%   sm = bct.io.convert.manifoldToSurfaceMesh(M)
%
% Inputs:
%   M - bct.Manifold object
%
% Outputs:
%   sm - MATLAB surfaceMesh object for visualization and analysis
%
% Example:
%   B = bct.bct.fromMesh(V, F);
%   sm = bct.io.convert.manifoldToSurfaceMesh(B.Manifold);
%   surfaceMeshShow(sm);
%
% See also: surfaceMesh, bct.Manifold

% Validate input
if ~isa(M, 'bct.Manifold')
    error('bct:InvalidInput', 'Input must be a bct.Manifold object');
end

% Check for required data
if isempty(M.Vertices) || isempty(M.Faces)
    error('bct:MissingData', 'Manifold must have both Vertices and Faces');
end

% Create surfaceMesh object
sm = surfaceMesh(M.Vertices, M.Faces);

end
