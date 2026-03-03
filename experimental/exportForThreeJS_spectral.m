function manifest = exportForThreeJS_spectral(M, outBase, options)
% EXPORTFORTHREEJS_SPECTRAL Export bct.Manifold with spectral data to Three.js format
%
% Syntax:
%   manifest = exportForThreeJS_spectral(M, outBase)
%   manifest = exportForThreeJS_spectral(M, outBase, Name, Value)
%
% Inputs:
%   M       - bct.Manifold object (with precomputed geometry, topology, eigenmodes)
%   outBase - Output file path without extension (e.g., 'data/bunny_spectral')
%
% Name-Value Arguments:
%   NumModes             - Number of eigenmodes to export (default: all cached)
%   ExportEigenvectors   - Export eigenvectors (default: true)
%   ExportGradientBasis  - Export gradient eigenbasis (default: true)
%   TangentProject       - Project gradients to face tangent planes (default: true)
%   ExportFaceAreas      - Export face area data (default: true)
%   ExportFaceTangents   - Export face tangent vectors (default: false)
%   ExportVertexMass     - Export vertex mass/area weights (default: true)
%   AlignBytes           - Byte alignment for binary arrays (default: 4)
%   Precision            - 'single' (default) or 'double' for output precision
%
% Outputs:
%   manifest - Structure with export metadata
%   Creates two files:
%     <outBase>.bin  - Binary data file
%     <outBase>.json - JSON manifest with layouts and byte offsets
%
% Data Layout (for JavaScript):
%   eigenvectors: [K × nV] float32, mode-major layout
%                 Linear index: eigenvectors[k + K*v] for mode k, vertex v
%
%   gradientBasis: [3 × K × nF] float32, component-major layout
%                  Linear index: gradientBasis[c + 3*(k + K*f)]
%                  where c=0,1,2 for X,Y,Z components
%
%   faceNeighbors: [nF × 3] int32, 0-based face indices, -1 for boundary
%   neighborEdge:  [nF × 3] uint8, 0..2 local edge index in neighbor face
%
% Description:
%   Exports a bct.Manifold with spectral analysis data to binary+JSON format
%   for efficient loading in JavaScript/WebGPU applications.
%
%   Requires precomputed data:
%     - M.geometry() - Face/vertex geometry
%     - M.topology() - Mesh topology with halfedge structure
%     - M.eigenmodes() - Eigenmode basis
%
%   Uses bct.Manifold conventions:
%     - eigenvalues, eigenvectors (not lambda, psi)
%     - Descriptive field names
%     - Consistent data organization
%
% Examples:
%   % Basic export
%   M = bct.data.load('Id', 'bunny');
%   M.geometry();
%   M.topology();
%   M.eigenmodes(256);
%   exportForThreeJS_spectral(M, 'data/bunny_spectral');
%
%   % Export with specific options
%   exportForThreeJS_spectral(M, 'data/bunny', ...
%       'NumModes', 128, ...
%       'TangentProject', true, ...
%       'Precision', 'single');
%
% See also: bct.manifold.transform.gradient, bct.file.writeBinaryManifest

arguments
    M (1,1) bct.Manifold
    outBase (1,1) string
    options.NumModes (1,1) {mustBePositive, mustBeInteger} = inf
    options.ExportEigenvectors (1,1) logical = true
    options.ExportGradientBasis (1,1) logical = true
    options.TangentProject (1,1) logical = true
    options.ExportFaceAreas (1,1) logical = true
    options.ExportFaceTangents (1,1) logical = false
    options.ExportVertexMass (1,1) logical = true
    options.AlignBytes (1,1) {mustBePositive, mustBeInteger} = 4
    options.Precision (1,1) string {mustBeMember(options.Precision, ["single", "double"])} = "single"
end

% -----------------------------
% Get cached data from Manifold
% -----------------------------
fprintf('Preparing spectral export for Three.js...\n');

