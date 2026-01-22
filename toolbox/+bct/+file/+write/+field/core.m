function core(file, F, options)
%CORE Write core field data (value + attributes) to HDF5
%
% Syntax:
%   bct.file.write.field.core(file, F)
%   bct.file.write.field.core(file, F, 'Path', '/fields/myfield')
%
% Inputs:
%   file - string, HDF5 file path (must exist)
%   F    - bct.Field object
%
% Name-Value Arguments:
%   Path      - string (default auto), HDF5 path for field group
%   Overwrite - logical (default true), overwrite existing datasets
%   Strict    - logical (default true), validate schema compliance
%
% Description:
%   Writes field data to HDF5:
%   - Field value array
%   - Field attributes (name, support, valueType, units, etc.)
%   - Time metadata if time-varying
%
% Examples:
%   F = bct.Field(M, data, 'Support', 'vertex', 'ValueType', 'scalar');
%   bct.file.create('fields.h5');
%   bct.file.write.field.core('fields.h5', F, 'Path', '/fields/activation');
%
% See also: bct.file.write.field, bct.Field

arguments
    file (1,1) string
    F (1,1) bct.Field
    options.Path (1,1) string = ""
    options.Overwrite (1,1) logical = true
    options.Strict (1,1) logical = true
end

%% Validate file exists
if ~isfile(file)
    error('bct:file:write:field:core:FileNotFound', ...
        'File "%s" does not exist. Use bct.file.create first.', file);
end

%% Determine path
if options.Path == ""
    % Auto-generate path from field name if available
    if isfield(F.Attributes, 'name')
        fieldName = char(F.Attributes.name);
    else
        fieldName = 'field';
    end
    fieldPath = sprintf('/fields/%s', fieldName);
else
    fieldPath = char(options.Path);
end

%% Build schema-compliant structure
fieldAttrs = struct();
fieldAttrs.path = fieldPath;
fieldAttrs.schema = 'bct.field@1.0';
fieldAttrs.package = 'bct.field';

% Add field attributes
if isfield(F.Attributes, 'name')
    fieldAttrs.name = F.Attributes.name;
end
if isfield(F.Attributes, 'description')
    fieldAttrs.description = F.Attributes.description;
end

% Create dataset for field value
fieldAttrs.value = bct.schema.dataset.make(F.value, ...
    'Name', 'value', ...
    'Path', [fieldPath '/value'], ...
    'Description', 'Field data values', ...
    'Units', char(F.Attributes.units), ...
    'Support', char(F.Attributes.support), ...
    'ComputedBy', 'bct.Field');

% Add time metadata if time-varying
if isfield(F.Attributes, 'time') && ~isempty(F.Attributes.time)
    timeData = F.Attributes.time;
    if isnumeric(timeData)
        fieldAttrs.time = bct.schema.dataset.make(timeData, ...
            'Name', 'time', ...
            'Path', [fieldPath '/time'], ...
            'Description', 'Time points', ...
            'Units', 's', ...
            'Support', 'time', ...
            'ComputedBy', 'bct.Field');
    end
end

%% Write using schema-driven serialization
bct.file.h5.writeFromSchema(file, fieldAttrs, ...
    'CreateFile', false, ...
    'Overwrite', options.Overwrite, ...
    'Strict', options.Strict);

end
