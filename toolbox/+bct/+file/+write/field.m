function field(file, F, options)
%FIELD Write bct.Field to HDF5 or Zarr using schema-driven serialization
%
% Syntax:
%   bct.file.write.field(file, F)
%   bct.file.write.field(file, F, 'Format', 'zarr')
%
% Inputs:
%   file - string, file path (.h5 for HDF5, .zarr for Zarr, or use Format option)
%   F    - bct.Field object or array of Field objects
%
% Name-Value Arguments:
%   Format     - string (default auto from extension), 'h5' or 'zarr'
%   Overwrite  - logical (default true), overwrite existing datasets
%   Strict     - logical (default true), validate schema compliance
%   Path       - string (default auto), path for field(s)
%   GroupPath  - string (default '/fields'), parent group for multiple fields
%
% Description:
%   Writes Field objects to HDF5 or Zarr with schema-compliant structure.
%   Format is auto-detected from extension or specified explicitly.
%   - Single field: writes to specified Path or auto-generates
%   - Multiple fields: writes each to GroupPath/<fieldname>
%
% Examples:
%   % Write single field to HDF5
%   F = bct.Field(M, data, 'Support', 'vertex', 'ValueType', 'scalar');
%   bct.file.write.field('data.h5', F);
%
%   % Write single field to Zarr
%   bct.file.write.field('data.zarr', F);
%
%   % Write multiple fields
%   F1 = bct.Field(M, data1, 'Support', 'vertex', 'Name', 'activation');
%   F2 = bct.Field(M, data2, 'Support', 'vertex', 'Name', 'thickness');
%   bct.file.write.field('data.zarr', [F1, F2]);
%
%   % Write with custom path
%   bct.file.write.field('data.zarr', F, 'Path', '/analysis/result');
%
% Modular Functions:
%   For writing specific field components:
%   - bct.file.write.field.core(file, F, 'Path', path)         % HDF5
%   - bct.file.write.field.zarr.core(zarr, F, 'Path', path)   % Zarr
%
% See also: bct.file.write.field.core, bct.Field, bct.file.h5.writeFromSchema

arguments
    file (1,1) string
    F  % bct.Field or array of Field objects
    options.Format (1,1) string = ""
    options.Overwrite (1,1) logical = true
    options.Strict (1,1) logical = true
    options.Path (1,1) string = ""
    options.GroupPath (1,1) string = "/fields"
end

%% Detect format from extension or Format option
if options.Format == ""
    % Auto-detect from extension
    [~, ~, ext] = fileparts(file);
    if strcmpi(ext, '.zarr')
        format = 'zarr';
    elseif strcmpi(ext, '.h5') || strcmpi(ext, '.hdf5')
        format = 'h5';
    else
        error('bct:file:write:field:UnknownFormat', ...
            'Cannot detect format from extension "%s". Use Format option.', ext);
    end
else
    format = lower(options.Format);
    if ~ismember(format, {'h5', 'hdf5', 'zarr'})
        error('bct:file:write:field:InvalidFormat', ...
            'Format must be ''h5'', ''hdf5'', or ''zarr''.');
    end
    if strcmp(format, 'hdf5')
        format = 'h5';
    end
end

%% Dispatch to format-specific writer
if strcmp(format, 'zarr')
    writeFieldZarr(file, F, options);
    return;
end

%% HDF5 writer (existing code)
%% Validate file exists
if ~isfile(file)
    error('bct:file:write:field:FileNotFound', ...
        'File "%s" does not exist. Use CreateFile=true or bct.file.create.', file);
end

%% Handle single vs multiple fields
numFields = numel(F);

