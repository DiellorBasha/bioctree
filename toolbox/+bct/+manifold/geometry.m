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
%   geom - Structure with fields:
%     .face   - Structure with face-based geometry:
%               .areas          - [nF×1] Area of each face
%               .circumcenters  - [nF×3] Circumcenter of each face
%               .centroids      - [nF×3] Face centroids (barycenters)
%               .cotan          - [nF×3] Cotangent weights per face vertex
%               .normals        - [nF×3] Face normal vectors
%               .tangent1       - [nF×3] First tangent vectors
%               .tangent2       - [nF×3] Second tangent vectors
%               .header         - Metadata
%     .vertex - Structure with vertex-based geometry:
%               .normals        - [nV×3] Vertex normal vectors
%               .tangent1       - [nV×3] First tangent vectors
%               .tangent2       - [nV×3] Second tangent vectors
%               .header         - Metadata
%     .edge   - Structure with edge-based geometry:
%               .lengths        - [nE×1] Edge lengths
%               .weights        - Structure with .cotangent and .euclidean
%               .header         - Metadata
%     .dual   - Structure with dual mesh geometry (requires closed mesh):
%               .edgeLengths    - [nE×1] Dual edge lengths
%               .vertexAreas    - [nV×1] Dual vertex areas
%               .header         - Metadata
%     .header - Global metadata about computation options
%
% Description:
%   Convenience function that computes all geometric properties of a
%   manifold in a single call. Results are organized into face, vertex,
%   edge, and dual structures. Each aggregator calls the individual
%   functions from bct.manifold.geometry submodules.
%
%   By default, dual geometry is NOT computed because it requires expensive
%   halfedge data structures. Set 'includeDual' to true to compute dual
%   edge lengths and vertex areas.
%
% Examples:
%   % Compute all geometry
%   M = bct.Manifold(V, F);
%   geom = bct.manifold.geometry(M);
%   
%   % Access individual properties
%   C = geom.face.centroids;
%   A = geom.face.areas;
%   L = geom.edge.lengths;
%   VN = geom.vertex.normals;
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
% See also: bct.manifold.geometry.face, bct.manifold.geometry.vertex,
%           bct.manifold.geometry.edge, bct.manifold.metric.annotate

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

% Compute all geometry properties using aggregators
geom = struct();

% Store options in header
geom.header = struct( ...
    'precision', precision, ...
    'circumcenterMethod', circumcenterMethod, ...
    'boundaryPolicy', boundaryPolicy, ...
    'dualCellType', dualCellType ...
);

% Face-based geometry (using aggregator)
geom.face = bct.manifold.geometry.face(M, ...
    'precision', precision, ...
    'circumcenterMethod', circumcenterMethod);

% Vertex-based geometry (using aggregator)
geom.vertex = bct.manifold.geometry.vertex(M);

% Edge-based geometry (using aggregator)
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
        geom.dual.edgeLengths = [];
        geom.dual.vertexAreas = [];
        geom.dual.header = struct('error', ME.identifier, 'message', ME.message);
    end
else
    % Skip dual computation (default for performance)
    geom.dual = struct();
    geom.dual.edgeLengths = [];
    geom.dual.vertexAreas = [];
    geom.dual.header = struct('skipped', true, 'reason', 'includeDual=false');
end

% Apply unit annotation if requested
if annotate
    geom = bct.manifold.metric.annotate(geom, 'geometry');
end

end
