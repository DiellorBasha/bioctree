function topology(file, M, options)
%TOPOLOGY Write manifold topology group to HDF5
%
% Syntax:
%   bct.file.write.manifold.topology(file, M)
%   bct.file.write.manifold.topology(file, M, 'Overwrite', true)
%
% Inputs:
%   file - string, HDF5 file path (must exist)
%   M    - bct.Manifold object
%
% Name-Value Arguments:
%   Overwrite - logical (default true), overwrite existing datasets
%   Strict    - logical (default true), validate schema compliance
%
% Description:
%   Writes topology group to /topology with connectivity structures:
%   - Adjacency matrices
%   - Boundary information
%   - Halfedge structure
%   - Connected components
%
% Examples:
%   M = bct.Manifold.read('mesh.obj');
%   bct.file.create('mesh.h5');
%   bct.file.write.manifold.topology('mesh.h5', M);
%
% See also: bct.file.write.manifold, bct.manifold.topology

arguments
    file (1,1) string
    M (1,1) bct.Manifold
    options.Overwrite (1,1) logical = true
    options.Strict (1,1) logical = true
end

%% Validate file exists
if ~isfile(file)
    error('bct:file:write:manifold:topology:FileNotFound', ...
        'File "%s" does not exist.', file);
end

%% Get topology attributes (computed on demand)
topo = M.topology();

%% Write using schema-driven serialization
bct.file.h5.writeFromSchema(file, topo, ...
    'CreateFile', false, ...
    'Overwrite', options.Overwrite, ...
    'Strict', options.Strict);

end
