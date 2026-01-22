function F = core(file, options)
%CORE Read core field data from HDF5
%
% Syntax:
%   F = bct.file.read.field.core(file)
%   F = bct.file.read.field.core(file, 'Path', '/fields/activation')
%
% Inputs:
%   file - string, HDF5 file path
%
% Name-Value Arguments:
%   Path     - string (required), HDF5 path to field group
%   Manifold - bct.Manifold (optional), manifold object for Field construction
%
% Outputs:
%   F - bct.Field object or struct (if Manifold not provided)
%
% Description:
%   Reads field data from HDF5:
%   - Field value array
%   - Field attributes (support, valueType, units, etc.)
%   - Time metadata if present
%
% Examples:
%   % Read field with manifold
%   M = bct.file.read.manifold.core('mesh.h5');
%   F = bct.file.read.field.core('mesh.h5', 'Path', '/fields/activation', 'Manifold', M);
%
%   % Read field data only (returns struct)
%   data = bct.file.read.field.core('mesh.h5', 'Path', '/fields/activation');
%
% See also: bct.file.read.field, bct.Field

arguments
    file (1,1) string
    options.Path (1,1) string
    options.Manifold = []
end

%% Validate file exists
if ~isfile(file)
    error('bct:file:read:field:core:FileNotFound', ...
        'File "%s" does not exist.', file);
end

%% Read field value
fieldPath = char(options.Path);
valuePath = [fieldPath '/value'];

try
    value = h5read(file, valuePath);
catch ME
    error('bct:file:read:field:core:ReadFailed', ...
        'Failed to read field value from "%s": %s', valuePath, ME.message);
end

%% Read field attributes
try
    dsInfo = h5info(file, valuePath);
    attrs = struct();
    
    for i = 1:numel(dsInfo.Attributes)
        attrName = dsInfo.Attributes(i).Name;
        attrValue = dsInfo.Attributes(i).Value;
        
        switch attrName
            case 'support'
                attrs.support = char(attrValue);
            case 'units'
                attrs.units = char(attrValue);
            case 'name'
                attrs.name = char(attrValue);
            case 'description'
                attrs.description = char(attrValue);
        end
    end
catch ME
    warning('bct:file:read:field:core:AttributeReadFailed', ...
        'Failed to read field attributes: %s', ME.message);
    attrs = struct('support', 'unknown', 'units', '1');
end

%% Read time data if present
try
    timePath = [fieldPath '/time'];
    timeData = h5read(file, timePath);
    attrs.time = timeData;
catch
    % No time data present
end

%% Create Field object if Manifold provided
if ~isempty(options.Manifold)
    % Construct bct.Field
    F = bct.Field(options.Manifold, value);
    % Set attributes
    if isfield(attrs, 'support')
        F.Attributes.support = attrs.support;
    end
    if isfield(attrs, 'units')
        F.Attributes.units = attrs.units;
    end
    if isfield(attrs, 'name')
        F.Attributes.name = attrs.name;
    end
    if isfield(attrs, 'description')
        F.Attributes.description = attrs.description;
    end
    if isfield(attrs, 'time')
        F.Attributes.time = attrs.time;
    end
else
    % Return struct with value and attributes
    F = struct();
    F.value = value;
    F.attributes = attrs;
end

end
