function out = dual(meshInput, varargin)
%DUAL Compute all dual mesh geometric properties
%
% Syntax:
%   dualGeom = bct.manifold.geometry.dual(M)
%   dualGeom = bct.manifold.geometry.dual(V, F)
%   dualGeom = bct.manifold.geometry.dual(___, Name, Value)
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
%   'boundaryPolicy'     - 'error' (default) - behavior when boundary edges present
%   'dualCellType'       - 'circumcentric' (default) - type of dual cell
%
% Outputs:
%   out - Structure matching bct.manifold.geometry.dual.schema:
%     .attributes              - Group-level metadata (computation options)
%     .edgeLengths.value       - [Ne×1] Dual edge lengths (connects face circumcenters)
%     .edgeLengths.attributes  - Dataset metadata
%     .vertexAreas.value       - [Nv×1] Dual vertex areas (circumcentric dual cell areas)
%     .vertexAreas.attributes  - Dataset metadata
%
% Description:
%   Aggregator function that computes all dual mesh geometric properties
%   by calling the individual functions in bct.manifold.geometry.dual.*
%
%   The dual mesh is constructed by connecting face circumcenters. Dual
%   edge lengths connect circumcenters of adjacent faces, and dual vertex
%   areas are the areas of dual cells around each primal vertex.
%
%   Note: Dual computations require closed manifolds (no boundary edges).
%   If boundaries are present, computations will fail unless boundaryPolicy
%   is set appropriately.
%
% Examples:
%   % Compute all dual geometry
%   M = bct.Manifold(V, F);
%   dualGeom = bct.manifold.geometry.dual(M);
%   
%   % Access individual properties
%   dualEdges = dualGeom.edgeLengths.value;
%   dualAreas = dualGeom.vertexAreas.value;
%   
%   % Compute with single precision
%   dualGeom = bct.manifold.geometry.dual(M, 'precision', 'single');
%
% See also: bct.manifold.geometry.face, bct.manifold.geometry.vertex,
%           bct.manifold.geometry.edge, bct.manifold.geometry

% Parse inputs
p = inputParser;
p.FunctionName = 'bct.manifold.geometry.dual';
p.KeepUnmatched = true;

if isa(meshInput, 'bct.Manifold')
    addRequired(p, 'M', @(x) isa(x, 'bct.Manifold'));
    parse(p, meshInput);
else
    addRequired(p, 'V', @isnumeric);
    addRequired(p, 'F', @isnumeric);
    if isempty(varargin) || ~isnumeric(varargin{1})
        error('bct:manifold:geometry:dual:InvalidInput', ...
            'Expected dual(M) or dual(V, F)');
    end
    parse(p, meshInput, varargin{1});
    varargin = varargin(2:end);  % Remove F from varargin
end

addParameter(p, 'precision', 'double', @(x) ischar(x) || isstring(x));
addParameter(p, 'circumcenterMethod', 'native', @(x) ischar(x) || isstring(x));
addParameter(p, 'boundaryPolicy', 'error', @(x) ischar(x) || isstring(x));
addParameter(p, 'dualCellType', 'circumcentric', @(x) ischar(x) || isstring(x));
parse(p, meshInput, varargin{:});

precision = string(p.Results.precision);
circumcenterMethod = string(p.Results.circumcenterMethod);
boundaryPolicy = string(p.Results.boundaryPolicy);
dualCellType = string(p.Results.dualCellType);

% Compute dual properties
[edgeHeader, edgeLengths] = bct.manifold.geometry.dual.edgeLengths(meshInput, ...
    'boundaryPolicy', boundaryPolicy, ...
    'circumcenterMethod', circumcenterMethod, ...
    'precision', precision);
[vertexHeader, vertexAreas] = bct.manifold.geometry.dual.vertexAreas(meshInput, ...
    'dualCellType', dualCellType, ...
    'boundaryPolicy', boundaryPolicy, ...
    'circumcenterMethod', circumcenterMethod, ...
    'precision', precision);

% Initialize output structure matching schema
out = struct();

% Group-level attributes (matches s.group.attributes in schema)
out.attributes = struct();
out.attributes.schema = 'bct.manifold.geometry.dual@1.0.0';
out.attributes.package = 'bct.manifold.geometry.dual';
out.attributes.dual_construction = 'circumcentric';
out.attributes.precision = char(precision);
out.attributes.circumcenterMethod = char(circumcenterMethod);
out.attributes.boundaryPolicy = char(boundaryPolicy);
out.attributes.dualCellType = char(dualCellType);
out.attributes.computed_utc = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));

nE = size(edgeLengths, 1);
nV = size(vertexAreas, 1);

% Dataset 1: edgeLengths
out.edgeLengths.value = edgeLengths;
out.edgeLengths.attributes = struct(...
    'name', 'edgeLengths', ...
    'path', 'geometry/dual/edgeLengths', ...
    'description', 'Length of dual edges (distance between adjacent face circumcenters)', ...
    'shape', [nE, 1], ...
    'dtype', 'double', ...
    'units', 'm', ...
    'support', 'edge', ...
    'computedBy', 'bct.manifold.geometry.dual.edgeLengths');

% Dataset 2: vertexAreas
out.vertexAreas.value = vertexAreas;
out.vertexAreas.attributes = struct(...
    'name', 'vertexAreas', ...
    'path', 'geometry/dual/vertexAreas', ...
    'description', 'Area of dual cells (Voronoi regions) around each primal vertex', ...
    'shape', [nV, 1], ...
    'dtype', 'double', ...
    'units', 'm^2', ...
    'support', 'vertex', ...
    'computedBy', 'bct.manifold.geometry.dual.vertexAreas');

end
