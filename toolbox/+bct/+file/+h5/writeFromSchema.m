function writeFromSchema(file, attrs, options)
%WRITEFROMSCHEMA Write HDF5 file structure from BCT schema-compliant attributes
%
% Syntax:
%   bct.file.h5.writeFromSchema(file, attrs)
%   bct.file.h5.writeFromSchema(file, attrs, 'CreateFile', true)
%
% Inputs:
%   file  - string, HDF5 file path
%   attrs - BCT schema-compliant attribute structure with:
%           .path        - hierarchical path (e.g., '/manifold')
%           .schema      - schema identifier (e.g., 'bct.Manifold@1.1')
%           .package     - source package (e.g., 'bct')
%           .<datasets>  - dataset structures with .value and .attributes
%           .<subgroups> - nested group structures (recursive)
%
% Name-Value Arguments:
%   CreateFile - logical (default false), create file if it doesn't exist
%   Overwrite  - logical (default true), overwrite existing datasets
%   Strict     - logical (default true), validate schema compliance
%
% Description:
%   Schema-driven HDF5 serialization that:
%   - Creates hierarchical group structure from .path fields
%   - Writes datasets from .value fields
%   - Writes HDF5 attributes from .attributes metadata
%   - Recursively processes nested groups and subgroups
%   - Validates schema compliance using bct.schema.* validators
%
% Examples:
%   % Write Manifold to HDF5
%   M = bct.Manifold.read('mesh.obj');
%   attrs = M.Attributes;
%   bct.file.h5.writeFromSchema('mesh.h5', attrs, 'CreateFile', true);
%
%   % Update existing HDF5 with new group
%   geomAttrs = M.geometry();  % Returns schema-compliant struct
%   bct.file.h5.writeFromSchema('mesh.h5', geomAttrs);
%
% Schema Structure:
%   The input attrs struct must follow bct.schema conventions:
%
%   Group attributes (bct.schema.group):
%     .path    - HDF5 path string (e.g., '/manifold', '/geometry')
%     .schema  - schema identifier with version
%     .package - source package name
%     .ID      - unique identifier (optional)
%
%   Dataset attributes (bct.schema.dataset):
%     .<name>.value      - actual data array
%     .<name>.attributes - dataset metadata struct with:
%       .name        - dataset name
%       .path        - full HDF5 path
%       .description - human-readable description
%       .shape       - data dimensions
%       .dtype       - MATLAB data type
%       .units       - physical units (optional)
%       .support     - geometric support (optional)
%       .computedBy  - source function
%
%   Nested groups (recursive):
%     .<subgroup> - nested struct with same schema structure
%
% File Structure Generated:
%   /<group>/                      # Group with attributes
%     @path        = "/<group>"
%     @schema      = "bct.Package@1.0"
%     @package     = "bct"
%     @ID          = "uuid-string"
%     /<dataset>                   # Dataset with attributes
%       @name        = "dataset"
%       @description = "Dataset description"
%       @shape       = [N, M]
%       @dtype       = "double"
%       @units       = "m"
%     /<subgroup>/                 # Nested group (recursive)
%       ...
%
% See also: bct.schema.group, bct.schema.dataset, bct.file.h5.writeGroup,
%           bct.file.h5.writeDataset, bct.file.h5.writeAttribute

arguments
    file (1,1) string
    attrs (1,1) struct
    options.CreateFile (1,1) logical = false
    options.Overwrite (1,1) logical = true
    options.Strict (1,1) logical = true
end

%% Create file if requested
if options.CreateFile && ~isfile(file)
    bct.file.create(file);
end

%% Validate file exists
if ~isfile(file)
    error('bct:file:h5:writeFromSchema:FileNotFound', ...
        'File "%s" does not exist. Use CreateFile=true or create manually.', file);
end

%% Validate schema compliance if strict
if options.Strict
    try
        bct.schema.group.validate(attrs);
    catch ME
        warning('bct:file:h5:writeFromSchema:ValidationWarning', ...
            'Schema validation failed: %s\nProceeding with write...', ME.message);
    end
