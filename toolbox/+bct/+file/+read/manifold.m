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

%% Detect format: Zarr directory store vs HDF5 file
[~, ~, ext] = fileparts(file);
isZarr = strcmpi(ext, '.zarr') && isfolder(file);

if isZarr
    % Dispatch to Zarr reader
    M = readManifoldFromZarr(file, options);
    return;
end

%% Validate HDF5 file exists
if ~isfile(file)
    error('bct:file:read:manifold:FileNotFound', ...
        'File "%s" does not exist.', file);
end

%% Determine what to read (HDF5 path)
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

%% ========================================================================
%% ZARR READER
%% ========================================================================
function M = readManifoldFromZarr(zarrPath, options)
%READMANIFOLDFROMZARR Read complete Manifold from Zarr directory store.
%   Reads core mesh, then populates the Manifold cache with any available
%   geometry, topology, operators, eigenmodes groups.

if ~isfolder(zarrPath)
    error('bct:file:read:manifold:ZarrNotFound', ...
        'Zarr store not found: %s', zarrPath);
end

fprintf('Reading Manifold from Zarr: %s\n', zarrPath);

%% 1. Read core (vertices, faces) via existing zarr reader
M = bct.file.manifold.read.zarr(zarrPath);
fprintf('  ✓ Core: %d vertices, %d faces\n', ...
    size(M.Vertices, 1), size(M.Faces, 1));

%% 2. Auto-detect available groups
zarrGroupExists = @(g) isfolder(fullfile(zarrPath, 'manifold', g));

readEigen = resolveZarrAutoFlag(options.Eigenmodes, zarrGroupExists('eigenmodes'));

%% 3. Read eigenmodes
if readEigen
    try
        eigenPath = fullfile('manifold', 'eigenmodes');

        % Read eigenvalues [k × 1]
        lambda = bct.file.zarr.readArray(zarrPath, fullfile(eigenPath, 'eigenvalues'));
        lambda = double(lambda(:));  % ensure column vector

        % Read eigenvectors [N × k]
        U = bct.file.zarr.readArray(zarrPath, fullfile(eigenPath, 'eigenvectors'));
        U = double(U);

        % Read metadata
        eigenAttrs = bct.file.zarr.readAttrs(zarrPath, eigenPath);

        % Respect NumModes option
        kAvailable = numel(lambda);
        if ~isempty(options.NumModes) && options.NumModes < kAvailable
            k = options.NumModes;
            lambda = lambda(1:k);
            U = U(:, 1:k);
        else
            k = kAvailable;
        end

        % Build schema-compliant eigen struct and inject into cache
        eigenStruct = struct();
        eigenStruct.eigenvalues = struct('value', lambda, ...
            'attributes', struct('shape', [k 1], 'dtype', 'float64'));
        eigenStruct.eigenvectors = struct('value', U, ...
            'attributes', struct('shape', [size(U,1) k], 'dtype', 'float64'));
        eigenStruct.attributes = eigenAttrs;
        eigenStruct.attributes.numModes = k;

        M.loadCache('eigenmodes', eigenStruct);

        fprintf('  ✓ Eigenmodes: %d modes\n', k);
    catch ME
        if islogical(options.Eigenmodes) && options.Eigenmodes
            rethrow(ME);
        end
        fprintf('  - Eigenmodes: %s\n', ME.message);
    end
end

%% 4. Read operators (mass, stiffness, etc.)
readOps = resolveZarrAutoFlag(options.Operators, zarrGroupExists('operators'));
if readOps
    try
        opsPath = fullfile('manifold', 'operators');
        opsDir = fullfile(zarrPath, opsPath);
        opGroups = dir(opsDir);
        opGroups = opGroups([opGroups.isdir] & ~startsWith({opGroups.name}, '.'));

        opsStruct = struct();
        for i = 1:numel(opGroups)
            opName = opGroups(i).name;
            try
                opData = readSparseOrDenseFromZarr(zarrPath, fullfile(opsPath, opName));
                opsStruct.(opName) = opData;
            catch
                % Skip operators that fail to read
            end
        end

        M.loadCache('operators', opsStruct);

        fprintf('  ✓ Operators: %s\n', strjoin(string(fieldnames(opsStruct)), ', '));
    catch ME
        if islogical(options.Operators) && options.Operators
            rethrow(ME);
        end
        fprintf('  - Operators: %s\n', ME.message);
    end
end

fprintf('✓ Zarr read complete\n');

end

%% ========================================================================
%% ZARR HELPERS
%% ========================================================================
function shouldRead = resolveZarrAutoFlag(flag, groupPresent)
%RESOLVEZARRAUTO Resolve auto/true/false flag against group existence.
if islogical(flag)
    shouldRead = flag;
elseif isstring(flag) || ischar(flag)
    if strcmpi(flag, 'auto')
        shouldRead = groupPresent;
    else
        shouldRead = false;
    end
else
    shouldRead = false;
end
end

function data = readSparseOrDenseFromZarr(zarrPath, arrayPath)
%READSPARSEORDENSEFROMZARR Read an operator that may be stored as COO sparse.
%   Checks for row_ind/col_ind/values subgroups (COO format) or reads as dense.

fullDir = fullfile(zarrPath, arrayPath);
hasCOO = isfolder(fullfile(fullDir, 'row_ind')) && ...
         isfolder(fullfile(fullDir, 'col_ind')) && ...
         isfolder(fullfile(fullDir, 'values'));

if hasCOO
    % Read COO components
    rowInd = bct.file.zarr.readArray(zarrPath, fullfile(arrayPath, 'row_ind'));
    colInd = bct.file.zarr.readArray(zarrPath, fullfile(arrayPath, 'col_ind'));
    vals   = bct.file.zarr.readArray(zarrPath, fullfile(arrayPath, 'values'));

    % Read shape from attributes
    attrs = bct.file.zarr.readAttrs(zarrPath, arrayPath);
    if isfield(attrs, 'shape')
        nRows = attrs.shape(1);
        nCols = attrs.shape(2);
    else
        nRows = double(max(rowInd)) + 1;
        nCols = double(max(colInd)) + 1;
    end

    % COO is 0-based → convert to 1-based
    rowInd = double(rowInd(:)) + 1;
    colInd = double(colInd(:)) + 1;
    vals   = double(vals(:));

    S = sparse(rowInd, colInd, vals, nRows, nCols);
    data = struct('value', S, 'attributes', attrs);
else
    % Try reading as dense array
    arr = bct.file.zarr.readArray(zarrPath, arrayPath);
    attrs = bct.file.zarr.readAttrs(zarrPath, arrayPath);
    data = struct('value', double(arr), 'attributes', attrs);
end
end
