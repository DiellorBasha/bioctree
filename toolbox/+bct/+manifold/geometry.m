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
%   'precision'          - 'double' (default) or 'single' for numeric precision
%   'circumcenterMethod' - 'native' (default) or 'triangulation' for circumcenters
%   'boundaryPolicy'     - 'error' (default) for dual measures with boundaries
%   'dualCellType'       - 'circumcentric' (default) for dual vertex areas
%   'annotate'           - false (default) or true to wrap outputs as quantity structs
%   'includeDual'        - false (default) or true to compute dual geometry (can be slow)
%
% Outputs:
%   geom - Structure matching bct.schema.geometry:
%     .Attributes - Group-level metadata (path, schema, package, computation options)
%     .face       - Subgroup with face-based geometry datasets
%     .vertex     - Subgroup with vertex-based geometry datasets
%     .edge       - Subgroup with edge-based geometry datasets
%     .dual       - Subgroup with dual mesh geometry datasets (optional)
%
%   Each subgroup contains datasets with .value and .attributes following
%   the canonical bct.schema.geometry specification.
%
% Description:
%   Top-level aggregator that computes all geometric properties of a
%   manifold in a single call. Output structure conforms to the canonical
%   bct.schema.geometry for consistent validation and future serialization.
%   
%   Each subgroup (face, vertex, edge, dual) has its own schema and can be
%   serialized independently. By default, dual geometry is NOT computed 
%   because it requires expensive halfedge data structures. Set 'includeDual' 
%   to true to compute dual edge lengths and vertex areas.
%
% Examples:
%   % Compute all geometry
%   M = bct.Manifold(V, F);
%   geom = bct.manifold.geometry(M);
%   
%   % Access individual properties (use .value to extract data)
%   C = geom.face.centroids.value;
%   A = geom.face.areas.value;
%   L = geom.edge.lengths.value;
%   VN = geom.vertex.normals.value;
%   dTheta = geom.face.transport.value;      % Halfedge transport angles
%   
%   % Compute with single precision
%   geom = bct.manifold.geometry(M, 'precision', 'single');
%   
%   % Compute with dual geometry (slower)
%   geom = bct.manifold.geometry(M, 'includeDual', true);
%   
%   % Compute with unit annotations
%   geom = bct.manifold.geometry(M, 'annotate', true);
%   geom.face.areas.unit       % 'm^2'
%   geom.edge.lengths.unit     % 'm'
%
% See also: bct.schema.geometry, bct.manifold.geometry.face, 
%           bct.manifold.geometry.vertex, bct.manifold.geometry.edge, 
%           bct.manifold.metric.annotate

% Parse inputs
p = inputParser;
p.FunctionName = 'bct.manifold.geometry';
addRequired(p, 'M', @(x) isa(x, 'bct.Manifold'));
addParameter(p, 'precision', 'double', @(x) ischar(x) || isstring(x));
addParameter(p, 'circumcenterMethod', 'native', @(x) ischar(x) || isstring(x));
addParameter(p, 'boundaryPolicy', 'error', @(x) ischar(x) || isstring(x));
addParameter(p, 'dualCellType', 'circumcentric', @(x) ischar(x) || isstring(x));
addParameter(p, 'annotate', false, @islogical);
addParameter(p, 'includeDual', false, @islogical);
parse(p, M, varargin{:});

precision = string(p.Results.precision);
circumcenterMethod = string(p.Results.circumcenterMethod);
boundaryPolicy = string(p.Results.boundaryPolicy);
dualCellType = string(p.Results.dualCellType);
annotate = p.Results.annotate;
includeDual = p.Results.includeDual;

% Initialize output structure matching schema
geom = struct();

% Group-level attributes (matches s.group.attributes in schema)
geom.attributes = struct();
geom.attributes.schema = 'bct.manifold.geometry@1.0.0';
geom.attributes.package = 'bct.manifold.geometry';
geom.attributes.precision = char(precision);
geom.attributes.circumcenterMethod = char(circumcenterMethod);
geom.attributes.boundaryPolicy = char(boundaryPolicy);
geom.attributes.dualCellType = char(dualCellType);
geom.attributes.includeDual = includeDual;
geom.attributes.computed_utc = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));

% Subgroups (each with their own schema-compliant structure)
% Face-based geometry
geom.face = bct.manifold.geometry.face(M, ...
    'precision', precision, ...
    'circumcenterMethod', circumcenterMethod);

% Vertex-based geometry
geom.vertex = bct.manifold.geometry.vertex(M);

% Edge-based geometry
geom.edge = bct.manifold.geometry.edge(M, 'precision', precision);

% Dual-based geometry (optional, can be slow due to halfedge computation)
if includeDual
    try
        geom.dual = bct.manifold.geometry.dual(M, ...
            'precision', precision, ...
            'circumcenterMethod', circumcenterMethod, ...
            'boundaryPolicy', boundaryPolicy, ...
            'dualCellType', dualCellType);
    catch ME
        % Store error info if dual computation fails (e.g., boundary present)
        geom.dual = struct();
        geom.dual.attributes = struct('error', ME.identifier, 'message', ME.message);
        geom.dual.edgeLengths = struct('value', [], 'attributes', struct('error', true));
        geom.dual.vertexAreas = struct('value', [], 'attributes', struct('error', true));
    end
else
    % Skip dual computation (default for performance)
    geom.dual = struct();
    geom.dual.attributes = struct('skipped', true, 'reason', 'includeDual=false');
    geom.dual.edgeLengths = struct('value', [], 'attributes', struct('skipped', true));
    geom.dual.vertexAreas = struct('value', [], 'attributes', struct('skipped', true));
end

% Apply unit annotation if requested
if annotate
    geom = bct.manifold.metric.annotate(geom, 'geometry');
end

end