if numFields == 1
    %% Single field
    if options.Path == ""
        % Auto-generate path
        if isfield(F.Attributes, 'name')
            fieldName = char(F.Attributes.name);
        else
            fieldName = 'field';
        end
        fieldPath = sprintf('%s/%s', options.GroupPath, fieldName);
    else
        fieldPath = options.Path;
    end
    
    fprintf('Writing Field to: %s\n', file);
    bct.file.write.field.core(file, F, ...
        'Path', fieldPath, ...
        'Overwrite', options.Overwrite, ...
        'Strict', options.Strict);
    
    fprintf('  ✓ Field: %s\n', fieldPath);
    fprintf('    Support: %s\n', F.Attributes.support);
    fprintf('    ValueType: %s\n', F.Attributes.valueType);
    fprintf('    Shape: %s\n', mat2str(size(F.value)));
    
else
    %% Multiple fields
    fprintf('Writing %d Fields to: %s\n', numFields, file);
    
    for i = 1:numFields
        Fi = F(i);
        
        % Determine path for this field
        if isfield(Fi.Attributes, 'name')
            fieldName = char(Fi.Attributes.name);
        else
            fieldName = sprintf('field_%d', i);
        end
        fieldPath = sprintf('%s/%s', options.GroupPath, fieldName);
        
        % Write field
        try
            bct.file.write.field.core(file, Fi, ...
                'Path', fieldPath, ...
                'Overwrite', options.Overwrite, ...
                'Strict', options.Strict);
            
            fprintf('  ✓ Field %d/%d: %s\n', i, numFields, fieldPath);
        catch ME
            warning('bct:file:write:field:WriteFailed', ...
                'Failed to write field %d: %s', i, ME.message);
        end
    end
end

fprintf('✓ Write complete\n');

end

%% ========================================================================
%% Helper: Write field to Zarr
%% ========================================================================
function writeFieldZarr(zarrPath, F, options)
    % Create Zarr root if needed
    if ~isfolder(zarrPath)
        mkdir(zarrPath);
        bct.file.zarr.createGroup(zarrPath, '');
    end
    
    % Validate input
    if ~isa(F, 'bct.Field')
        error('bct:file:write:field:InvalidInput', ...
            'Input must be a bct.Field object or array.');
    end
    
    numFields = numel(F);
    
    if numFields == 1
        %% Single field
        % Determine path
        if options.Path == ""
            if isfield(F.Attributes, 'name')
                fieldName = char(F.Attributes.name);
            else
                fieldName = 'field';
            end
            fieldPath = sprintf('/fields/%s', fieldName);
        else
            fieldPath = char(options.Path);
        end
        
        % Write field
        fprintf('Writing Field to Zarr: %s\n', zarrPath);
        bct.file.write.field.zarr.core(zarrPath, F, ...
            'Path', fieldPath, ...
            'Overwrite', options.Overwrite, ...
            'Strict', options.Strict);
        
        fprintf('  Path: %s\n', fieldPath);
        fprintf('  Support: %s\n', F.Attributes.support);
        fprintf('  ValueType: %s\n', F.Attributes.valueType);
        fprintf('  Shape: %s\n', mat2str(size(F.value)));
        
    else
        %% Multiple fields
        fprintf('Writing %d Fields to Zarr: %s\n', numFields, zarrPath);
        
        for i = 1:numFields
            Fi = F(i);
            
            % Determine path for this field
            if isfield(Fi.Attributes, 'name')
                fieldName = char(Fi.Attributes.name);
            else
                fieldName = sprintf('field_%d', i);
            end
            fieldPath = sprintf('%s/%s', options.GroupPath, fieldName);
            
            % Write field
            try
                bct.file.write.field.zarr.core(zarrPath, Fi, ...
                    'Path', fieldPath, ...
                    'Overwrite', options.Overwrite, ...
                    'Strict', options.Strict);
                
                fprintf('  ✓ Field %d/%d: %s\n', i, numFields, fieldPath);
            catch ME
                warning('bct:file:write:field:zarr:WriteFailed', ...
                    'Failed to write field %d: %s', i, ME.message);
            end
        end
    end
    
    fprintf('✓ Zarr write complete\n');
end
