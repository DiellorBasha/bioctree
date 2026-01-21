function s = schema()
%SCHEMA Schema definition for bct.manifold.geometry (top-level aggregator)
%
% Syntax:
%   s = bct.manifold.geometry.schema()
%
% Outputs:
%   s - Schema structure with fields:
%     .group      - Group metadata for HDF5/Zarr
%     .subgroups  - Array of subgroup schemas
%     .dimensions - (empty, dimensions defined in subgroups)
%     .datasets   - (empty, datasets defined in subgroups)
%
% Description:
%   This schema defines the hierarchical structure for complete manifold
%   geometry, aggregating vertex, face, edge, and dual submodules.
%   
%   HDF5/Zarr hierarchy:
%     geometry/                    (this group)
%       ├── vertex/                (vertex geometry subgroup)
%       │   ├── normals
%       │   ├── tangent1
%       │   └── tangent2
%       ├── face/                  (face geometry subgroup)
%       │   ├── areas
%       │   ├── circumcenters
%       │   ├── centroids
%       │   ├── cotan
%       │   ├── normals
%       │   ├── tangent1
%       │   └── tangent2
%       ├── edge/                  (edge geometry subgroup)
%       │   ├── lengths
%       │   ├── weights_cotangent
%       │   └── weights_euclidean
%       └── dual/                  (dual geometry subgroup)
%           ├── edgeLengths
%           └── vertexAreas
%
% See also: bct.manifold.geometry.vertex.schema,
%           bct.manifold.geometry.face.schema,
%           bct.manifold.geometry.edge.schema,
%           bct.manifold.geometry.dual.schema

% Initialize schema structure
s = struct();

%% Group metadata
s.group = struct();
s.group.name = 'geometry';
s.group.path = 'geometry';
s.group.schema = 'bct.manifold.geometry@1.0.0';

% Group-level attributes
s.group.attributes = struct();
s.group.attributes.schema = 'bct.manifold.geometry@1.0.0';
s.group.attributes.package = 'bct.manifold.geometry';
s.group.attributes.description = 'Complete geometric properties of the manifold';
s.group.attributes.subgroups = {'vertex', 'face', 'edge', 'dual'};

%% Subgroup schemas
% Each subgroup has its own schema defining its structure
s.subgroups = struct();

% Vertex geometry subgroup
s.subgroups.vertex = struct();
s.subgroups.vertex.name = 'vertex';
s.subgroups.vertex.path = 'geometry/vertex';
s.subgroups.vertex.schema_function = 'bct.manifold.geometry.vertex.schema';
s.subgroups.vertex.required = true;
s.subgroups.vertex.description = 'Vertex-based geometric properties (normals, tangent frames)';

% Face geometry subgroup
s.subgroups.face = struct();
s.subgroups.face.name = 'face';
s.subgroups.face.path = 'geometry/face';
s.subgroups.face.schema_function = 'bct.manifold.geometry.face.schema';
s.subgroups.face.required = true;
s.subgroups.face.description = 'Face-based geometric properties (areas, centroids, normals, tangent frames)';

% Edge geometry subgroup
s.subgroups.edge = struct();
s.subgroups.edge.name = 'edge';
s.subgroups.edge.path = 'geometry/edge';
s.subgroups.edge.schema_function = 'bct.manifold.geometry.edge.schema';
s.subgroups.edge.required = true;
s.subgroups.edge.description = 'Edge-based geometric properties (lengths, weights)';

% Dual geometry subgroup
s.subgroups.dual = struct();
s.subgroups.dual.name = 'dual';
s.subgroups.dual.path = 'geometry/dual';
s.subgroups.dual.schema_function = 'bct.manifold.geometry.dual.schema';
s.subgroups.dual.required = false;  % Optional: expensive, requires closed mesh
s.subgroups.dual.description = 'Dual mesh geometric properties (edge lengths, vertex areas)';

%% Dimensions
% No dimensions at this level - all defined in subgroups
s.dimensions = struct([]);

%% Datasets
% No datasets at this level - all defined in subgroups
s.datasets = struct([]);

%% Computation options
% Document available options for geometry computation
s.options = struct();

s.options.precision = struct();
s.options.precision.name = 'precision';
s.options.precision.type = 'string';
s.options.precision.allowed = {'double', 'single'};
s.options.precision.default = 'double';
s.options.precision.description = 'Numeric precision for geometric computations';

s.options.circumcenterMethod = struct();
s.options.circumcenterMethod.name = 'circumcenterMethod';
s.options.circumcenterMethod.type = 'string';
s.options.circumcenterMethod.allowed = {'native', 'triangulation'};
s.options.circumcenterMethod.default = 'native';
s.options.circumcenterMethod.description = 'Method for computing face circumcenters';

s.options.boundaryPolicy = struct();
s.options.boundaryPolicy.name = 'boundaryPolicy';
s.options.boundaryPolicy.type = 'string';
s.options.boundaryPolicy.allowed = {'error', 'skip', 'extrapolate'};
s.options.boundaryPolicy.default = 'error';
s.options.boundaryPolicy.description = 'Policy for handling boundary edges in dual geometry';

s.options.dualCellType = struct();
s.options.dualCellType.name = 'dualCellType';
s.options.dualCellType.type = 'string';
s.options.dualCellType.allowed = {'circumcentric', 'barycentric'};
s.options.dualCellType.default = 'circumcentric';
s.options.dualCellType.description = 'Type of dual cell for vertex area computation';

s.options.includeDual = struct();
s.options.includeDual.name = 'includeDual';
s.options.includeDual.type = 'logical';
s.options.includeDual.allowed = [true, false];
s.options.includeDual.default = false;
s.options.includeDual.description = 'Whether to compute expensive dual geometry';

end
