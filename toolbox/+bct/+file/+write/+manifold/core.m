function core(file, M, options)
%CORE Write core manifold data (vertices, faces, edges) to HDF5
%
% Syntax:
%   bct.file.write.manifold.core(file, M)
%   bct.file.write.manifold.core(file, M, 'Overwrite', true)
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
%   Writes core manifold mesh data to /manifold group:
%   - Vertices: [N×3] coordinates
%   - Faces: [F×3] connectivity (converted to 0-based)
%   - Edges: [E×2] connectivity (converted to 0-based)
%   - Group attributes from M.Attributes
%
% Examples:
%   M = bct.Manifold.read('mesh.obj');
%   bct.file.create('mesh.h5');
%   bct.file.write.manifold.core('mesh.h5', M);
%
% See also: bct.file.write.manifold, bct.file.h5.writeFromSchema

arguments
    file (1,1) string
    M (1,1) bct.Manifold
    options.Overwrite (1,1) logical = true
    options.Strict (1,1) logical = true
end

%% Validate file exists
if ~isfile(file)
    error('bct:file:write:manifold:core:FileNotFound', ...
        'File "%s" does not exist. Use bct.file.create first.', file);
end

%% Write using schema-driven serialization
attrs = M.Attributes;
bct.file.h5.writeFromSchema(file, attrs, ...
    'CreateFile', false, ...
    'Overwrite', options.Overwrite, ...
    'Strict', options.Strict);

end
