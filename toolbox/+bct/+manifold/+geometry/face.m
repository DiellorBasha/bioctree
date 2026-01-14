function out = face(meshInput, varargin)
%FACE Compute all face-based geometric properties
%
% Syntax:
%   faceGeom = bct.manifold.geometry.face(M)
%   faceGeom = bct.manifold.geometry.face(V, F)
%   faceGeom = bct.manifold.geometry.face(___, Name, Value)
%
% Inputs:
%   M    - bct.Manifold object
%   OR
%   V    - [Nv×3] vertex coordinates
%   F    - [Nf×3] face connectivity (1-indexed)
%
% Name-Value Arguments:
%   'precision'          - 'double' (default) or 'single'
%   'circumcenterMethod' - 'native' (default) or 'triangulation'
%
% Outputs:
%   out - Structure with fields:
%     .areas          - [Nf×1] Area of each triangular face
%     .circumcenters  - [Nf×3] Circumcenter of each face
%     .centroids      - [Nf×3] Centroid (barycenter) of each face
%     .cotan          - [Nf×3] Cotangent weights per face vertex
%     .normals        - [Nf×3] Face normal vectors (unit)
%     .tangent1       - [Nf×3] First tangent vectors (unit)
%     .tangent2       - [Nf×3] Second tangent vectors (unit)
%     .header         - Metadata about computation options
%
% Description:
%   Aggregator function that computes all face-based geometric properties
%   by calling the individual functions in bct.manifold.geometry.face.*
%   The normals, tangent1, and tangent2 form right-handed orthonormal frames.
%
% Examples:
%   % Compute all face geometry
%   M = bct.Manifold(V, F);
%   faceGeom = bct.manifold.geometry.face(M);
%   
%   % Access individual properties
%   areas = faceGeom.areas;
%   normals = faceGeom.normals;
%   tangent1 = faceGeom.tangent1;
%   
%   % Compute with single precision
%   faceGeom = bct.manifold.geometry.face(M, 'precision', 'single');
%
% See also: bct.manifold.geometry.vertex, bct.manifold.geometry.edge,
%           bct.manifold.geometry

% Parse inputs
p = inputParser;
p.FunctionName = 'bct.manifold.geometry.face';
p.KeepUnmatched = true;

if isa(meshInput, 'bct.Manifold')
    addRequired(p, 'M', @(x) isa(x, 'bct.Manifold'));
    parse(p, meshInput);
else
    addRequired(p, 'V', @isnumeric);
    addRequired(p, 'F', @isnumeric);
    if isempty(varargin) || ~isnumeric(varargin{1})
        error('bct:manifold:geometry:face:InvalidInput', ...
            'Expected face(M) or face(V, F)');
    end
    parse(p, meshInput, varargin{1});
    varargin = varargin(2:end);  % Remove F from varargin
end

addParameter(p, 'precision', 'double', @(x) ischar(x) || isstring(x));
addParameter(p, 'circumcenterMethod', 'native', @(x) ischar(x) || isstring(x));
parse(p, meshInput, varargin{:});

precision = string(p.Results.precision);
circumcenterMethod = string(p.Results.circumcenterMethod);

% Create surfaceMesh once to avoid redundant creation in subfunctions
if isa(meshInput, 'bct.Manifold')
    V = meshInput.Vertices;
    F = meshInput.Faces;
else
    V = meshInput;
    F = varargin{1};
end
mesh = surfaceMesh(V, F);

% Initialize output structure
out = struct();
out.header = struct(...
    'precision', precision, ...
    'circumcenterMethod', circumcenterMethod ...
);

% Compute face areas (pass surfaceMesh)
[areaHeader, out.areas] = bct.manifold.geometry.face.areas(mesh, ...
    'precision', precision);
out.header.areas = areaHeader;

% Compute face circumcenters (pass surfaceMesh)
[circumHeader, out.circumcenters] = bct.manifold.geometry.face.circumcenters(mesh, ...
    'method', circumcenterMethod, ...
    'precision', precision);
out.header.circumcenters = circumHeader;

% Compute face centroids (pass surfaceMesh)
[centroidHeader, out.centroids] = bct.manifold.geometry.face.centroids(mesh);
out.header.centroids = centroidHeader;

% Compute cotangent weights (pass surfaceMesh)
[cotanHeader, out.cotan] = bct.manifold.geometry.face.cotan(mesh);
out.header.cotan = cotanHeader;

% Compute face frame (normals and tangents together for efficiency, pass surfaceMesh)
[frameHeader, out.normals, out.tangent1, out.tangent2] = bct.manifold.geometry.face.frame(mesh);
out.header.frame = frameHeader;

end
