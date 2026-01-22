function eigenmodes(file, M, options)
%EIGENMODES Write manifold eigenmodes group to HDF5
%
% Syntax:
%   bct.file.write.manifold.eigenmodes(file, M)
%   bct.file.write.manifold.eigenmodes(file, M, 'NumModes', 100)
%
% Inputs:
%   file - string, HDF5 file path (must exist)
%   M    - bct.Manifold object
%
% Name-Value Arguments:
%   Overwrite - logical (default true), overwrite existing datasets
%   Strict    - logical (default true), validate schema compliance
%   NumModes  - integer (default 100), number of eigenmodes to write
%
% Description:
%   Writes eigenmodes group to /eigenmodes with spectral decomposition:
%   - Eigenvalues: [K×1] Laplace-Beltrami eigenvalues
%   - Eigenvectors: [N×K] eigenvectors (M-orthonormal)
%
% Examples:
%   M = bct.Manifold.read('mesh.obj');
%   bct.file.create('mesh.h5');
%   bct.file.write.manifold.eigenmodes('mesh.h5', M, 'NumModes', 200);
%
% See also: bct.file.write.manifold, bct.manifold.eigenmodes

arguments
    file (1,1) string
    M (1,1) bct.Manifold
    options.Overwrite (1,1) logical = true
    options.Strict (1,1) logical = true
    options.NumModes (1,1) {mustBeInteger, mustBePositive} = 100
end

%% Validate file exists
if ~isfile(file)
    error('bct:file:write:manifold:eigenmodes:FileNotFound', ...
        'File "%s" does not exist.', file);
end

%% Get eigenmodes (compute or retrieve from cache)
[eigenvalues, eigenvectors] = M.eigenmodes(options.NumModes);

%% Build schema-compliant attributes structure
eigenAttrs = struct();
eigenAttrs.path = '/eigenmodes';
eigenAttrs.schema = 'bct.eigenmodes@1.0';
eigenAttrs.package = 'bct.manifold.eigen';

% Eigenvalues dataset
eigenAttrs.eigenvalues = bct.schema.dataset.make(eigenvalues, ...
    'Name', 'eigenvalues', ...
    'Path', '/eigenmodes/eigenvalues', ...
    'Description', 'Laplace-Beltrami eigenvalues', ...
    'Units', '1/m^2', ...
    'Support', 'eigenmode', ...
    'ComputedBy', 'bct.manifold.eigenmodes');

% Eigenvectors dataset
eigenAttrs.eigenvectors = bct.schema.dataset.make(eigenvectors, ...
    'Name', 'eigenvectors', ...
    'Path', '/eigenmodes/eigenvectors', ...
    'Description', 'Laplace-Beltrami eigenvectors (M-orthonormal)', ...
    'Units', '1', ...
    'Support', 'vertex', ...
    'ComputedBy', 'bct.manifold.eigenmodes');

%% Write using schema-driven serialization
bct.file.h5.writeFromSchema(file, eigenAttrs, ...
    'CreateFile', false, ...
    'Overwrite', options.Overwrite, ...
    'Strict', options.Strict);

end
