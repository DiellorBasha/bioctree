function value = readDataset(file, path)
%READDATASET  Read HDF5 dataset using h5read
%
%   value = bct.file.h5.readDataset(file, path)
%
% Purpose
%   Low-level wrapper around h5read for reading datasets.
%
% Inputs
%   file - string, file path
%   path - string, HDF5 dataset path
%
% Output
%   value - dataset contents

arguments
    file (1,1) string
    path (1,1) string
end

% Normalize path
path = bct.file.h5.normalizePath(path);

% Read using h5read
try
    value = h5read(file, char(path));
catch ME
    error('bct:file:h5:readDataset:ReadFailed', ...
        'Failed to read dataset "%s": %s', path, ME.message);
end

end