end

%% Write group structure recursively
writeGroup(file, attrs, options.Overwrite);

end

%% ========================================================================
%% RECURSIVE GROUP WRITER
%% ========================================================================
function writeGroup(file, attrs, overwrite)
%WRITEGROUP Recursively write group, datasets, and subgroups
%
% Group Attributes (top-level metadata):
%   - path, schema, package, ID, etc.
%
% Datasets (fields with .value and .attributes):
%   - Written as HDF5 datasets with attributes
%
% Subgroups (nested structs with .path):
%   - Recursively processed

% Get group path
if ~isfield(attrs, 'path')
    error('bct:file:h5:writeFromSchema:MissingPath', ...
        'Group attributes must have .path field');
end
groupPath = char(attrs.path);

% Ensure group exists
bct.file.h5.ensureGroup(file, groupPath);

% Write group-level attributes
writeGroupAttributes(file, groupPath, attrs);

% Process all fields
fieldNames = fieldnames(attrs);
for i = 1:numel(fieldNames)
    fieldName = fieldNames{i};
    fieldValue = attrs.(fieldName);
    
    % Skip group-level metadata fields
    if ismember(fieldName, {'path', 'schema', 'package', 'ID', 'Name', 'Source', ...
            'CreatedAt', 'CreatedBy', 'Metric', 'FaceWinding', 'NormalConvention', ...
            'CoordinateSystem', 'IndexBase'})
        continue;
    end
    
    % Check if this is a dataset (has .value and .attributes)
    if isstruct(fieldValue) && isfield(fieldValue, 'value') && isfield(fieldValue, 'attributes')
        % This is a BCT dataset - write it
        writeDataset(file, fieldValue, overwrite);
    elseif isstruct(fieldValue) && isfield(fieldValue, 'path')
        % This is a nested group - recurse
        writeGroup(file, fieldValue, overwrite);
    end
    % Ignore other fields (scalars, arrays without schema structure)
end

end

%% ========================================================================
%% WRITE GROUP ATTRIBUTES
%% ========================================================================
function writeGroupAttributes(file, groupPath, attrs)
%WRITEGROUPATTRIBUTES Write group-level HDF5 attributes

% Core group attributes (always write)
if isfield(attrs, 'schema')
    bct.file.h5.writeAttribute(file, groupPath, 'schema', char(attrs.schema));
end
if isfield(attrs, 'package')
    bct.file.h5.writeAttribute(file, groupPath, 'package', char(attrs.package));
end
if isfield(attrs, 'path')
    bct.file.h5.writeAttribute(file, groupPath, 'path', char(attrs.path));
end

% Optional metadata
if isfield(attrs, 'ID')
    bct.file.h5.writeAttribute(file, groupPath, 'id', char(attrs.ID));
end
if isfield(attrs, 'Name')
    bct.file.h5.writeAttribute(file, groupPath, 'name', char(attrs.Name));
end
if isfield(attrs, 'Source')
    bct.file.h5.writeAttribute(file, groupPath, 'source', char(attrs.Source));
end
if isfield(attrs, 'CreatedAt')
    if isdatetime(attrs.CreatedAt)
        timeStr = char(attrs.CreatedAt, 'yyyy-MM-dd''T''HH:mm:ss');
    else
        timeStr = char(attrs.CreatedAt);
    end
    bct.file.h5.writeAttribute(file, groupPath, 'created_at', timeStr);
end
if isfield(attrs, 'CreatedBy')
    bct.file.h5.writeAttribute(file, groupPath, 'created_by', char(attrs.CreatedBy));
end

% Manifold-specific attributes
if isfield(attrs, 'FaceWinding')
    bct.file.h5.writeAttribute(file, groupPath, 'face_winding', char(attrs.FaceWinding));
end
if isfield(attrs, 'NormalConvention')
    bct.file.h5.writeAttribute(file, groupPath, 'normal_convention', char(attrs.NormalConvention));
