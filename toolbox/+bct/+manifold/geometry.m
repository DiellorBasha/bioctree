function geom = geometry(M, varargin)
%GEOMETRY Compute all geometric properties of a manifold
%
% Syntax:
%   geom = bct.manifold.geometry(M)
%   geom = bct.manifold.geometry(M, Name, Value)
%
% Inputs:
%   M - bct.Manifold object
%
% Name-Value Arguments:
%   'NormalType'         - 'vertex' (default) or 'face' for normal computation
%   'TangentDomain'      - 'face' (default) or 'vertex' for tangent frames
%   'ForceFrame'         - false (default) or true to force frame recomputation
%   'precision'          - 'double' (default) or 'single' for new measures
%   'circumcenterMethod' - 'native' (default) or 'triangulation' for circumcenters
%   'boundaryPolicy'     - 'error' (default) for dual measures with boundaries
%   'dualCellType'       - 'circumcentric' (default) for dual vertex areas
%
% Outputs:
%   geom - Structure with fields:
%     .centroids          - [nF×3] Face centroids
%     .normals            - [nV×3] or [nF×3] Normal vectors (depends on NormalType)
%     .tangents           - Structure with tangent frames
%     .frame              - Structure with orthonormal frame
%     .cotan              - [nF×3] Cotangent values per face
%     .faceAreas          - [nF×1] Area of each face (NEW)
%     .edgeLengths        - [nE×1] Length of each edge (NEW)
%     .faceCircumcenters  - [nF×3] Circumcenter of each face (NEW)
%     .dualEdgeLengths    - [nE×1] Dual edge lengths (NEW, requires closed mesh)
%     .dualVertexAreas    - [nV×1] Dual vertex areas (NEW, requires closed mesh)
%     .header             - Metadata about computation options
%
% Description:
%   Convenience function that computes all geometric properties of a
%   manifold in a single call. Results are returned in a structure for
%   easy access and are automatically cached by bct.Manifold.
%
% Examples:
%   % Compute all geometry
%   M = bct.Manifold(V, F);
%   geom = bct.manifold.geometry(M);
%   
%   % Access individual properties
%   C = geom.centroids;
%   A = geom.faceAreas;
%   L = geom.edgeLengths;
%   
%   % Compute with single precision
%   geom = bct.manifold.geometry(M, 'precision', 'single');
%
% See also: bct.manifold.geometry.faceAreas, bct.manifold.geometry.edgeLengths,
%           bct.manifold.geometry.faceCircumcenters, bct.manifold.geometry.dualEdgeLengths,
%           bct.manifold.geometry.dualVertexAreas

% Parse inputs
p = inputParser;
p.FunctionName = 'bct.manifold.geometry';
addRequired(p, 'M', @(x) isa(x, 'bct.Manifold'));
addParameter(p, 'NormalType', 'vertex', @(x) ischar(x) || isstring(x));
addParameter(p, 'TangentDomain', 'face', @(x) ischar(x) || isstring(x));
addParameter(p, 'ForceFrame', false, @islogical);
addParameter(p, 'precision', 'double', @(x) ischar(x) || isstring(x));
addParameter(p, 'circumcenterMethod', 'native', @(x) ischar(x) || isstring(x));
addParameter(p, 'boundaryPolicy', 'error', @(x) ischar(x) || isstring(x));
addParameter(p, 'dualCellType', 'circumcentric', @(x) ischar(x) || isstring(x));
parse(p, M, varargin{:});

normalType = p.Results.NormalType;
tangentDomain = p.Results.TangentDomain;
forceFrame = p.Results.ForceFrame;
precision = string(p.Results.precision);
circumcenterMethod = string(p.Results.circumcenterMethod);
boundaryPolicy = string(p.Results.boundaryPolicy);
dualCellType = string(p.Results.dualCellType);

% Validate inputs
if ~ismember(lower(normalType), {'vertex', 'face'})
    error('bct:manifold:geometry:InvalidNormalType', ...
        'NormalType must be ''vertex'' or ''face''');
end
if ~ismember(lower(tangentDomain), {'vertex', 'face'})
    error('bct:manifold:geometry:InvalidTangentDomain', ...
        'TangentDomain must be ''vertex'' or ''face''');
end

% Compute all geometry properties
geom = struct();

% Store options in header
geom.header = struct( ...
    'precision', precision, ...
    'circumcenterMethod', circumcenterMethod, ...
    'boundaryPolicy', boundaryPolicy, ...
    'dualCellType', dualCellType ...
);

% Legacy geometry (existing code)
geom.centroids = bct.manifold.geometry.centroids(M);
geom.normals = bct.manifold.geometry.normals(M, normalType);

% Tangent frames
[N, e1, e2] = bct.manifold.geometry.tangents(M, 'Domain', tangentDomain);
geom.tangents = struct('N', N, 'e1', e1, 'e2', e2);

% Frame (cached orthonormal frame)
if forceFrame
    geom.frame = bct.manifold.geometry.frame(M, 'Force', true);
else
    geom.frame = bct.manifold.geometry.frame(M);
end

% Cotangent values
geom.cotan = bct.manifold.geometry.cotan(M.Vertices, M.Faces);

% NEW: DEC prerequisite measures
% Compute in order (some depend on others)

% Face areas
[areaHeader, geom.faceAreas] = bct.manifold.geometry.faceAreas(M, ...
    'precision', precision);
geom.header.faceAreas = areaHeader;

% Edge lengths
[edgeHeader, geom.edgeLengths] = bct.manifold.geometry.edgeLengths(M, ...
    'precision', precision);
geom.header.edgeLengths = edgeHeader;

% Face circumcenters
[circumHeader, geom.faceCircumcenters] = bct.manifold.geometry.faceCircumcenters(M, ...
    'method', circumcenterMethod, ...
    'precision', precision);
geom.header.faceCircumcenters = circumHeader;

% Dual edge lengths (may error if boundary present)
try
    [dualEdgeHeader, geom.dualEdgeLengths] = bct.manifold.geometry.dualEdgeLengths(M, ...
        'boundaryPolicy', boundaryPolicy, ...
        'circumcenterMethod', circumcenterMethod, ...
        'precision', precision);
    geom.header.dualEdgeLengths = dualEdgeHeader;
catch ME
    % Store error info if dual computation fails (e.g., boundary present)
    geom.dualEdgeLengths = [];
    geom.header.dualEdgeLengths = struct('error', ME.identifier, 'message', ME.message);
end

% Dual vertex areas (may error if boundary present)
try
    [dualVertexHeader, geom.dualVertexAreas] = bct.manifold.geometry.dualVertexAreas(M, ...
        'dualCellType', dualCellType, ...
        'boundaryPolicy', boundaryPolicy, ...
        'circumcenterMethod', circumcenterMethod, ...
        'precision', precision);
    geom.header.dualVertexAreas = dualVertexHeader;
catch ME
    % Store error info if dual computation fails
    geom.dualVertexAreas = [];
    geom.header.dualVertexAreas = struct('error', ME.identifier, 'message', ME.message);
end

end
