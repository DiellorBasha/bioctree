function exportForThreeJS_eulerian(M, fg, vg, faceNeighbors0, U_face, H_face, outBase)
% exportForThreeJS_eulerian
% Export mesh + opposite-vertex neighbor table + per-face Eulerian velocity field
% + precomputed normals/centroids for Three.js/WebGPU.
%
% Required buffers (names used by Three.js):
%   V              float32 [nV*3]
%   F              uint32  [nF*3]    (0-based indices)
%   faceNeighbors  int32   [nF*3]    (0-based neighbor face ids, -1 boundary)
%   U_face         float32 [nF*3]
%   vertexNormals  float32 [nV*3]
%   faceNormals    float32 [nF*3]
%   centroids      float32 [nF*3]
% Optional:
%   faceAreas      float32 [nF]

if nargin < 6
    outBase = "particle_vis_eulerian";
end

% ---------- Cast ----------
V  = single(M.Vertices);                 % [nV x 3]
F  = uint32(M.Faces - 1);                % [nF x 3], 0-based

nV = size(V,1);
nF = size(F,1);

U  = single(U_face);                     % [nF x 3]
assert(size(U,1) == nF && size(U,2) == 3, 'U_face must be [nF x 3].');

VN = single(vg.normals);                 % [nV x 3]
FN = single(fg.normals);                 % [nF x 3]
C  = single(fg.centroids);               % [nF x 3]
A  = single(fg.areas);                   % [nF x 1] optional

% Neighbor table already 0-based with -1 boundary
Nb = int32(faceNeighbors0);
assert(all(size(Nb) == [nF, 3]), 'faceNeighbors0 must be [nF x 3].');

% ---------- Flatten ----------
Vf  = reshape(V.',  [], 1);
Ff  = reshape(F.',  [], 1);
Nbf = reshape(Nb.', [], 1);
Uf  = reshape(U.',  [], 1);
VNf = reshape(VN.', [], 1);
FNf = reshape(FN.', [], 1);
Cf  = reshape(C.',  [], 1);
Af  = reshape(A,    [], 1);
Hf = single(H_face(:));                 % [nF x 1]
assert(numel(Hf) == nF, 'H_face must be [nF x 1].');
Hmax = max(Hf);
spawnMask = uint8(Hf >= 0.90 * Hmax);   % near source region
sinkMask  = uint8(Hf <= 0.05 * Hmax);   % far/peripheral region

arrays = {
    struct('name',"V",             'data',Vf,  'dtype',"float32")
    struct('name',"F",             'data',Ff,  'dtype',"uint32")
    struct('name',"faceNeighbors", 'data',Nbf, 'dtype',"int32")
    struct('name',"U_face",        'data',Uf,  'dtype',"float32")
    struct('name',"vertexNormals", 'data',VNf, 'dtype',"float32")
    struct('name',"faceNormals",   'data',FNf, 'dtype',"float32")
    struct('name',"centroids",     'data',Cf,  'dtype',"float32")
    struct('name',"faceAreas",     'data',Af,  'dtype',"float32")
    % NEW:
    struct('name',"H_face",        'data',Hf,       'dtype',"float32")
    struct('name',"spawnMask",     'data',spawnMask,'dtype',"uint8")
    struct('name',"sinkMask",      'data',sinkMask, 'dtype',"uint8")
};

% ---------- Write BIN + manifest ----------
binPath  = outBase + ".bin";
jsonPath = outBase + ".json";

fid = fopen(binPath, 'w');
if fid < 0, error("Cannot open %s for writing.", binPath); end

offset = uint32(0);

manifest = struct();
manifest.nV = uint32(nV);
manifest.nF = uint32(nF);
manifest.buffers = [];

for i = 1:numel(arrays)
    A = arrays{i};

    % 4-byte alignment
    align = uint32(4);
    pad = mod(double(align - mod(offset, align)), double(align));
    if pad ~= 0
        fwrite(fid, zeros(pad,1,'uint8'), 'uint8');
        offset = offset + uint32(pad);
    end

    entry = struct();
    entry.name = A.name;
    entry.dtype = A.dtype;
    entry.count = uint32(numel(A.data));
    entry.byteOffset = offset;

    fwrite(fid, A.data, matlabClassForDtype(A.dtype));

    bytesWritten = uint32(numel(A.data) * bytesPerElement(A.dtype));
    offset = offset + bytesWritten;

    manifest.buffers = [manifest.buffers; entry]; %#ok<AGROW>
end

fclose(fid);

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
