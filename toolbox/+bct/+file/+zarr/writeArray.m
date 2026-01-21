function writeArray(zarrPath, arrayPath, data, options)
%BCT.FILE.ZARR.WRITEARRAY  Write array to Zarr with .zarray metadata
%
%   bct.file.zarr.writeArray(zarrPath, arrayPath, data)
%   bct.file.zarr.writeArray(zarrPath, arrayPath, data, Name=Value)
%
% Purpose
%   Writes a numeric array to a Zarr store with automatic chunking and
%   type conversion. Creates .zarray metadata and writes data chunks.
%
% Inputs
%   zarrPath  - string, root Zarr directory (e.g., "bunny.zarr")
%   arrayPath - string, array path relative to zarrPath (e.g., "manifold/vertices")
%   data      - numeric array to write
%
% Name-Value Arguments
%   Overwrite   - logical (default true), overwrite if exists
%   ChunkSize   - array (default auto), chunk dimensions
%   Compression - struct (default none), compression options
%   FillValue   - scalar (default 0), fill value for missing chunks
%   Datatype    - string (default auto from data), zarr datatype
%
% Examples
%   % Write vertices as float32
%   bct.file.zarr.writeArray("mesh.zarr", "manifold/vertices", V, ...
%       Datatype="single");
%
%   % Write faces with chunking
%   bct.file.zarr.writeArray("mesh.zarr", "manifold/faces", F, ...
%       ChunkSize=[1000, 3]);
%
% See also: zarrcreate, zarrwrite, bct.file.zarr.writeAttrs

arguments
    zarrPath (1,1) string
    arrayPath (1,1) string
    data
    options.Overwrite (1,1) logical = true
    options.ChunkSize = []
    options.Compression = struct()
    options.FillValue = 0
    options.Datatype (1,1) string = ""
end

%% Construct full path
fullPath = fullfile(zarrPath, arrayPath);

%% Check if exists
if isfolder(fullPath)
    if ~options.Overwrite
        error('bct:file:zarr:writeArray:PathExists', ...
            'Path "%s" already exists and Overwrite=false.', fullPath);
    end
    % Remove existing array
    rmdir(fullPath, 's');
end

%% Ensure parent groups exist and create array directory
parentPath = fileparts(fullPath);
if ~isfolder(parentPath)
    bct.file.zarr.createGroup(zarrPath, fileparts(arrayPath));
end

% Create array directory
if ~isfolder(fullPath)
    mkdir(fullPath);
end

%% Determine datatype
if strlength(options.Datatype) == 0
    % Auto-detect from MATLAB type
    dtype = class(data);
else
    dtype = char(options.Datatype);
end

%% Determine chunk size
if isempty(options.ChunkSize)
    % Default: single chunk (no chunking)
    % Manifold data (vertices, faces, edges) should not be chunked
    % Chunking will be implemented for fields (time-series, multi-channel data)
    chunkSize = size(data);
else
    % User-specified chunking
    chunkSize = options.ChunkSize;
end

%% Create Zarr array using pure MATLAB (Zarr v2 format)
% Zarr v2: .zarray JSON + binary chunk files
% CRITICAL: Write C-order (row-major) bytes for GPU consumption (Three.js)
try
    % Create .zarray metadata
    zarrMeta = struct();
    zarrMeta.zarr_format = 2;
    zarrMeta.shape = size(data);
    zarrMeta.chunks = chunkSize;
    zarrMeta.dtype = zarrDtype(dtype);
    zarrMeta.compressor = [];  % No compression
    zarrMeta.fill_value = options.FillValue;
    zarrMeta.order = 'C';  % Row-major (GPU-friendly)
    zarrMeta.filters = [];
    
    % Write .zarray
    zarrayPath = fullfile(fullPath, '.zarray');
    jsonStr = jsonencode(zarrMeta);
    fid = fopen(zarrayPath, 'w');
    if fid == -1
        error('Failed to create .zarray file');
    end
    fwrite(fid, jsonStr, 'char');
    fclose(fid);
    
    % Convert to correct type
    dataTyped = cast(data, dtype);
    
    % Write data as single chunk with C-order (row-major) layout
    % MATLAB is column-major, so transpose 2D arrays for GPU interleaving
    % This gives [x1,y1,z1, x2,y2,z2, ...] instead of [x1..xN, y1..yN, z1..zN]
    chunkName = generateChunkName(length(size(data)));
    chunkPath = fullfile(fullPath, chunkName);
    
    fid = fopen(chunkPath, 'w');
    if fid == -1
        error('Failed to create chunk file');
    end
    
    if ndims(data) == 2
        % 2D arrays: transpose for C-order (row-major) layout
        % This ensures GPU-friendly interleaved format for vertices, faces, edges
        fwrite(fid, dataTyped.', dtype);
    else
        % 1D or higher-dimensional: write as-is
        fwrite(fid, dataTyped, dtype);
    end
    
    fclose(fid);
    
catch ME
    error('bct:file:zarr:writeArray:WriteFailed', ...
        'Failed to write Zarr array: %s', ME.message);
end

end

%% ========================================================================
%% HELPER: Convert MATLAB dtype to Zarr dtype string
%% ========================================================================
function dtype = zarrDtype(matlabType)
%ZARRDTYPE  Convert MATLAB type to Zarr dtype string
%
% Zarr v2 dtype format: '<dtype' for little-endian (GPU-friendly)
% Examples: '<f4' (float32), '<f8' (float64), '<u4' (uint32)

switch matlabType
    case 'double'
        dtype = '<f8';  % 64-bit float, little-endian
    case 'single'
        dtype = '<f4';  % 32-bit float, little-endian (GPU-friendly)
    case 'uint32'
        dtype = '<u4';  % 32-bit unsigned int, little-endian
    case 'uint64'
        dtype = '<u8';
    case 'int32'
        dtype = '<i4';
    case 'int64'
        dtype = '<i8';
    case 'uint16'
        dtype = '<u2';
    case 'int16'
        dtype = '<i2';
    case 'uint8'
        dtype = '<u1';
    case 'int8'
        dtype = '<i1';
    otherwise
        error('Unsupported MATLAB type: %s', matlabType);
end
end

%% ========================================================================
%% HELPER: Generate chunk filename based on dimensionality
%% ========================================================================
function name = generateChunkName(ndims)
%GENERATECHUNKNAME  Create chunk filename for single-chunk array
%
% Zarr v2 chunk naming: dot-separated indices
% Examples: '0' (1D), '0.0' (2D), '0.0.0' (3D)

if ndims == 1
    name = '0';
elseif ndims == 2
    name = '0.0';
else
    name = '0.0.0';
end

end
