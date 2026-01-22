function manifold(file, M, options)
%MANIFOLD Write complete bct.Manifold to HDF5 or Zarr with all available data
%
% Syntax:
%   bct.file.write.manifold(file, M)
%   bct.file.write.manifold(file, M, 'Geometry', true)
%   bct.file.write.manifold(file, M, 'Format', 'zarr')
%   bct.file.write.manifold(file, M, 'Eigenmodes', true, 'NumModes', 200)
%
% Inputs:
%   file - string, file path (.h5 for HDF5, .zarr for Zarr, or use Format option)
%   M    - bct.Manifold object
%
% Name-Value Arguments:
%   Format     - string (default auto from extension), 'h5' or 'zarr'
%   Overwrite  - logical (default true), overwrite existing datasets
%   Strict     - logical (default true), validate schema compliance
%   Core       - logical|'auto' (default 'auto'), write core manifold data
%   Geometry   - logical|'auto' (default 'auto'), write geometry group
%   Topology   - logical|'auto' (default 'auto'), write topology group  
%   Operators  - logical|'auto' (default 'auto'), write operators group
%   Eigenmodes - logical|'auto' (default 'auto'), write eigenmodes group
%   NumModes   - integer (default 100), number of eigenmodes to write
%   ChunkSize  - integer (default 100), eigenmodes chunk size (Zarr only)
%
% Description:
%   Serializes complete Manifold to HDF5 or Zarr. Format is auto-detected 
%   from extension or can be specified explicitly. File/directory is created 
%   automatically if needed. By default (with 'auto' flags), writes all 
%   groups that exist in cache.
%
% Auto Detection (default behavior):
%   'auto' mode checks M's cache and writes groups that already exist:
%   - Checks M.Attributes for geometry/topology/operators subgroups
%   - Checks if eigenmodes have been computed
%   - Only writes what's available without forcing computation
%
% Format Detection:
%   - .h5, .hdf5 extension → HDF5
%   - .zarr extension → Zarr
%   - No extension + Format specified → use Format option
%   - Zarr stores sparse matrices as COO, chunks eigenmodes by 100 modes
%
% Examples:
%   % Write everything available (auto-detect from cache)
%   M = bct.data.load('Id', 'fsaverage_rh_pial');
%   geom = M.geometry();  % Compute geometry
%   ops = M.operators();  % Compute operators
%   bct.file.write.manifold('mesh.h5', M);    % HDF5
%   bct.file.write.manifold('mesh.zarr', M);  % Zarr
%
%   % Explicit format
%   bct.file.write.manifold('mesh', M, 'Format', 'zarr');
%
%   % Write core manifold only (explicitly)
%   bct.file.write.manifold.core('mesh.h5', M);
%
%   % Force write all groups with computation
%   bct.file.write.manifold('mesh_full.zarr', M, ...
%       'Geometry', true, ...
%       'Topology', true, ...
%       'Operators', true, ...
%       'Eigenmodes', true, ...
%       'NumModes', 200);
%
% Modular Functions:
%   For writing individual groups, use:
%   - bct.file.write.manifold.core(file, M)           % HDF5
%   - bct.file.write.manifold.geometry(file, M)       % HDF5
%   - bct.file.write.manifold.zarr.core(zarr, M)      % Zarr
%   - bct.file.write.manifold.zarr.geometry(zarr, M)  % Zarr
%
% See also: bct.file.write.manifold.zarr, bct.file.h5.writeFromSchema,
%           bct.file.zarr.writeFromSchema
%
% HDF5 Structure Generated:
%   /manifold/                    # Core manifold group
%     @schema = "bct.Manifold@1.1"
%     @package = "bct"
%     @path = "/manifold"
%     @id = "uuid"
%     @name = "bunny"
%     @metric_units = "m"
%     @face_winding = "CCW"
%     vertices                    # [N×3] vertex coordinates
%       @name = "vertices"
%       @shape = [N, 3]
%       @dtype = "double"
%       @units = "m"
%       @support = "vertex"
%       @computed_by = "bct.Manifold"
%     faces                       # [F×3] face indices (0-based)
%       @name = "faces"
%       @index_base = 0
%       @support = "face"
%     edges                       # [E×2] edge indices (0-based)
%       @name = "edges"
%       @index_base = 0
%       @support = "edge"
%
% See also: bct.file.h5.writeFromSchema, bct.schema.manifold, bct.Manifold

arguments
    file (1,1) string
    M (1,1) bct.Manifold
    options.Format (1,1) string = ""
    options.Overwrite (1,1) logical = true
    options.Strict (1,1) logical = true
    options.Core = 'auto'
    options.Geometry = 'auto'
    options.Topology = 'auto'
    options.Operators = 'auto'
    options.Eigenmodes = 'auto'
    options.NumModes (1,1) {mustBeInteger, mustBePositive} = 100
    options.ChunkSize (1,1) {mustBeInteger, mustBePositive} = 100
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
        error('bct:file:write:manifold:UnknownFormat', ...
            'Cannot detect format from extension "%s". Use Format option.', ext);
    end
