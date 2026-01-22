function s = schema()
%SCHEMA Returns HDF5/Zarr-compatible schema for vertex geometry
%
% Syntax:
%   s = bct.manifold.geometry.vertex.schema()
%
% Outputs:
%   s - Schema structure with HDF5/Zarr group/dataset hierarchy:
%       .group      - Group-level metadata (attributes)
%       .datasets   - Cell array of dataset specifications
%       .dimensions - Dimension scale definitions
%       .dtypes     - Data type mappings (HDF5, Zarr, MATLAB)
%       .valueTypes - Value type taxonomy (reference)
%
% Description:
%   Returns schema formatted for HDF5/Zarr serialization with clear
%   separation between group attributes and dataset specifications.
%
%   Structure mirrors HDF5/Zarr conventions:
%   - Group attributes describe the computation container
%   - Each dataset has its own attributes, shape, and dtype
%   - Dimension scales provide axis labels and interpretations
%
%   HDF5/Zarr Layout:
%     vertex_geometry/          <- Group (s.group)
%       ├── .zattrs             <- Group attributes
%       ├── normals/            <- Dataset (s.datasets(1))
%       │   ├── .zarray         <- Shape, dtype, chunks
%       │   ├── .zattrs         <- Dataset attributes
%       │   └── 0               <- Binary data
%       ├── tangent1/
%       └── tangent2/
%
% Examples:
%   % Get schema
%   s = bct.manifold.geometry.vertex.schema();
%   
%   % Group-level attributes for HDF5/Zarr export
%   groupAttrs = s.group.attributes;
%   
%   % Iterate over datasets for export
%   for i = 1:numel(s.datasets)
%       ds = s.datasets(i);
%       fprintf('Dataset: %s [%s]\n', ds.name, ds.dtype.matlab);
%       fprintf('  Attributes: %s\n', jsonencode(ds.attributes));
%   end
%   
%   % Iterate over dimensions
%   for i = 1:numel(s.dimensions)
%       dim = s.dimensions(i);
%       fprintf('Dimension: %s (length=%s)\n', dim.name, mat2str(dim.length));
%   end
%
% See also: bct.manifold.geometry.vertex, bct.file.zarr.writeArray

%% GROUP-LEVEL METADATA (HDF5 group attributes / Zarr .zattrs)
s.group = struct();
s.group.name = 'vertex_geometry';
s.group.path = 'geometry/vertex';  % Typical location in manifold hierarchy
s.group.schema = 'bct.manifold.geometry.vertex@1.0.0';
s.group.description = 'Vertex-based geometric properties of a triangulated 2-manifold';

% Group attributes (written to .zattrs or HDF5 group attributes)
s.group.attributes = struct();
s.group.attributes.schema = 'bct.manifold.geometry.vertex@1.0.0';
s.group.attributes.package = 'bct.manifold.geometry.vertex';
s.group.attributes.frame_handedness = 'right-handed';
s.group.attributes.frame_convention = 'tangent2 = normal × tangent1';
s.group.attributes.normal_weighting = 'area-weighted';
s.group.attributes.tangent_method = 'reference_axis_projection';
s.group.attributes.created_utc = '';  % Populated at write time

%% DIMENSION SCALES (flat struct array with consistent fields)
% All dimensions have same fields for easy iteration
s.dimensions = struct([]);

% Dimension 1: numVertices
s.dimensions(1).name = 'numVertices';
s.dimensions(1).description = 'Number of vertices in the mesh';
s.dimensions(1).length = [];  % Dynamic, determined at runtime (Nv)
s.dimensions(1).labels = [];  % No axis labels for vertex indices
s.dimensions(1).scale_path = 'manifold/vertices';  % HDF5 dimension scale reference
s.dimensions(1).index_base = 1;  % MATLAB uses 1-based indexing
s.dimensions(1).axis_type = 'index';  % 'index' | 'coordinate' | 'label'

% Dimension 2: xyz (spatial coordinates)
s.dimensions(2).name = 'xyz';
s.dimensions(2).description = 'Cartesian coordinate components in R³';
s.dimensions(2).length = 3;  % Fixed length
s.dimensions(2).labels = ["x", "y", "z"];
s.dimensions(2).scale_path = [];  % No external scale reference
s.dimensions(2).index_base = [];  % Not applicable for coordinate axes
s.dimensions(2).axis_type = 'coordinate';

%% DATASET SPECIFICATIONS (flat struct array with consistent fields)
s.datasets = struct([]);