% Get eigenmodes (must be precomputed)
if ~M.hasCached('eigenmodes')
    error('bct:exportForThreeJS:MissingEigenmodes', ...
        'Eigenmodes must be computed before export. Call M.eigenmodes(k) first.');
end
eigenData = M.eigenmodes();
numAvailableModes = double(eigenData.k);

% Determine number of modes to export
numModesToExport = min(options.NumModes, numAvailableModes);
K = uint32(numModesToExport);
fprintf('  Exporting %d of %d available eigenmodes\n', numModesToExport, numAvailableModes);

% Get geometry (must be precomputed)
if ~M.hasCached('geometry')
    error('bct:exportForThreeJS:MissingGeometry', ...
        'Geometry must be computed before export. Call M.geometry() first.');
end
geom = M.geometry();

% Get topology (must be precomputed)
if ~M.hasCached('topology')
    error('bct:exportForThreeJS:MissingTopology', ...
        'Topology must be computed before export. Call M.topology() first.');
end
topo = M.topology();

% Extract dimensions
nV = uint32(M.numVertices());
nF = uint32(M.numFaces());

% Convert precision
precisionClass = options.Precision;
if precisionClass == "single"
    castFn = @single;
else
    castFn = @double;
end

% -----------------------------
% Extract geometry arrays
% -----------------------------
fprintf('  Extracting geometry arrays...\n');

% Vertex positions [nV × 3] 
positions = castFn(M.Vertices);

% Face indices [nF × 3] - convert to 0-based for JavaScript
faceIndices = uint32(M.Faces - 1);

% Vertex normals [nV × 3]
vertexNormals = castFn(geom.vertexNormals);

% Face normals [nF × 3]
faceNormals = castFn(geom.normals);
faceNormals = normalizeRows(faceNormals);

% Face centroids [nF × 3]
faceCentroids = castFn(geom.centroids);

% Face areas [nF × 1]
if options.ExportFaceAreas
    faceAreas = castFn(geom.areas(:));
else
    faceAreas = [];
end

% Face tangent frames [nF × 3] for each tangent
if options.ExportFaceTangents
    tangent1 = castFn(geom.tangent1);
    tangent2 = castFn(geom.tangent2);
else
    tangent1 = [];
    tangent2 = [];
end

% -----------------------------
% Extract topology arrays
% -----------------------------
fprintf('  Extracting topology arrays...\n');

% Face neighbors from halfedge structure [nF × 3]
% 0-based indices, -1 for boundary edges
H = topo.halfedge;
faceNeighbors = int32(H.faceNeighbors - 1);  % Convert to 0-based
faceNeighbors(H.faceNeighbors == 0) = int32(-1);  % Mark boundaries

% Neighbor edge indices [nF × 3] - already 0-based (0, 1, or 2)
neighborEdge = uint8(H.neighborEdge);

% -----------------------------
% Extract eigenmode data
% -----------------------------
fprintf('  Extracting eigenmode data...\n');

% Eigenvalues [K × 1]
eigenvalues = castFn(eigenData.values(1:numModesToExport));

% Eigenvectors [K × nV] - mode-major layout for GPU efficiency
if options.ExportEigenvectors
    eigenvectors_VK = castFn(eigenData.vectors(:, 1:numModesToExport));  % [nV × K]
    eigenvectors = eigenvectors_VK.';  % [K × nV] mode-major
else
    eigenvectors = [];
end

% Vertex mass vector [nV × 1] for M-orthonormality
% Export as vector to avoid full sparse matrix in JavaScript
if options.ExportVertexMass
    massMatrix = M.massmatrix();
    vertexMass = castFn(full(diag(massMatrix)));
else
    vertexMass = [];
end

