function core(zarrPath, M, options)
%CORE Write core manifold data to Zarr (vertices, faces, edges)
%
% Syntax:
%   bct.file.write.manifold.zarr.core(zarrPath, M)
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
%   Writes core manifold mesh topology to Zarr:
%   - vertices (float32, C-order)
%   - faces (uint32, 0-based indexing)
%   - edges (uint32, 0-based indexing)
%   
%   Uses schema-driven serialization via bct.file.zarr.writeFromSchema.
%
% Examples:
%   M = bct.data.load('Id', 'fsaverage_rh_pial');
%   bct.file.write.manifold.zarr.core('mesh.zarr', M);
%
% See also: bct.file.zarr.writeFromSchema, bct.schema.manifold

arguments
    zarrPath (1,1) string
    M (1,1) bct.Manifold
    options.Overwrite (1,1) logical = true
    options.Strict (1,1) logical = true
end

%% Create schema from Manifold
schema = struct();

% Add core datasets
schema.vertices = struct();
schema.vertices.value = M.Vertices;
schema.vertices.attributes = struct();
schema.vertices.attributes.name = 'vertices';
schema.vertices.attributes.support = 'vertex';
schema.vertices.attributes.dtype_target = 'single';
schema.vertices.attributes.units = 'm';

schema.faces = struct();
schema.faces.value = M.Faces;
schema.faces.attributes = struct();
schema.faces.attributes.name = 'faces';
schema.faces.attributes.support = 'face';
schema.faces.attributes.index_base = 0;  % Will be converted to 0-based

if isprop(M, 'Edges') && ~isempty(M.Edges)
    schema.edges = struct();
    schema.edges.value = M.Edges;
    schema.edges.attributes = struct();
    schema.edges.attributes.name = 'edges';
    schema.edges.attributes.support = 'edge';
    schema.edges.attributes.index_base = 0;  % Will be converted to 0-based
end

%% Write using schema engine
try
    bct.file.zarr.writeFromSchema(zarrPath, schema, 'manifold', ...
        'Overwrite', options.Overwrite, 'Strict', options.Strict);
catch ME
    error('bct:file:write:manifold:zarr:core:WriteFailed', ...
        'Failed to write core manifold: %s', ME.message);
end

end
