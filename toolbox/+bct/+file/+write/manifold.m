function manifold(file, M, options)
%MANIFOLD Write complete bct.Manifold to HDF5 or Zarr
%
% Syntax:
%   bct.file.write.manifold(file, M)
%   bct.file.write.manifold(file, M, 'Format', 'zarr')
%
% Inputs:
%   file - string, file path (.h5 for HDF5, .zarr for Zarr, or use Format option)
%   M    - bct.Manifold object
%
% Name-Value Arguments:
%   Format    - string (default auto from extension), 'h5', 'hdf5', or 'zarr'
%   Overwrite - logical (default true), overwrite existing datasets
%   Strict    - logical (default true), validate schema compliance
%
% Description:
%   Unified interface for writing Manifold objects to HDF5 or Zarr format.
%   Automatically detects format from file extension (.h5, .hdf5, .zarr).
%   
%   Uses M.toStruct() to convert the Manifold to a schema-compliant structure,
%   then writes everything using the appropriate format's writeFromSchema.
%   
%   Only writes cached data - if you want to write specific groups, cache them
%   first by accessing M.geometry, M.topology, M.operators, M.eigenmodes.
%
% Format Detection:
%   - .h5, .hdf5 extension → HDF5
%   - .zarr extension → Zarr
%   - No extension + Format specified → use Format option
%   - Zarr stores sparse matrices as COO format
%
% Examples:
%   % Cache desired data first
%   M = bct.data.load('Id', 'fsaverage_rh_pial');
%   geom = M.geometry;    % Cache geometry
%   topo = M.topology;    % Cache topology
%   ops = M.operators;    % Cache operators
%   eigen = M.eigenmodes(100);  % Cache eigenmodes
%   
%   % Write everything cached
%   bct.file.write.manifold('mesh.h5', M);    % HDF5
%   bct.file.write.manifold('mesh.zarr', M);  % Zarr
%
%   % Explicit format
%   bct.file.write.manifold('mesh', M, 'Format', 'zarr');
%
%   % Write core only (don't cache anything)
%   M = bct.Manifold(V, F);
%   bct.file.write.manifold('mesh.h5', M);  % Only V, F, E
%       'Geometry', true, ...
%       'Topology', true, ...
%       'Operators', true, ...
%       'Eigenmodes', true, ...
%       'NumModes', 200);
%
% Modular Functions:
%   For writing individual groups, use:
%   - bct.file.write.manifold.core(file, M)           % HDF5
%
% See also: bct.Manifold.toStruct, bct.file.h5.writeFromSchema,
%           bct.file.zarr.writeFromSchema

arguments
    file (1,1) string
    M (1,1) bct.Manifold
    options.Format (1,1) string = ""
    options.Overwrite (1,1) logical = true
    options.Strict (1,1) logical = true
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
        'Strict', options.Strict);
    return;
end

%% HDF5 writer
%% Create file if it doesn't exist
if ~isfile(file)
    bct.file.create(file);
end

fprintf('Writing Manifold to: %s\n', file);

%% Convert Manifold to schema-compliant structure
S = M.toStruct();

%% Write entire structure using schema engine to /manifold/ group
try
    bct.file.h5.writeFromSchema(file, S, '/manifold', ...
        'CreateFile', false, ...
        'Overwrite', options.Overwrite, ...
        'Strict', options.Strict);
    
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
    
    fprintf('✓ Write complete\n');
    
catch ME
    error('bct:file:write:manifold:WriteFailed', ...
        'Failed to write manifold: %s', ME.message);
end

end
