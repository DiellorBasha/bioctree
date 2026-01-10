function F = load(id, options)
%BCT.FIELDS.LOAD Load bundled field test data
%
% Syntax:
%   F = bct.fields.load()                    % Load default
%   F = bct.fields.load(id)                  % Load by ID
%   F = bct.fields.load(Name=Value)          % Load by attributes
%
% Inputs:
%   id - Field asset ID string (e.g., "scalarField_test_vertex")
%
% Optional Parameters (for attribute-based selection):
%   Support    - Support type: "vertex" | "face" | "edge"
%   ValueType  - Value type: "scalar" | "vector3" | "tangent2"
%   Dataset    - Dataset name (e.g., "test", "demo")
%   MeshId     - Associated mesh ID (optional)
%
% Outputs:
%   F - Field struct conforming to bct.fields.schema
%       .schemaVersion - Schema version string
%       .support       - Support type
%       .valueType     - Value type
%       .value         - Numeric array
%       .meshId        - Mesh identifier (if specified)
%       .time          - Time struct (if time-varying)
%       .frame         - Frame basis (if tangent2)
%       .metadata      - Additional metadata
%
% Examples:
%   % Load default field
%   F = bct.fields.load();
%   
%   % Load by ID
%   F = bct.fields.load("scalarField_test_vertex");
%   
%   % Load by attributes
%   F = bct.fields.load(Support="vertex", ValueType="scalar");
%   F = bct.fields.load(Dataset="test", Support="face");
%
% See also: bct.fields.make, bct.data.load, bct.data.index

arguments
    id (1,1) string = ""
    options.Support (1,1) string = ""
    options.ValueType (1,1) string = ""
    options.Dataset (1,1) string = ""
    options.MeshId (1,1) string = ""
end

% Get field catalog from bct.data.index
catalog = bct.data.index();

% Filter to only field entries (check if FieldType == "field")
isField = arrayfun(@(x) string(x.FieldType) == "field", catalog);
fieldCatalog = catalog(isField);

if isempty(fieldCatalog)
    error('bct:fields:NoCatalog', ...
        'No field assets found in catalog. Check bct.data.index().');
end

% Determine which asset to load
if id == "" && options.Support == "" && options.ValueType == "" && ...
        options.Dataset == "" && options.MeshId == ""
    % Load default
    idx = find(arrayfun(@(x) isfield(x, 'Default') && x.Default, fieldCatalog), 1);
    if isempty(idx)
        error('bct:fields:NoDefault', 'No default field asset found in catalog');
    end
    entry = fieldCatalog(idx);
    
elseif id ~= ""
    % Load by ID
    ids = string({fieldCatalog.Id});
    idx = find(ids == id, 1);
    if isempty(idx)
        error('bct:fields:UnknownID', 'Field asset ID "%s" not found in catalog', id);
    end
    entry = fieldCatalog(idx);
    
else
    % Load by attributes
    mask = true(size(fieldCatalog));
    
    if options.Support ~= ""
        supports = arrayfun(@(x) string(x.FieldSupport), fieldCatalog);
        mask = mask & (supports == options.Support);
    end
    
    if options.ValueType ~= ""
        valueTypes = arrayfun(@(x) string(x.FieldValueType), fieldCatalog);
        mask = mask & (valueTypes == options.ValueType);
    end
    
    if options.Dataset ~= ""
        datasets = string({fieldCatalog.Dataset});
        mask = mask & (datasets == options.Dataset);
    end
    
    if options.MeshId ~= ""
        % Filter by meshId (if present in catalog entries)
        meshIdMask = false(size(fieldCatalog));
        for i = 1:numel(fieldCatalog)
            if isfield(fieldCatalog(i), 'FieldMeshId') && ...
                    string(fieldCatalog(i).FieldMeshId) == options.MeshId
                meshIdMask(i) = true;
            end
        end
        mask = mask & meshIdMask;
    end
    
    idx = find(mask, 1);
    if isempty(idx)
        error('bct:fields:NoMatch', ...
            'No field asset matches: Support=%s, ValueType=%s, Dataset=%s', ...
            options.Support, options.ValueType, options.Dataset);
    end
    
    entry = fieldCatalog(idx);
end

% Build full path
data_dir = fileparts(fileparts(mfilename('fullpath')));  % Go up to +bct
data_assets_dir = fullfile(data_dir, '+data', 'assets', 'fields');
full_path = fullfile(data_assets_dir, entry.FieldPath);

% Verify file exists
if ~exist(full_path, 'file')
    error('bct:fields:FileNotFound', ...
        'Field asset file not found: %s', full_path);
end

% Load raw data
try
    data = load(full_path, '-mat');
catch ME
    error('bct:fields:LoadFailed', ...
        'Failed to load field asset "%s": %s', entry.Id, ME.message);
end

% Extract field data based on catalog metadata
support = entry.FieldSupport;
valueType = entry.FieldValueType;

% Try to find value array - check common variable names
valueArray = [];
possibleNames = {'value', 'scalarField', 'vectorField', 'data', 'field', 'F', 'V'};

for i = 1:numel(possibleNames)
    if isfield(data, possibleNames{i})
        valueArray = data.(possibleNames{i});
        break;
    end
end

% If not found by name, take the first numeric array
if isempty(valueArray)
    fields = fieldnames(data);
    for i = 1:numel(fields)
        if isnumeric(data.(fields{i}))
            valueArray = data.(fields{i});
            break;
        end
    end
end

if isempty(valueArray)
    error('bct:fields:NoValueData', ...
        'Could not find numeric value array in file: %s', full_path);
end

% Build Field struct using bct.fields.make
makeArgs = {
    'support', support, ...
    'valueType', valueType, ...
    'value', valueArray
};

% Add meshId if present in catalog
if isfield(entry, 'FieldMeshId') && ~isempty(entry.FieldMeshId)
    makeArgs = [makeArgs, {'meshId', entry.FieldMeshId}];
end

% Add time info if present in catalog
if isfield(entry, 'FieldTime') && ~isempty(entry.FieldTime)
    makeArgs = [makeArgs, {'time', entry.FieldTime}];
end

% Add frame if present in file (for tangent2)
if strcmp(valueType, 'tangent2') && isfield(data, 'frame')
    makeArgs = [makeArgs, {'frame', data.frame}];
end

% Build metadata from catalog
metadata = struct();
metadata.Id = entry.Id;
metadata.Dataset = entry.Dataset;
metadata.SourceFile = entry.FieldPath;

if isfield(entry, 'Tags')
    metadata.Tags = entry.Tags;
end

% Merge any metadata from file
if isfield(data, 'metadata')
    fileMeta = data.metadata;
    metaFields = fieldnames(fileMeta);
    for i = 1:numel(metaFields)
        field = metaFields{i};
        if ~isfield(metadata, field)
            metadata.(field) = fileMeta.(field);
        end
    end
end

makeArgs = [makeArgs, {'metadata', metadata}];

% Create validated Field struct
try
    F = bct.fields.make(makeArgs{:});
catch ME
    error('bct:fields:ValidationFailed', ...
        'Failed to validate loaded field "%s": %s', entry.Id, ME.message);
end

end
