function zarr(zarrPath, M, options)
%ZARR Write complete Manifold to Zarr with all available data
%
% Syntax:
%   bct.file.write.manifold.zarr(zarrPath, M)
%   bct.file.write.manifold.zarr(zarrPath, M, 'Geometry', true)
%
% Inputs:
%   zarrPath - string, Zarr directory path (e.g., 'mesh.zarr')
%   M        - bct.Manifold object
%
% Name-Value Arguments:
%   Overwrite  - logical (default true), overwrite existing datasets
%   Strict     - logical (default true), validate schema compliance
%   Core       - logical|'auto' (default 'auto'), write core manifold data
%   Geometry   - logical|'auto' (default 'auto'), write geometry group
%   Topology   - logical|'auto' (default 'auto'), write topology group
%   Operators  - logical|'auto' (default 'auto'), write operators group
%   Eigenmodes - logical|'auto' (default 'auto'), write eigenmodes group
%   NumModes   - integer (default 100), number of eigenmodes to write
%   ChunkSize  - integer (default 100), eigenmodes chunk size
%
% Description:
%   Serializes complete Manifold to Zarr directory. Directory is created 
%   automatically if needed. By default (with 'auto' flags), writes all 
%   groups that exist in cache.
%
% Zarr Structure:
%   mesh.zarr/
%     .zgroup, .zattrs
%     manifold/          (core: vertices, faces, edges)
%     geometry/          (vertex, face, edge geometry)
%     topology/          (adjacency, boundary, halfedge - sparse as COO)
%     operators/         (mass, stiffness, DEC - sparse as COO)
%     eigenmodes/        (eigenvalues, eigenvectors - chunked by 100 modes)
%
% Examples:
%   % Write everything available (auto-detect from cache)
%   M = bct.data.load('Id', 'fsaverage_rh_pial');
%   geom = M.geometry();
%   ops = M.operators();
%   bct.file.write.manifold.zarr('mesh.zarr', M);
%
%   % Force compute and write specific groups
%   bct.file.write.manifold.zarr('mesh.zarr', M, ...
%       'Geometry', true, 'Eigenmodes', true, 'NumModes', 200);
%
% See also: bct.file.zarr.writeFromSchema

arguments
    zarrPath (1,1) string
    M (1,1) bct.Manifold
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

%% Create Zarr root
if ~isfolder(zarrPath)
    mkdir(zarrPath);
end

% Create root .zgroup
bct.file.zarr.createGroup(zarrPath, '');

% Write root attributes
rootAttrs = struct();
rootAttrs.schema = 'bct.manifold@1.1';
rootAttrs.format = 'zarr';
rootAttrs.zarr_version = 2;
rootAttrs.created_utc = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
bct.file.zarr.writeAttrs(zarrPath, '', rootAttrs);

%% Determine what to write
writeCore = resolveAutoFlag(options.Core, M, 'core');
writeGeom = resolveAutoFlag(options.Geometry, M, 'geometry');
writeTopo = resolveAutoFlag(options.Topology, M, 'topology');
writeOps = resolveAutoFlag(options.Operators, M, 'operators');
writeEigen = resolveAutoFlag(options.Eigenmodes, M, 'eigenmodes');

fprintf('Writing Manifold to Zarr: %s\n', zarrPath);

%% Write core manifold
if writeCore
    try
        bct.file.write.manifold.zarr.core(zarrPath, M, ...
            'Overwrite', options.Overwrite, 'Strict', options.Strict);
        fprintf('  ✓ Core: %d vertices, %d faces, %d edges\n', ...
            size(M.Vertices, 1), size(M.Faces, 1), size(M.Edges, 1));
    catch ME
        if islogical(options.Core) && options.Core
            rethrow(ME);
        end
        warning('Failed to write core: %s', ME.message);
    end
end

%% Write geometry
if writeGeom
    try
        % Use cached data directly
        geom = M.geometry;
        schema = bct.schema.geometry(geom);
        bct.file.zarr.writeFromSchema(zarrPath, schema, 'geometry', ...
            'Overwrite', options.Overwrite, 'Strict', options.Strict);
        fprintf('  ✓ Geometry group\n');
    catch ME
        if islogical(options.Geometry) && options.Geometry
            rethrow(ME);
        end
        warning('Failed to write geometry: %s', ME.message);
    end
