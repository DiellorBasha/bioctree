function writeDataset(file, path, value, options)
%WRITEDATASET  Write HDF5 dataset using h5create/h5write
%
%   bct.file.h5.writeDataset(file, path, value)
%
% Purpose
%   Low-level wrapper for writing datasets to HDF5.
%
% Inputs
%   file  - string, file path
%   path  - string, HDF5 dataset path
%   value - data to write
%
% Name-Value Arguments
%   Overwrite - logical (default true), delete existing if present

arguments
    file (1,1) string
    path (1,1) string
    value
    options.Overwrite (1,1) logical = true
end

% Normalize path
path = bct.file.h5.normalizePath(path);

% Handle overwrite by deleting if exists
if options.Overwrite && bct.file.exists(file, path)
    try
        % Delete using low-level HDF5 API
        fid = H5F.open(char(file), 'H5F_ACC_RDWR', 'H5P_DEFAULT');
        H5L.delete(fid, char(path), 'H5P_DEFAULT');
        H5F.close(fid);
    catch ME
        warning('bct:file:h5:writeDataset:DeleteFailed', ...
            'Failed to delete existing dataset "%s": %s', path, ME.message);
    end
end

% Determine data type and size
if ischar(value) || isstring(value)
    % String data
    value = char(value);
    h5create(file, char(path), [1 1], 'Datatype', 'string');
    h5write(file, char(path), value);
elseif isnumeric(value) || islogical(value)
    % Numeric data
    sz = size(value);
    
    % Map MATLAB type to HDF5 type
    if isa(value, 'double')
        dtype = 'double';
    elseif isa(value, 'single')
        dtype = 'single';
    elseif isa(value, 'int64')
        dtype = 'int64';
    elseif isa(value, 'int32')
        dtype = 'int32';
    elseif isa(value, 'int16')
        dtype = 'int16';
    elseif isa(value, 'int8')
        dtype = 'int8';
    elseif isa(value, 'uint64')
        dtype = 'uint64';
    elseif isa(value, 'uint32')
        dtype = 'uint32';
    elseif isa(value, 'uint16')
        dtype = 'uint16';
    elseif isa(value, 'uint8')
        dtype = 'uint8';
    elseif islogical(value)
        dtype = 'uint8';
        value = uint8(value);
    else
        dtype = 'double';
        value = double(value);
    end
    
    try
        h5create(file, char(path), sz, 'Datatype', dtype);
        h5write(file, char(path), value);
    catch ME
        error('bct:file:h5:writeDataset:WriteFailed', ...
            'Failed to write dataset "%s": %s', path, ME.message);
    end
else
    error('bct:file:h5:writeDataset:UnsupportedType', ...
        'Unsupported data type for HDF5 write: %s', class(value));
end

end
