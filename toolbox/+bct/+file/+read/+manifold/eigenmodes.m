function [eigenvalues, eigenvectors] = eigenmodes(file, options)
%EIGENMODES Read manifold eigenmodes group from HDF5
%
% Syntax:
%   [eigenvalues, eigenvectors] = bct.file.read.manifold.eigenmodes(file)
%   [eigenvalues, eigenvectors] = bct.file.read.manifold.eigenmodes(file, 'NumModes', 100)
%
% Inputs:
%   file - string, HDF5 file path
%
% Name-Value Arguments:
%   Path     - string (default '/eigenmodes'), HDF5 group path
%   NumModes - integer (optional), number of modes to read (reads all if not specified)
%
% Outputs:
%   eigenvalues  - [K×1] eigenvalues
%   eigenvectors - [N×K] eigenvectors (M-orthonormal)
%
% Description:
%   Reads eigenmodes group from HDF5:
%   - Eigenvalues: Laplace-Beltrami eigenvalues
%   - Eigenvectors: eigenvectors (M-orthonormal)
%
% Examples:
%   [eigenvalues, eigenvectors] = bct.file.read.manifold.eigenmodes('mesh.h5');
%   [eigenvalues, eigenvectors] = bct.file.read.manifold.eigenmodes('mesh.h5', 'NumModes', 50);
%
% See also: bct.file.read.manifold, bct.manifold.eigenmodes

arguments
    file (1,1) string
    options.Path (1,1) string = "/eigenmodes"
    options.NumModes = []
end

%% Validate file exists
if ~isfile(file)
    error('bct:file:read:manifold:eigenmodes:FileNotFound', ...
        'File "%s" does not exist.', file);
end

%% Check if eigenmodes group exists
groupPath = char(options.Path);
try
    h5info(file, groupPath);
catch
    error('bct:file:read:manifold:eigenmodes:GroupNotFound', ...
        'Eigenmodes group "%s" not found in file.', groupPath);
end

%% Read eigenvalues and eigenvectors
eigenvalues = h5read(file, [groupPath '/eigenvalues']);
eigenvectors = h5read(file, [groupPath '/eigenvectors']);

%% Limit number of modes if requested
if ~isempty(options.NumModes)
    K = min(options.NumModes, numel(eigenvalues));
    eigenvalues = eigenvalues(1:K);
    eigenvectors = eigenvectors(:, 1:K);
end

end
