function core(zarrPath, F, options)
%CORE Write field data to Zarr
%
% Syntax:
%   bct.file.write.field.zarr.core(zarrPath, F, 'Path', '/fields/activation')
%
% Inputs:
%   zarrPath - string, Zarr directory path
%   F        - bct.Field object or array of Field objects
%
% Name-Value Arguments:
%   Path      - string (required), Zarr path for field (e.g., '/fields/activation')
%   Overwrite - logical (default true), overwrite existing data
%   Strict    - logical (default true), validate schema compliance
%
% Description:
%   Writes field data to Zarr:
%   - Field value array
%   - Field attributes (support, valueType, units, etc.)
%   - Time metadata if field is time-varying
%   
%   Uses schema-driven serialization.
%
% Examples:
%   F = bct.Field(M, values);
%   bct.file.write.field.zarr.core('mesh.zarr', F, 'Path', '/fields/activation');
%
% See also: bct.file.zarr.writeFromSchema, bct.schema.field

arguments
    zarrPath (1,1) string
    F
    options.Path (1,1) string
    options.Overwrite (1,1) logical = true
    options.Strict (1,1) logical = true
end

%% Validate input
if ~isa(F, 'bct.Field')
    error('bct:file:write:field:zarr:core:InvalidInput', ...
        'Input must be a bct.Field object.');
end

%% Create field group
bct.file.zarr.createGroup(zarrPath, options.Path);

%% Write field value
valuePath = fullfile(options.Path, 'value');
data = F.value;

% Determine dtype (float32 for fields by default)
if isfloat(data)
    dtype = 'single';
else
    dtype = class(data);
end

bct.file.zarr.writeArray(zarrPath, valuePath, data, ...
    'Datatype', dtype, 'Overwrite', options.Overwrite);

%% Write value attributes
valueAttrs = struct();
if isfield(F.Attributes, 'support')
    valueAttrs.support = F.Attributes.support;
end
if isfield(F.Attributes, 'valueType')
    valueAttrs.valueType = F.Attributes.valueType;
end
if isfield(F.Attributes, 'units')
    valueAttrs.units = F.Attributes.units;
end
valueAttrs.shape = size(data);
valueAttrs.dtype = dtype;

bct.file.zarr.writeAttrs(zarrPath, valuePath, valueAttrs);

%% Write field group attributes
fieldAttrs = struct();
if isfield(F.Attributes, 'name')
    fieldAttrs.name = F.Attributes.name;
end
if isfield(F.Attributes, 'description')
    fieldAttrs.description = F.Attributes.description;
end
if isfield(F.Attributes, 'support')
    fieldAttrs.support = F.Attributes.support;
end
if isfield(F.Attributes, 'valueType')
    fieldAttrs.valueType = F.Attributes.valueType;
end

bct.file.zarr.writeAttrs(zarrPath, options.Path, fieldAttrs);

%% Write time metadata if present
if isfield(F.Attributes, 'time') && ~isempty(F.Attributes.time)
    timePath = fullfile(options.Path, 'time');
    timeData = F.Attributes.time;
    
    bct.file.zarr.writeArray(zarrPath, timePath, timeData, ...
        'Datatype', class(timeData), 'Overwrite', options.Overwrite);
    
    timeAttrs = struct();
    timeAttrs.name = 'time';
    timeAttrs.units = 's';
    timeAttrs.shape = size(timeData);
    bct.file.zarr.writeAttrs(zarrPath, timePath, timeAttrs);
end

end
