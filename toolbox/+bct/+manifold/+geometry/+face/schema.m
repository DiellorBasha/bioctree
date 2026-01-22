function s = schema()
%SCHEMA Returns HDF5/Zarr-compatible schema for face geometry
%
% Syntax:
%   s = bct.manifold.geometry.face.schema()
%
% Outputs:
%   s - Schema structure with HDF5/Zarr group/dataset hierarchy
%
% See also: bct.manifold.geometry.face, bct.file.zarr.writeArray

%% GROUP-LEVEL METADATA
s.group = struct();
s.group.name = 'face_geometry';
s.group.path = 'geometry/face';
s.group.schema = 'bct.manifold.geometry.face@1.0.0';
s.group.description = 'Face-based geometric properties of a triangulated 2-manifold';

s.group.attributes = struct();
s.group.attributes.schema = 'bct.manifold.geometry.face@1.0.0';
s.group.attributes.package = 'bct.manifold.geometry.face';
s.group.attributes.frame_handedness = 'right-handed';
s.group.attributes.frame_convention = 'tangent2 = normal × tangent1';
s.group.attributes.created_utc = '';

%% DIMENSION SCALES
s.dimensions = struct([]);

s.dimensions(1).name = 'numFaces';
s.dimensions(1).description = 'Number of triangular faces in the mesh';
s.dimensions(1).length = [];
s.dimensions(1).labels = [];
s.dimensions(1).scale_path = 'manifold/faces';
s.dimensions(1).index_base = 1;
s.dimensions(1).axis_type = 'index';

s.dimensions(2).name = 'xyz';
s.dimensions(2).description = 'Cartesian coordinate components in R³';
s.dimensions(2).length = 3;
s.dimensions(2).labels = ["x", "y", "z"];
s.dimensions(2).scale_path = [];
s.dimensions(2).index_base = [];
s.dimensions(2).axis_type = 'coordinate';

s.dimensions(3).name = 'faceVertices';
s.dimensions(3).description = 'Three vertices per triangular face';
s.dimensions(3).length = 3;
s.dimensions(3).labels = ["v1", "v2", "v3"];
s.dimensions(3).scale_path = [];
s.dimensions(3).index_base = [];
s.dimensions(3).axis_type = 'index';

%% DATASET SPECIFICATIONS
s.datasets = struct([]);

% Dataset 1: areas
s.datasets(1).name = 'areas';
s.datasets(1).path = 'geometry/face/areas';
s.datasets(1).required = true;
s.datasets(1).shape = 'numFaces×1';
s.datasets(1).dims = ["numFaces"];

s.datasets(1).dtype.matlab = 'double';
s.datasets(1).dtype.hdf5 = 'H5T_NATIVE_DOUBLE';
s.datasets(1).dtype.zarr = '<f8';

s.datasets(1).attributes.description = 'Area of each triangular face';
s.datasets(1).attributes.axis = ["face"];
s.datasets(1).attributes.units = 'm^2';
s.datasets(1).attributes.support = 'face';
s.datasets(1).attributes.valueType = 'scalar';
s.datasets(1).attributes.semantic = 'scalar';
s.datasets(1).attributes.normalization = [];
s.datasets(1).attributes.orthogonal_to = [];
s.datasets(1).attributes.computedBy = 'bct.manifold.geometry.face.areas';

% Dataset 2: circumcenters
s.datasets(2).name = 'circumcenters';
s.datasets(2).path = 'geometry/face/circumcenters';
s.datasets(2).required = true;
s.datasets(2).shape = 'numFaces×3';
s.datasets(2).dims = ["numFaces", "xyz"];

s.datasets(2).dtype.matlab = 'double';
s.datasets(2).dtype.hdf5 = 'H5T_NATIVE_DOUBLE';
s.datasets(2).dtype.zarr = '<f8';

s.datasets(2).attributes.description = 'Circumcenter of each triangular face';
s.datasets(2).attributes.axis = ["face", "xyz"];
s.datasets(2).attributes.units = 'm';
s.datasets(2).attributes.support = 'face';
s.datasets(2).attributes.valueType = 'ambient';
s.datasets(2).attributes.semantic = 'vector3';
s.datasets(2).attributes.normalization = [];
s.datasets(2).attributes.orthogonal_to = [];
s.datasets(2).attributes.computedBy = 'bct.manifold.geometry.face.circumcenters';

% Dataset 3: centroids
s.datasets(3).name = 'centroids';
s.datasets(3).path = 'geometry/face/centroids';
s.datasets(3).required = true;
s.datasets(3).shape = 'numFaces×3';
s.datasets(3).dims = ["numFaces", "xyz"];

s.datasets(3).dtype.matlab = 'double';
s.datasets(3).dtype.hdf5 = 'H5T_NATIVE_DOUBLE';
s.datasets(3).dtype.zarr = '<f8';

