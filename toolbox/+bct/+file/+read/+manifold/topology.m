function topo = topology(file, options)
%TOPOLOGY Read manifold topology group from HDF5
%
% Syntax:
%   topo = bct.file.read.manifold.topology(file)
%   topo = bct.file.read.manifold.topology(file, 'Path', '/topology')
%
% Inputs:
%   file - string, HDF5 file path
%
% Name-Value Arguments:
%   Path - string (default '/topology'), HDF5 group path
%
% Outputs:
%   topo - struct with topology data matching bct.manifold.topology output
%
% Description:
%   Reads topology group from HDF5:
%   - Adjacency matrices
%   - Boundary information
%   - Halfedge structure
%   - Connected components
%
% Examples:
%   topo = bct.file.read.manifold.topology('mesh.h5');
%
% See also: bct.file.read.manifold, bct.manifold.topology

arguments
    file (1,1) string
    options.Path (1,1) string = "/topology"
end

%% Validate file exists
if ~isfile(file)
    error('bct:file:read:manifold:topology:FileNotFound', ...
        'File "%s" does not exist.', file);
end

%% Check if topology group exists
groupPath = char(options.Path);
try
    groupInfo = h5info(file, groupPath);
catch
    error('bct:file:read:manifold:topology:GroupNotFound', ...
        'Topology group "%s" not found in file.', groupPath);
end

%% Read all datasets recursively
topo = readGroupRecursive(file, groupPath);

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
    warning('bct:file:read:manifold:topology:ReadFailed', ...
        'Failed to read from "%s": %s', path, ME.message);
end

end
