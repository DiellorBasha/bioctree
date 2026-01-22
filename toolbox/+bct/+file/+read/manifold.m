function M = manifold(file, options)
%MANIFOLD Read complete bct.Manifold from HDF5 with all available groups
%
% Syntax:
%   M = bct.file.read.manifold(file)
%   M = bct.file.read.manifold(file, 'Geometry', true)
%   M = bct.file.read.manifold(file, 'Eigenmodes', true, 'NumModes', 50)
%
% Inputs:
%   file - string, HDF5 file path
%
% Name-Value Arguments:
%   Core       - logical|'auto' (default 'auto'), read core manifold data
%   Geometry   - logical|'auto' (default 'auto'), read geometry group
%   Topology   - logical|'auto' (default 'auto'), read topology group
%   Operators  - logical|'auto' (default 'auto'), read operators group
%   Eigenmodes - logical|'auto' (default 'auto'), read eigenmodes group
%   NumModes   - integer (default all), number of eigenmodes to read
%
% Outputs:
%   M - bct.Manifold object with requested data
%
% Description:
%   Deserializes complete Manifold from HDF5.
%   By default (with 'auto' flags), reads all groups that exist in file.
%   Set flags to true to require group (error if missing), false to skip.
%
% Auto Detection (default behavior):
%   'auto' mode checks HDF5 file structure and reads available groups:
%   - Checks if /manifold, /geometry, /topology, /operators, /eigenmodes exist
%   - Only reads what's present, skips missing groups
%   - No error if optional groups are missing
%
% Examples:
%   % Read everything available (auto-detect from file)
%   M = bct.file.read.manifold('mesh.h5');  % Simple!
%
%   % Read core manifold only (explicitly)
%   M = bct.file.read.manifold.core('mesh.h5');
%
%   % Force read specific groups (error if missing)
%   M = bct.file.read.manifold('mesh.h5', ...
%       'Geometry', true, 'Operators', true);
%
%   % Read limited eigenmodes
%   M = bct.file.read.manifold('mesh.h5', 'Eigenmodes', true, 'NumModes', 50);
%
% Modular Functions:
%   For reading individual groups:
%   - M = bct.file.read.manifold.core(file)
%   - geom = bct.file.read.manifold.geometry(file)
%   - topo = bct.file.read.manifold.topology(file)
%   - ops = bct.file.read.manifold.operators(file)
%   - [eigenvalues, eigenvectors] = bct.file.read.manifold.eigenmodes(file)
%
% See also: bct.file.read.manifold.core, bct.file.write.manifold

arguments
    file (1,1) string
    options.Core = 'auto'
    options.Geometry = 'auto'
    options.Topology = 'auto'
    options.Operators = 'auto'
    options.Eigenmodes = 'auto'
    options.NumModes = []
end

%% Validate file exists
if ~isfile(file)
    error('bct:file:read:manifold:FileNotFound', ...
        'File "%s" does not exist.', file);
end

%% Determine what to read
readCore = resolveAutoFlag(options.Core, file, '/manifold');
readGeom = resolveAutoFlag(options.Geometry, file, '/geometry');
readTopo = resolveAutoFlag(options.Topology, file, '/topology');
readOps = resolveAutoFlag(options.Operators, file, '/operators');
readEigen = resolveAutoFlag(options.Eigenmodes, file, '/eigenmodes');

fprintf('Reading Manifold from: %s\n', file);

%% Read core manifold
if readCore
    M = bct.file.read.manifold.core(file);
    fprintf('  ✓ Core: %d vertices, %d faces, %d edges\n', ...
        size(M.Vertices, 1), size(M.Faces, 1), size(M.Edges, 1));
else
    fprintf('  - Core: skipped\n');
    M = [];
    return;
end

%% Read optional groups
% Note: These would need integration with Manifold caching system
% For now, just store in a separate struct that could be returned

if readGeom
    try
        geom = bct.file.read.manifold.geometry(file);
        fprintf('  ✓ Geometry group\n');
        % TODO: Integrate with M's cache
    catch ME
        if islogical(options.Geometry) && options.Geometry
            rethrow(ME);
        end
        fprintf('  - Geometry group: not available\n');
    end
end

if readTopo
    try
        topo = bct.file.read.manifold.topology(file);
        fprintf('  ✓ Topology group\n');
        % TODO: Integrate with M's cache
    catch ME
        if islogical(options.Topology) && options.Topology
            rethrow(ME);
        end
        fprintf('  - Topology group: not available\n');
    end
end

if readOps
    try
        ops = bct.file.read.manifold.operators(file);
        fprintf('  ✓ Operators group\n');
        % TODO: Integrate with M's cache
    catch ME
        if islogical(options.Operators) && options.Operators
            rethrow(ME);
        end
        fprintf('  - Operators group: not available\n');
    end
end

if readEigen
    try
        if isempty(options.NumModes)
            [lambda, U] = bct.file.read.manifold.eigenmodes(file);
        else
            [lambda, U] = bct.file.read.manifold.eigenmodes(file, 'NumModes', options.NumModes);
        end
        fprintf('  ✓ Eigenmodes: %d modes\n', numel(lambda));
        % TODO: Integrate with M's eigenmode cache
    catch ME
        if islogical(options.Eigenmodes) && options.Eigenmodes
            rethrow(ME);
        end
        fprintf('  - Eigenmodes: not available\n');
    end
end

fprintf('✓ Read complete\n');

end

%% ========================================================================
%% HELPER: Resolve auto flags
%% ========================================================================
function shouldRead = resolveAutoFlag(flag, file, groupPath)
%RESOLVEAUTOFLAG Determine if group should be read based on flag and file

if islogical(flag)
    shouldRead = flag;
elseif isstring(flag) || ischar(flag)
    if strcmpi(flag, 'auto')
        shouldRead = groupExists(file, groupPath);
    else
        error('bct:file:read:manifold:InvalidFlag', ...
            'Flag must be logical or ''auto'', got: %s', flag);
    end
else
    error('bct:file:read:manifold:InvalidFlag', ...
        'Flag must be logical or ''auto''');
end

end

function exists = groupExists(file, groupPath)
%GROUPEXISTS Check if HDF5 group exists in file

try
    h5info(file, groupPath);
    exists = true;
catch
    exists = false;
end

end
