function eigenmodes(zarrPath, M, options)
%EIGENMODES Write eigenmodes group to Zarr with chunking
%
% Syntax:
%   bct.file.write.manifold.zarr.eigenmodes(zarrPath, M)
%   bct.file.write.manifold.zarr.eigenmodes(zarrPath, M, 'NumModes', 200)
%
% Inputs:
%   zarrPath - string, Zarr directory path
%   M        - bct.Manifold object
%
% Name-Value Arguments:
%   NumModes  - integer (default 100), number of eigenmodes to compute/write
%   ChunkSize - integer (default 100), number of modes per chunk
%   Overwrite - logical (default true), overwrite existing data
%   Strict    - logical (default true), validate schema compliance
%
% Description:
%   Writes eigenmodes subgroup to Zarr:
%   - eigenvalues (1D array)
%   - eigenvectors (2D array, chunked by modes)
%   
%   Chunking enables streaming and progressive loading of eigenmodes.
%   Default chunk size: 100 modes per chunk.
%   Uses schema-driven serialization.
%
% Examples:
%   M = bct.data.load('Id', 'fsaverage_rh_pial');
%   bct.file.write.manifold.zarr.eigenmodes('mesh.zarr', M);
%
%   % Write 200 modes with 50 modes per chunk
%   bct.file.write.manifold.zarr.eigenmodes('mesh.zarr', M, ...
%       'NumModes', 200, 'ChunkSize', 50);
%
% See also: bct.file.zarr.writeFromSchema, bct.schema.eigenmodes

arguments
    zarrPath (1,1) string
    M (1,1) bct.Manifold
    options.NumModes (1,1) {mustBeInteger, mustBePositive} = 100
    options.ChunkSize (1,1) {mustBeInteger, mustBePositive} = 100
    options.Overwrite (1,1) logical = true
    options.Strict (1,1) logical = true
end

%% Compute eigenmodes
[eigenvalues, eigenvectors] = bct.manifold.eigenmodes(M, options.NumModes);

%% Convert to schema
schema = bct.schema.eigenmodes(eigenvalues, eigenvectors);

%% Write group and attributes
bct.file.zarr.createGroup(zarrPath, 'eigenmodes');

groupAttrs = struct();
groupAttrs.schema = 'bct.eigenmodes@1.1';
groupAttrs.package = 'bct.manifold';
groupAttrs.path = '/eigenmodes';
groupAttrs.num_modes = options.NumModes;
if isfield(schema, 'attributes') && isfield(schema.attributes, 'solver')
    groupAttrs.solver = schema.attributes.solver;
end
bct.file.zarr.writeAttrs(zarrPath, 'eigenmodes', groupAttrs);

%% Write eigenvalues (no chunking needed)
eigenvalPath = 'eigenmodes/eigenvalues';
bct.file.zarr.writeArray(zarrPath, eigenvalPath, eigenvalues, ...
    'Datatype', 'double', 'Overwrite', options.Overwrite);

% Eigenvalue attributes
eigenvalAttrs = struct();
eigenvalAttrs.name = 'eigenvalues';
eigenvalAttrs.shape = size(eigenvalues);
eigenvalAttrs.dtype = 'float64';
eigenvalAttrs.units = '1';
eigenvalAttrs.support = 'mode';
bct.file.zarr.writeAttrs(zarrPath, eigenvalPath, eigenvalAttrs);

%% Write eigenvectors with chunking
eigenvecPath = 'eigenmodes/eigenvectors';

% Write with chunking
nVertices = size(eigenvectors, 1);
nModes = size(eigenvectors, 2);
chunkSize = [nVertices, min(options.ChunkSize, nModes)];

writeChunkedArray(zarrPath, eigenvecPath, eigenvectors, chunkSize, options.Overwrite);

% Eigenvector attributes
eigenvecAttrs = struct();
eigenvecAttrs.name = 'eigenvectors';
eigenvecAttrs.shape = size(eigenvectors);
eigenvecAttrs.dtype = 'float64';
eigenvecAttrs.units = '1';
eigenvecAttrs.support = 'vertex';
eigenvecAttrs.orthonormal = true;
eigenvecAttrs.chunks = chunkSize;
bct.file.zarr.writeAttrs(zarrPath, eigenvecPath, eigenvecAttrs);

end

%% ========================================================================
%% Helper: Write chunked array manually
%% ========================================================================
function writeChunkedArray(zarrPath, arrayPath, data, chunkSize, overwrite)
    fullPath = fullfile(zarrPath, arrayPath);
    
    % Remove existing if overwrite
    if isfolder(fullPath) && overwrite
        rmdir(fullPath, 's');
    end
    
    % Create array directory
    if ~isfolder(fullPath)
        mkdir(fullPath);
    end
    
    % Create .zarray metadata
    zarrMeta = struct();
    zarrMeta.zarr_format = 2;
    zarrMeta.shape = size(data);
    zarrMeta.chunks = chunkSize;
    zarrMeta.dtype = '<f8';  % float64, little-endian
    zarrMeta.compressor = [];  % No compression
    zarrMeta.fill_value = 0.0;
    zarrMeta.order = 'C';  % Row-major
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
    
    % Write chunks
    [nRows, nCols] = size(data);
    nChunksRow = ceil(nRows / chunkSize(1));
    nChunksCol = ceil(nCols / chunkSize(2));
    
    for iRow = 0:(nChunksRow-1)
        for iCol = 0:(nChunksCol-1)
            % Determine chunk data range
            rowStart = iRow * chunkSize(1) + 1;
            rowEnd = min((iRow + 1) * chunkSize(1), nRows);
            colStart = iCol * chunkSize(2) + 1;
            colEnd = min((iCol + 1) * chunkSize(2), nCols);
            
            % Extract chunk data
            chunkData = data(rowStart:rowEnd, colStart:colEnd);
            
            % Pad if needed (Zarr requires fixed chunk sizes)
            if size(chunkData, 1) < chunkSize(1) || size(chunkData, 2) < chunkSize(2)
                paddedData = zeros(chunkSize, 'like', chunkData);
                paddedData(1:size(chunkData, 1), 1:size(chunkData, 2)) = chunkData;
                chunkData = paddedData;
            end
            
            % Generate chunk filename
            chunkName = sprintf('%d.%d', iRow, iCol);
            chunkPath = fullfile(fullPath, chunkName);
            
            % Write chunk as binary (C-order = transpose)
            fid = fopen(chunkPath, 'w');
            if fid == -1
                error('Failed to create chunk file: %s', chunkPath);
            end
            fwrite(fid, chunkData.', 'double');
            fclose(fid);
        end
    end
end
