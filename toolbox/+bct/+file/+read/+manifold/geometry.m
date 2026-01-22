function geom = geometry(file, options)
%GEOMETRY Read manifold geometry group from HDF5
%
% Syntax:
%   geom = bct.file.read.manifold.geometry(file)
%   geom = bct.file.read.manifold.geometry(file, 'Path', '/geometry')
%
% Inputs:
%   file - string, HDF5 file path
%
% Name-Value Arguments:
%   Path - string (default '/geometry'), HDF5 group path
%
% Outputs:
%   geom - struct with geometry data matching bct.manifold.geometry output
%
% Description:
%   Reads geometry group from HDF5:
%   - Vertex: normals, tangent frames, areas, curvatures
%   - Face: normals, centroids, areas, tangent bases
%   - Edge: lengths, midpoints
%
% Examples:
%   geom = bct.file.read.manifold.geometry('mesh.h5');
%
% See also: bct.file.read.manifold, bct.manifold.geometry

arguments
    file (1,1) string
    options.Path (1,1) string = "/geometry"
end

%% Validate file exists
if ~isfile(file)
    error('bct:file:read:manifold:geometry:FileNotFound', ...
        'File "%s" does not exist.', file);
end

%% Check if geometry group exists
groupPath = char(options.Path);
try
    groupInfo = h5info(file, groupPath);
catch
    error('bct:file:read:manifold:geometry:GroupNotFound', ...
        'Geometry group "%s" not found in file.', groupPath);
end

%% Read all datasets recursively
geom = readGroupRecursive(file, groupPath);

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
    warning('bct:file:read:manifold:geometry:ReadFailed', ...
        'Failed to read from "%s": %s', path, ME.message);
end

end
