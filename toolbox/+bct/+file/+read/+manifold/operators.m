function ops = operators(file, options)
%OPERATORS Read manifold operators group from HDF5
%
% Syntax:
%   ops = bct.file.read.manifold.operators(file)
%   ops = bct.file.read.manifold.operators(file, 'Path', '/operators')
%
% Inputs:
%   file - string, HDF5 file path
%
% Name-Value Arguments:
%   Path - string (default '/operators'), HDF5 group path
%
% Outputs:
%   ops - struct with operator matrices matching bct.manifold.operators output
%
% Description:
%   Reads operators group from HDF5:
%   - Mass matrix
%   - Stiffness matrix
%   - Laplace-Beltrami operator
%   - DEC operators (d0, d1, dd0, dd1, Hodge stars)
%   - Composition operators (gradient, divergence, curl)
%
% Examples:
%   ops = bct.file.read.manifold.operators('mesh.h5');
%
% See also: bct.file.read.manifold, bct.manifold.operators

arguments
    file (1,1) string
    options.Path (1,1) string = "/operators"
end

%% Validate file exists
if ~isfile(file)
    error('bct:file:read:manifold:operators:FileNotFound', ...
        'File "%s" does not exist.', file);
end

%% Check if operators group exists
groupPath = char(options.Path);
try
    groupInfo = h5info(file, groupPath);
catch
    error('bct:file:read:manifold:operators:GroupNotFound', ...
        'Operators group "%s" not found in file.', groupPath);
end

%% Read all datasets recursively
ops = readGroupRecursive(file, groupPath);

end

function data = readGroupRecursive(file, path)
%READGROUPRECURSIVE Recursively read HDF5 group structure

data = struct();

try
    info = h5info(file, path);
    
    % Read datasets
    for i = 1:numel(info.Datasets)
        dsName = info.Datasets(i).Name;
        dsPath = [path '/' dsName];
        data.(dsName) = h5read(file, dsPath);
    end
    
    % Recursively read subgroups
    for i = 1:numel(info.Groups)
        [~, groupName] = fileparts(info.Groups(i).Name);
        data.(groupName) = readGroupRecursive(file, info.Groups(i).Name);
    end
catch ME
    warning('bct:file:read:manifold:operators:ReadFailed', ...
        'Failed to read from "%s": %s', path, ME.message);
end

end
