function topology(zarrPath, M, options)
%TOPOLOGY Write topology group to Zarr
%
% Syntax:
%   bct.file.write.manifold.zarr.topology(zarrPath, M)
%
% Inputs:
%   zarrPath - string, Zarr directory path
%   M        - bct.Manifold object
%
% Name-Value Arguments:
%   Overwrite - logical (default true), overwrite existing data
%   Strict    - logical (default true), validate schema compliance
%
% Description:
%   Writes topology subgroup to Zarr:
%   - adjacency structures
%   - boundary information
%   - halfedge structures
%   
%   Sparse matrices are stored in COO format.
%   Uses schema-driven serialization.
%
% Examples:
%   M = bct.data.load('Id', 'fsaverage_rh_pial');
%   topo = M.topology();
%   bct.file.write.manifold.zarr.topology('mesh.zarr', M);
%
% See also: bct.file.zarr.writeFromSchema, bct.schema.topology

arguments
    zarrPath (1,1) string
    M (1,1) bct.Manifold
    options.Overwrite (1,1) logical = true
    options.Strict (1,1) logical = true
end

%% Get topology (from cache if available)
topo = M.topology;

%% Write using schema engine
try
    bct.file.zarr.writeFromSchema(zarrPath, topo, 'topology', ...
        'Overwrite', options.Overwrite, 'Strict', options.Strict);
catch ME
    error('bct:file:write:manifold:zarr:topology:WriteFailed', ...
        'Failed to write topology: %s', ME.message);
end

end
