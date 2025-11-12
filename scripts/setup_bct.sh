#!/usr/bin/env bash
# scripts/setup_bct.sh — scaffold/fix the bct (bioctree HDF5) module
# Usage: bash scripts/setup_bct.sh
# Run from the repo root (bioctree/)
set -euo pipefail

ROOT="$(pwd)"
say() { printf "[bct-setup] %s\n" "$*"; }

# -----------------------------------------------------------------------------
# 1) Directories
# -----------------------------------------------------------------------------
mkdir -p "$ROOT/toolbox/+bct/@bct" \
         "$ROOT/toolbox/+bct/+internal" \
         "$ROOT/toolbox/+bct/schema" \
         "$ROOT/demo" \
         "$ROOT/tests/+bct" \
         "$ROOT/data/bioctree_files/raw" \
         "$ROOT/data/bioctree_files/processed" \
         "$ROOT/data/bioctree_files/derivatives" \
         "$ROOT/data/cache" \
         "$ROOT/data/config" \
         "$ROOT/data/temp" \
         "$ROOT/scripts"

say "Ensured directory structure."

# -----------------------------------------------------------------------------
# 2) .gitignore additions
# -----------------------------------------------------------------------------
GITIGNORE="$ROOT/.gitignore"
if [[ ! -f "$GITIGNORE" ]]; then touch "$GITIGNORE"; fi
if ! grep -q "### bct ###" "$GITIGNORE"; then
  cat >> "$GITIGNORE" <<'EOF'
### bct ###
/data/cache/
/data/temp/
/data/bioctree_files/derivatives/
/data/bioctree_files/processed/
/data/**/*.h5~
EOF
  say "Appended bct rules to .gitignore"
else
  say "Skip: .gitignore rules already present"
fi

# -----------------------------------------------------------------------------
# Helper: write file only if missing (uses safe single-quoted heredoc)
# -----------------------------------------------------------------------------
write_if_absent () {
  local path="$1"; shift
  if [[ -e "$path" ]]; then
    say "Skip: $path (exists)"
  else
    mkdir -p "$(dirname "$path")"
    # shellcheck disable=SC2001
    cat > "$path" <<'EOF'
'"$@"'
EOF
    say "Wrote: $path"
  fi
}

# NOTE: For files containing special characters (MATLAB code), we avoid the
# helper above and place the heredoc directly (safer).

# -----------------------------------------------------------------------------
# 3) MATLAB: toolbox/+bct/@bct/bct.m  (facade)
# -----------------------------------------------------------------------------
BCT_FACADE="$ROOT/toolbox/+bct/@bct/bct.m"
if [[ -e "$BCT_FACADE" ]]; then
  say "Skip: $BCT_FACADE (exists)"
else
  cat > "$BCT_FACADE" <<'EOF'