end
if isfield(attrs, 'CoordinateSystem')
    bct.file.h5.writeAttribute(file, groupPath, 'coordinate_system', char(attrs.CoordinateSystem));
end
if isfield(attrs, 'IndexBase')
    bct.file.h5.writeAttribute(file, groupPath, 'matlab_index_base', int32(attrs.IndexBase));
end

% Metric attributes (flattened)
if isfield(attrs, 'Metric')
    metric = attrs.Metric;
    if isfield(metric, 'units')
        bct.file.h5.writeAttribute(file, groupPath, 'metric_units', char(metric.units));
    end
    if isfield(metric, 'rescaled')
        bct.file.h5.writeAttribute(file, groupPath, 'metric_rescaled', int32(metric.rescaled));
    end
    if isfield(metric, 'rescale')
        rescale = metric.rescale;
        if isfield(rescale, 'factor')
            bct.file.h5.writeAttribute(file, groupPath, 'metric_rescale_factor', rescale.factor);
        end
        if isfield(rescale, 'original_units')
            bct.file.h5.writeAttribute(file, groupPath, 'metric_rescale_original_units', char(rescale.original_units));
        end
        if isfield(rescale, 'timestamp')
            bct.file.h5.writeAttribute(file, groupPath, 'metric_rescale_timestamp', char(rescale.timestamp));
        end
    end
end

end

%% ========================================================================
%% WRITE DATASET
%% ========================================================================
function writeDataset(file, dataset, overwrite)
%WRITEDATASET Write BCT dataset to HDF5
%
% Dataset structure:
%   .value      - data array
%   .attributes - metadata struct

% Extract data and metadata
data = dataset.value;
attrs = dataset.attributes;

% Handle empty data (e.g., dual geometry on meshes with boundaries)
if isempty(data)
    % Silently skip - this is expected for optional computations that failed
    return;
end

% Get dataset path
if ~isfield(attrs, 'path')
    error('bct:file:h5:writeFromSchema:MissingDatasetPath', ...
        'Dataset attributes must have .path field');
end
datasetPath = char(attrs.path);

% Handle index conversion for connectivity arrays
% Convert MATLAB 1-based to 0-based for interchange formats
if isfield(attrs, 'support')
    support = char(attrs.support);
    if ismember(support, {'face', 'edge'})
        % Connectivity array - convert to 0-based
        data = data - 1;
    end
end

% Write dataset
bct.file.h5.writeDataset(file, datasetPath, data, 'Overwrite', overwrite);

% Write dataset attributes
writeDatasetAttributes(file, datasetPath, attrs);

end

%% ========================================================================
%% WRITE DATASET ATTRIBUTES
%% ========================================================================
function writeDatasetAttributes(file, datasetPath, attrs)
%WRITEDATASETATTRIBUTES Write dataset-level HDF5 attributes

% Core dataset attributes
if isfield(attrs, 'name')
    bct.file.h5.writeAttribute(file, datasetPath, 'name', char(attrs.name));
end
if isfield(attrs, 'description')
    bct.file.h5.writeAttribute(file, datasetPath, 'description', char(attrs.description));
end
if isfield(attrs, 'shape')
    bct.file.h5.writeAttribute(file, datasetPath, 'shape', int64(attrs.shape));
end
if isfield(attrs, 'dtype')
    bct.file.h5.writeAttribute(file, datasetPath, 'dtype', char(attrs.dtype));
end
if isfield(attrs, 'units')
    bct.file.h5.writeAttribute(file, datasetPath, 'units', char(attrs.units));
end
if isfield(attrs, 'support')
    bct.file.h5.writeAttribute(file, datasetPath, 'support', char(attrs.support));
end
if isfield(attrs, 'computedBy')
    bct.file.h5.writeAttribute(file, datasetPath, 'computed_by', char(attrs.computedBy));
end

% Add index_base for connectivity arrays
if isfield(attrs, 'support')
    support = char(attrs.support);
    if ismember(support, {'face', 'edge'})
        % Exported as 0-based
        bct.file.h5.writeAttribute(file, datasetPath, 'index_base', int32(0));
    end
end

end