% -----------------------------
% Compute gradient eigenbasis
% -----------------------------
if options.ExportGradientBasis
    fprintf('  Computing gradient eigenbasis...\n');
    
    % Use bct.manifold.transform.gradient to project gradient onto eigenmodes
    gradientBasis = bct.manifold.transform.gradient(M, numModesToExport, ...
        'TangentProject', options.TangentProject, ...
        'Precision', options.Precision);
    
    % gradientBasis is [nF × K × 3] - reshape to flat array [3*K*nF × 1]
    gradientBasis_flat = castFn(reshape(permute(gradientBasis, [3 2 1]), [], 1));
else
    gradientBasis_flat = [];
end

% -----------------------------
% Flatten arrays for binary export
% -----------------------------
fprintf('  Flattening arrays for binary export...\n');

% Flatten each array to column vector
positions_flat = reshape(positions.', [], 1);            % [3*nV × 1]
faceIndices_flat = reshape(faceIndices.', [], 1);        % [3*nF × 1]
faceCentroids_flat = reshape(faceCentroids.', [], 1);    % [3*nF × 1]
faceNormals_flat = reshape(faceNormals.', [], 1);        % [3*nF × 1]
faceNeighbors_flat = reshape(faceNeighbors.', [], 1);    % [3*nF × 1]
neighborEdge_flat = reshape(neighborEdge.', [], 1);      % [3*nF × 1]
eigenvalues_flat = reshape(eigenvalues, [], 1);          % [K × 1]

% Build array list for export
arrays = {
    struct('name', "positions",      'data', positions_flat,      'dtype', precisionClass, 'shape', [double(nV) 3])
    struct('name', "faceIndices",    'data', faceIndices_flat,    'dtype', "uint32",       'shape', [double(nF) 3])
    struct('name', "faceCentroids",  'data', faceCentroids_flat,  'dtype', precisionClass, 'shape', [double(nF) 3])
    struct('name', "faceNormals",    'data', faceNormals_flat,    'dtype', precisionClass, 'shape', [double(nF) 3])
    struct('name', "faceNeighbors",  'data', faceNeighbors_flat,  'dtype', "int32",        'shape', [double(nF) 3])
    struct('name', "neighborEdge",   'data', neighborEdge_flat,   'dtype', "uint8",        'shape', [double(nF) 3])
    struct('name', "eigenvalues",    'data', eigenvalues_flat,    'dtype', precisionClass, 'shape', [double(K) 1])
};

% Add optional arrays
if ~isempty(vertexMass)
    vertexMass_flat = reshape(vertexMass, [], 1);
    arrays{end+1} = struct('name', "vertexMass", 'data', vertexMass_flat, 'dtype', precisionClass, 'shape', [double(nV) 1]);
end

% Add optional arrays
if ~isempty(vertexMass)
    vertexMass_flat = reshape(vertexMass, [], 1);
    arrays{end+1} = struct('name', "vertexMass", 'data', vertexMass_flat, 'dtype', precisionClass, 'shape', [double(nV) 1]);
end

if ~isempty(faceAreas)
    faceAreas_flat = reshape(faceAreas, [], 1);
    arrays{end+1} = struct('name', "faceAreas", 'data', faceAreas_flat, 'dtype', precisionClass, 'shape', [double(nF) 1]);
end

if ~isempty(tangent1)
    tangent1_flat = reshape(tangent1.', [], 1);
    tangent2_flat = reshape(tangent2.', [], 1);
    arrays{end+1} = struct('name', "tangent1", 'data', tangent1_flat, 'dtype', precisionClass, 'shape', [double(nF) 3]);
    arrays{end+1} = struct('name', "tangent2", 'data', tangent2_flat, 'dtype', precisionClass, 'shape', [double(nF) 3]);
end

if ~isempty(eigenvectors)
    eigenvectors_flat = reshape(eigenvectors, [], 1);  % [K*nV × 1]
    arrays{end+1} = struct('name', "eigenvectors", 'data', eigenvectors_flat, 'dtype', precisionClass, 'shape', [double(K) double(nV)]);
end

if ~isempty(gradientBasis_flat)
    arrays{end+1} = struct('name', "gradientBasis", 'data', gradientBasis_flat, 'dtype', precisionClass, 'shape', [3 double(K) double(nF)]);
end

% -----------------------------
% Write binary + manifest
% -----------------------------
fprintf('  Writing binary data...\n');

binPath  = outBase + ".bin";
jsonPath = outBase + ".json";

[fid, msg] = fopen(binPath, 'w');
if fid < 0
    error("Cannot open %s for writing: %s", binPath, msg);
end

offset = uint32(0);
align  = uint32(options.AlignBytes);

% Initialize manifest structure
manifest = struct();
manifest.schema = "bct.threejs.spectral@1";
manifest.nV = nV;
manifest.nF = nF;
manifest.K  = K;

% Document array layouts for JavaScript/WebGPU consumption
manifest.layouts = struct();
manifest.layouts.positions      = "VxC (vertex-major, C=3), idx = 3*v + c";
manifest.layouts.faceIndices    = "FxC (face-major, C=3), idx = 3*f + c";
manifest.layouts.eigenvectors   = "KxV (mode-major), idx = k + K*v";
manifest.layouts.gradientBasis  = "CxKxF (C=3), idx = c + 3*(k + K*f)";
manifest.layouts.vertexMass     = "Vx1, idx = v";

% Document processing flags
manifest.flags = struct();
manifest.flags.gradientBasisTangentProjected = logical(options.ExportGradientBasis && options.TangentProject);
manifest.flags.vertexMassExported = logical(options.ExportVertexMass);

manifest.buffers = [];

for i = 1:numel(arrays)
    A = arrays{i};

    % Align
    if align > 1
        pad = mod(double(align - mod(offset, align)), double(align));
        if pad ~= 0 && pad ~= double(align)
            fwrite(fid, zeros(pad,1,'uint8'), 'uint8');
            offset = offset + uint32(pad);
        end
    end

    entry = struct();
    entry.name = A.name;
    entry.dtype = A.dtype;
    entry.shape = A.shape;
    entry.count = uint32(numel(A.data));
    entry.byteOffset = offset;

    fwrite(fid, A.data, matlabClassForDtype(A.dtype));

    bytesWritten = uint32(numel(A.data) * bytesPerElement(A.dtype));
    offset = offset + bytesWritten;

    manifest.buffers = [manifest.buffers; entry]; %#ok<AGROW>
end

fclose(fid);

% Write manifest
fprintf('  Writing manifest...\n');
txt = jsonencode(manifest);
[fid, msg] = fopen(jsonPath, 'w');
if fid < 0
    error("Cannot open %s for writing: %s", jsonPath, msg);
end
fwrite(fid, txt, 'char');
fclose(fid);

fprintf('Export complete:\n  %s\n  %s\n', jsonPath, binPath);

end

% -------------------------------------------------------------------------
% Helpers
% -------------------------------------------------------------------------
function N = normalizeRows(N)
% Normalize each row to unit length
den = vecnorm(N, 2, 2);
den = max(den, eps('single'));
N = N ./ den;
end

function cls = matlabClassForDtype(dtype)
% Map dtype string to MATLAB class for fwrite
switch dtype
    case "float32", cls = 'single';
    case "float64", cls = 'double';
    case "uint32",  cls = 'uint32';
    case "int32",   cls = 'int32';
    case "uint8",   cls = 'uint8';
    otherwise, error("Unsupported dtype: %s", dtype);
end
end

function b = bytesPerElement(dtype)
% Get number of bytes for each dtype
switch dtype
    case "float32", b = 4;
    case "float64", b = 8;
    case "uint32",  b = 4;
    case "int32",   b = 4;
    case "uint8",   b = 1;
    otherwise, error("Unsupported dtype: %s", dtype);
end
end
