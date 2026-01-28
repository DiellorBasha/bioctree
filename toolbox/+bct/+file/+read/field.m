function F = field(file, options)
%FIELD Read field data from HDF5 with auto-detection
%
% Syntax:
%   F = bct.file.read.field(file)
%   F = bct.file.read.field(file, 'Path', '/fields/activation')
%   F = bct.file.read.field(file, 'GroupPath', '/fields')
%
% Inputs:
%   file - string, HDF5 file path
%
% Name-Value Arguments:
%   Path        - string (optional), HDF5 path to single field group
%   GroupPath   - string (optional), HDF5 path to parent group containing multiple fields
%   Manifold    - bct.Manifold (optional), manifold for Field construction
%   ReadMultiple - logical, if true and GroupPath provided, read all fields in group (default: false)
%
% Outputs:
%   F - bct.Field object or array of Field objects
%
% Description:
%   Reads field data from HDF5 with automatic detection:
%   - Single field: Use 'Path' option
%   - Multiple fields: Use 'GroupPath' and 'ReadMultiple' options
%   - Auto-detection: If neither Path nor GroupPath provided, searches for '/fields' group
%
% Examples:
%   % Read single field
%   M = bct.file.read.manifold('mesh.h5');
%   F = bct.file.read.field('mesh.h5', 'Path', '/fields/activation', 'Manifold', M);
%
%   % Read all fields in group
%   fields = bct.file.read.field('mesh.h5', 'GroupPath', '/fields', ...
%                                 'ReadMultiple', true, 'Manifold', M);
%
%   % Auto-detect and read first field
%   F = bct.file.read.field('mesh.h5', 'Manifold', M);
%
% See also: bct.file.read.field.core, bct.file.write.field

arguments
    file (1,1) string
    options.Path (1,1) string = ""
    options.GroupPath (1,1) string = ""
    options.Manifold = []
    options.ReadMultiple (1,1) logical = false
end

%% Validate file exists
if ~isfile(file)
    error('bct:file:read:field:FileNotFound', ...
        'File "%s" does not exist.', file);
end

%% Determine read mode
if options.Path ~= ""
    % Single field mode
    F = readSingleField(file, options.Path, options.Manifold);
    
elseif options.GroupPath ~= ""
    % Multiple field mode
    if options.ReadMultiple
        F = readMultipleFields(file, options.GroupPath, options.Manifold);
    else
        error('bct:file:read:field:InvalidOptions', ...
            'GroupPath provided but ReadMultiple=false. Set ReadMultiple=true or use Path option.');
    end
    
else
    % Auto-detection mode
    F = autoDetectAndRead(file, options.Manifold);
end

end

%% Helper: Read single field
function F = readSingleField(file, path, manifold)
    fprintf('Reading field from "%s"\n', path);
    F = bct.file.read.field.core(file, 'Path', path, 'Manifold', manifold);
end

%% Helper: Read multiple fields
function F = readMultipleFields(file, groupPath, manifold)
    % Get list of subgroups
    try
        groupInfo = h5info(file, char(groupPath));
    catch ME
        error('bct:file:read:field:GroupNotFound', ...
            'Failed to read group "%s": %s', groupPath, ME.message);
    end
    
    % Check for field subgroups
    nFields = numel(groupInfo.Groups);
    if nFields == 0
        warning('bct:file:read:field:NoFields', ...
            'No field subgroups found in "%s".', groupPath);
        F = [];
        return;
    end
    
    % Read each field
    fprintf('Reading %d fields from "%s"\n', nFields, groupPath);
    F = repmat(bct.Field.empty, nFields, 1);
    
    for i = 1:nFields
        fieldPath = groupInfo.Groups(i).Name;
        try
            F(i) = bct.file.read.field.core(file, 'Path', fieldPath, 'Manifold', manifold);
            fprintf('  [%d/%d] Read field: %s\n', i, nFields, fieldPath);
        catch ME
            warning('bct:file:read:field:FieldReadFailed', ...
                'Failed to read field "%s": %s', fieldPath, ME.message);
        end
    end
end

%% Helper: Auto-detect and read
function F = autoDetectAndRead(file, manifold)
    % Try standard '/fields' location
    defaultPath = '/fields';
    
    if groupExists(file, defaultPath)
        % Check if it has subgroups
        groupInfo = h5info(file, defaultPath);
        nFields = numel(groupInfo.Groups);
        
        if nFields > 0
            fprintf('Auto-detected %d fields in "%s"\n', nFields, defaultPath);
            
            if nFields == 1
                % Read single field
                fieldPath = groupInfo.Groups(1).Name;
                F = readSingleField(file, fieldPath, manifold);
            else
                % Multiple fields - ask user or read first
                fprintf('Multiple fields found. Reading first field only.\n');
                fprintf('Use ''GroupPath'' and ''ReadMultiple'' options to read all fields.\n');
                fieldPath = groupInfo.Groups(1).Name;
                F = readSingleField(file, fieldPath, manifold);
            end
        else
            error('bct:file:read:field:NoFields', ...
                'Group "%s" exists but contains no field subgroups.', defaultPath);
        end
    else
        error('bct:file:read:field:AutoDetectFailed', ...
            'No fields found. Standard "/fields" group does not exist.\n%s', ...
            'Specify path explicitly using ''Path'' or ''GroupPath'' option.');
    end
end

%% Helper: Check if group exists
function exists = groupExists(file, groupPath)
    try
        h5info(file, char(groupPath));
        exists = true;
    catch
        exists = false;
    end
end
