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
%     atlas/             (optional: FreeSurfer atlas with region mappings)
%
% Examples:
%   % Write everything available (auto-detect from cache)
%   M = bct.data.load('Id', 'fsaverage_rh_pial');
%   geom = M.geometry();
%   ops = M.operators();
%   bct.file.write.manifold.zarr('mesh.zarr', M);
%
%   % Write with atlas (attach before write)
%   mesh = bct.data.load('Id', 'fsaverage_rh_pial');  % mesh includes atlas
%   M = bct.Manifold(mesh);
%   M.Atlas = mesh.Atlas;       % Attach FreeSurfer atlas for region mapping
%   geom = M.geometry();
%   bct.file.write.manifold.zarr('mesh_with_atlas.zarr', M);
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
end

%% Create Zarr root
if ~isfolder(zarrPath)
    mkdir(zarrPath);
end

% Create root .zgroup
bct.file.zarr.createGroup(zarrPath, "");

% Write root attributes
rootAttrs = struct();
rootAttrs.schema = 'bct.manifold@1.1';
rootAttrs.format = 'zarr';
rootAttrs.zarr_version = 2;
rootAttrs.created_utc = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
bct.file.zarr.writeAttrs(zarrPath, "", rootAttrs);

fprintf('Writing Manifold to Zarr: %s\n', zarrPath);

%% Convert Manifold to schema-compliant structure
S = M.toStruct();

%% Write entire structure using schema engine to /manifold/ subgroup
try
    bct.file.zarr.writeFromSchema(zarrPath, S, "manifold", ...
        'Overwrite', options.Overwrite, 'Strict', options.Strict);
    
    % Report what was written
    fprintf('  ✓ Core: %d vertices, %d faces, %d edges\n', ...
        size(S.vertices.value, 1), size(S.faces.value, 1), size(S.edges.value, 1));
    
    if isfield(S, 'geometry')
        fprintf('  ✓ Geometry group\n');
    end
    
    if isfield(S, 'topology')
        fprintf('  ✓ Topology group\n');
    end
    
    if isfield(S, 'operators')
        fprintf('  ✓ Operators group\n');
    end
    
    if isfield(S, 'eigenmodes')
        nModes = size(S.eigenmodes.eigenvectors.value, 2);
        fprintf('  ✓ Eigenmodes: %d modes\n', nModes);
    end
    
catch ME
    error('bct:file:write:manifold:zarr:WriteFailed', ...
        'Failed to write manifold: %s', ME.message);
end

fprintf('Zarr write complete.\n');

end
