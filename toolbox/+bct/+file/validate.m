function tf = validate(file, options)
%BCT.FILE.VALIDATE  Validate BCT HDF5 file schema consistency
%
%   tf = bct.file.validate(file)
%
% Purpose
%   Validates that a file conforms to BCT manifold HDF5 schema requirements.
%   Checks for required attributes and group structure.
%
% Inputs
%   file - string or char, file path
%
% Name-Value Arguments
%   Strict - logical (default true), enforce strict validation
%            If false, only checks minimal requirements
%   Throw  - logical (default false), throw error on failure
%            If false, returns false and issues warning
%
% Output
%   tf - logical, true if valid
%
% Validation Checks
%   - File exists
%   - Root attribute 'schema' exists and matches expected pattern
%   - Root attribute 'created_utc' exists
%   - Group '/manifold' exists
%   - /manifold attribute 'units_length' exists
%   - /manifold attribute 'index_base_faces' exists
%
% Examples
%   % Validate file (warning on failure)
%   if ~bct.file.validate("mesh.h5")
%       error("Invalid file");
%   end
%
%   % Strict validation (error on failure)
%   bct.file.validate("mesh.h5", "Throw", true);
%
% See also: bct.file.create, bct.file.info

arguments
    file (1,1) string
    options.Strict (1,1) logical = true
    options.Throw (1,1) logical = false
end

%% Validation logic
tf = true;
issues = {};

% Check 1: File exists
if ~isfile(file)
    tf = false;
    issues{end+1} = sprintf('File "%s" does not exist', file);
end

if ~tf
    if options.Throw
        error('bct:file:validate:FileNotFound', strjoin(issues, '\n'));
    else
        warning('bct:file:validate:FileNotFound', strjoin(issues, '\n'));
    end
    return;
end

% Check 2: Root schema attribute
try
    schema = bct.file.h5.readAttribute(file, '/', 'schema');
    if ~startsWith(schema, "bct.manifold")
        tf = false;
        issues{end+1} = sprintf('Invalid schema: "%s"', schema);
    end
catch ME
    tf = false;
    issues{end+1} = 'Missing root attribute: schema';
end

% Check 3: Root created_utc
try
    bct.file.h5.readAttribute(file, '/', 'created_utc');
catch
    tf = false;
    issues{end+1} = 'Missing root attribute: created_utc';
end

% Check 4: /manifold group exists
if ~bct.file.exists(file, '/manifold')
    tf = false;
    issues{end+1} = 'Missing required group: /manifold';
end

% Check 5: /manifold attributes
if bct.file.exists(file, '/manifold')
    try
        bct.file.h5.readAttribute(file, '/manifold', 'units_length');
    catch
        tf = false;
        issues{end+1} = 'Missing /manifold attribute: units_length';
    end
    
    try
        bct.file.h5.readAttribute(file, '/manifold', 'index_base_faces');
    catch
        tf = false;
        issues{end+1} = 'Missing /manifold attribute: index_base_faces';
    end
end

%% Report results
if ~tf
    msg = sprintf('File validation failed:\n  %s', strjoin(issues, '\n  '));
    if options.Throw
        error('bct:file:validate:Invalid', msg);
    else
        warning('bct:file:validate:Invalid', msg);
    end
end

end