else
    format = lower(options.Format);
    if ~ismember(format, {'h5', 'hdf5', 'zarr'})
        error('bct:file:write:manifold:InvalidFormat', ...
            'Format must be ''h5'', ''hdf5'', or ''zarr''.');
    end
    if strcmp(format, 'hdf5')
        format = 'h5';
    end
end

%% Dispatch to format-specific writer
if strcmp(format, 'zarr')
    % Call Zarr writer
    bct.file.write.manifold.zarr(file, M, ...
        'Overwrite', options.Overwrite, ...
        'Strict', options.Strict, ...
        'Core', options.Core, ...
        'Geometry', options.Geometry, ...
        'Topology', options.Topology, ...
        'Operators', options.Operators, ...
        'Eigenmodes', options.Eigenmodes, ...
        'NumModes', options.NumModes, ...
        'ChunkSize', options.ChunkSize);
    return;
end

%% HDF5 writer (existing code)
%% Create file if it doesn't exist
if ~isfile(file)
    bct.file.create(file);
end

%% Determine what to write
writeCore = options.Core;
writeGeom = resolveAutoFlag(options.Geometry, M, 'geometry');
writeTopo = resolveAutoFlag(options.Topology, M, 'topology');
writeOps = resolveAutoFlag(options.Operators, M, 'operators');
writeEigen = resolveAutoFlag(options.Eigenmodes, M, 'eigenmodes');

%% Write groups
fprintf('Writing Manifold to: %s\n', file);

% Core manifold (vertices, faces, edges)
if writeCore
    bct.file.write.manifold.core(file, M, ...
        'Overwrite', options.Overwrite, ...
        'Strict', options.Strict);
    fprintf('  ✓ Core: %d vertices, %d faces, %d edges\n', ...
        size(M.Vertices, 1), size(M.Faces, 1), size(M.Edges, 1));
end

% Geometry group
if writeGeom
    try
        bct.file.write.manifold.geometry(file, M, ...
            'Overwrite', options.Overwrite, ...
            'Strict', options.Strict);
        fprintf('  ✓ Geometry group\n');
    catch ME
        warning('bct:file:write:manifold:GeometryFailed', ...
            'Failed to write geometry: %s', ME.message);
    end
end

% Topology group
if writeTopo
    try
        bct.file.write.manifold.topology(file, M, ...
            'Overwrite', options.Overwrite, ...
            'Strict', options.Strict);
        fprintf('  ✓ Topology group\n');
    catch ME
        warning('bct:file:write:manifold:TopologyFailed', ...
            'Failed to write topology: %s', ME.message);
    end
end

% Operators group
if writeOps
    try
        bct.file.write.manifold.operators(file, M, ...
            'Overwrite', options.Overwrite, ...
            'Strict', options.Strict);
        fprintf('  ✓ Operators group\n');
    catch ME
        warning('bct:file:write:manifold:OperatorsFailed', ...
            'Failed to write operators: %s', ME.message);
    end
end

% Eigenmodes group
if writeEigen
    try
        bct.file.write.manifold.eigenmodes(file, M, ...
            'Overwrite', options.Overwrite, ...
            'Strict', options.Strict, ...
            'NumModes', options.NumModes);
        fprintf('  ✓ Eigenmodes group (%d modes)\n', options.NumModes);
    catch ME
        warning('bct:file:write:manifold:EigenmodesFailed', ...
            'Failed to write eigenmodes: %s', ME.message);
    end
end

fprintf('✓ Write complete\n');

end

%% ========================================================================
%% HELPER: Resolve auto flags
%% ========================================================================
function shouldWrite = resolveAutoFlag(flag, M, groupName)
%RESOLVEAUTOFLAG Determine if group should be written based on flag and cache

if islogical(flag)
    shouldWrite = flag;
elseif isstring(flag) || ischar(flag)
    if strcmpi(flag, 'auto')
        shouldWrite = hasComputedGroup(M, groupName);
    else
        error('bct:file:write:manifold:InvalidFlag', ...
            'Flag must be logical or ''auto'', got: %s', flag);
    end
else
    error('bct:file:write:manifold:InvalidFlag', ...
        'Flag must be logical or ''auto''');
end
end

function hasGroup = hasComputedGroup(M, groupName)
%HASCOMPUTEDGROUP Check if Manifold has computed group in cache

attrs = M.Attributes;
hasGroup = isfield(attrs, groupName);

% Special case for eigenmodes
if strcmp(groupName, 'eigenmodes')
    try
        [~, ~] = M.eigenmodes(0);
        hasGroup = true;
    catch
        hasGroup = false;
    end
end
end
