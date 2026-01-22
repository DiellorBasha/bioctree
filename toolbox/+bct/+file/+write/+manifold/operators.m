function operators(file, M, options)
%OPERATORS Write manifold operators group to HDF5
%
% Syntax:
%   bct.file.write.manifold.operators(file, M)
%   bct.file.write.manifold.operators(file, M, 'Overwrite', true)
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
%   Writes operators group to /operators with differential operators:
%   - Mass matrix
%   - Stiffness matrix
%   - Laplace-Beltrami operator
%   - DEC operators (d0, d1, dd0, dd1, Hodge stars)
%   - Composition operators (gradient, divergence, curl)
%
% Examples:
%   M = bct.Manifold.read('mesh.obj');
%   bct.file.create('mesh.h5');
%   bct.file.write.manifold.operators('mesh.h5', M);
%
% See also: bct.file.write.manifold, bct.manifold.operators

arguments
    file (1,1) string
    M (1,1) bct.Manifold
    options.Overwrite (1,1) logical = true
    options.Strict (1,1) logical = true
end

%% Validate file exists
if ~isfile(file)
    error('bct:file:write:manifold:operators:FileNotFound', ...
        'File "%s" does not exist.', file);
end

%% Get operators attributes (computed on demand)
ops = M.operators();

%% Write using schema-driven serialization
bct.file.h5.writeFromSchema(file, ops, ...
    'CreateFile', false, ...
    'Overwrite', options.Overwrite, ...
    'Strict', options.Strict);

end
