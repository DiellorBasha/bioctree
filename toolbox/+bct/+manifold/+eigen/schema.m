function s = schema()
%SCHEMA HDF5/Zarr schema for eigenmode data structure
%
% Syntax:
%   s = bct.manifold.eigen.schema()
%
% Outputs:
%   s - Schema structure defining HDF5/Zarr layout for eigenmode data
%
% Description:
%   Defines the canonical schema for eigenmode data structures to enable
%   HDF5 and Zarr serialization. The schema follows standard conventions:
%   
%   - Group-level metadata in attributes
%   - Data arrays as datasets
%   - Dimensions define array shapes
%   - Paths define HDF5/Zarr hierarchy
%
%   Schema version: bct.manifold.eigen@1.0.0
%
% Schema Structure:
%   eigen/
%   ├── @attributes           # Group-level metadata
%   │   ├── schema           # "bct.manifold.eigen@1.0.0"
%   │   ├── package          # "bct.manifold.eigen"
%   │   ├── numModes         # Number of eigenmodes (k)
%   │   ├── numVertices      # Number of vertices (N)
%   │   ├── operator         # "Laplace-Beltrami"
%   │   ├── basis            # "P1-FEM"
%   │   ├── ordering         # "ascending"
%   │   ├── massType         # "voronoi", "barycentric", or "full"
%   │   └── removedDC        # true/false (DC mode removed)
%   ├── values               # [numModes×1 double] eigenvalues
%   └── vectors              # [numVertices×numModes double] eigenvectors
%
% Examples:
%   % Get schema
%   s = bct.manifold.eigen.schema();
%   
%   % Access dimensions
%   dimNames = s.dimensions.keys();  % {'numModes', 'numVertices'}
%   
%   % Access datasets
%   valuesDS = s.datasets('values');
%   fprintf('values: %s [%s]\n', valuesDS.path, valuesDS.dims);
%
% See also: bct.manifold.eigen, bct.manifold.eigenmodes

% Schema metadata
s.group.name = 'eigen';
s.group.path = 'eigen';
s.group.schema = 'bct.manifold.eigen@1.0.0';

% Group-level attributes (metadata)
s.group.attributes = {
    struct('name', 'schema',      'dtype', 'string',  'description', 'Schema version identifier');
    struct('name', 'package',     'dtype', 'string',  'description', 'MATLAB package path');
    struct('name', 'numModes',    'dtype', 'uint32',  'description', 'Number of eigenmodes (k)');
    struct('name', 'numVertices', 'dtype', 'uint32',  'description', 'Number of vertices (N)');
    struct('name', 'operator',    'dtype', 'string',  'description', 'Differential operator ("Laplace-Beltrami")');
    struct('name', 'basis',       'dtype', 'string',  'description', 'Finite element basis ("P1-FEM")');
    struct('name', 'ordering',    'dtype', 'string',  'description', 'Eigenvalue ordering ("ascending")');
    struct('name', 'massType',    'dtype', 'string',  'description', 'Mass matrix type ("voronoi", "barycentric", "full")');
    struct('name', 'removedDC',   'dtype', 'logical', 'description', 'Whether DC mode was removed');
};

% Dimensions (array shapes)
s.dimensions = containers.Map();
s.dimensions('numModes') = struct(...
    'description', 'Number of eigenmodes (k)', ...
    'dynamic', true);  % Can vary based on computation
s.dimensions('numVertices') = struct(...
    'description', 'Number of vertices (N)', ...
    'dynamic', true);  % Depends on manifold

% Datasets (data arrays)
s.datasets = containers.Map();

% eigenvalues: [numModes×1] eigenvalues
s.datasets('eigenvalues') = struct(...
    'name', 'eigenvalues', ...
    'path', 'eigen/eigenvalues', ...
    'dims', 'numModes', ...
    'shape', [NaN, 1], ...
    'dtype', struct(...
        'matlab', 'double', ...
        'hdf5', 'H5T_IEEE_F64LE', ...
        'zarr', '<f8'), ...
    'description', 'Eigenvalues of Laplace-Beltrami operator (sorted ascending)', ...
    'units', '1/area_units^2', ...
    'required', true);

