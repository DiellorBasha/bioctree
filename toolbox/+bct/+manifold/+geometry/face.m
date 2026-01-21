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
%   out - Structure matching bct.manifold.geometry.face.schema:
%     .attributes     - Group-level metadata (computation options)
%     .areas          - [Nf×1] Area of each triangular face
%     .circumcenters  - [Nf×3] Circumcenter of each face
%     .centroids      - [Nf×3] Centroid (barycenter) of each face
%     .cotan          - [Nf×3] Cotangent weights per face vertex
%     .normals        - [Nf×3] Face normal vectors (unit)
%     .tangent1       - [Nf×3] First tangent vectors (unit)
%     .tangent2       - [Nf×3] Second tangent vectors (unit)
%
% Description:
%   Aggregator function that computes all face-based geometric properties.
%   Output structure conforms to bct.manifold.geometry.face.schema for
%   seamless serialization to HDF5/Zarr formats.
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

% Compute all face properties
[areaHeader, areas] = bct.manifold.geometry.face.areas(mesh, 'precision', precision);
[circumHeader, circumcenters] = bct.manifold.geometry.face.circumcenters(mesh, ...
    'method', circumcenterMethod, 'precision', precision);
[centroidHeader, centroids] = bct.manifold.geometry.face.centroids(mesh);
[cotanHeader, cotan] = bct.manifold.geometry.face.cotan(mesh);
[frameHeader, normals, tangent1, tangent2] = bct.manifold.geometry.face.frame(mesh);

% Initialize output structure matching schema
out = struct();

% Group-level attributes (matches s.group.attributes in schema)
out.attributes = struct();
out.attributes.schema = 'bct.manifold.geometry.face@1.0.0';
out.attributes.package = 'bct.manifold.geometry.face';
out.attributes.frame_handedness = 'right-handed';
out.attributes.frame_convention = 'tangent2 = normal × tangent1';
out.attributes.precision = char(precision);
out.attributes.circumcenterMethod = char(circumcenterMethod);
out.attributes.computed_utc = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));

% Dataset fields (matches s.datasets in schema, order preserved)
out.areas = areas;                  % Dataset 1
out.circumcenters = circumcenters;  % Dataset 2
out.centroids = centroids;          % Dataset 3
out.cotan = cotan;                  % Dataset 4
out.normals = normals;              % Dataset 5
out.tangent1 = tangent1;            % Dataset 6
out.tangent2 = tangent2;            % Dataset 7

end
