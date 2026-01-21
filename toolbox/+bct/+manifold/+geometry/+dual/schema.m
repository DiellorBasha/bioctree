function s = schema()
%SCHEMA Returns HDF5/Zarr-compatible schema for dual mesh geometry
%
% Syntax:
%   s = bct.manifold.geometry.dual.schema()
%
% Outputs:
%   s - Schema structure with HDF5/Zarr group/dataset hierarchy
%
% See also: bct.manifold.geometry.dual, bct.file.zarr.writeArray

%% GROUP-LEVEL METADATA
s.group = struct();
s.group.name = 'dual_geometry';
s.group.path = 'geometry/dual';
s.group.schema = 'bct.manifold.geometry.dual@1.0.0';
s.group.description = 'Dual mesh geometric properties (circumcentric dual)';

s.group.attributes = struct();
s.group.attributes.schema = 'bct.manifold.geometry.dual@1.0.0';
s.group.attributes.package = 'bct.manifold.geometry.dual';
s.group.attributes.dual_construction = 'circumcentric';
s.group.attributes.created_utc = '';

%% DIMENSION SCALES
s.dimensions = struct([]);

s.dimensions(1).name = 'numEdges';
s.dimensions(1).description = 'Number of edges in primal mesh (dual edges connect face circumcenters)';
s.dimensions(1).length = [];
s.dimensions(1).labels = [];
s.dimensions(1).scale_path = 'manifold/edges';
s.dimensions(1).index_base = 1;
s.dimensions(1).axis_type = 'index';

s.dimensions(2).name = 'numVertices';
s.dimensions(2).description = 'Number of vertices in primal mesh (dual vertices are face circumcenters)';
s.dimensions(2).length = [];
s.dimensions(2).labels = [];
s.dimensions(2).scale_path = 'manifold/vertices';
s.dimensions(2).index_base = 1;
s.dimensions(2).axis_type = 'index';

%% DATASET SPECIFICATIONS
s.datasets = struct([]);

% Dataset 1: edgeLengths
s.datasets(1).name = 'edgeLengths';
s.datasets(1).path = 'geometry/dual/edgeLengths';
s.datasets(1).required = true;
s.datasets(1).shape = 'numEdges×1';
s.datasets(1).dims = ["numEdges"];

s.datasets(1).dtype.matlab = 'double';
s.datasets(1).dtype.hdf5 = 'H5T_NATIVE_DOUBLE';
s.datasets(1).dtype.zarr = '<f8';

s.datasets(1).attributes.description = 'Length of dual edges (distance between adjacent face circumcenters)';
s.datasets(1).attributes.axis = ["edge"];
s.datasets(1).attributes.units = 'm';
s.datasets(1).attributes.support = 'edge';
s.datasets(1).attributes.valueType = 'scalar';
s.datasets(1).attributes.semantic = 'scalar';
s.datasets(1).attributes.normalization = [];
s.datasets(1).attributes.orthogonal_to = [];

% Dataset 2: vertexAreas
s.datasets(2).name = 'vertexAreas';
s.datasets(2).path = 'geometry/dual/vertexAreas';
s.datasets(2).required = true;
s.datasets(2).shape = 'numVertices×1';
s.datasets(2).dims = ["numVertices"];

s.datasets(2).dtype.matlab = 'double';
s.datasets(2).dtype.hdf5 = 'H5T_NATIVE_DOUBLE';
s.datasets(2).dtype.zarr = '<f8';

s.datasets(2).attributes.description = 'Area of dual cells (Voronoi regions) around each primal vertex';
s.datasets(2).attributes.axis = ["vertex"];
s.datasets(2).attributes.units = 'm^2';
s.datasets(2).attributes.support = 'vertex';
s.datasets(2).attributes.valueType = 'scalar';
s.datasets(2).attributes.semantic = 'scalar';
s.datasets(2).attributes.normalization = [];
s.datasets(2).attributes.orthogonal_to = [];

%% VALUE TYPE TAXONOMY
s.valueTypes = struct();
s.valueTypes.normal = 'Vectors perpendicular to the manifold surface';
s.valueTypes.tangent = 'Vectors lying in the tangent plane';
s.valueTypes.ambient = 'Vectors in full 3D ambient space';
s.valueTypes.scalar = 'Scalar values with no directional meaning';

end
