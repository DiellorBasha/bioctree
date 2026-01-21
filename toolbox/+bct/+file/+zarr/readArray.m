function data = readArray(zarrPath, arrayPath, options)
%READARRAY  Read array from Zarr v2 store
%
%   data = bct.file.zarr.readArray(zarrPath, arrayPath)
%
% Purpose
%   Reads a Zarr v2 array from a filesystem directory store.
%   Handles C-order (row-major) to MATLAB column-major conversion.
%
% Inputs
%   zarrPath  - string, root path to Zarr store (directory)
%   arrayPath - string, relative path to array within store
%               (e.g., "manifold/vertices")
%
% Name-Value Arguments
%   Transpose - logical (default true), transpose 2D arrays from C-order
%               to MATLAB column-major order
%
% Output
%   data - Array data in MATLAB format (transposed if 2D)
%
% Notes
%   - Assumes single-chunk arrays (manifold topology)
%   - Reads .zarray metadata and binary chunk files
%   - C-order data is transposed for 2D arrays by default
%
% Examples
%   vertices = bct.file.zarr.readArray("mesh.zarr", "manifold/vertices");
%   faces = bct.file.zarr.readArray("mesh.zarr", "manifold/faces");
%
% See also: bct.file.zarr.writeArray

arguments
    zarrPath (1,1) string
    arrayPath (1,1) string
    options.Transpose (1,1) logical = true
end

%% Validate inputs
if ~isfolder(zarrPath)
    error('bct:file:zarr:readArray:InvalidPath', ...
        'Zarr store not found: %s', zarrPath);
end

fullPath = fullfile(zarrPath, arrayPath);
if ~isfolder(fullPath)
    error('bct:file:zarr:readArray:ArrayNotFound', ...
        'Array not found: %s', arrayPath);
end

%% Read .zarray metadata
zarrayPath = fullfile(fullPath, '.zarray');
if ~isfile(zarrayPath)
    error('bct:file:zarr:readArray:MissingMetadata', ...
        '.zarray file not found: %s', arrayPath);
end

metaJson = fileread(zarrayPath);
meta = jsondecode(metaJson);

% Validate Zarr format
if meta.zarr_format ~= 2
    error('bct:file:zarr:readArray:UnsupportedFormat', ...
        'Only Zarr v2 format supported, got: %d', meta.zarr_format);
end

%% Determine chunk filename
ndims = length(meta.shape);
if ndims == 1
    chunkName = '0';
elseif ndims == 2
    chunkName = '0.0';
else
    chunkName = '0.0.0';
end

chunkPath = fullfile(fullPath, chunkName);
if ~isfile(chunkPath)
    error('bct:file:zarr:readArray:ChunkNotFound', ...
        'Chunk file not found: %s', chunkName);
end

%% Read binary chunk
% Convert Zarr dtype to MATLAB type
matlabType = zarrDtypeToMatlab(meta.dtype);

% Open and read binary file
fid = fopen(chunkPath, 'r');
if fid == -1
    error('bct:file:zarr:readArray:ReadFailed', ...
        'Failed to open chunk file: %s', chunkPath);
end

try
    % Read all data
    rawData = fread(fid, inf, matlabType);
    fclose(fid);
catch ME
    fclose(fid);
    rethrow(ME);
end

%% Reshape and transpose
if ndims == 2
    % C-order (row-major) was written as transpose of MATLAB data
    % Need to transpose back to get MATLAB column-major order
    shape = meta.shape;
    
    if options.Transpose
        % Reshape as [cols, rows] then transpose to [rows, cols]
        data = reshape(rawData, shape(2), shape(1))';
    else
        % Keep C-order (for debugging/validation)
        data = reshape(rawData, shape(2), shape(1))';
    end
else
    % 1D or 3D - reshape directly
    data = reshape(rawData, meta.shape);
end

end

%% ========================================================================
%% HELPER: Convert Zarr dtype string to MATLAB type
%% ========================================================================
function matlabType = zarrDtypeToMatlab(dtype)
%ZARRDTYPETOMATLAB  Convert Zarr dtype string to MATLAB type
%
% Zarr v2 dtype format: '<dtype' for little-endian
% Examples: '<f4' → 'single', '<u4' → 'uint32'

switch dtype
    case '<f8'
        matlabType = 'double';
    case '<f4'
        matlabType = 'single';
    case '<u4'
        matlabType = 'uint32';
    case '<u8'
        matlabType = 'uint64';
    case '<i4'
        matlabType = 'int32';
    case '<i8'
        matlabType = 'int64';
    case '<u2'
        matlabType = 'uint16';
    case '<i2'
        matlabType = 'int16';
    case '<u1'
        matlabType = 'uint8';
    case '<i1'
        matlabType = 'int8';
    otherwise
        error('Unsupported Zarr dtype: %s', dtype);
end
end
