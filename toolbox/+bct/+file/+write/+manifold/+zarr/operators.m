function operators(zarrPath, M, options)
%OPERATORS Write operators group to Zarr
%
% Syntax:
%   bct.file.write.manifold.zarr.operators(zarrPath, M)
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
%   Writes operators subgroup to Zarr:
%   - FEM operators (mass, stiffness, laplacian)
%   - DEC operators (d0, d1, dd0, dd1, hodge stars)
%   - Composition operators (gradient, divergence, curl)
%   
%   All sparse matrices stored in COO format for efficiency.
%   Uses schema-driven serialization.
%
% Examples:
%   M = bct.data.load('Id', 'fsaverage_rh_pial');
%   ops = M.operators();
%   bct.file.write.manifold.zarr.operators('mesh.zarr', M);
%
% See also: bct.file.zarr.writeFromSchema, bct.schema.operators

arguments
    zarrPath (1,1) string
    M (1,1) bct.Manifold
    options.Overwrite (1,1) logical = true
    options.Strict (1,1) logical = true
end

%% Get operators (from cache if available)
ops = M.operators;

%% Write using schema engine
try
    bct.file.zarr.writeFromSchema(zarrPath, ops, 'operators', ...
        'Overwrite', options.Overwrite, 'Strict', options.Strict);
catch ME
    error('bct:file:write:manifold:zarr:operators:WriteFailed', ...
        'Failed to write operators: %s', ME.message);
end

end
