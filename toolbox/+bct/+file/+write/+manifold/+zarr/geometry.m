function geometry(zarrPath, M, options)
%GEOMETRY Write geometry group to Zarr
%
% Syntax:
%   bct.file.write.manifold.zarr.geometry(zarrPath, M)
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
%   Writes geometry subgroup to Zarr:
%   - vertex geometry (normals, areas, etc.)
%   - face geometry (normals, areas, centroids, etc.)
%   - edge geometry (lengths, midpoints, etc.)
%   
%   Uses schema-driven serialization.
%
% Examples:
%   M = bct.data.load('Id', 'fsaverage_rh_pial');
%   geom = M.geometry();
%   bct.file.write.manifold.zarr.geometry('mesh.zarr', M);
%
% See also: bct.file.zarr.writeFromSchema, bct.schema.geometry

arguments
    zarrPath (1,1) string
    M (1,1) bct.Manifold
    options.Overwrite (1,1) logical = true
    options.Strict (1,1) logical = true
end

%% Get geometry (from cache if available)
geom = M.geometry;

%% Write using schema engine
try
    bct.file.zarr.writeFromSchema(zarrPath, geom, 'geometry', ...
        'Overwrite', options.Overwrite, 'Strict', options.Strict);
catch ME
    error('bct:file:write:manifold:zarr:geometry:WriteFailed', ...
        'Failed to write geometry: %s', ME.message);
end

end