% Dataset 1: normals
s.datasets(1).name = 'normals';
s.datasets(1).path = 'geometry/vertex/normals';
s.datasets(1).required = true;
s.datasets(1).shape = 'numVertices×3';  % Symbolic shape using dimension names
s.datasets(1).dims = ["numVertices", "xyz"];  % Dimension references

% Data types for different backends
s.datasets(1).dtype.matlab = 'double';
s.datasets(1).dtype.hdf5 = 'H5T_NATIVE_DOUBLE';
s.datasets(1).dtype.zarr = '<f8';

% Dataset attributes
s.datasets(1).attributes.description = 'Unit normal vectors at each vertex (area-weighted)';
s.datasets(1).attributes.axis = ["vertex", "xyz"];  % Human-readable axis labels
s.datasets(1).attributes.units = 'dimensionless';
s.datasets(1).attributes.support = 'vertex';
s.datasets(1).attributes.valueType = 'normal';  % Perpendicular to surface
s.datasets(1).attributes.semantic = 'vector3';
s.datasets(1).attributes.normalization = 'unit';
s.datasets(1).attributes.orthogonal_to = [];  % Not orthogonal to other datasets
s.datasets(1).attributes.computedBy = 'bct.manifold.geometry.vertex.frame';

% Dataset 2: tangent1
s.datasets(2).name = 'tangent1';
s.datasets(2).path = 'geometry/vertex/tangent1';
s.datasets(2).required = true;
s.datasets(2).shape = 'numVertices×3';
s.datasets(2).dims = ["numVertices", "xyz"];

s.datasets(2).dtype.matlab = 'double';
s.datasets(2).dtype.hdf5 = 'H5T_NATIVE_DOUBLE';
s.datasets(2).dtype.zarr = '<f8';

s.datasets(2).attributes.description = 'First tangent vectors (unit, orthogonal to normals)';
s.datasets(2).attributes.axis = ["vertex", "xyz"];
s.datasets(2).attributes.units = 'dimensionless';
s.datasets(2).attributes.support = 'vertex';
s.datasets(2).attributes.valueType = 'tangent';  % Lies in tangent plane
s.datasets(2).attributes.semantic = 'vector3';
s.datasets(2).attributes.normalization = 'unit';
s.datasets(2).attributes.orthogonal_to = "normals";  % Orthogonal to normals
s.datasets(2).attributes.computedBy = 'bct.manifold.geometry.vertex.frame';

% Dataset 3: tangent2
s.datasets(3).name = 'tangent2';
s.datasets(3).path = 'geometry/vertex/tangent2';
s.datasets(3).required = true;
s.datasets(3).shape = 'numVertices×3';
s.datasets(3).dims = ["numVertices", "xyz"];

s.datasets(3).dtype.matlab = 'double';
s.datasets(3).dtype.hdf5 = 'H5T_NATIVE_DOUBLE';
s.datasets(3).dtype.zarr = '<f8';

s.datasets(3).attributes.description = 'Second tangent vectors (unit, orthogonal to normals and tangent1)';
s.datasets(3).attributes.axis = ["vertex", "xyz"];
s.datasets(3).attributes.units = 'dimensionless';
s.datasets(3).attributes.support = 'vertex';
s.datasets(3).attributes.valueType = 'tangent';  % Lies in tangent plane
s.datasets(3).attributes.semantic = 'vector3';
s.datasets(3).attributes.normalization = 'unit';
s.datasets(3).attributes.orthogonal_to = ["normals", "tangent1"];  % Orthogonal to both
s.datasets(3).attributes.computedBy = 'bct.manifold.geometry.vertex.frame';

%% VALUE TYPE TAXONOMY (reference for all BCT schemas)
s.valueTypes = struct();
s.valueTypes.normal = 'Vectors perpendicular to the manifold surface (outward/inward pointing)';
s.valueTypes.tangent = 'Vectors lying in the tangent plane at each point (parallel to surface)';
s.valueTypes.ambient = 'Vectors in full 3D ambient space (no special surface relationship)';
s.valueTypes.scalar = 'Scalar values with no directional meaning';

%% MATLAB STRUCTURE MAPPING (for validateSchema backward compatibility)
% Maps MATLAB struct fields to dataset names
s.matlab_mapping = struct();
s.matlab_mapping.header = 'group_attributes';  % MATLAB header → group attrs
s.matlab_mapping.normals = 'normals';          % Direct mapping
s.matlab_mapping.tangent1 = 'tangent1';
s.matlab_mapping.tangent2 = 'tangent2';

end