s.datasets(3).attributes.description = 'Barycentric centroid of each face';
s.datasets(3).attributes.axis = ["face", "xyz"];
s.datasets(3).attributes.units = 'm';
s.datasets(3).attributes.support = 'face';
s.datasets(3).attributes.valueType = 'ambient';
s.datasets(3).attributes.semantic = 'vector3';
s.datasets(3).attributes.normalization = [];
s.datasets(3).attributes.orthogonal_to = [];
s.datasets(3).attributes.computedBy = 'bct.manifold.geometry.face.centroids';

% Dataset 4: cotan
s.datasets(4).name = 'cotan';
s.datasets(4).path = 'geometry/face/cotan';
s.datasets(4).required = true;
s.datasets(4).shape = 'numFaces×3';
s.datasets(4).dims = ["numFaces", "faceVertices"];

s.datasets(4).dtype.matlab = 'double';
s.datasets(4).dtype.hdf5 = 'H5T_NATIVE_DOUBLE';
s.datasets(4).dtype.zarr = '<f8';

s.datasets(4).attributes.description = 'Cotangent weights for each face vertex';
s.datasets(4).attributes.axis = ["face", "vertex"];
s.datasets(4).attributes.units = 'dimensionless';
s.datasets(4).attributes.support = 'face';
s.datasets(4).attributes.valueType = 'scalar';
s.datasets(4).attributes.semantic = 'weights';
s.datasets(4).attributes.normalization = [];
s.datasets(4).attributes.orthogonal_to = [];
s.datasets(4).attributes.computedBy = 'bct.manifold.geometry.face.cotan';

% Dataset 5: normals
s.datasets(5).name = 'normals';
s.datasets(5).path = 'geometry/face/normals';
s.datasets(5).required = true;
s.datasets(5).shape = 'numFaces×3';
s.datasets(5).dims = ["numFaces", "xyz"];

s.datasets(5).dtype.matlab = 'double';
s.datasets(5).dtype.hdf5 = 'H5T_NATIVE_DOUBLE';
s.datasets(5).dtype.zarr = '<f8';

s.datasets(5).attributes.description = 'Unit normal vectors for each face';
s.datasets(5).attributes.axis = ["face", "xyz"];
s.datasets(5).attributes.units = 'dimensionless';
s.datasets(5).attributes.support = 'face';
s.datasets(5).attributes.valueType = 'normal';
s.datasets(5).attributes.semantic = 'vector3';
s.datasets(5).attributes.normalization = 'unit';
s.datasets(5).attributes.orthogonal_to = [];
s.datasets(5).attributes.computedBy = 'bct.manifold.geometry.face.frame';

% Dataset 6: tangent1
s.datasets(6).name = 'tangent1';
s.datasets(6).path = 'geometry/face/tangent1';
s.datasets(6).required = true;
s.datasets(6).shape = 'numFaces×3';
s.datasets(6).dims = ["numFaces", "xyz"];

s.datasets(6).dtype.matlab = 'double';
s.datasets(6).dtype.hdf5 = 'H5T_NATIVE_DOUBLE';
s.datasets(6).dtype.zarr = '<f8';

s.datasets(6).attributes.description = 'First tangent vectors (unit, orthogonal to normals)';
s.datasets(6).attributes.axis = ["face", "xyz"];
s.datasets(6).attributes.units = 'dimensionless';
s.datasets(6).attributes.support = 'face';
s.datasets(6).attributes.valueType = 'tangent';
s.datasets(6).attributes.semantic = 'vector3';
s.datasets(6).attributes.normalization = 'unit';
s.datasets(6).attributes.orthogonal_to = "normals";
s.datasets(6).attributes.computedBy = 'bct.manifold.geometry.face.frame';

% Dataset 7: tangent2
s.datasets(7).name = 'tangent2';
s.datasets(7).path = 'geometry/face/tangent2';
s.datasets(7).required = true;
s.datasets(7).shape = 'numFaces×3';
s.datasets(7).dims = ["numFaces", "xyz"];

s.datasets(7).dtype.matlab = 'double';
s.datasets(7).dtype.hdf5 = 'H5T_NATIVE_DOUBLE';
s.datasets(7).dtype.zarr = '<f8';

s.datasets(7).attributes.description = 'Second tangent vectors (unit, orthogonal to normals and tangent1)';
s.datasets(7).attributes.axis = ["face", "xyz"];
s.datasets(7).attributes.units = 'dimensionless';
s.datasets(7).attributes.support = 'face';
s.datasets(7).attributes.valueType = 'tangent';
s.datasets(7).attributes.semantic = 'vector3';
s.datasets(7).attributes.normalization = 'unit';
s.datasets(7).attributes.orthogonal_to = ["normals", "tangent1"];
s.datasets(7).attributes.computedBy = 'bct.manifold.geometry.face.frame';

%% VALUE TYPE TAXONOMY
s.valueTypes = struct();
s.valueTypes.normal = 'Vectors perpendicular to the manifold surface';
s.valueTypes.tangent = 'Vectors lying in the tangent plane';
s.valueTypes.ambient = 'Vectors in full 3D ambient space';
s.valueTypes.scalar = 'Scalar values with no directional meaning';

end