classdef bct < handle
  % bct: BioCTree HDF5 facade (schema v1.0.0, skeleton Option A)
  properties (SetAccess=private)
    fn string
    T double = NaN; N double = NaN; fs double = NaN
    schema struct
  end
  methods (Static)
    function obj = create(fn)
      if exist(fn,'file'), delete(fn); end
      obj = bct; obj.fn = string(fn);
      M = bct.internal.Schema.loadFrozenManifest();
      bct.internal.Schema.writeSkeleton(fn, M);
      obj.schema = M;
    end
    function obj = open(fn)
      obj = bct; obj.fn = string(fn);
      obj.schema = bct.internal.Schema.readManifest(fn);
      bct.internal.Validator.validateSkeleton(fn, obj.schema);
      if bct.internal.Util.pathExists(fn, "/signals/raw")
        s = h5info(fn,"/signals/raw");
        obj.T = s.Dataspace.Size(1); obj.N = s.Dataspace.Size(2);
        try, obj.fs = double(h5readatt(fn,'/','fs_hz')); catch, end
      end
    end
  end
  methods
    function write_raw(this, X, fs)
      X = single(X); [T,N] = size(X);
      if bct.internal.Util.pathExists(this.fn,"/axes/node_id")
        nAxis = numel(h5read(this.fn,"/axes/node_id"));
        assert(nAxis==N,"bct:NodeCountMismatch","Signal N=%d vs node_id=%d",N,nAxis);
      else
        h5create(this.fn,'/axes/node_id',[N 1],'Datatype','int32');
        h5write(this.fn,'/axes/node_id',int32((0:N-1)'));
      end
      if bct.internal.Util.pathExists(this.fn,"/axes/time_s")
        tAxis = numel(h5read(this.fn,"/axes/time_s"));
        assert(tAxis==T,"bct:TimeLengthMismatch","Signal T=%d vs time_s=%d",T,tAxis);
      else
        h5create(this.fn,'/axes/time_s',[T 1],'Datatype','double');
        h5write(this.fn,'/axes/time_s',(0:T-1)'/fs);
      end
      h5create(this.fn,'/signals/raw',[T N],'Datatype','single', ...
        'ChunkSize',[min(T,2048) min(N,256)], 'Deflate',5, 'Shuffle',true);
      h5write(this.fn,'/signals/raw',X);
      h5writeatt(this.fn,'/','fs_hz',single(fs));
      bct.internal.DimScale.attach(this.fn,"/signals/raw", ...
        {"/axes/time_s","/axes/node_id"},{'time_s','node_id'});
      this.T=T; this.N=N; this.fs=fs;
    end

    function write_graph(this, G)
      Ngraph = size(G.coords,1);
      if bct.internal.Util.pathExists(this.fn,"/axes/node_id")
        nAxis = numel(h5read(this.fn,"/axes/node_id"));
        assert(nAxis==Ngraph,"bct:NodeCountMismatch","Graph N=%d vs node_id=%d",Ngraph,nAxis);
      else
        h5create(this.fn,'/axes/node_id',[Ngraph 1],'Datatype','int32');
        h5write(this.fn,'/axes/node_id',int32((0:Ngraph-1)'));
      end
      h5create(this.fn,'/graph/nodes/coords',[Ngraph 3],'Datatype','single');
      h5write(this.fn,'/graph/nodes/coords',single(G.coords));
      E=size(G.E,1);
      h5create(this.fn,'/graph/edges/coo_i',[E 1],'Datatype','int32');
      h5create(this.fn,'/graph/edges/coo_j',[E 1],'Datatype','int32');
      h5create(this.fn,'/graph/edges/coo_w',[E 1],'Datatype','single');
      h5write(this.fn,'/graph/edges/coo_i',int32(G.E(:,1)));
      h5write(this.fn,'/graph/edges/coo_j',int32(G.E(:,2)));
      h5write(this.fn,'/graph/edges/coo_w',single(getfield(G,'w',ones(E,1,'single'))));
      if isfield(G,'lap_type'), h5writeatt(this.fn,'/graph','lap_type',string(G.lap_type)); end
      if isfield(G,'lmax'),     h5writeatt(this.fn,'/graph','lmax',single(G.lmax)); end
      h5writeatt(this.fn,'/graph','indexing','zero_based');
    end

    function X = read_raw(this, tSpan, nodeIdx)
      if ischar(nodeIdx) && nodeIdx==':', nodeIdx=[1 this.N]; end
      st=[tSpan(1) nodeIdx(1)]; ct=[tSpan(2)-tSpan(1)+1, nodeIdx(end)-nodeIdx(1)+1];
      X = h5read(this.fn,"/signals/raw",st,ct);
    end

    function report = validate(this)
      report = bct.internal.Validator.validateAll(this.fn, this.schema);
    end
  end
end
EOF
  say "Created bct facade."
fi

# -----------------------------------------------------------------------------
# 4) MATLAB: internal helpers (Schema, Validator, DimScale, Util)
# -----------------------------------------------------------------------------
SCHEMA_M="$ROOT/toolbox/+bct/+internal/Schema.m"
if [[ -e "$SCHEMA_M" ]]; then
  say "Skip: $SCHEMA_M (exists)"
else
  cat > "$SCHEMA_M" <<'EOF'
classdef Schema
methods(Static)
  function M = loadFrozenManifest()
    base = fileparts(mfilename('fullpath'));
    jsonPath = fullfile(base(1:strfind(base,'+bct')+3),'schema','bct-core-1.0.0.json');
    M = jsondecode(fileread(jsonPath));
  end
  function writeSkeleton(fn, M)
    for g = ["/axes","/graph","/signals","/decomp","/filters","/results","/events","/masks","/schema"]
      bct.internal.Util.ensureGroup(fn, g);
    end
    h5writeatt(fn,'/','datatype','bct');
    h5writeatt(fn,'/','schema_name',M.schema_name);
    h5writeatt(fn,'/','schema_version',M.schema_version);
    h5writeatt(fn,'/','indexing','zero_based');
    h5writeatt(fn,'/','uuid', bct.internal.Util.uuid4());
    h5writeatt(fn,'/','created_utc', datestr(datetime('now','TimeZone','UTC'),'yyyy-mm-ddTHH:MM:SSZ'));
    h5create(fn,'/schema/manifest_json',[1 1],'Datatype','string');
    h5write(fn,'/schema/manifest_json', string(jsonencode(M)));
  end
  function M = readManifest(fn)
    M = jsondecode(char(h5read(fn,'/schema/manifest_json')));
  end
end
end
EOF
  say "Created internal Schema helper."
fi

VALIDATOR_M="$ROOT/toolbox/+bct/+internal/Validator.m"
if [[ -e "$VALIDATOR_M" ]]; then
  say "Skip: $VALIDATOR_M (exists)"
else
  cat > "$VALIDATOR_M" <<'EOF'
classdef Validator
methods(Static)
  function report = validateSkeleton(fn, M)
    ok=true; msgs=string.empty(0,1);
    root=h5info(fn,"/"); present=string({root.Attributes.Name});
    req=string(M.root_attributes_required);
    miss=setdiff(req,present);
    if ~isempty(miss), ok=false; msgs(end+1)="Missing root attrs: "+strjoin(miss,", "); end
    for g = ["/axes","/graph","/signals","/decomp","/filters","/results","/events","/masks","/schema"]
      if ~bct.internal.Util.pathExists(fn,g), ok=false; msgs(end+1)="Missing group: "+g; end
    end
    report=struct('ok',ok,'messages',msgs);
    if ~ok, error("bct:SchemaInvalid","%s",strjoin(msgs,newline)); end
  end
  function report = validateAll(fn, M)
    V=bct.internal.Validator.validateSkeleton(fn,M); %#ok<NASGU>
    ok=true; msgs=string.empty(0,1);
    if bct.internal.Util.pathExists(fn,"/signals/raw")
      s=h5info(fn,"/signals/raw"); T=s.Dataspace.Size(1); N=s.Dataspace.Size(2);
      if bct.internal.Util.pathExists(fn,"/axes/time_s") && numel(h5read(fn,"/axes/time_s"))~=T
        ok=false; msgs(end+1)="time_s length must equal raw T.";
      end
      if bct.internal.Util.pathExists(fn,"/axes/node_id") && numel(h5read(fn,"/axes/node_id"))~=N
        ok=false; msgs(end+1)="node_id length must equal raw N.";
      end
    end
    report=struct('ok',ok,'messages',msgs);
    if ~ok, error("bct:SchemaInvalid","%s",strjoin(msgs,newline)); end
  end
end
end
EOF
  say "Created internal Validator."
fi

DIMSCALE_M="$ROOT/toolbox/+bct/+internal/DimScale.m"
if [[ -e "$DIMSCALE_M" ]]; then
  say "Skip: $DIMSCALE_M (exists)"
else
  cat > "$DIMSCALE_M" <<'EOF'
classdef DimScale
methods(Static)
  function attach(fn, dsetPath, scalePaths, labels)
    fid=H5F.open(fn,'H5F_ACC_RDWR','H5P_DEFAULT');
    dset=H5D.open(fid,dsetPath);
    for i=1:numel(scalePaths)
      sc=H5D.open(fid,scalePaths{i});
      H5DS.set_scale(sc,labels{i});
      H5DS.attach_scale(dset,sc,i-1);
      H5DS.set_label(dset,i-1,labels{i});
      H5D.close(sc);
    end
    H5D.close(dset); H5F.close(fid);
  end
end
end
EOF
  say "Created internal DimScale helper."
fi

UTIL_M="$ROOT/toolbox/+bct/+internal/Util.m"
if [[ -e "$UTIL_M" ]]; then
  say "Skip: $UTIL_M (exists)"
else
  cat > "$UTIL_M" <<'EOF'
classdef Util
methods(Static)
  function ensureGroup(fn, path)
    if ~bct.internal.Util.pathExists(fn, path)
      fid=H5F.open(fn,'H5F_ACC_RDWR','H5P_DEFAULT');
      gid=H5G.create(fid,path,0); H5G.close(gid); H5F.close(fid);
    end
  end
  function tf = pathExists(fn, path)
    try, h5info(fn,path); tf=true; catch, tf=false; end
  end
  function u = uuid4()
    bytes = randi([0 255],[16 1],'uint8');
    u = sprintf('%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x', bytes);
  end
end
end
EOF
  say "Created internal Util helper."
fi

# -----------------------------------------------------------------------------
# 5) Schema manifest JSON
# -----------------------------------------------------------------------------
MANIFEST="$ROOT/toolbox/+bct/schema/bct-core-1.0.0.json"
if [[ -e "$MANIFEST" ]]; then
  say "Skip: $MANIFEST (exists)"
else
  cat > "$MANIFEST" <<'EOF'
{
  "datatype": "bct",
  "schema_name": "bct-core",
  "schema_version": "1.0.0",
  "root_attributes_required": ["datatype","schema_name","schema_version","indexing","uuid","created_utc"],
  "axes": {
    "time_s":       {"path": "/axes/time_s",       "dtype": "float64", "rank": 1, "optional": false},
    "node_id":      {"path": "/axes/node_id",      "dtype": "int32",   "rank": 1, "optional": false},
    "freq_hz":      {"path": "/axes/freq_hz",      "dtype": "float32", "rank": 1, "optional": true},
    "graph_lambda": {"path": "/axes/graph_lambda", "dtype": "float32", "rank": 1, "optional": true}
  },
  "datasets": {
    "/signals/raw":              {"shape": ["T","N"],         "dtype_any_of": ["float32"], "dim_scales": ["time_s","node_id"], "optional": false},
    "/decomp/time_freq/coeffs":  {"shape": ["F","T","N"],     "dtype_any_of": ["float32","complex64"], "dim_scales": ["freq_hz","time_s","node_id"], "optional": true},
    "/decomp/graph_freq/coeffs": {"shape": ["K","T","N"],     "dtype_any_of": ["float32","complex64"], "dim_scales": ["graph_lambda","time_s","node_id"], "optional": true}
  },
  "dimension_constraints": [
    {"equals": ["len(/axes/node_id)", "shape(/signals/raw)[1]"], "optional_left": false, "optional_right": false},
    {"equals": ["len(/axes/time_s)",  "shape(/signals/raw)[0]"], "optional_left": false, "optional_right": false},
    {"equals": ["shape(/decomp/time_freq/coeffs)[1:3]", "shape(/signals/raw)"], "optional_left": true},
    {"equals": ["shape(/decomp/graph_freq/coeffs)[1:3]", "shape(/signals/raw)"], "optional_left": true}
  ]
}
EOF
  say "Wrote schema manifest."
fi

# -----------------------------------------------------------------------------
# 6) Demo script
# -----------------------------------------------------------------------------
DEMO="$ROOT/demo/demo_bct_minimal.m"
if [[ -e "$DEMO" ]]; then
  say "Skip: $DEMO (exists)"
else
  cat > "$DEMO" <<'EOF'
bioctree_init();
outfn = fullfile(fileparts(mfilename('fullpath')),'..','data','bioctree_files','raw','demo_sub01.bct.h5');

% 1) Create empty bct
B = bct.bct.create(outfn);

% 2) Write graph (synthetic)
N = 32; coords = rand(N,3); E = [randi(N,64,1) randi(N,64,1)];
G = struct('coords',coords,'E',E,'lap_type','normalized','lmax',single(2.0));
B.write_graph(G);

% 3) Write raw signal
T=500; fs=100; X = randn(T,N,'single'); B.write_raw(X, fs);

% 4) Read a window
Xwin = B.read_raw([101 200],[1 8]); disp(size(Xwin));

% 5) Validate
B.validate(); disp('bct demo OK');
EOF
  say "Created demo script."