end

%% Write topology
if writeTopo
    try
        % Use cached data directly
        topo = M.topology;
        schema = bct.schema.topology(topo);
        bct.file.zarr.writeFromSchema(zarrPath, schema, 'topology', ...
            'Overwrite', options.Overwrite, 'Strict', options.Strict);
        fprintf('  ✓ Topology group\n');
    catch ME
        if islogical(options.Topology) && options.Topology
            rethrow(ME);
        end
        warning('Failed to write topology: %s', ME.message);
    end
end

%% Write operators
if writeOps
    try
        % Use cached data directly
        ops = M.operators;
        schema = bct.schema.operators(ops);
        bct.file.zarr.writeFromSchema(zarrPath, schema, 'operators', ...
            'Overwrite', options.Overwrite, 'Strict', options.Strict);
        fprintf('  ✓ Operators group\n');
    catch ME
        if islogical(options.Operators) && options.Operators
            rethrow(ME);
        end
        warning('Failed to write operators: %s', ME.message);
    end
end

%% Write eigenmodes
if writeEigen
    try
        % Use cached data directly
        eigendata = M.eigenmodes;
        % Extract eigenvalues and eigenvectors from cached data
        if isstruct(eigendata)
            eigenvalues = eigendata.eigenvalues;
            eigenvectors = eigendata.eigenvectors;
        else
            % If cached as array, assume it's eigenvectors and we need to compute eigenvalues
            [eigenvalues, eigenvectors] = bct.manifold.eigenmodes(M, options.NumModes);
        end
        
        % Limit to requested number of modes
        if size(eigenvectors, 2) > options.NumModes
            eigenvalues = eigenvalues(1:options.NumModes);
            eigenvectors = eigenvectors(:, 1:options.NumModes);
        end
        
        schema = bct.schema.eigenmodes(eigenvalues, eigenvectors);
        bct.file.zarr.writeFromSchema(zarrPath, schema, 'eigenmodes', ...
            'Overwrite', options.Overwrite, 'Strict', options.Strict);
        fprintf('  ✓ Eigenmodes: %d modes (chunked by %d)\n', ...
            options.NumModes, options.ChunkSize);
    catch ME
        if islogical(options.Eigenmodes) && options.Eigenmodes
            rethrow(ME);
        end
        warning('Failed to write eigenmodes: %s', ME.message);
    end
end

fprintf('Zarr write complete.\n');

end

%% ========================================================================
%% Helper: Resolve 'auto' flag based on cache
%% ========================================================================
function shouldWrite = resolveAutoFlag(flag, M, groupName)
    if islogical(flag)
        shouldWrite = flag;
    elseif ischar(flag) || isstring(flag)
        if strcmpi(flag, 'auto')
            shouldWrite = hasComputedGroup(M, groupName);
        else
            error('Invalid flag value: %s. Use true, false, or ''auto''.', flag);
        end
    else
        error('Invalid flag type. Use logical or ''auto''.');
    end
end

%% ========================================================================
%% Helper: Check if group has been computed (cached)
%% ========================================================================
function hasComputed = hasComputedGroup(M, groupName)
    switch groupName
        case 'core'
            % Core always exists
            hasComputed = true;
        case 'geometry'
            % Check if M.geometry property has data
            hasComputed = isprop(M, 'geometry') && ~isempty(M.geometry);
        case 'topology'
            % Check if M.topology property has data
            hasComputed = isprop(M, 'topology') && ~isempty(M.topology);
        case 'operators'
            % Check if M.operators property has data
            hasComputed = isprop(M, 'operators') && ~isempty(M.operators);
        case 'eigenmodes'
            % Check if M.eigenmodes property has data
            hasComputed = isprop(M, 'eigenmodes') && ~isempty(M.eigenmodes);
        otherwise
            hasComputed = false;
    end
end
