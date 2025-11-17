%% =========================================================================
%  bct.h5 TEMPLATE CREATOR (FLATTENED MANIFOLD)
%  Creates "template.bct.h5" with:
%   /bct/signal, /bct/manifold (flattened), /bct/events, /bct/scales,
%   /bct/subject, /bct/provenance
%  - Dimension Scales (H5DS): S,C,N,T,F,K,E
%  - Enums for event kinds; region refs to signal/manifold
%  - VLEN UTF-8 for labels/provenance
%  - Flattened manifold: datasets directly under /bct/manifold/*
%  Author: (you)
%  ========================================================================
clear; clc;

file = "template.bct.h5";
if isfile(file), delete(file); end

%% ------------------------- Tunable placeholder sizes ---------------------
S = 2;           % stacks (e.g., trials)
C = 1;           % components (scalar)
N = 128;         % vertices
T = 1000;        % time samples
F = 256;         % faces
K = 8;           % eigenpairs (optional but present)
E = 1;           % events rows
P = 1;           % provenance records

fs   = 1000;     % Hz
t0   = 0.0;
now_utc = posixtime(datetime('now','TimeZone','UTC'));
uuidStr = char(java.util.UUID.randomUUID);

%% -------------------- Create file with low-level properties ---------------
fcpl = H5P.create('H5P_FILE_CREATE');
fapl = H5P.create('H5P_FILE_ACCESS');
H5P.set_alignment(fapl, 4096, 4*1024*1024);  % thresh=4KB, align=4MB
H5P.set_libver_bounds(fapl, 'H5F_LIBVER_V110', 'H5F_LIBVER_V110'); % latest-ish
fid  = H5F.create(file, 'H5F_ACC_TRUNC', fcpl, fapl);
H5F.close(fid);

%% -------------------- Make all groups/namespaces --------------------------
grpList = [
  "/bct"
  "/bct/signal"
  "/bct/manifold"             % FLATTENED: all manifold datasets here
  "/bct/events"
  "/bct/scales"
  "/bct/scales/axes"
  "/bct/scales/time"
  "/bct/scales/space"
  "/bct/subject"
  "/bct/subject/vars"
  "/bct/provenance"
];
for i=1:numel(grpList), ensureGroup(file, grpList(i)); end

%% -------------------- Root & group-level attributes -----------------------
h5writeatt(file, "/", "bct_version", "1.0.0");
h5writeatt(file, "/", "uuid", uuidStr);
h5writeatt(file, "/", "created_utc", now_utc);
h5writeatt(file, "/", "generator", "MATLAB template script (flattened manifold)");
h5writeatt(file, "/", "space", "subject_native");
h5writeatt(file, "/", "endian", "little");
h5writeatt(file, "/", "libver", "latest");
h5writeatt(file, "/", "description", "Template bct.h5 with flattened manifold schema");
h5writeatt(file, "/", "linking_policy", "subject_only");

h5writeatt(file, "/bct/manifold", "hemi", "both");
h5writeatt(file, "/bct/manifold", "surface", "pial");

%% -------------------- Axis scales (H5DS) ----------------------------------
S_ax = int64(0:S-1);
C_ax = int16(0:C-1);
N_ax = int64(0:N-1);
T_ax = int64(0:T-1);         % regular sampling => samples
F_ax = int64(0:F-1);
K_ax = int64(0:K-1);
E_ax = int64(0:E-1);

h5create(file, "/bct/scales/axes/S", size(S_ax), "Datatype", "int64"); h5write(file, "/bct/scales/axes/S", S_ax);
h5writeatt(file, "/bct/scales/axes/S", "semantic", "stack");
h5writeatt(file, "/bct/scales/axes/S", "labels", {'trial1','trial2'});

h5create(file, "/bct/scales/axes/C", size(C_ax), "Datatype", "int16"); h5write(file, "/bct/scales/axes/C", C_ax);
h5writeatt(file, "/bct/scales/axes/C", "semantic", "components");
h5writeatt(file, "/bct/scales/axes/C", "labels", {'scalar'});  % or {'x','y','z'}

h5create(file, "/bct/scales/axes/N", size(N_ax), "Datatype", "int64"); h5write(file, "/bct/scales/axes/N", N_ax);
h5writeatt(file, "/bct/scales/axes/N", "semantic", "vertex_index");

h5create(file, "/bct/scales/axes/T", size(T_ax), "Datatype", "int64"); h5write(file, "/bct/scales/axes/T", T_ax);
h5writeatt(file, "/bct/scales/axes/T", "semantic", "time");
h5writeatt(file, "/bct/scales/axes/T", "units", "sample");
h5writeatt(file, "/bct/scales/axes/T", "sampling_rate_hz", fs);
h5writeatt(file, "/bct/scales/axes/T", "t0_sec", t0);

h5create(file, "/bct/scales/axes/F", size(F_ax), "Datatype", "int64"); h5write(file, "/bct/scales/axes/F", F_ax);
h5writeatt(file, "/bct/scales/axes/F", "semantic", "face_index");

h5create(file, "/bct/scales/axes/K", size(K_ax), "Datatype", "int64"); h5write(file, "/bct/scales/axes/K", K_ax);
h5writeatt(file, "/bct/scales/axes/K", "semantic", "spatial_mode_index");
h5writeatt(file, "/bct/scales/axes/K", "laplacian", "combinatorial");

h5create(file, "/bct/scales/axes/E", size(E_ax), "Datatype", "int64"); h5write(file, "/bct/scales/axes/E", E_ax);
h5writeatt(file, "/bct/scales/axes/E", "semantic", "event_row_index");

% Mark as H5DS scales (labels equal to names)
setAsScale(file, "/bct/scales/axes/S", "S");
setAsScale(file, "/bct/scales/axes/C", "C");
setAsScale(file, "/bct/scales/axes/N", "N");
setAsScale(file, "/bct/scales/axes/T", "T");
setAsScale(file, "/bct/scales/axes/F", "F");
setAsScale(file, "/bct/scales/axes/K", "K");
setAsScale(file, "/bct/scales/axes/E", "E");
%% 
% Clamp a proposed chunk vector to dataset size (elementwise), at least 1
function ch = clampChunks(dsz, prop)
  dsz  = double(dsz);
  prop = double(prop);
  ch   = max(1, min(prop, dsz));
  ch   = floor(ch);
end

% Choose a safe 1-D chunk length (<= len)
function ch = chunk1D(len, target)
  if nargin < 2, target = 1024; end
  len = double(len);
  ch  = max(1, min(target, len));
  ch  = floor(ch);
end

%% -------------------- SIGNAL: /bct/signal/data [S,C,N,T] ------------------
sigChunks = clampChunks([S, C, N, T], [1, C, 2048, 1000]);
h5create(file, "/bct/signal/data", [S, C, N, T], ...
  "Datatype", "single", "ChunkSize", sigChunks, "Deflate", 4);

% Write a small block to materialize dataset
sampleBlock = single(zeros([1, C, min(N,2048), min(T,1000)], 'single'));
h5write(file, "/bct/signal/data", sampleBlock, [1,1,1,1], size(sampleBlock));
h5writeatt(file, "/bct/signal/data", "dtype_primary", "float32");
h5writeatt(file, "/bct/signal/data", "component_semantic", "scalar");

% Attach scales
attachScale(file, "/bct/signal/data", 0, "/bct/scales/axes/S", "S");
attachScale(file, "/bct/signal/data", 1, "/bct/scales/axes/C", "C");
attachScale(file, "/bct/signal/data", 2, "/bct/scales/axes/N", "N");
attachScale(file, "/bct/signal/data", 3, "/bct/scales/axes/T", "T");

%% -------------------- MANIFOLD: FLATTENED DATASETS ------------------------
% vertex [N,3] float32
vChunks = clampChunks([N,3], [4096,3]);
h5create(file, "/bct/manifold/vertex", [N,3], "Datatype", "single", ...
         "ChunkSize", vChunks, "Deflate", 3);
verts = single(rand(N,3)*100); % mm, RAS-ish placeholders
h5write(file, "/bct/manifold/vertex", verts);
h5writeatt(file, "/bct/manifold/vertex", "units", "mm");
h5writeatt(file, "/bct/manifold/vertex", "space", "RAS");
attachScale(file, "/bct/manifold/vertex", 0, "/bct/scales/axes/N", "N");

% face [F,3] uint32
h5create(file, "/bct/manifold/face", [F,3], "Datatype", "uint32");
faces = uint32(randi([0 N-1],F,3));
h5write(file, "/bct/manifold/face", faces);
h5writeatt(file, "/bct/manifold/face", "winding", "CCW");
h5writeatt(file, "/bct/manifold/face", "index_base", int32(0));
attachScale(file, "/bct/manifold/face", 0, "/bct/scales/axes/F", "F");

% /bct/manifold/normals_vertex  [N,3]
nvChunks = clampChunks([N,3], [4096,3]);
h5create(file, "/bct/manifold/normals_vertex", [N,3], "Datatype", "single", ...
         "ChunkSize", nvChunks, "Deflate", 3);
vnorm = single(randn(N,3)); vnorm = vnorm ./ max(eps, vecnorm(vnorm,2,2));
h5write(file, "/bct/manifold/normals_vertex", vnorm);
h5writeatt(file, "/bct/manifold/normals_vertex", "units", "unit-vector");
attachScale(file, "/bct/manifold/normals_vertex", 0, "/bct/scales/axes/N", "N");

h5create(file, "/bct/manifold/normals_face", [F,3], "Datatype", "single");
fnorm = single(randn(F,3)); fnorm = fnorm ./ max(eps, vecnorm(fnorm,2,2));
h5write(file, "/bct/manifold/normals_face", fnorm);
h5writeatt(file, "/bct/manifold/normals_face", "units", "unit-vector");
attachScale(file, "/bct/manifold/normals_face", 0, "/bct/scales/axes/F", "F");

% per-vertex property example: vertex_curvature [N] float32
% /bct/manifold/vertex_curvature  [N]
vcChunks = chunk1D(N, 16384);
h5create(file, "/bct/manifold/vertex_curvature", [N], ...
         "Datatype", "single", "ChunkSize", vcChunks, "Deflate", 4);
h5write(file, "/bct/manifold/vertex_curvature", single(randn(N,1)));
h5writeatt(file, "/bct/manifold/vertex_curvature", "units", "1/mm");
h5writeatt(file, "/bct/manifold/vertex_curvature", "description", "placeholder curvature");
h5writeatt(file, "/bct/manifold/vertex_curvature", "collection", "properties");
h5writeatt(file, "/bct/manifold/vertex_curvature", "domain", "vertex");
attachScale(file, "/bct/manifold/vertex_curvature", 0, "/bct/scales/axes/N", "N");

%% -------------------- MANIFOLD: CSR & Laplacian (flattened) --------------
% Simple ring graph (0-based indices in storage)
deg    = zeros(N,1,'single');
indptr = zeros(N+1,1,'int64');
nbrs   = cell(N,1);
for i = 1:N
  nbrs{i} = int32(mod([i-2, i], N));  % 0-based neighbors
end

indices = int32([]); 
data    = single([]);
for i = 1:N
  nn = nbrs{i};
  indices = [indices; nn(:)];         %#ok<AGROW>
  data    = [data; single(1); single(1)]; %#ok<AGROW>
  deg(i)  = 2;
  indptr(i+1) = indptr(i) + 2;
end

% ---------- Adjacency CSR (1-D datasets with scalar chunks) ----------
len_indptr  = numel(indptr);
len_indices = numel(indices);
len_data    = numel(data);

h5create(file, "/bct/manifold/adj_indptr", [len_indptr], "Datatype","int64", ...
         "ChunkSize", chunk1D(len_indptr, 32768), "Deflate",4);
h5write (file, "/bct/manifold/adj_indptr", indptr(:));
h5writeatt(file, "/bct/manifold/adj_indptr", "csr_shape", int64([N N]));
% adjacency: symmetric = true
h5writeatt(file, "/bct/manifold/adj_indptr", "symmetric", uint8(1));
h5writeatt(file, "/bct/manifold/adj_indptr", "collection", "graph");
%% 

h5create(file, "/bct/manifold/adj_indices", [len_indices], "Datatype","int32", ...
         "ChunkSize", chunk1D(len_indices, 65536), "Deflate",4);
h5create(file, "/bct/manifold/adj_data", [len_data], "Datatype","single", ...
         "ChunkSize", chunk1D(len_data, 65536), "Deflate",4);
% degree [N] (1-D with clamped chunk)
h5create(file, "/bct/manifold/degree", [N], "Datatype","single", ...
         "ChunkSize", chunk1D(N, 16384), "Deflate",3);
h5create(file, "/bct/manifold/lap_indptr", [len_indptr], "Datatype","int64", ...
         "ChunkSize", chunk1D(len_indptr, 32768), "Deflate",4);
h5create(file, "/bct/manifold/lap_indices", [len_indices], "Datatype","int32", ...
         "ChunkSize", chunk1D(len_indices, 65536), "Deflate",4);
h5create(file, "/bct/manifold/lap_data", [len_lap], "Datatype","single", ...
         "ChunkSize", chunk1D(len_lap, 65536), "Deflate",4);


% eig_vecs [N,K] (2-D clamped chunks)
evChunks = clampChunks([N, K], [4096, max(1, min(32, K))]);
h5create(file, "/bct/manifold/eig_vecs", [N,K], "Datatype","single", ...
         "ChunkSize", evChunks, "Deflate",4);
% eig_vals [K]  (scalar chunk)
h5create(file, "/bct/manifold/eig_vals", [K], "Datatype","double", ...
         "ChunkSize", chunk1D(K, 8192), "Deflate",3);
%% 

h5write (file, "/bct/manifold/adj_indices", indices(:));
h5writeatt(file, "/bct/manifold/adj_indices", "index_base", int32(0));
h5writeatt(file, "/bct/manifold/adj_indices", "collection", "graph");


h5write (file, "/bct/manifold/adj_data", data(:));
h5writeatt(file, "/bct/manifold/adj_data", "meaning", "edge weight");
h5writeatt(file, "/bct/manifold/adj_data", "collection", "graph");


h5write (file, "/bct/manifold/degree", deg);
attachScale(file, "/bct/manifold/degree", 0, "/bct/scales/axes/N", "N");
h5writeatt(file, "/bct/manifold/degree", "collection", "graph");

% ---------- Laplacian CSR (same pattern as adjacency) ----------
lapData  = -data;           % off-diagonal -1 (simple example)
len_lap  = numel(lapData);


h5write (file, "/bct/manifold/lap_indptr", indptr(:));
h5writeatt(file, "/bct/manifold/lap_indptr", "csr_shape", int64([N N]));
h5writeatt(file, "/bct/manifold/lap_indptr", "collection", "graph");


h5write (file, "/bct/manifold/lap_indices", indices(:));
h5writeatt(file, "/bct/manifold/lap_indices", "collection", "graph");


h5write (file, "/bct/manifold/lap_data", lapData(:));
h5writeatt(file, "/bct/manifold/lap_data", "lap_type", "combinatorial");
h5writeatt(file, "/bct/manifold/lap_data", "collection", "graph");

% ---------- Eigenpairs ----------

h5write (file, "/bct/manifold/eig_vals", sort(rand(K,1),'ascend'));
attachScale(file, "/bct/manifold/eig_vals", 0, "/bct/scales/axes/K", "K");
h5writeatt(file, "/bct/manifold/eig_vals", "collection", "graph");

h5write (file, "/bct/manifold/eig_vecs", single(randn(N,K)));
attachScale(file, "/bct/manifold/eig_vecs", 0, "/bct/scales/axes/N", "N");
attachScale(file, "/bct/manifold/eig_vecs", 1, "/bct/scales/axes/K", "K");
% eig_vecs: orthonormal = false
h5writeatt(file, "/bct/manifold/eig_vecs", "orthonormal", uint8(0));
h5writeatt(file, "/bct/manifold/eig_vecs", "collection", "graph");


%% -------------------- SUBJECT: attributes-first + optional vars -----------
h5writeatt(file, "/bct/subject", "subject_id", char(java.util.UUID.randomUUID));
h5writeatt(file, "/bct/subject", "sex", "male");
h5writeatt(file, "/bct/subject", "age_years", single(63.4));
h5writeatt(file, "/bct/subject", "age_basis", "at_acquisition");
h5writeatt(file, "/bct/subject", "APOE", "e3/e4");
h5writeatt(file, "/bct/subject", "APOE_e4_count", int8(1));
h5writeatt(file, "/bct/subject", "link_namespace", "PREVENT-AD");
h5writeatt(file, "/bct/subject", "link_keys", {'sex','age_years','APOE'});
%% 

% Optional vars: list of SNP IDs (VLEN UTF-8 via low-level API)
fid = H5F.open(file,'H5F_ACC_RDWR','H5P_DEFAULT');

typeVL = H5T.copy('H5T_C_S1');
% --- make it variable-length (works across MATLAB versions)
try
    H5T.set_size(typeVL, 'H5T_VARIABLE');  % preferred in many releases
catch
    H5T.set_size(typeVL, H5ML.get_constant_value('H5T_VARIABLE'));
end
% --- UTF-8 + NULL-terminated
H5T.set_cset  (typeVL, H5ML.get_constant_value('H5T_CSET_UTF8'));
H5T.set_strpad(typeVL, H5ML.get_constant_value('H5T_STR_NULLTERM'));

snps  = {'rs429358','rs7412','rs12345'};    % cellstr
space = H5S.create_simple(1, numel(snps), []);   % 1-D length = numel(snps)
dcpl  = H5P.create('H5P_DATASET_CREATE');        % (optional) keep default

dset = H5D.create(fid, "/bct/subject/vars/snp_ids", typeVL, space, ...
                  'H5P_DEFAULT', dcpl, 'H5P_DEFAULT');
H5D.write(dset, typeVL, 'H5S_ALL','H5S_ALL','H5P_DEFAULT', snps);

H5D.close(dset); H5S.close(space); H5P.close(dcpl);
H5T.close(typeVL); H5F.close(fid);


%% -------------------- PROVENANCE: JSONL (vlen utf-8) ----------------------
% --- PROVENANCE: JSONL (VLEN UTF-8) ---
fid = H5F.open(file,'H5F_ACC_RDWR','H5P_DEFAULT');

% Make a variable-length UTF-8 string datatype
typeVL = H5T.copy('H5T_C_S1');
try
    H5T.set_size(typeVL, 'H5T_VARIABLE');  % works in many MATLAB releases
catch
    H5T.set_size(typeVL, H5ML.get_constant_value('H5T_VARIABLE'));
end
H5T.set_cset  (typeVL, H5ML.get_constant_value('H5T_CSET_UTF8'));
H5T.set_strpad(typeVL, H5ML.get_constant_value('H5T_STR_NULLTERM'));

% Payload: one JSON string (cellstr)
prov  = jsonencode(struct('software',"MATLAB", ...
                          'script',"template creator (flattened)", ...
                          'utc', now_utc), 'PrettyPrint', true);
payload = {prov};

% 1-D dataset of length numel(payload)
space = H5S.create_simple(1, numel(payload), []);
dcpl  = H5P.create('H5P_DATASET_CREATE');  % optional; keep defaults

dset = H5D.create(fid, "/bct/provenance/records", typeVL, space, ...
                  'H5P_DEFAULT', dcpl, 'H5P_DEFAULT');
H5D.write(dset, typeVL, 'H5S_ALL','H5S_ALL','H5P_DEFAULT', payload);

H5D.close(dset); H5S.close(space); H5P.close(dcpl);
H5T.close(typeVL); H5F.close(fid);


%% -------------------- EVENTS: columns, enums, region refs -----------------
% Helper: create 1D dataset and attach E scale
create1DAndAttachE(file, "/bct/events/id",           uint64((1:E)'));          % [E] u64
create1DAndAttachE(file, "/bct/events/s_idx",        int32(zeros(E,1)));
create1DAndAttachE(file, "/bct/events/c_idx",        int16(zeros(E,1)));
create1DAndAttachE(file, "/bct/events/t_index",      int64(100*ones(E,1)));
create1DAndAttachE(file, "/bct/events/created_utc",  double(now_utc*ones(E,1)));

% Optional time convenience
create1DAndAttachE(file, "/bct/events/t_sec",        double((100/fs)*ones(E,1)));
%% 

% Enums
spaceNames  = {'vertex','face_bary','xyz'}; spaceVals = [0 1 2];
spatNames   = {'none','lap_k','diff_tau','parcel'};  spatVals  = [0 1 2 3];
tempNames   = {'none','freq_hz','band','wav_scale'}; tempVals  = [0 1 2 3];

createEnumDataset(file, "/bct/events/space_repr", 'H5T_STD_U8LE', spaceNames, spaceVals, uint8(zeros(E,1))); % vertex
createEnumDataset(file, "/bct/events/spat_kind",  'H5T_STD_U8LE', spatNames,  spatVals,  uint8(zeros(E,1))); % none
createEnumDataset(file, "/bct/events/temp_kind",  'H5T_STD_U8LE', tempNames,  tempVals,  uint8(zeros(E,1))); % none
%% 

% Spatial columns (using vertex representation)
% /bct/events/bc  [E,3]
deleteIfExists(file, "/bct/events/bc");                        % <-- new
bcChunks = clampChunks([E,3], [1024,3]);
h5create(file, "/bct/events/bc", [E,3], "Datatype","single", ...
         "ChunkSize", bcChunks, "Deflate", 3);
% initialize and then set first row (be explicit with start/count)
h5write(file, "/bct/events/bc", zeros(E,3,'single'), [1,1], [E,3]);
h5write(file, "/bct/events/bc", single([1,0,0]),     [1,1], [1,3]);
tryAttachE(file, "/bct/events/bc");                               % <-- new

% /bct/events/xyz  [E,3]
deleteIfExists(file, "/bct/events/xyz");                      % <-- new
xyzChunks = clampChunks([E,3], [1024,3]);
h5create(file, "/bct/events/xyz", [E,3], "Datatype","single", ...
         "ChunkSize", xyzChunks, "Deflate", 3);
h5write(file, "/bct/events/xyz", zeros(E,3,'single'), [1,1], [E,3]);
h5write(file, "/bct/events/xyz", single(verts(11,:)), [1,1], [1,3]);
tryAttachE(file, "/bct/events/xyz");                              % <-- new

%% 

% Spatial scale context
create1DAndAttachE(file, "/bct/events/spat_k",      int64( (-1)*ones(E,1) ));
create1DAndAttachE(file, "/bct/events/spat_tau",    single( zeros(E,1) ));
create1DAndAttachE(file, "/bct/events/spat_parcel", int32( (-1)*ones(E,1) ));

% Temporal scale context
create1DAndAttachE(file, "/bct/events/freq_hz",   single( zeros(E,1) ));
create1DAndAttachE(file, "/bct/events/band_id",   int16( (-1)*ones(E,1) ));
create1DAndAttachE(file, "/bct/events/wav_scale", single( zeros(E,1) ));

% Annotation columns
create1DAndAttachE(file, "/bct/events/quality",      single( ones(E,1) ));
create1DAndAttachE(file, "/bct/events/provenance_id", uint64( ones(E,1) ));
%% 
% ==================== /bct/events/label  (VLEN UTF-8) ====================
% --- /bct/events/label  (idempotent, VLEN UTF-8, string array) ---
deleteIfExists(file, "/bct/events/label");   % <— remove old dataset if present

% Build VLEN UTF-8 datatype (version-proof)
typeVL = H5T.copy('H5T_C_S1');
try
    H5T.set_size(typeVL, 'H5T_VARIABLE');
catch
    H5T.set_size(typeVL, H5ML.get_constant_value('H5T_VARIABLE'));
end
H5T.set_cset  (typeVL, H5ML.get_constant_value('H5T_CSET_UTF8'));
H5T.set_strpad(typeVL, H5ML.get_constant_value('H5T_STR_NULLTERM'));

labels = repmat("Event A", E, 1);            % string array, not cell

fid   = H5F.open(file,'H5F_ACC_RDWR','H5P_DEFAULT');
space = H5S.create_simple(1, E, []);
dset  = H5D.create(fid, "/bct/events/label", typeVL, space, ...
                   'H5P_DEFAULT','H5P_DEFAULT','H5P_DEFAULT');
H5D.write(dset, typeVL, 'H5S_ALL','H5S_ALL','H5P_DEFAULT', labels);

H5D.close(dset); H5S.close(space); H5T.close(typeVL); H5F.close(fid);

attachScale(file, "/bct/events/label", 0, "/bct/scales/axes/E", "E");

%% 

% ========== Region reference columns: signal_ref, mesh_ref ===============
% Prepare a region ref to a slice of /bct/signal/data: S=0,C=0,N=20:40, T=100:200
deleteIfExists(file, "/bct/events/signal_ref");
deleteIfExists(file, "/bct/events/mesh_ref");

fid   = H5F.open(file,'H5F_ACC_RDWR','H5P_DEFAULT');

% -- build one dataset-region ref into /bct/signal/data
dsetS = H5D.open(fid, "/bct/signal/data");
spaceS= H5D.get_space(dsetS);
start = [0 0 20 100];  count = [1 1 21 101];   % [S C N T]
H5S.select_hyperslab(spaceS, 'H5S_SELECT_SET', start, [], count, []);
refSignalOne = H5R.create(fid, "/bct/signal/data", 'H5R_DATASET_REGION', spaceS);
H5S.close(spaceS); H5D.close(dsetS);

% -- replicate that reference E times to match [E]
spaceE = H5S.create_simple(1, E, []);
dtypeR = H5T.copy('H5T_STD_REF_DSETREG');
dsetR  = H5D.create(fid, "/bct/events/signal_ref", dtypeR, spaceE, ...
                    'H5P_DEFAULT','H5P_DEFAULT','H5P_DEFAULT');

refSignalVec = repmat(refSignalOne, 1, E);      % length-E vector of refs
H5D.write(dsetR, dtypeR, 'H5S_ALL','H5S_ALL','H5P_DEFAULT', refSignalVec);
H5D.close(dsetR); H5S.close(spaceE);
attachScale(file, "/bct/events/signal_ref", 0, "/bct/scales/axes/E", "E");

% -- build one dataset-region ref into /bct/manifold/vertex (row 10, all 3 coords)
dsetV = H5D.open(fid, "/bct/manifold/vertex");
spaceV= H5D.get_space(dsetV);
start = [10 0];  count = [1 3];
H5S.select_hyperslab(spaceV, 'H5S_SELECT_SET', start, [], count, []);
refMeshOne = H5R.create(fid, "/bct/manifold/vertex", 'H5R_DATASET_REGION', spaceV);
H5S.close(spaceV); H5D.close(dsetV);

spaceE = H5S.create_simple(1, E, []);
dsetM  = H5D.create(fid, "/bct/events/mesh_ref", dtypeR, spaceE, ...
                    'H5P_DEFAULT','H5P_DEFAULT','H5P_DEFAULT');
refMeshVec = repmat(refMeshOne, 1, E);
H5D.write(dsetM, dtypeR, 'H5S_ALL','H5S_ALL','H5P_DEFAULT', refMeshVec);
H5D.close(dsetM); H5S.close(spaceE);

H5F.close(fid);
attachScale(file, "/bct/events/mesh_ref", 0, "/bct/scales/axes/E", "E");



%% -------------------- Scales params (attrs only, minimal) -----------------
h5writeatt(file, "/bct/scales/time", "note", "minimal placeholder for time-scale params");
h5writeatt(file, "/bct/scales/space", "note", "minimal placeholder for spatial-scale params");

%% -------------------- Done -------------------------------------------------
disp("Created " + file + " with flattened manifold bct schema.");
% Inspect with: h5disp(file)

%% ============================ Local functions =============================
function ensureGroup(h5file, grpPath)
  fid = H5F.open(h5file, 'H5F_ACC_RDWR', 'H5P_DEFAULT');
  lcpl = H5P.create('H5P_LINK_CREATE'); H5P.set_create_intermediate_group(lcpl, true);
  gcpl = H5P.create('H5P_GROUP_CREATE');
  try
    gid = H5G.create(fid, grpPath, lcpl, gcpl, 'H5P_DEFAULT'); H5G.close(gid);
  catch
    % already exists
  end
  H5P.close(lcpl); H5P.close(gcpl); H5F.close(fid);
end

function setAsScale(h5file, dspath, label)
  fid = H5F.open(h5file, 'H5F_ACC_RDWR', 'H5P_DEFAULT');
  ds  = H5D.open(fid, dspath);
  H5DS.set_scale(ds, label);
  H5D.close(ds); H5F.close(fid);
end

function attachScale(h5file, parentPath, dimIndex, scalePath, label)
  fid = H5F.open(h5file, 'H5F_ACC_RDWR', 'H5P_DEFAULT');
  parent = H5D.open(fid, parentPath);
  scale  = H5D.open(fid, scalePath);
  H5DS.attach_scale(parent, scale, dimIndex);
  H5DS.set_label(parent, dimIndex, label);
  H5D.close(scale); H5D.close(parent); H5F.close(fid);
end

% function create1DAndAttachE(h5file, path, data, dtype)
%   if nargin<4, dtype = class(data); end
%   n = numel(data);
%   ch = chunk1D(n, 1024);               % ensure chunk <= length
%   h5create(h5file, path, size(data), "Datatype", dtype, ...
%            "ChunkSize", ch, "Deflate", 3);
%   h5write (h5file, path, data);
%   attachScale(h5file, path, 0, "/bct/scales/axes/E", "E");
% end
function create1DAndAttachE(h5file, path, data, dtype)
  if nargin < 4, dtype = class(data); end
  n  = numel(data);
  ch = chunk1D(n, 1024);          % scalar chunk (rank-1)

  % ensure a clean slate if re-running blocks
  deleteIfExists(h5file, path);

  h5create(h5file, path, [n], "Datatype", dtype, ...
           "ChunkSize", ch, "Deflate", 3);
  h5write (h5file, path, data(:));

  % attach scale (skip if already attached)
  try
    attachScale(h5file, path, 0, "/bct/scales/axes/E", "E");
  catch
    % ignore if already attached
  end
end


function createEnumDataset(h5file, path, baseType, names, values, payload)
  % delete existing dataset if re-running
  deleteIfExists(h5file, path);

  fid    = H5F.open(h5file,'H5F_ACC_RDWR','H5P_DEFAULT');
  t_base = H5T.copy(baseType);
  t_enum = H5T.enum_create(t_base);
  for k = 1:numel(names)
    H5T.enum_insert(t_enum, names{k}, uint8(values(k)));
  end

  n     = numel(payload);                     % rank-1 extent
  space = H5S.create_simple(1, n, []);
  dset  = H5D.create(fid, path, t_enum, space, ...
                     'H5P_DEFAULT','H5P_DEFAULT','H5P_DEFAULT');

  H5D.write(dset, t_enum, 'H5S_ALL','H5S_ALL','H5P_DEFAULT', payload(:));

  H5D.close(dset); H5S.close(space);
  H5T.close(t_enum); H5T.close(t_base); H5F.close(fid);

  % attach E scale (ignore if already)
  try
    attachScale(h5file, path, 0, "/bct/scales/axes/E", "E");
  catch
  end
end

function tf = linkExists(h5file, path)
  fid = H5F.open(h5file,'H5F_ACC_RDWR','H5P_DEFAULT');
  tf  = H5L.exists(fid, path, 'H5P_DEFAULT') > 0;
  H5F.close(fid);
end

function deleteIfExists(h5file, path)
  fid = H5F.open(h5file,'H5F_ACC_RDWR','H5P_DEFAULT');
  if H5L.exists(fid, path, 'H5P_DEFAULT') > 0
    H5L.delete(fid, path, 'H5P_DEFAULT');
  end
  H5F.close(fid);
end
function tryAttachE(h5file, dspath)
  try
    attachScale(h5file, dspath, 0, "/bct/scales/axes/E", "E");
  catch
    % already attached or dataset missing (ignore)
  end
end