fi

# -----------------------------------------------------------------------------
# 7) Test skeleton
# -----------------------------------------------------------------------------
TEST="$ROOT/tests/+bct/test_bct_create_open.m"
if [[ -e "$TEST" ]]; then
  say "Skip: $TEST (exists)"
else
  cat > "$TEST" <<'EOF'
function tests = test_bct_create_open, tests = functiontests(localfunctions); end
function setupOnce(t)
root = fileparts(mfilename('fullpath'));
t.TestData.fn = fullfile(root,'..','..','data','temp','unit_demo.bct.h5');
if ~exist(fileparts(t.TestData.fn),'dir'), mkdir(fileparts(t.TestData.fn)); end
end
function testCreateWriteRead(t)
B = bct.bct.create(t.TestData.fn);
N=10; T=100; fs=100;
G = struct('coords',rand(N,3),'E',[randi(N,30,1) randi(N,30,1)],'lap_type','normalized','lmax',single(2));
B.write_graph(G); B.write_raw(single(randn(T,N)), fs);
B.validate();
X = B.read_raw([1 10],[1 5]);
verifySize(t, X, [10 5]);
end
EOF
  say "Created test skeleton."
fi

# -----------------------------------------------------------------------------
# 8) Reminder for bioctree_init.m
# -----------------------------------------------------------------------------
if [[ -f "$ROOT/bioctree_init.m" ]]; then
  say "bioctree_init.m already exists — ensure it adds 'toolbox' to path."
else
  cat > "$ROOT/bioctree_init.m" <<'EOF'
function bioctree_init()
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root,'toolbox'));  % brings +bct package
addpath(fullfile(root,'workflows'), fullfile(root,'io'), ...
        fullfile(root,'plotlib'), fullfile(root,'demo'), ...
        fullfile(root,'tests'));
fprintf('[bioctree] Paths added. Data root: %s\n', fullfile(root,'data'));
end
EOF
  say "Created bioctree_init.m"
fi

say "Done. Try: matlab -batch \"bioctree_init; run('demo/demo_bct_minimal.m')\""