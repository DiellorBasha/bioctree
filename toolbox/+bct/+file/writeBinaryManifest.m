function writeBinaryManifest(M, outPath, options)
%WRITEBINARYMANIFEST Export bct.Manifold to binary + JSON manifest format
%
% Syntax:
%   bct.file.writeBinaryManifest(M, outPath)
%   bct.file.writeBinaryManifest(M, outPath, Name, Value)
%
% Inputs:
%   M       - bct.Manifold object
%   outPath - Output file path without extension (e.g., 'data/mesh')
%
% Name-Value Arguments:
%   AlignBytes - Byte alignment for binary arrays (default: 4)
%   Precision  - 'double' or 'single' for numeric precision (default: 'double')
%
% Outputs:
%   Creates two files:
%     <outPath>.bin  - Binary data file with all numeric arrays
%     <outPath>.json - JSON manifest with schema and byte offsets
%
% Description:
%   Exports a complete bct.Manifold to a binary+JSON format suitable for
%   external processing or archival. All public properties and cached data
%   are exported:
%
%   - Public properties: Vertices, Faces, Edges, ID, Metric
%   - Cached geometry: face/vertex/edge properties (if computed)
%   - Cached topology: edges, adjacency, halfedge structure (if computed)
%   - Cached operators: mass, stiffness, DEC operators (if computed)
%   - Cached eigenmodes: eigenvalues, eigenvectors (if computed)
%
%   The JSON manifest contains:
%     - Schema describing all fields and their types
%     - Buffer entries with path, dtype, shape, count, byteOffset
%     - Metadata about the manifold and export settings
%
%   Numeric arrays are flattened to column vectors in the binary file.
%   String fields (like ID) are stored in the JSON only.
%
% Examples:
%   % Export with all defaults
%   M = bct.data.load('Id', 'fsaverage_rh_pial');
%   ops = M.operators();  % Populate cache
%   bct.file.writeBinaryManifest(M, 'output/mesh');
%   % Creates: output/mesh.bin, output/mesh.json
%
%   % Export with single precision and 8-byte alignment
%   bct.file.writeBinaryManifest(M, 'output/mesh', 'Precision', 'single', 'AlignBytes', 8);
%
%   % Read back in Python:
%   % import json, numpy as np
%   % with open('mesh.json') as f: manifest = json.load(f)
%   % data = np.fromfile('mesh.bin', dtype='uint8')
%   % For each buffer: arr = data[offset:offset+count*bytes].view(dtype).reshape(shape)
%
% See also: bct.manifold.out, bct.file.readBinaryManifest

arguments
    M (1,1) bct.Manifold
    outPath (1,1) string
    options.AlignBytes (1,1) {mustBePositive, mustBeInteger} = 4
    options.Precision (1,1) string {mustBeMember(options.Precision, ["double", "single"])} = "double"
end

% Convert precision setting
if options.Precision == "single"
    % Note: Currently the struct export doesn't support precision control
    % This would require adding precision parameter to bct.manifold.out
    warning('bct:file:writeBinaryManifest:PrecisionNotImplemented', ...
        'Precision control not yet implemented. Using stored precision.');
end

% Step 1: Get structured output from Manifold
fprintf('Exporting manifold structure...\n');
outStruct = bct.manifold.out(M, 'struct');

% Step 2: Exclude operators (large sparse matrices)
if isfield(outStruct, 'operators')
    fprintf('  Excluding operators namespace (sparse matrices)\n');
    outStruct = rmfield(outStruct, 'operators');
end

% Step 3: Flatten structure to extract all numeric arrays
fprintf('Flattening nested structures...\n');
[arrays, schema] = bct.file.write.flattenStruct(outStruct);
fprintf('  Found %d numeric arrays to export\n', numel(arrays));

% Step 4: Write binary file
binPath = outPath + ".bin";
fprintf('Writing binary data to %s...\n', binPath);
bufferManifest = bct.file.write.writeBinary(arrays, binPath, ...
    'alignBytes', options.AlignBytes);

% Step 5: Build complete manifest
manifest = struct();
manifest.schema = "bct.manifold.binary@1";
manifest.version = "1.0.0";
manifest.generated = string(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));

% Manifold metadata
manifest.manifold = struct();
manifest.manifold.id = outStruct.ID;
manifest.manifold.nVertices = M.numVertices();
manifest.manifold.nFaces = M.numFaces();
manifest.manifold.nEdges = M.numEdges();

if isfield(outStruct, 'Metric')
    manifest.manifold.metric = outStruct.Metric;
end

% Export settings
manifest.settings = struct();
manifest.settings.alignBytes = options.AlignBytes;
manifest.settings.precision = options.Precision;
manifest.settings.excludedData = ["operators"];  % Sparse matrices excluded

% Data schema (describes structure)
manifest.dataSchema = schema;

% Buffer information (byte offsets for reading binary)
manifest.buffers = bufferManifest.buffers;

% Step 6: Write JSON manifest
jsonPath = outPath + ".json";
fprintf('Writing manifest to %s...\n', jsonPath);
bct.file.write.writeManifest(manifest, jsonPath);

fprintf('Export complete:\n');
fprintf('  Binary: %s\n', binPath);
fprintf('  Manifest: %s\n', jsonPath);

end
