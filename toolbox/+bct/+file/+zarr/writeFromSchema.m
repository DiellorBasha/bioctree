function writeFromSchema(zarrPath, schema, groupPath, options)
%WRITEFROMSCHEMA Write schema-compliant data to Zarr with recursive traversal
%
% Syntax:
%   bct.file.zarr.writeFromSchema(zarrPath, schema, groupPath)
%   bct.file.zarr.writeFromSchema(zarrPath, schema, groupPath, 'Overwrite', true)
%
% Inputs:
%   zarrPath  - string, root Zarr directory path
%   schema    - struct, schema-compliant data structure
%   groupPath - string, relative path within Zarr (use "" for root)
%
% Name-Value Arguments:
%   Overwrite - logical (default true), overwrite existing arrays
%   Strict    - logical (default true), validate schema compliance
%
% Description:
%   Recursively traverses schema structure and writes to Zarr:
%   - Groups: creates directories with .zgroup and .zattrs
%   - Datasets: creates arrays with .zarray, binary chunks, and .zattrs
%   - Attributes: writes to .zattrs as JSON
%   - Automatic index conversion (1-based → 0-based for connectivity)
%   - Sparse matrix support (COO format)
%
% Examples:
%   % Write manifold schema to Zarr
%   schema = M.Attributes;
%   bct.file.zarr.writeFromSchema('mesh.zarr', schema, 'manifold');
%
%   % Write geometry schema
%   geom = M.geometry();
%   schema = bct.schema.geometry(geom);
%   bct.file.zarr.writeFromSchema('mesh.zarr', schema, 'geometry');
%
% See also: bct.file.h5.writeFromSchema, bct.file.zarr.writeArray

arguments
    zarrPath (1,1) string
    schema (1,1) struct
    groupPath (1,1) string
    options.Overwrite (1,1) logical = true
    options.Strict (1,1) logical = true
end

%% Create root if needed
if groupPath == ""
    if ~isfolder(zarrPath)
        mkdir(zarrPath);
    end
end

%% Create group
bct.file.zarr.createGroup(zarrPath, groupPath);

%% Write group attributes
groupAttrs = extractGroupAttributes(schema);
if ~isempty(fieldnames(groupAttrs))
    bct.file.zarr.writeAttrs(zarrPath, groupPath, groupAttrs);
end

%% Process schema fields
fields = fieldnames(schema);
for i = 1:numel(fields)
    field = fields{i};
    value = schema.(field);
    
    % Skip special fields that are attributes
    if startsWith(field, 'attributes') || strcmp(field, 'Attributes')
        continue;
    end
    
    if isstruct(value)
        % Check if this is a dataset or subgroup
        if isDatasetSchema(value)
            % Dataset: write array with attributes
            writeDataset(zarrPath, groupPath, field, value, options);
        else
            % Subgroup: recurse
            subgroupPath = buildPath(groupPath, field);
            writeFromSchema(zarrPath, value, subgroupPath, options);
        end
    end
end

end

%% ========================================================================
%% Helper: Extract group-level attributes
%% ========================================================================
function attrs = extractGroupAttributes(schema)
    attrs = struct();
    
    % Check for .attributes field
    if isfield(schema, 'attributes')
        attrs = schema.attributes;
        return;
    end
    
    % Check for .Attributes field (Manifold convention)
    if isfield(schema, 'Attributes')
        sourceAttrs = schema.Attributes;
        attrFields = fieldnames(sourceAttrs);
        
        for i = 1:numel(attrFields)
            field = attrFields{i};
            value = sourceAttrs.(field);
            
            % Skip nested structs that are subgroups
            if ~isstruct(value) || isscalar(value)
                attrs.(field) = value;
            else
                % Flatten nested structures
                attrs = flattenStruct(attrs, field, value);
            end
        end
    end
end

%% ========================================================================
%% Helper: Check if struct is a dataset schema
%% ========================================================================
function isDataset = isDatasetSchema(s)
    % Dataset schema has both 'value' and 'attributes' fields
    isDataset = isfield(s, 'value') && isfield(s, 'attributes');
end

%% ========================================================================
%% Helper: Write dataset (array + attributes)
%% ========================================================================
function writeDataset(zarrPath, groupPath, fieldName, dataset, options)
    % Construct array path
    arrayPath = buildPath(groupPath, fieldName);
    
    % Extract data and attributes
    data = dataset.value;
    attrs = dataset.attributes;
    
    % Handle empty data
    if isempty(data)
        warning('bct:file:zarr:writeFromSchema:EmptyData', ...
            'Dataset "%s" is empty, skipping.', arrayPath);
        return;
    end
    
    % Check for sparse matrix
    if issparse(data)
        writeSparseMatrix(zarrPath, arrayPath, data, attrs, options);
        return;
    end
    
    % Convert indices if needed (1-based → 0-based)
    if isfield(attrs, 'index_base')
        if attrs.index_base == 0 && isinteger(data)
            % Data should be 0-based, convert from MATLAB's 1-based
            data = data - 1;
        end
    end
    
    % Determine datatype
    dtype = determineDtype(attrs, data);
    
    % Write array
    try
        bct.file.zarr.writeArray(zarrPath, arrayPath, data, ...
            'Datatype', dtype, 'Overwrite', options.Overwrite);
    catch ME
        error('bct:file:zarr:writeFromSchema:WriteArrayFailed', ...
            'Failed to write array "%s": %s', arrayPath, ME.message);
    end
    
    % Write array attributes
    arrayAttrs = prepareArrayAttributes(attrs);
    if ~isempty(fieldnames(arrayAttrs))
        bct.file.zarr.writeAttrs(zarrPath, arrayPath, arrayAttrs);
    end
