%% =========================================================================
%  bct.h5 TEMPLATE CREATOR (FLATTENED TOP-LEVEL: NO /bct SUPERGROUP)
%  Creates "template.bct.h5" with:
%   /signal, /manifold, /events, /scales, /subject, /provenance
%  - Dimension Scales (H5DS): S,C,N,T,F,K,E (under /scales/axes/*)
%  - Enums for event kinds; region refs to signal/manifold
%  - VLEN UTF-8 for labels/provenance/subject vars (string arrays)
%  - Flattened manifold internals (vertex, face, CSR, eigenpairs, props)
%  Author: (you)
%  ========================================================================
clear; clc;

file = "template.bct.h5";
if isfile(file), delete(file); end

%% ------------------------- Tunable placeholder sizes ---------------------
S = 2;           % stacks (e.g., trials)
C = 1;           % components (scalar=1, vector=3)
N = 128;         % vertices
T = 1000;        % time samples
F = 256;         % faces
K = 8;           % eigenpairs
E = 1;           % events rows
P = 1;           % provenance records

fs   = 1000;     % Hz
t0   = 0.0;
now_utc = posixtime(datetime('now','TimeZone','UTC'));
uuidStr = char(java.util.UUID.randomUUID);

%% -------------------- Create file with low-level properties ---------------
fcpl = H5P.create('H5P_FILE_CREATE');
fapl = H5P.create('H5P_FILE_ACCESS');
H5P.set_alignment(fapl, 4096, 4*1024*1024);                 % 4KB thresh, 4MB align
H5P.set_libver_bounds(fapl, 'H5F_LIBVER_V110', 'H5F_LIBVER_V110');
fid  = H5F.create(file, 'H5F_ACC_TRUNC', fcpl, fapl);
H5F.close(fid);

%% -------------------- Make groups/namespaces at ROOT ----------------------
grpList = [
  "/signal"
  "/manifold"
  "/events"
  "/scales"
  "/scales/axes"
  "/scales/time"
  "/scales/space"
  "/subject"
  "/subject/vars"
  "/provenance"
];
for i=1:numel(grpList), ensureGroup(file, grpList(i)); end

%% -------------------- Root & group-level attributes -----------------------
% (moved anything that used to be on /bct to the root "/")
h5writeatt(file, "/", "bct_version", "1.0.0");
h5writeatt(file, "/", "uuid", uuidStr);
h5writeatt(file, "/", "created_utc", now_utc);
h5writeatt(file, "/", "generator", "MATLAB template script (flattened top-level)");
h5writeatt(file, "/", "space", "subject_native");
h5writeatt(file, "/", "endian", "little");
h5writeatt(file, "/", "libver", "latest");
h5writeatt(file, "/", "description", "Template bct.h5 with flattened top-level schema");
h5writeatt(file, "/", "linking_policy", "subject_only");     % cohort linking rule

% optional manifold-wide attributes live on the /manifold group
h5writeatt(file, "/manifold", "hemi", "both");
h5writeatt(file, "/manifold", "surface", "pial");

%% -------------------- Axis scales (H5DS) ----------------------------------
S_ax = int64(0:S-1);
C_ax = int16(0:C-1);
N_ax = int64(0:N-1);
T_ax = int64(0:T-1);         % samples
F_ax = int64(0:F-1);
K_ax = int64(0:K-1);
E_ax = int64(0:E-1);

h5create(file, "/scales/axes/S", size(S_ax), "Datatype", "int64"); h5write(file, "/scales/axes/S", S_ax);
h5writeatt(file, "/scales/axes/S", "semantic", "stack");
h5writeatt(file, "/scales/axes/S", "labels", {'trial1','trial2'});

h5create(file, "/scales/axes/C", size(C_ax), "Datatype", "int16"); h5write(file, "/scales/axes/C", C_ax);
h5writeatt(file, "/scales/axes/C", "semantic", "components");
h5writeatt(file, "/scales/axes/C", "labels", {'scalar'});   % or {'x','y','z'}

h5create(file, "/scales/axes/N", size(N_ax), "Datatype", "int64"); h5write(file, "/scales/axes/N", N_ax);
h5writeatt(file, "/scales/axes/N", "semantic", "vertex_index");

h5create(file, "/scales/axes/T", size(T_ax), "Datatype", "int64"); h5write(file, "/scales/axes/T", T_ax);
h5writeatt(file, "/scales/axes/T", "semantic", "time");
h5writeatt(file, "/scales/axes/T", "units", "sample");
h5writeatt(file, "/scales/axes/T", "sampling_rate_hz", fs);
h5writeatt(file, "/scales/axes/T", "t0_sec", t0);

h5create(file, "/scales/axes/F", size(F_ax), "Datatype", "int64"); h5write(file, "/scales/axes/F", F_ax);
h5writeatt(file, "/scales/axes/F", "semantic", "face_index");

h5create(file, "/scales/axes/K", size(K_ax), "Datatype", "int64"); h5write(file, "/scales/axes/K", K_ax);
h5writeatt(file, "/scales/axes/K", "semantic", "spatial_mode_index");
h5writeatt(file, "/scales/axes/K", "laplacian", "combinatorial");

h5create(file, "/scales/axes/E", size(E_ax), "Datatype", "int64"); h5write(file, "/scales/axes/E", E_ax);
h5writeatt(file, "/scales/axes/E", "semantic", "event_row_index");

% mark as H5DS scales
setAsScale(file, "/scales/axes/S", "S");
setAsScale(file, "/scales/axes/C", "C");
setAsScale(file, "/scales/axes/N", "N");
setAsScale(file, "/scales/axes/T", "T");
setAsScale(file, "/scales/axes/F", "F");
setAsScale(file, "/scales/axes/K", "K");
setAsScale(file, "/scales/axes/E", "E");

%% -------------------- SIGNAL: /signal/data [S,C,N,T] ----------------------
sigChunks = clampChunks([S, C, N, T], [1, C, 2048, 1000]);
h5create(file, "/signal/data", [S, C, N, T], ...
  "Datatype", "single", "ChunkSize", sigChunks, "Deflate", 4);

% materialize with a small write
sampleBlock = single(zeros([1, C, min(N,2048), min(T,1000)], 'single'));
h5write(file, "/signal/data", sampleBlock, [1,1,1,1], size(sampleBlock));
h5writeatt(file, "/signal/data", "dtype_primary", "float32");
h5writeatt(file, "/signal/data", "component_semantic", "scalar");

% attach H5DS scales
attachScale(file, "/signal/data", 0, "/scales/axes/S", "S");
attachScale(file, "/signal/data", 1, "/scales/axes/C", "C");
attachScale(file, "/signal/data", 2, "/scales/axes/N", "N");
attachScale(file, "/signal/data", 3, "/scales/axes/T", "T");

%% -------------------- MANIFOLD (flattened internals) ---------------------
% vertex [N,3] float32
vChunks = clampChunks([N,3], [4096,3]);
h5create(file, "/manifold/vertex", [N,3], "Datatype", "single", ...
         "ChunkSize", vChunks, "Deflate", 3);
verts = single(rand(N,3)*100);
h5write(file, "/manifold/vertex", verts);
h5writeatt(file, "/manifold/vertex", "units", "mm");
h5writeatt(file, "/manifold/vertex", "space", "RAS");
attachScale(file, "/manifold/vertex", 0, "/scales/axes/N", "N");

% face [F,3] uint32
h5create(file, "/manifold/face", [F,3], "Datatype", "uint32");
faces = uint32(randi([0 N-1],F,3));
h5write(file, "/manifold/face", faces);
h5writeatt(file, "/manifold/face", "winding", "CCW");
h5writeatt(file, "/manifold/face", "index_base", int32(0));
attachScale(file, "/manifold/face", 0, "/scales/axes/F", "F");

% normals
nvChunks = clampChunks([N,3], [4096,3]);
h5create(file, "/manifold/normals_vertex", [N,3], "Datatype", "single", ...
         "ChunkSize", nvChunks, "Deflate", 3);
vnorm = single(randn(N,3)); vnorm = vnorm ./ max(eps, vecnorm(vnorm,2,2));
h5write(file, "/manifold/normals_vertex", vnorm);
h5writeatt(file, "/manifold/normals_vertex", "units", "unit-vector");
attachScale(file, "/manifold/normals_vertex", 0, "/scales/axes/N", "N");

h5create(file, "/manifold/normals_face", [F,3], "Datatype", "single");
fnorm = single(randn(F,3)); fnorm = fnorm ./ max(eps, vecnorm(fnorm,2,2));
h5write(file, "/manifold/normals_face", fnorm);
h5writeatt(file, "/manifold/normals_face", "units", "unit-vector");
attachScale(file, "/manifold/normals_face", 0, "/scales/axes/F", "F");

% per-vertex property example
vcChunks = chunk1D(N, 16384);
h5create(file, "/manifold/vertex_curvature", [N], ...
         "Datatype", "single", "ChunkSize", vcChunks, "Deflate", 4);
h5write(file, "/manifold/vertex_curvature", single(randn(N,1)));
h5writeatt(file, "/manifold/vertex_curvature", "units", "1/mm");
h5writeatt(file, "/manifold/vertex_curvature", "description", "placeholder curvature");
h5writeatt(file, "/manifold/vertex_curvature", "collection", "properties");
h5writeatt(file, "/manifold/vertex_curvature", "domain", "vertex");
attachScale(file, "/manifold/vertex_curvature", 0, "/scales/axes/N", "N");

%% -------------------- MANIFOLD: CSR & Laplacian (flattened) --------------
% simple ring graph
deg    = zeros(N,1,'single');
indptr = zeros(N+1,1,'int64');
nbrs   = cell(N,1);
for i = 1:N, nbrs{i} = int32(mod([i-2, i], N)); end
indices = int32([]); data = single([]);
for i = 1:N
  nn = nbrs{i};
  indices = [indices; nn(:)]; data = [data; single(1); single(1)]; %#ok<AGROW>
  deg(i) = 2; indptr(i+1) = indptr(i) + 2;
end

len_indptr  = numel(indptr);
len_indices = numel(indices);
len_data    = numel(data);

h5create(file, "/manifold/adj_indptr", [len_indptr], "Datatype","int64", ...
         "ChunkSize", chunk1D(len_indptr, 32768), "Deflate",4);
h5write (file, "/manifold/adj_indptr", indptr(:));
h5writeatt(file, "/manifold/adj_indptr", "csr_shape", int64([N N]));
h5writeatt(file, "/manifold/adj_indptr", "symmetric", uint8(1));
h5writeatt(file, "/manifold/adj_indptr", "collection", "graph");

h5create(file, "/manifold/adj_indices", [len_indices], "Datatype","int32", ...
         "ChunkSize", chunk1D(len_indices, 65536), "Deflate",4);
h5write (file, "/manifold/adj_indices", indices(:));
h5writeatt(file, "/manifold/adj_indices", "index_base", int32(0));
h5writeatt(file, "/manifold/adj_indices", "collection", "graph");

h5create(file, "/manifold/adj_data", [len_data], "Datatype","single", ...
         "ChunkSize", chunk1D(len_data, 65536), "Deflate",4);
h5write (file, "/manifold/adj_data", data(:));
h5writeatt(file, "/manifold/adj_data", "meaning", "edge weight");
h5writeatt(file, "/manifold/adj_data", "collection", "graph");

% degree
h5create(file, "/manifold/degree", [N], "Datatype","single", ...
         "ChunkSize", chunk1D(N, 16384), "Deflate",3);
h5write (file, "/manifold/degree", deg);
attachScale(file, "/manifold/degree", 0, "/scales/axes/N", "N");
h5writeatt(file, "/manifold/degree", "collection", "graph");

% Laplacian CSR
lapData  = -data;  len_lap = numel(lapData);
h5create(file, "/manifold/lap_indptr", [len_indptr], "Datatype","int64", ...
         "ChunkSize", chunk1D(len_indptr, 32768), "Deflate",4);
h5write (file, "/manifold/lap_indptr", indptr(:));
h5writeatt(file, "/manifold/lap_indptr", "csr_shape", int64([N N]));
h5writeatt(file, "/manifold/lap_indptr", "collection", "graph");

h5create(file, "/manifold/lap_indices", [len_indices], "Datatype","int32", ...
         "ChunkSize", chunk1D(len_indices, 65536), "Deflate",4);
h5write (file, "/manifold/lap_indices", indices(:));
h5writeatt(file, "/manifold/lap_indices", "collection", "graph");

h5create(file, "/manifold/lap_data", [len_lap], "Datatype","single", ...
         "ChunkSize", chunk1D(len_lap, 65536), "Deflate",4);
h5write (file, "/manifold/lap_data", lapData(:));
h5writeatt(file, "/manifold/lap_data", "lap_type", "combinatorial");
h5writeatt(file, "/manifold/lap_data", "collection", "graph");

% Eigenpairs
h5create(file, "/manifold/eig_vals", [K], "Datatype","double", ...
         "ChunkSize", chunk1D(K, 8192), "Deflate",3);
h5write (file, "/manifold/eig_vals", sort(rand(K,1),'ascend'));
attachScale(file, "/manifold/eig_vals", 0, "/scales/axes/K", "K");
h5writeatt(file, "/manifold/eig_vals", "collection", "graph");

evChunks = clampChunks([N, K], [4096, max(1, min(32, K))]);
h5create(file, "/manifold/eig_vecs", [N,K], "Datatype","single", ...
         "ChunkSize", evChunks, "Deflate",4);
h5write (file, "/manifold/eig_vecs", single(randn(N,K)));
attachScale(file, "/manifold/eig_vecs", 0, "/scales/axes/N", "N");
attachScale(file, "/manifold/eig_vecs", 1, "/scales/axes/K", "K");
h5writeatt(file, "/manifold/eig_vecs", "orthonormal", uint8(0));  % false
h5writeatt(file, "/manifold/eig_vecs", "collection", "graph");

%% -------------------- SUBJECT: attributes + optional vars -----------------
h5writeatt(file, "/subject", "subject_id", char(java.util.UUID.randomUUID));
h5writeatt(file, "/subject", "sex", "male");
h5writeatt(file, "/subject", "age_years", single(63.4));
h5writeatt(file, "/subject", "age_basis", "at_acquisition");
h5writeatt(file, "/subject", "APOE", "e3/e4");
h5writeatt(file, "/subject", "APOE_e4_count", int8(1));
h5writeatt(file, "/subject", "link_namespace", "PREVENT-AD");
h5writeatt(file, "/subject", "link_keys", string(["sex","age_years","APOE"])); % string array

% optional vars under /subject/vars: example SNP id list (VLEN UTF-8)
write_vlen_utf8(file, "/subject/vars/snp_ids", ["rs429358"; "rs7412"; "rs12345"]);

%% -------------------- PROVENANCE: JSONL (VLEN UTF-8) ---------------------
prov  = jsonencode(struct('software',"MATLAB", ...
                          'script',"template creator (flattened top-level)", ...
                          'utc', now_utc), 'PrettyPrint', true);
write_vlen_utf8(file, "/provenance/records", string(prov));

%% -------------------- EVENTS: columns, enums, region refs -----------------
% scalar 1-D columns (rank-1 datasets)
create1DAndAttachE(file, "/events/id",            uint64((1:E)')); % [E] u64
create1DAndAttachE(file, "/events/s_idx",         int32(zeros(E,1)));
create1DAndAttachE(file, "/events/c_idx",         int16(zeros(E,1)));
create1DAndAttachE(file, "/events/t_index",       int64(100*ones(E,1)));
create1DAndAttachE(file, "/events/created_utc",   double(now_utc*ones(E,1)));
create1DAndAttachE(file, "/events/t_sec",         double((100/fs)*ones(E,1)));

% enums
spaceNames  = {'vertex','face_bary','xyz'}; spaceVals = [0 1 2];
spatNames   = {'none','lap_k','diff_tau','parcel'};  spatVals  = [0 1 2 3];
tempNames   = {'none','freq_hz','band','wav_scale'}; tempVals  = [0 1 2 3];

createEnumDataset(file, "/events/space_repr", 'H5T_STD_U8LE', spaceNames, spaceVals, uint8(zeros(E,1)));
createEnumDataset(file, "/events/spat_kind",  'H5T_STD_U8LE', spatNames,  spatVals,  uint8(zeros(E,1)));
createEnumDataset(file, "/events/temp_kind",  'H5T_STD_U8LE', tempNames,  tempVals,  uint8(zeros(E,1)));

% 2-D columns
deleteIfExists(file, "/events/bc");
bcChunks = clampChunks([E,3], [1024,3]);
h5create(file, "/events/bc", [E,3], "Datatype","single", ...
         "ChunkSize", bcChunks, "Deflate", 3);
h5write(file, "/events/bc", zeros(E,3,'single'), [1,1], [E,3]);
h5write(file, "/events/bc", single([1,0,0]),     [1,1], [1,3]);
tryAttachE(file, "/events/bc");

deleteIfExists(file, "/events/xyz");
xyzChunks = clampChunks([E,3], [1024,3]);
h5create(file, "/events/xyz", [E,3], "Datatype","single", ...
         "ChunkSize", xyzChunks, "Deflate", 3);
h5write(file, "/events/xyz", zeros(E,3,'single'), [1,1], [E,3]);
h5write(file, "/events/xyz", single(verts(11,:)), [1,1], [1,3]);
tryAttachE(file, "/events/xyz");

% more scalar columns
create1DAndAttachE(file, "/events/spat_k",      int64( (-1)*ones(E,1) ));
create1DAndAttachE(file, "/events/spat_tau",    single( zeros(E,1) ));
create1DAndAttachE(file, "/events/spat_parcel", int32( (-1)*ones(E,1) ));
create1DAndAttachE(file, "/events/freq_hz",     single( zeros(E,1) ));
create1DAndAttachE(file, "/events/band_id",     int16( (-1)*ones(E,1) ));
create1DAndAttachE(file, "/events/wav_scale",   single( zeros(E,1) ));
create1DAndAttachE(file, "/events/quality",     single( ones(E,1) ));
create1DAndAttachE(file, "/events/provenance_id", uint64( ones(E,1) ));

% labels [E] (VLEN UTF-8)
write_vlen_utf8(file, "/events/label", repmat("Event A", E, 1));
attachScale(file, "/events/label", 0, "/scales/axes/E", "E");

% region refs: /signal/data and /manifold/vertex
deleteIfExists(file, "/events/signal_ref");
deleteIfExists(file, "/events/mesh_ref");

fid   = H5F.open(file,'H5F_ACC_RDWR','H5P_DEFAULT');

dsetS = H5D.open(fid, "/signal/data");
spaceS= H5D.get_space(dsetS);
start = [0 0 20 100]; count = [1 1 21 101];   % [S C N T]
H5S.select_hyperslab(spaceS, 'H5S_SELECT_SET', start, [], count, []);
refSignalOne = H5R.create(fid, "/signal/data", 'H5R_DATASET_REGION', spaceS);
H5S.close(spaceS); H5D.close(dsetS);

spaceE = H5S.create_simple(1, E, []);
dtypeR = H5T.copy('H5T_STD_REF_DSETREG');
dsetR  = H5D.create(fid, "/events/signal_ref", dtypeR, spaceE, ...
                    'H5P_DEFAULT','H5P_DEFAULT','H5P_DEFAULT');
H5D.write(dsetR, dtypeR, 'H5S_ALL','H5S_ALL','H5P_DEFAULT', repmat(refSignalOne,1,E));
H5D.close(dsetR); H5S.close(spaceE);
attachScale(file, "/events/signal_ref", 0, "/scales/axes/E", "E");

dsetV = H5D.open(fid, "/manifold/vertex");
spaceV= H5D.get_space(dsetV);
start = [10 0]; count = [1 3];
H5S.select_hyperslab(spaceV, 'H5S_SELECT_SET', start, [], count, []);
refMeshOne = H5R.create(fid, "/manifold/vertex", 'H5R_DATASET_REGION', spaceV);
H5S.close(spaceV); H5D.close(dsetV);

spaceE = H5S.create_simple(1, E, []);
dsetM  = H5D.create(fid, "/events/mesh_ref", dtypeR, spaceE, ...
                    'H5P_DEFAULT','H5P_DEFAULT','H5P_DEFAULT');
H5D.write(dsetM, dtypeR, 'H5S_ALL','H5S_ALL','H5P_DEFAULT', repmat(refMeshOne,1,E));
H5D.close(dsetM); H5S.close(spaceE); H5F.close(fid);
attachScale(file, "/events/mesh_ref", 0, "/scales/axes/E", "E");

%% -------------------- Scales params (attrs-only stubs) --------------------
h5writeatt(file, "/scales/time",  "note", "placeholder for time-scale params");
h5writeatt(file, "/scales/space", "note", "placeholder for spatial-scale params");

%% -------------------- Done ------------------------------------------------
disp("Created " + file + " with flattened top-level bct schema.");
% h5disp(file);

%% ============================ Local functions =============================
function ensureGroup(h5file, grpPath)
  fid = H5F.open(h5file, 'H5F_ACC_RDWR', 'H5P_DEFAULT');
  lcpl = H5P.create('H5P_LINK_CREATE'); H5P.set_create_intermediate_group(lcpl, true);
  gcpl = H5P.create('H5P_GROUP_CREATE');
  try, gid = H5G.create(fid, grpPath, lcpl, gcpl, 'H5P_DEFAULT'); H5G.close(gid); end
  H5P.close(lcpl); H5P.close(gcpl); H5F.close(fid);
end

function setAsScale(h5file, dspath, label)
  fid = H5F.open(h5file, 'H5F_ACC_RDWR', 'H5P_DEFAULT');
  ds  = H5D.open(fid, dspath); H5DS.set_scale(ds, label);
  H5D.close(ds); H5F.close(fid);
end

function attachScale(h5file, parentPath, dimIndex, scalePath, label)
  fid = H5F.open(h5file, 'H5F_ACC_RDWR', 'H5P_DEFAULT');
  parent = H5D.open(fid, parentPath); scale  = H5D.open(fid, scalePath);
  H5DS.attach_scale(parent, scale, dimIndex); H5DS.set_label(parent, dimIndex, label);
  H5D.close(scale); H5D.close(parent); H5F.close(fid);
end

function ch = clampChunks(dsz, prop)
  dsz  = double(dsz); prop = double(prop);
  ch   = floor(max(1, min(prop, dsz)));
end

function ch = chunk1D(len, target)
  if nargin < 2, target = 1024; end
  len = double(len); ch  = floor(max(1, min(target, len)));
end

function deleteIfExists(h5file, path)
  fid = H5F.open(h5file,'H5F_ACC_RDWR','H5P_DEFAULT');
  if H5L.exists(fid, path, 'H5P_DEFAULT') > 0, H5L.delete(fid, path, 'H5P_DEFAULT'); end
  H5F.close(fid);
end

function tryAttachE(h5file, dspath)
  try, attachScale(h5file, dspath, 0, "/scales/axes/E", "E"); catch, end
end

function create1DAndAttachE(h5file, path, data, dtype)
  if nargin < 4, dtype = class(data); end
  n = numel(data); ch = chunk1D(n, 1024);
  deleteIfExists(h5file, path);
  h5create(h5file, path, [n], "Datatype", dtype, "ChunkSize", ch, "Deflate", 3);
  h5write (h5file, path, data(:));
  try, attachScale(h5file, path, 0, "/scales/axes/E", "E"); catch, end
end

function createEnumDataset(h5file, path, baseType, names, values, payload)
  deleteIfExists(h5file, path);
  fid    = H5F.open(h5file,'H5F_ACC_RDWR','H5P_DEFAULT');
  t_base = H5T.copy(baseType); t_enum = H5T.enum_create(t_base);
  for k = 1:numel(names), H5T.enum_insert(t_enum, names{k}, uint8(values(k))); end
  n = numel(payload); space = H5S.create_simple(1, n, []);
  dset = H5D.create(fid, path, t_enum, space, 'H5P_DEFAULT','H5P_DEFAULT','H5P_DEFAULT');
  H5D.write(dset, t_enum, 'H5S_ALL','H5S_ALL','H5P_DEFAULT', payload(:));
  H5D.close(dset); H5S.close(space); H5T.close(t_enum); H5T.close(t_base); H5F.close(fid);
  try, attachScale(h5file, path, 0, "/scales/axes/E", "E"); catch, end
end

function write_vlen_utf8(h5file, dspath, strings)
  deleteIfExists(h5file, dspath);
  if ischar(strings), strings = string(strings); end
  if iscellstr(strings), strings = string(strings); end
  strings = strings(:);                         % string array column

  % build VLEN UTF-8 datatype
  typeVL = H5T.copy('H5T_C_S1');
  try,    H5T.set_size(typeVL, 'H5T_VARIABLE');
  catch,  H5T.set_size(typeVL, H5ML.get_constant_value('H5T_VARIABLE'));
  end
  H5T.set_cset  (typeVL, H5ML.get_constant_value('H5T_CSET_UTF8'));
  H5T.set_strpad(typeVL, H5ML.get_constant_value('H5T_STR_NULLTERM'));

  fid   = H5F.open(h5file,'H5F_ACC_RDWR','H5P_DEFAULT');
  space = H5S.create_simple(1, numel(strings), []);
  dset  = H5D.create(fid, dspath, typeVL, space, 'H5P_DEFAULT','H5P_DEFAULT','H5P_DEFAULT');
  H5D.write(dset, typeVL, 'H5S_ALL','H5S_ALL','H5P_DEFAULT', strings);
  H5D.close(dset); H5S.close(space); H5T.close(typeVL); H5F.close(fid);
end
