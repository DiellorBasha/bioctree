function exportForThreeJS(M, fg, faceNeighbors, faceNeighborEdge, transport2x2, outBase)
% exportForThreeJS  Export mesh + advection auxiliaries for Three.js/WebGPU.
%
% outBase: file path without extension, e.g. "bunny_attractor"
% Produces: outBase.json and outBase.bin

if nargin < 6
    outBase = "mesh_export";
end

% ---------- 1) Cast + convert indexing ----------
V  = single(M.Vertices);                 % [nV x 3]
F  = uint32(M.Faces - 1);                % [nF x 3] 0-based for JS

t1 = single(fg.tangent1);                % [nF x 3]
t2 = single(fg.tangent2);                % [nF x 3]
nF = single(fg.normals);                 % [nF x 3]
aF = single(fg.areas);                   % [nF x 1]
cF = single(fg.centroids);               % [nF x 3]

% neighbors: int32 with -1 boundary sentinel, 0-based for valid faces
faceNeighbors0 = int32(faceNeighbors);
mask = faceNeighbors0 > 0;
faceNeighbors0(mask) = faceNeighbors0(mask) - 1;  % convert to 0-based
% Keep -1 as -1
faceNeighbors0(faceNeighbors0 == 0) = -1; % safety in case you used 0 sentinel

neighborEdge = uint8(faceNeighborEdge);  % [nF x 3] typically values 1..3 in MATLAB
% If neighborEdge is 1..3, convert to 0..2 for JS convenience:
neighborEdge = neighborEdge - uint8(1);

% transport2x2: flatten to [nF x 3 x 4] = [T11 T12 T21 T22]
% Ensure single
T = single(transport2x2);
% T is [nF x 3 x 2 x 2] -> flatten last two dims
nFaces = size(T,1);
Tf = zeros(nFaces, 3, 4, 'single');
Tf(:,:,1) = T(:,:,1,1);
Tf(:,:,2) = T(:,:,1,2);
Tf(:,:,3) = T(:,:,2,1);
Tf(:,:,4) = T(:,:,2,2);
Tf = reshape(Tf, [], 1); % 1D packed (nF*3*4)

% Flatten everything for binary packing
Vf  = reshape(V.', [], 1);     % xyzxyz...
Ff  = reshape(F.', [], 1);     % i0 i1 i2 ...
t1f = reshape(t1.', [], 1);
t2f = reshape(t2.', [], 1);
nFf = reshape(nF.', [], 1);
aFf = reshape(aF,  [], 1);
cFf = reshape(cF.', [], 1);
Nb  = reshape(faceNeighbors0.', [], 1);
Ne  = reshape(neighborEdge.', [], 1);

% ---------- 2) Pack into one .bin with offsets ----------
arrays = {
    struct('name',"V",             'data',Vf,  'dtype',"float32")
    struct('name',"F",             'data',Ff,  'dtype',"uint32")
    struct('name',"t1",            'data',t1f, 'dtype',"float32")
    struct('name',"t2",            'data',t2f, 'dtype',"float32")
    struct('name',"faceNormals",   'data',nFf, 'dtype',"float32")
    struct('name',"faceAreas",     'data',aFf, 'dtype',"float32")
    struct('name',"centroids",     'data',cFf, 'dtype',"float32")
    struct('name',"faceNeighbors", 'data',Nb,  'dtype',"int32")
    struct('name',"neighborEdge",  'data',Ne,  'dtype',"uint8")
    struct('name',"transport2x2",  'data',Tf,  'dtype',"float32")
};

% Write binary + build manifest
binPath  = outBase + ".bin";
jsonPath = outBase + ".json";

fid = fopen(binPath, 'w');
if fid < 0, error("Cannot open %s for writing.", binPath); end

offset = uint32(0);
manifest = struct();
manifest.nV = size(M.Vertices,1);
manifest.nF = size(M.Faces,1);
manifest.buffers = [];

for i = 1:numel(arrays)
    A = arrays{i};

    % Align to 4 bytes for most data; uint8 can be left as-is, but keep 4-byte alignment anyway.
    align = uint32(4);
    pad = mod(double(align - mod(offset, align)), double(align));
    if pad ~= 0
        fwrite(fid, zeros(pad,1,'uint8'), 'uint8');
        offset = offset + uint32(pad);
    end

    % Record
    entry = struct();
    entry.name = A.name;
    entry.dtype = A.dtype;
    entry.count = uint32(numel(A.data));
    entry.byteOffset = offset;

    % Write
    fwrite(fid, A.data, matlabClassForDtype(A.dtype));

    bytesWritten = uint32(numel(A.data) * bytesPerElement(A.dtype));
    offset = offset + bytesWritten;

    manifest.buffers = [manifest.buffers; entry]; %#ok<AGROW>
end

fclose(fid);

% ---------- 3) Write JSON manifest ----------
txt = jsonencode(manifest);
fid = fopen(jsonPath, 'w');
fwrite(fid, txt, 'char');
fclose(fid);

fprintf("Wrote:\n  %s\n  %s\n", jsonPath, binPath);

end

function cls = matlabClassForDtype(dtype)
switch dtype
    case "float32", cls = 'single';
    case "uint32",  cls = 'uint32';
    case "int32",   cls = 'int32';
    case "uint8",   cls = 'uint8';
    otherwise, error("Unsupported dtype: %s", dtype);
end
end

function b = bytesPerElement(dtype)
switch dtype
    case "float32", b = 4;
    case "uint32",  b = 4;
    case "int32",   b = 4;
    case "uint8",   b = 1;
    otherwise, error("Unsupported dtype: %s", dtype);
end
end