end

%% ========================================================================
%% Helper: Write sparse matrix as COO format
%% ========================================================================
function writeSparseMatrix(zarrPath, arrayPath, data, attrs, options)
    % Convert sparse matrix to COO (Coordinate) format
    [row, col, val] = find(data);
    
    % Convert to 0-based indexing for row/col
    row = uint32(row - 1);
    col = uint32(col - 1);
    
    % Create group for sparse matrix
    bct.file.zarr.createGroup(zarrPath, arrayPath);
    
    % Write metadata as group attributes
    sparseAttrs = struct();
    sparseAttrs.format = 'coo';
    sparseAttrs.shape = size(data);
    sparseAttrs.nnz = nnz(data);
    sparseAttrs.dtype = class(val);
    
    % Preserve original attributes
    attrFields = fieldnames(attrs);
    for i = 1:numel(attrFields)
        field = attrFields{i};
        if ~strcmp(field, 'shape') && ~strcmp(field, 'dtype')
            sparseAttrs.(field) = attrs.(field);
        end
    end
    
    bct.file.zarr.writeAttrs(zarrPath, arrayPath, sparseAttrs);
    
    % Write COO arrays
    bct.file.zarr.writeArray(zarrPath, buildPath(arrayPath, 'row'), row, ...
        'Datatype', 'uint32', 'Overwrite', options.Overwrite);
    bct.file.zarr.writeArray(zarrPath, buildPath(arrayPath, 'col'), col, ...
        'Datatype', 'uint32', 'Overwrite', options.Overwrite);
    bct.file.zarr.writeArray(zarrPath, buildPath(arrayPath, 'data'), val, ...
        'Datatype', class(val), 'Overwrite', options.Overwrite);
end

%% ========================================================================
%% Helper: Determine Zarr datatype from attributes and data
%% ========================================================================
function dtype = determineDtype(attrs, data)
    % Check for explicit dtype in attributes
    if isfield(attrs, 'dtype')
        dtype = attrs.dtype;
        return;
    end
    
    % Check for dtype_target (preferred for GPU)
    if isfield(attrs, 'dtype_target')
        dtype = attrs.dtype_target;
        return;
    end
    
    % Infer from data type
    matlabType = class(data);
    switch matlabType
        case 'double'
            dtype = 'double';  % Keep precision for operators/eigenmodes
        case 'single'
            dtype = 'single';
        case 'uint32'
            dtype = 'uint32';
        case 'int32'
            dtype = 'int32';
        case 'logical'
            dtype = 'uint8';
        otherwise
            dtype = matlabType;
    end
end

%% ========================================================================
%% Helper: Prepare array attributes (filter and format)
%% ========================================================================
function arrayAttrs = prepareArrayAttributes(attrs)
    arrayAttrs = struct();
    
    % Copy relevant attributes
    attrFields = fieldnames(attrs);
    for i = 1:numel(attrFields)
        field = attrFields{i};
        value = attrs.(field);
        
        % Skip 'value' field
        if strcmp(field, 'value')
            continue;
        end
        
        % Convert arrays to cell arrays for JSON
        if isstring(value) || (ischar(value) && size(value, 1) == 1)
            arrayAttrs.(field) = char(value);
        elseif iscellstr(value) || isstring(value)
            arrayAttrs.(field) = cellstr(value);
        else
            arrayAttrs.(field) = value;
        end
    end
end

%% ========================================================================
%% Helper: Build path (handle empty base path)
%% ========================================================================
function path = buildPath(basePath, field)
    if strlength(basePath) == 0 || basePath == ""
        path = field;
    else
        path = fullfile(basePath, field);
    end
end

%% ========================================================================
%% Helper: Flatten nested structures for attributes
%% ========================================================================
function attrs = flattenStruct(attrs, prefix, s)
    fields = fieldnames(s);
    for i = 1:numel(fields)
        field = fields{i};
        value = s.(field);
        flatKey = [prefix '_' field];
        
        if isstruct(value)
            attrs = flattenStruct(attrs, flatKey, value);
        else
            attrs.(flatKey) = value;
        end
    end
end
