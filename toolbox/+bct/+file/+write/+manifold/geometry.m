function geometry(file, M, options)
%GEOMETRY Write manifold geometry group to HDF5
%
% Syntax:
%   bct.file.write.manifold.geometry(file, M)
%   bct.file.write.manifold.geometry(file, M, 'Overwrite', true)
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
%   Writes geometry group to /geometry with computed geometric properties:
%   - Vertex: normals, tangent frames, areas, curvatures
%   - Face: normals, centroids, areas, tangent bases
%   - Edge: lengths, midpoints
%
% Examples:
%   M = bct.Manifold.read('mesh.obj');
%   bct.file.create('mesh.h5');
%   bct.file.write.manifold.geometry('mesh.h5', M);
%
% See also: bct.file.write.manifold, bct.manifold.geometry

arguments
    file (1,1) string
    M (1,1) bct.Manifold
    options.Overwrite (1,1) logical = true
    options.Strict (1,1) logical = true
end

%% Validate file exists
if ~isfile(file)
    error('bct:file:write:manifold:geometry:FileNotFound', ...
        'File "%s" does not exist.', file);
end

%% Get geometry attributes (computed on demand)
geom = M.geometry();

%% Write using schema-driven serialization
bct.file.h5.writeFromSchema(file, geom, ...
    'CreateFile', false, ...
    'Overwrite', options.Overwrite, ...
    'Strict', options.Strict);

end
