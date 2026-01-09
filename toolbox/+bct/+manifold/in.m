function M = in(obj)
%IN Convert MATLAB geometry object to bct.Manifold
%
% Syntax:
%   M = bct.manifold.in(surfaceMeshObj)
%   M = bct.manifold.in(triangulationObj)
%   M = bct.manifold.in(patchObj)
%
% Supported Object Types:
%   - surfaceMesh: Uses Vertices and Faces properties
%   - triangulation: Uses Points (→ Vertices) and ConnectivityList (→ Faces)
%   - Patch (graphics object): Uses Vertices and Faces properties
%
% Inputs:
%   obj - MATLAB geometry object (surfaceMesh, triangulation, or Patch)
%
% Outputs:
%   M - bct.Manifold object
%
% Examples:
%   % From surfaceMesh
%   smesh = surfaceMesh(V, F);
%   M = bct.manifold.in(smesh);
%
%   % From triangulation
%   tri = triangulation(F, V);
%   M = bct.manifold.in(tri);
%
%   % From patch graphics object
%   p = patch('Faces', F, 'Vertices', V);
%   M = bct.manifold.in(p);
%
% See also: bct.Manifold, bct.manifold.load, surfaceMesh, triangulation

arguments
    obj
end

% Dispatch based on object type
if isa(obj, 'surfaceMesh')
    % surfaceMesh: Vertices and Faces properties
    V = obj.Vertices;
    F = obj.Faces;
    
elseif isa(obj, 'triangulation')
    % triangulation: Points → Vertices, ConnectivityList → Faces
    V = obj.Points;
    F = obj.ConnectivityList;
    
elseif isa(obj, 'matlab.graphics.primitive.Patch') || strcmp(class(obj), 'patch')
    % Patch graphics object: Vertices and Faces properties
    V = obj.Vertices;
    F = obj.Faces;
    
else
    error('bct:manifold:UnsupportedType', ...
        'Unsupported object type: %s. Expected surfaceMesh, triangulation, or Patch.', ...
        class(obj));
end

% Validate extracted data
if isempty(V) || isempty(F)
    error('bct:manifold:EmptyGeometry', ...
        'Object contains empty Vertices or Faces data.');
end

% Convert to double if necessary (Faces might be int32)
V = double(V);
F = double(F);

% Construct Manifold object
M = bct.Manifold(V, F);

end
