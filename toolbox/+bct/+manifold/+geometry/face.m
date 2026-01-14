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
%     .frame          - Structure with .normal, .tangent1, .tangent2 orthonormal frames
%     .header         - Metadata about computation options
%
% Description:
%   Aggregator function that computes all face-based geometric properties
%   by calling the individual functions in bct.manifold.geometry.face.*
%
% Examples:
%   % Compute all face geometry
%   M = bct.Manifold(V, F);
%   faceGeom = bct.manifold.geometry.face(M);
%   
%   % Access individual properties
%   areas = faceGeom.areas;
%   normals = faceGeom.normals;
%   frame = faceGeom.frame;
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

% Initialize output structure
out = struct();
out.header = struct(...
    'precision', precision, ...
    'circumcenterMethod', circumcenterMethod ...
);

% Compute face areas
[areaHeader, out.areas] = bct.manifold.geometry.face.areas(meshInput, ...
    'precision', precision);
out.header.areas = areaHeader;

% Compute face circumcenters
[circumHeader, out.circumcenters] = bct.manifold.geometry.face.circumcenters(meshInput, ...
    'method', circumcenterMethod, ...
    'precision', precision);
out.header.circumcenters = circumHeader;

% Compute face centroids
[centroidHeader, out.centroids] = bct.manifold.geometry.face.centroids(meshInput);
out.header.centroids = centroidHeader;

% Compute cotangent weights
[cotanHeader, out.cotan] = bct.manifold.geometry.face.cotan(meshInput);
out.header.cotan = cotanHeader;

% Compute face normals
[normalHeader, out.normals] = bct.manifold.geometry.face.normals(meshInput);
out.header.normals = normalHeader;

% Compute face frames
[frameHeader, normal, tangent1, tangent2] = bct.manifold.geometry.face.frame(meshInput);
out.frame = struct('normal', normal, 'tangent1', tangent1, 'tangent2', tangent2);
out.header.frame = frameHeader;

end
