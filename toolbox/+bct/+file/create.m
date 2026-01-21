function create(file, options)
%BCT.FILE.CREATE  Create a new HDF5 file with BCT manifold schema
%
%   bct.file.create(file)
%   bct.file.create(file, Name=Value)
%
% Purpose
%   Creates a new HDF5 file with required schema attributes and base
%   /manifold group. Initializes file metadata following the BCT manifold
%   HDF5 schema conventions.
%
% Inputs
%   file - string or char, file path (e.g., "data.h5")
%
% Name-Value Arguments
%   Mode         - "error" (default) | "overwrite"
%                  "error": error if file exists
%                  "overwrite": delete and recreate if exists
%   ManifoldID   - string (optional), identifier for this manifold
%   BCTVersion   - string (optional), BCT toolbox version
%   Schema       - string (default "bct.manifold.h5@1"), schema version
%   UnitsLength  - string (default "m"), canonical length unit
%   CoordSystem  - string (optional), coordinate system (e.g., "RAS")
%   IndexBase    - scalar (default 1), MATLAB-style 1-based indexing
%
% Algorithm
%   1. Check file existence and apply Mode policy
%   2. Create HDF5 file
%   3. Write root attributes: schema, created_utc, bct_version, manifold_id
%   4. Create /manifold group
%   5. Write /manifold attributes: units_length, index_base_faces, etc.
%
% Examples
%   % Create new file (error if exists)
%   bct.file.create("mesh.h5");
%
%   % Overwrite existing file
%   bct.file.create("mesh.h5", "Mode", "overwrite");
%
%   % With metadata
%   bct.file.create("mesh.h5", ...
%       "ManifoldID", "fsaverage_lh_white", ...
%       "BCTVersion", "1.0.0");
%
% See also: bct.file.info, bct.file.validate, bct.file.write

arguments
    file (1,1) string
    options.Mode (1,1) string {mustBeMember(options.Mode, ["error", "overwrite"])} = "error"
    options.ManifoldID (1,1) string = missing
    options.BCTVersion (1,1) string = missing
    options.Schema (1,1) string = "bct.manifold.h5@1"
    options.UnitsLength (1,1) string = "m"
    options.CoordSystem (1,1) string = missing
    options.IndexBase (1,1) double = 1
end

%% Handle file existence
if isfile(file)
    if strcmp(options.Mode, "error")
        error('bct:file:create:FileExists', ...
            'File "%s" already exists. Use Mode="overwrite" to replace.', file);
    elseif strcmp(options.Mode, "overwrite")
        delete(file);
    end
end

%% Create HDF5 file using low-level API
try
    % Create file directly using low-level API
    fcpl = H5P.create('H5P_FILE_CREATE');
    fapl = H5P.create('H5P_FILE_ACCESS');
    fid = H5F.create(char(file), 'H5F_ACC_TRUNC', fcpl, fapl);
    H5P.close(fcpl);
    H5P.close(fapl);
    H5F.close(fid);
    
    %% Write root attributes
    bct.file.h5.writeAttribute(file, '/', 'schema', options.Schema);
    bct.file.h5.writeAttribute(file, '/', 'created_utc', char(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z''')));
    
    if ~ismissing(options.BCTVersion)
        bct.file.h5.writeAttribute(file, '/', 'bct_version', options.BCTVersion);
    end
    
    if ~ismissing(options.ManifoldID)
        bct.file.h5.writeAttribute(file, '/', 'manifold_id', options.ManifoldID);
    end
    
    %% Create /manifold group
    bct.file.h5.ensureGroup(file, '/manifold');
    
    %% Write /manifold attributes
    bct.file.h5.writeAttribute(file, '/manifold', 'units_length', options.UnitsLength);
    bct.file.h5.writeAttribute(file, '/manifold', 'index_base_faces', int32(options.IndexBase));
    bct.file.h5.writeAttribute(file, '/manifold', 'index_base_edges', int32(options.IndexBase));
    bct.file.h5.writeAttribute(file, '/manifold', 'edges_present', int32(1));  % Assume present by default
    
    if ~ismissing(options.CoordSystem)
        bct.file.h5.writeAttribute(file, '/manifold', 'coordinate_system', options.CoordSystem);
    end
    
catch ME
    % Clean up on failure
    if isfile(file)
        delete(file);
    end
    rethrow(ME);
end

end
