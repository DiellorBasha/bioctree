function S = info(file, options)
%BCT.FILE.INFO  Get schema summary and key attributes from BCT HDF5 file
%
%   S = bct.file.info(file)
%
% Purpose
%   Returns a summary struct containing schema version, creation time,
%   and key metadata from a BCT HDF5 file.
%
% Inputs
%   file - string or char, file path
%
% Name-Value Arguments
%   Validate - logical (default true), validate file exists
%
% Output
%   S - struct with fields:
%       .file            - file path
%       .schema          - schema version string
%       .created_utc     - creation timestamp
%       .bct_version     - BCT version (if present)
%       .manifold_id     - manifold identifier (if present)
%       .units_length    - length units from /manifold
%       .coordinate_system - coordinate system (if present)
%       .index_base      - indexing convention
%
% Examples
%   S = bct.file.info("mesh.h5");
%   fprintf("Schema: %s\n", S.schema);
%   fprintf("Created: %s\n", S.created_utc);
%
% See also: bct.file.create, bct.file.validate, bct.file.exists

arguments
    file (1,1) string
    options.Validate (1,1) logical = true
end

%% Validate file exists
if options.Validate && ~isfile(file)
    error('bct:file:info:FileNotFound', ...
        'File "%s" does not exist.', file);
end

%% Read root attributes
S = struct();
S.file = file;

try
    % Required root attributes
    S.schema = bct.file.h5.readAttribute(file, '/', 'schema');
    S.created_utc = bct.file.h5.readAttribute(file, '/', 'created_utc');
    
    % Optional root attributes
    try
        S.bct_version = bct.file.h5.readAttribute(file, '/', 'bct_version');
    catch
        S.bct_version = missing;
    end
    
    try
        S.manifold_id = bct.file.h5.readAttribute(file, '/', 'manifold_id');
    catch
        S.manifold_id = missing;
    end
    
    %% Read /manifold attributes if group exists
    if bct.file.exists(file, '/manifold')
        S.units_length = bct.file.h5.readAttribute(file, '/manifold', 'units_length');
        S.index_base = bct.file.h5.readAttribute(file, '/manifold', 'index_base_faces');
        
        try
            S.coordinate_system = bct.file.h5.readAttribute(file, '/manifold', 'coordinate_system');
        catch
            S.coordinate_system = missing;
        end
    else
        S.units_length = missing;
        S.index_base = missing;
        S.coordinate_system = missing;
    end
    
catch ME
    error('bct:file:info:ReadFailed', ...
        'Failed to read file info: %s', ME.message);
end

end