% eigenvectors: [numVertices×numModes] eigenvectors
s.datasets('eigenvectors') = struct(...
    'name', 'eigenvectors', ...
    'path', 'eigen/eigenvectors', ...
    'dims', 'numVertices,numModes', ...
    'shape', [NaN, NaN], ...
    'dtype', struct(...
        'matlab', 'double', ...
        'hdf5', 'H5T_IEEE_F64LE', ...
        'zarr', '<f8'), ...
    'description', 'Eigenvectors (M-orthonormal columns)', ...
    'units', 'dimensionless', ...
    'required', true);

% Schema validation function
s.validate = @(eigen) validateEigenSchema(eigen);

end

function tf = validateEigenSchema(eigen)
%VALIDATEEIGENSCHEMA Validate eigenmode structure against schema
%
% Inputs:
%   eigen - Structure to validate
%
% Outputs:
%   tf - true if valid, false otherwise (with error messages)

tf = true;

% Check required fields
requiredFields = {'values', 'vectors'};
for i = 1:length(requiredFields)
    field = requiredFields{i};
    if ~isfield(eigen, field)
        warning('bct:manifold:eigen:schema:MissingField', ...
            'Missing required field: %s', field);
        tf = false;
    end
end

% Check attributes exist
if ~isfield(eigen, 'attributes')
    warning('bct:manifold:eigen:schema:MissingAttributes', ...
        'Missing attributes field');
    tf = false;
    return;
end

% Check required attributes
requiredAttrs = {'schema', 'package', 'numModes', 'numVertices', ...
                 'operator', 'basis', 'ordering', 'massType', 'removedDC'};
for i = 1:length(requiredAttrs)
    attr = requiredAttrs{i};
    if ~isfield(eigen.attributes, attr)
        warning('bct:manifold:eigen:schema:MissingAttribute', ...
            'Missing required attribute: %s', attr);
        tf = false;
    end
end

% Validate data dimensions if fields exist
if isfield(eigen, 'eigenvalues') && isfield(eigen, 'eigenvectors')
    eigenvalues_val = eigen.eigenvalues.value;
    eigenvectors_val = eigen.eigenvectors.value;
    k = size(eigenvectors_val, 2);
    if length(eigenvalues_val) ~= k
        warning('bct:manifold:eigen:schema:DimensionMismatch', ...
            'eigenvalues length (%d) does not match eigenvectors columns (%d)', ...
            length(eigenvalues_val), k);
        tf = false;
    end
end

% Validate attributes consistency
if isfield(eigen, 'attributes') && isfield(eigen.attributes, 'numModes')
    if isfield(eigen, 'eigenvalues')
        eigenvalues_val = eigen.eigenvalues.value;
        if eigen.attributes.numModes ~= length(eigenvalues_val)
            warning('bct:manifold:eigen:schema:AttributeMismatch', ...
                'attributes.numModes (%d) does not match actual eigenvalues length (%d)', ...
                eigen.attributes.numModes, length(eigenvalues_val));
            tf = false;
        end
    end
end

if isfield(eigen, 'attributes') && isfield(eigen.attributes, 'numVertices')
    if isfield(eigen, 'eigenvectors')
        eigenvectors_val = eigen.eigenvectors.value;
        if eigen.attributes.numVertices ~= size(eigenvectors_val, 1)
            warning('bct:manifold:eigen:schema:AttributeMismatch', ...
                'attributes.numVertices (%d) does not match eigenvectors rows (%d)', ...
                eigen.attributes.numVertices, size(eigenvectors_val, 1));
            tf = false;
        end
    end
end

end
