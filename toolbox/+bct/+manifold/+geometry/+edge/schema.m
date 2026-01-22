function s = schema()
%SCHEMA Returns HDF5/Zarr-compatible schema for edge geometry
%
% Syntax:
%   s = bct.manifold.geometry.edge.schema()
%
% Outputs:
%   s - Schema structure with HDF5/Zarr group/dataset hierarchy
%
% See also: bct.manifold.geometry.edge, bct.file.zarr.writeArray

%% GROUP-LEVEL METADATA
s.group = struct();
s.group.name = 'edge_geometry';
s.group.path = 'geometry/edge';
s.group.schema = 'bct.manifold.geometry.edge@1.0.0';
s.group.description = 'Edge-based geometric properties of a triangulated 2-manifold';

s.group.attributes = struct();
s.group.attributes.schema = 'bct.manifold.geometry.edge@1.0.0';
s.group.attributes.package = 'bct.manifold.geometry.edge';
s.group.attributes.created_utc = '';

%% DIMENSION SCALES
s.dimensions = struct([]);

s.dimensions(1).name = 'numEdges';
s.dimensions(1).description = 'Number of unique undirected edges in the mesh';
s.dimensions(1).length = [];
s.dimensions(1).labels = [];
s.dimensions(1).scale_path = 'manifold/edges';
s.dimensions(1).index_base = 1;
s.dimensions(1).axis_type = 'index';

s.dimensions(2).name = 'weightTypes';
s.dimensions(2).description = 'Different edge weight schemes';
s.dimensions(2).length = 2;
s.dimensions(2).labels = ["cotangent", "euclidean"];
s.dimensions(2).scale_path = [];
s.dimensions(2).index_base = [];
s.dimensions(2).axis_type = 'label';

%% DATASET SPECIFICATIONS
s.datasets = struct([]);

% Dataset 1: lengths
s.datasets(1).name = 'lengths';
s.datasets(1).path = 'geometry/edge/lengths';
s.datasets(1).required = true;
s.datasets(1).shape = 'numEdges×1';
s.datasets(1).dims = ["numEdges"];

s.datasets(1).dtype.matlab = 'double';
s.datasets(1).dtype.hdf5 = 'H5T_NATIVE_DOUBLE';
s.datasets(1).dtype.zarr = '<f8';

s.datasets(1).attributes.description = 'Euclidean length of each edge';
s.datasets(1).attributes.axis = ["edge"];
s.datasets(1).attributes.units = 'm';
s.datasets(1).attributes.support = 'edge';
s.datasets(1).attributes.valueType = 'scalar';
s.datasets(1).attributes.semantic = 'scalar';
s.datasets(1).attributes.normalization = [];
s.datasets(1).attributes.orthogonal_to = [];
s.datasets(1).attributes.computedBy = 'bct.manifold.geometry.edge.lengths';

% Dataset 2: weights_cotangent
s.datasets(2).name = 'weights_cotangent';
s.datasets(2).path = 'geometry/edge/weights_cotangent';
s.datasets(2).required = true;
s.datasets(2).shape = 'numEdges×1';
s.datasets(2).dims = ["numEdges"];

s.datasets(2).dtype.matlab = 'double';
s.datasets(2).dtype.hdf5 = 'H5T_NATIVE_DOUBLE';
s.datasets(2).dtype.zarr = '<f8';

s.datasets(2).attributes.description = 'Cotangent-based edge weights for FEM operators';
s.datasets(2).attributes.axis = ["edge"];
s.datasets(2).attributes.units = 'dimensionless';
s.datasets(2).attributes.support = 'edge';
s.datasets(2).attributes.valueType = 'scalar';
s.datasets(2).attributes.semantic = 'weights';
s.datasets(2).attributes.normalization = [];
s.datasets(2).attributes.orthogonal_to = [];
s.datasets(2).attributes.computedBy = 'bct.manifold.geometry.edge.weights';

% Dataset 3: weights_euclidean
s.datasets(3).name = 'weights_euclidean';
s.datasets(3).path = 'geometry/edge/weights_euclidean';
s.datasets(3).required = true;
s.datasets(3).shape = 'numEdges×1';
s.datasets(3).dims = ["numEdges"];

s.datasets(3).dtype.matlab = 'double';
s.datasets(3).dtype.hdf5 = 'H5T_NATIVE_DOUBLE';
s.datasets(3).dtype.zarr = '<f8';

s.datasets(3).attributes.description = 'Euclidean distance-based edge weights';
s.datasets(3).attributes.axis = ["edge"];
s.datasets(3).attributes.units = 'm';
s.datasets(3).attributes.support = 'edge';
s.datasets(3).attributes.valueType = 'scalar';
s.datasets(3).attributes.semantic = 'weights';
s.datasets(3).attributes.normalization = [];
s.datasets(3).attributes.orthogonal_to = [];
s.datasets(3).attributes.computedBy = 'bct.manifold.geometry.edge.weights';

%% VALUE TYPE TAXONOMY
s.valueTypes = struct();
s.valueTypes.normal = 'Vectors perpendicular to the manifold surface';
s.valueTypes.tangent = 'Vectors lying in the tangent plane';
s.valueTypes.ambient = 'Vectors in full 3D ambient space';
s.valueTypes.scalar = 'Scalar values with no directional meaning';

end
