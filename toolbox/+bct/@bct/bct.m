classdef bct < handle
  % bct: BioCTree HDF5 facade (schema v1.0.0, skeleton Option A)
  %
  % MIGRATION NOTES (v2.0):
  % The following properties have been DEPRECATED and moved to the Manifold object:
  %   - T  → Use Manifold.Time.T (number of time points)
  %   - N  → Use Manifold.N (number of vertices/nodes)
  %   - fs → Use Manifold.Time.fs (sampling frequency)
  %   - F  → Use size(Manifold.F, 1) for mesh faces, or context-specific for frequency bins
  %   - L  → Number of layers (not yet migrated to new architecture)
  %
  % The deprecated properties are still accessible for backward compatibility but will
  % be removed in a future release. Update your code to use the Manifold object instead.
  %
  % Example migration:
  %   OLD: nVerts = B.N; timePoints = B.T; sampRate = B.fs;
  %   NEW: nVerts = B.Manifold.N; timePoints = B.Manifold.Time.T; sampRate = B.Manifold.Time.fs;
  %
  properties (SetAccess=private)
    fn string
    schema struct
  end
  
  % DEPRECATED properties - kept for backward compatibility, will be removed in future versions
  properties (SetAccess=private, Hidden)
    % These properties are deprecated. Use Manifold.N, Manifold.Time.T, Manifold.Time.fs instead
    T double = NaN;  % DEPRECATED: Use Manifold.Time.T
    N double = NaN;  % DEPRECATED: Use Manifold.N
    L double = NaN;  % DEPRECATED: Number of layers (not yet migrated to new architecture)
    F double = NaN;  % DEPRECATED: Number of faces (use size(Manifold.F,1)) or frequency bins
    fs double = NaN; % DEPRECATED: Use Manifold.Time.fs
    
    % HDF5 presence flags and handles (deprecated - internal use only)
    has_raw   logical = false
    has_stack logical = false
    has_tf    logical = false
    h5 = struct('fid',[], 'd_raw',[], 'd_stack',[], 'd_tfR',[], 'd_tfI',[], ...
                's_raw',[], 's_stack',[], 's_tfR',[], 's_tfI',[])
  end
  % In classdef bct (add near other properties)
properties (Access=private, Constant)
    P = struct( ...
      'axes_time', "/axes/time_s", ...
      'axes_node', "/axes/node_id", ...
      'axes_layer',"/axes/layer_id", ...
      'axes_freq', "/axes/freq_hz", ...
      'raw',       "/signals/raw", ...
      'stack',     "/signals/raw_stack", ...
      'tfR',       "/decomp/time_freq/coeffs_real", ...
      'tfI',       "/decomp/time_freq/coeffs_imag" ...
    )
end

properties (Access=private, Transient)
    cache struct = struct();     % holds legacy A, W, E, mesh, mgraph, gsp, w
end

properties
    % Manifold object encapsulates mesh/graph topology
    % Preferred way to access mesh geometry and topology
    % Access as: B.Manifold.V, B.Manifold.F, B.Manifold.meshFourier(), etc.
    Manifold               % bct.manifold.Manifold object
    
    % Time object encapsulates temporal properties for time-varying signals
    % Stores sampling rate, duration, and temporal resolution information
    % Access as: B.Time.fs, B.Time.T, B.Time.Resolution, etc.
    Time bct.manifold.Time = bct.manifold.Time.empty()  % Time dimension properties
    
    % Signals defined on the Manifold
    % Can be a single bct.signal.Signal object or an array of Signal objects
    % All signals must have dimensions matching B.Manifold (N and optionally T)
    Signals bct.signal.Signal = bct.signal.Signal.empty()
end

properties (SetAccess=private)
    % Joint mesh-time spectral grid
    % Built from eigenvalues of Manifold.meshFourier and Time vector
    % Access as: B.SpectralGrid.lambda_grid, B.SpectralGrid.t_grid
    SpectralGrid struct = struct('lambda_grid', [], 't_grid', [], 'lambda_band', [], 't', [])
end


  methods (Static)
   function obj = create(outSpec)
    target = bct.internal.Paths.underData(outSpec, fullfile('bioctree_files','raw'));
    if exist(target,'file'), delete(target); end
    obj = bct.bct(); obj.fn = string(target);
    M = bct.internal.Schema.loadFrozenManifest();
    bct.internal.Schema.writeSkeleton(target, M);   % will create groups & embed manifest
    obj.schema = M;
  end
function obj = open(fn)
    obj = bct.bct(); obj.fn = string(fn);
    % Manifest + skeleton check
    obj.schema = bct.internal.Schema.readManifest(fn);
    bct.internal.Validator.validateSkeleton(fn, obj.schema);

    % Presence flags (ONE TIME — trust schema + Validator after this)
    obj.has_raw   = bct.internal.Util.pathExists(fn, obj.P.raw);
    obj.has_stack = bct.internal.Util.pathExists(fn, obj.P.stack);
    obj.has_tf    = bct.internal.Util.pathExists(fn, obj.P.tfR) && ...
                    bct.internal.Util.pathExists(fn, obj.P.tfI);

    % Read dimensions and populate both Manifold and deprecated properties
    T_val = NaN; N_val = NaN; fs_val = NaN; L_val = NaN; F_val = NaN;
    
    if obj.has_raw
        s = h5info(fn, obj.P.raw);
        T_val = s.Dataspace.Size(1);
        N_val = s.Dataspace.Size(2);
        try fs_val = double(h5readatt(fn,'/','fs_hz')); catch, fs_val = NaN; end
    else
        % If no /signals/raw, fall back to axes if present
        if bct.internal.Util.pathExists(fn, obj.P.axes_time)
            T_val = numel(h5read(fn, obj.P.axes_time));
        end
        if bct.internal.Util.pathExists(fn, obj.P.axes_node)
            N_val = numel(h5read(fn, obj.P.axes_node));
        end
        try fs_val = double(h5readatt(fn,'/','fs_hz')); catch, fs_val = NaN; end
    end

    if obj.has_stack
        sRS = h5info(fn, obj.P.stack);
        L_val = sRS.Dataspace.Size(1);
    end

    if obj.has_tf
        F_val = numel(h5read(fn, obj.P.axes_freq));
    end
    
    % Populate deprecated properties for backward compatibility
    obj.T = T_val; obj.N = N_val; obj.fs = fs_val; obj.L = L_val; obj.F = F_val;
    
    % Initialize Manifold object if we have graph/mesh data
    % For now, create empty Manifold - will be populated when graph/mesh data is loaded
    % User can explicitly set obj.Manifold later, or it will be set by fromMesh/fromAdjacency
    if ~isnan(N_val) && N_val > 0
        % Create a basic graph Manifold placeholder
        obj.Manifold = bct.manifold.Manifold();
        obj.Manifold.N = N_val;
        obj.Manifold.Type = "graph";  % Default assumption; can be overridden
        
        % Set Time information if available
        if ~isnan(T_val) && ~isnan(fs_val) && T_val > 0 && fs_val > 0
            obj.Manifold.Time = bct.manifold.Time(T_val, fs_val);
        end
    end

    % Open HDF5 handles for performance-critical operations
    obj.h5.fid = H5F.open(fn, 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
    if obj.has_raw
        obj.h5.d_raw = H5D.open(obj.h5.fid, obj.P.raw);
        obj.h5.s_raw = H5D.get_space(obj.h5.d_raw);
    end
    if obj.has_stack
        obj.h5.d_stack = H5D.open(obj.h5.fid, obj.P.stack);
        obj.h5.s_stack = H5D.get_space(obj.h5.d_stack);
    end
    if obj.has_tf
        obj.h5.d_tfR = H5D.open(obj.h5.fid, obj.P.tfR);
        obj.h5.s_tfR = H5D.get_space(obj.h5.d_tfR);
        obj.h5.d_tfI = H5D.open(obj.h5.fid, obj.P.tfI);
        obj.h5.s_tfI = H5D.get_space(obj.h5.d_tfI);
    end
  end
  end
  methods
    function delete(this)
    % Close low-level handles if they were opened (safe to call multiple times)
    try
      if ~isempty(this.h5.d_raw),  H5D.close(this.h5.d_raw);  end
      if ~isempty(this.h5.s_raw),  H5S.close(this.h5.s_raw);  end
      if ~isempty(this.h5.d_stack),H5D.close(this.h5.d_stack);end
      if ~isempty(this.h5.s_stack),H5S.close(this.h5.s_stack);end
      if ~isempty(this.h5.d_tfR),  H5D.close(this.h5.d_tfR);  end
      if ~isempty(this.h5.s_tfR),  H5S.close(this.h5.s_tfR);  end
      if ~isempty(this.h5.d_tfI),  H5D.close(this.h5.d_tfI);  end
      if ~isempty(this.h5.s_tfI),  H5S.close(this.h5.s_tfI);  end
      if ~isempty(this.h5.fid),    H5F.close(this.h5.fid);    end
    catch
      % swallow; best-effort close
    end
  end
    %% -------- small public getters (keep callers B-bound)
    function v = read_axis(this, name)
        p = "/axes/" + string(name);
        if ~bct.internal.Util.pathExists(this.fn, p)
            error('bct:AxisMissing','Axis not found: %s', p);
        end
        v = h5read(this.fn, char(p));
    end

    function tf = has(this, path)
        tf = bct.internal.Util.pathExists(this.fn, char(path));
    end

    function C = read_coords(this)
        if this.has('/graph/nodes/coords')
            C = h5read(this.fn, '/graph/nodes/coords');
        else
            C = [];
        end
    end

    function G = read_graph_gsp(this)
        if ~this.has('/graph/edges/coo_i'), G = []; return; end
        i0 = h5read(this.fn,'/graph/edges/coo_i'); 
        j0 = h5read(this.fn,'/graph/edges/coo_j');
        w  = h5read(this.fn,'/graph/edges/coo_w');
        i = double(i0)+1; j = double(j0)+1; w = double(w);
        nNodes = numel(this.read_axis('node_id'));
        W = sparse(i,j,w,nNodes,nNodes); W = max(W,W.');
        G = struct('W',W,'N',nNodes);
        C = this.read_coords(); if ~isempty(C), G.coords = double(C); end
        try G = gsp_estimate_lmax(G); catch, end
    end
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
    % --- basic sizes
    assert(isfield(G,'E') && ~isempty(G.E), 'bct:GraphMissingEdges', 'G.E (edge list) is required.');
    E = size(G.E,1);

    % --- nodes / N
    if isfield(G,'coords') && ~isempty(G.coords)
        N_graph = size(G.coords,1);
    elseif isfield(G,'A') && ~isempty(G.A)
        N_graph = size(G.A,1);
    else
        % fall back to max node index in E (MATLAB 1-based)
        N_graph = max(max(G.E(:,1:2)));
    end

    % --- enforce / create node axis
    if bct.internal.Util.pathExists(this.fn,"/axes/node_id")
        nAxis = numel(h5read(this.fn,"/axes/node_id"));
        assert(nAxis==N_graph, "bct:NodeCountMismatch", ...
            "Graph N=%d does not match node_id length=%d.", N_graph, nAxis);
    else
        h5create(this.fn,'/axes/node_id',[N_graph 1],'Datatype','int32');
        h5write(this.fn,'/axes/node_id', int32((0:N_graph-1)'));
    end

    % --- coords (optional)
    if isfield(G,'coords') && ~isempty(G.coords)
        h5create(this.fn,'/graph/nodes/coords',[N_graph 3],'Datatype','single');
        h5write(this.fn,'/graph/nodes/coords', single(G.coords));
    end

    % --- edges: support (i,j[,w]) or G.w vector
    i = G.E(:,1); j = G.E(:,2);
    if size(G.E,2) >= 3
        w = G.E(:,3);
    elseif isfield(G,'w') && ~isempty(G.w)
        w = G.w(:);
        assert(numel(w)==E, 'bct:WeightLengthMismatch', 'numel(G.w) must equal size(G.E,1).');
    elseif isfield(G,'W') && ~isempty(G.W) && issparse(G.W)
        % optional: if you prefer, you can rebuild from W; here we just default
        w = ones(E,1,'single');
    else
        w = ones(E,1,'single');
    end

    % bounds check & convert to zero-based for file
    assert(all(i>=1 & i<=N_graph & j>=1 & j<=N_graph), 'bct:EdgeIndexOutOfRange', 'Edges reference out-of-range node ids.');
    i0 = int32(i-1); j0 = int32(j-1); w = single(w);

    % --- write COO
    h5create(this.fn,'/graph/edges/coo_i',[E 1],'Datatype','int32');
    h5create(this.fn,'/graph/edges/coo_j',[E 1],'Datatype','int32');
    h5create(this.fn,'/graph/edges/coo_w',[E 1],'Datatype','single');
    h5write(this.fn,'/graph/edges/coo_i', i0);
    h5write(this.fn,'/graph/edges/coo_j', j0);
    h5write(this.fn,'/graph/edges/coo_w', w);

    % --- attributes (optional)
    if isfield(G,'lap_type'), h5writeatt(this.fn,'/graph','lap_type',string(G.lap_type)); end
    if isfield(G,'lmax'),     h5writeatt(this.fn,'/graph','lmax',single(G.lmax)); end
    if isfield(G,'type'),     h5writeatt(this.fn,'/graph','type',string(G.type)); end
    h5writeatt(this.fn,'/graph','indexing','zero_based');
end

function X = read_raw(this, tSpan, nodeIdx, layerOpt)
    if nargin < 4 || isempty(layerOpt)
        % fast path: use /signals/raw (default layer view)
        X = bct.internal.IO.readHyperslab(this.fn,'/signals/raw', tSpan, nodeIdx);
    else
        % explicit layer: read from stack
        X3 = this.read_raw_layers(layerOpt, tSpan, nodeIdx);
        X  = squeeze(X3);  % (Tsel×Nsel)
    end
end
function write_raw_layers(this, Xltn, fs, layer_ids)
% Xltn: (L × T × N) single/double
% layer_ids: optional int32(L×1), defaults to 0..L-1

Xltn = single(Xltn); [L,T,N] = size(Xltn);

% Ensure axes time_s & node_id exist/match (reuse your existing checks)
if bct.internal.Util.pathExists(this.fn,"/axes/node_id")
    nAxis = numel(h5read(this.fn,"/axes/node_id"));
    assert(nAxis==N, "bct:NodeCountMismatch", "N=%d vs node_id=%d", N, nAxis);
else
    h5create(this.fn,'/axes/node_id',[N 1],'Datatype','int32');
    h5write(this.fn,'/axes/node_id', int32((0:N-1)'));
end

if bct.internal.Util.pathExists(this.fn,"/axes/time_s")
    tAxis = numel(h5read(this.fn,"/axes/time_s"));
    assert(tAxis==T, "bct:TimeLengthMismatch", "T=%d vs time_s=%d", T, tAxis);
else
    h5create(this.fn,'/axes/time_s',[T 1],'Datatype','double');
    h5write(this.fn,'/axes/time_s',(0:T-1)'/fs);
end

% layer_id axis
if nargin < 4 || isempty(layer_ids)
    layer_ids = int32(0:L-1);
else
    layer_ids = int32(layer_ids(:));
    assert(numel(layer_ids)==L, "bct:LayerIdMismatch", "layer_ids must have L elements");
end
if bct.internal.Util.pathExists(this.fn,"/axes/layer_id")
    Laxis = numel(h5read(this.fn,"/axes/layer_id"));
    assert(Laxis==L, "bct:LayerCountMismatch", "L=%d vs layer_id len=%d", L, Laxis);
else
    h5create(this.fn,'/axes/layer_id',[L 1],'Datatype','int32');
    h5write(this.fn,'/axes/layer_id', layer_ids);
end

% dataset (L,T,N)
h5create(this.fn,'/signals/raw_stack',[L T N],'Datatype','single', ...
   'ChunkSize',[1 min(T,1024) min(N,128)], 'Deflate',5, 'Shuffle',true);
h5write(this.fn,'/signals/raw_stack', Xltn);

% attach scales
bct.internal.DimScale.attach(this.fn,"/signals/raw_stack", ...
   {"/axes/layer_id","/axes/time_s","/axes/node_id"}, ...
   {'layer_id','time_s','node_id'});

% store fs
h5writeatt(this.fn,'/','fs_hz', single(fs));

% convenience: set /signals/raw = first layer if absent
if ~bct.internal.Util.pathExists(this.fn,"/signals/raw")
   h5create(this.fn,'/signals/raw',[T N],'Datatype','single', ...
      'ChunkSize',[min(T,2048) min(N,256)], 'Deflate',5, 'Shuffle',true);
   % Ensure proper T×N dimensions even when T=1
   first_layer = squeeze(Xltn(1,:,:));
   if T == 1 && isvector(first_layer)
       first_layer = reshape(first_layer, 1, N);  % Ensure 1×N for T=1 case
   end
   h5write(this.fn,'/signals/raw', first_layer);
   bct.internal.DimScale.attach(this.fn,"/signals/raw", ...
      {"/axes/time_s","/axes/node_id"}, {'time_s','node_id'});
end

this.T=T; this.N=N; this.fs=fs;
end
function append_raw_layer(this, Xtn, layer_id)
% Xtn: (T × N) single/double; appends along layer dimension
Xtn = single(Xtn); [T,N] = size(Xtn);

% check existing axes
tAxis = numel(h5read(this.fn,"/axes/time_s"));
nAxis = numel(h5read(this.fn,"/axes/node_id"));
assert(tAxis==T && nAxis==N, "bct:ShapeMismatch", ...
    "Layer must be (T,N) matching existing axes.");

stackPath = "/signals/raw_stack"; lidPath = "/axes/layer_id";

if ~bct.internal.Util.pathExists(this.fn, stackPath)
    % initialize with L=1
    h5create(this.fn, lidPath, [1 1], 'Datatype','int32');
    h5write(this.fn,  lidPath, int32(layer_id));
    h5create(this.fn, stackPath, [1 T N], 'Datatype','single', ...
      'ChunkSize',[1 min(T,1024) min(N,128)], 'Deflate',5, 'Shuffle',true);
    h5write(this.fn, stackPath, reshape(Xtn,[1 T N]));
    bct.internal.DimScale.attach(this.fn,stackPath, ...
      {lidPath,"/axes/time_s","/axes/node_id"}, {'layer_id','time_s','node_id'});
    return;
end

% extend layer_id vector
L = numel(h5read(this.fn, lidPath));
fid = H5F.open(this.fn,'H5F_ACC_RDWR','H5P_DEFAULT');
d  = H5D.open(fid, lidPath); H5D.set_extent(d, int64([L+1 1])); H5D.close(d); H5F.close(fid);
h5write(this.fn, lidPath, int32(layer_id), [L+1 1], [1 1]);

% extend stack and write slice
fid = H5F.open(this.fn,'H5F_ACC_RDWR','H5P_DEFAULT');
d  = H5D.open(fid, stackPath); H5D.set_extent(d, int64([L+1 T N])); H5D.close(d); H5F.close(fid);
h5write(this.fn, stackPath, reshape(Xtn,[1 T N]), [L+1 1 1], [1 T N]);
end
function X = read_raw_layers(this, layers, tSpan, nIdx)
% layers: scalar or vector of 1-based indices (MATLAB style)
% returns (Lsel × Tsel × Nsel)
if ischar(nIdx) && nIdx==':', nIdx = [1 this.N]; end
st = [layers(1) tSpan(1) nIdx(1)];
ct = [numel(layers) tSpan(2)-tSpan(1)+1 nIdx(end)-nIdx(1)+1];
X  = h5read(this.fn, "/signals/raw_stack", st, ct);
end
function id = get_default_layer(this)
    if ~any(strcmp({h5info(this.fn).Attributes.Name}, 'default_layer_id'))
        h5writeatt(this.fn,'/','default_layer_id', int32(0));
    end
    id = double(h5readatt(this.fn,'/','default_layer_id')) + 1; % MATLAB 1-based
end
function set_default_layer(this, id1based)
    ids = h5read(this.fn,'/axes/layer_id');       % 0-based in file
    assert(ismember(int32(id1based-1), ids), 'bct:BadDefaultLayer', 'Layer does not exist.');
    h5writeatt(this.fn,'/','default_layer_id', int32(id1based-1));
    % maintain /signals/raw as a convenient view of that layer (copy-on-set)
    s = h5info(this.fn,'/signals/raw_stack'); T=s.Dataspace.Size(2); N=s.Dataspace.Size(3);
    Y = h5read(this.fn,'/signals/raw_stack', [id1based 1 1], [1 T N]); Y = squeeze(Y);
    if ~bct.internal.Util.pathExists(this.fn,'/signals/raw')
        h5create(this.fn,'/signals/raw',[T N],'Datatype','single', ...
            'ChunkSize',[min(T,2048) min(N,256)], 'Deflate',5, 'Shuffle',true);
        bct.internal.DimScale.attach(this.fn,"/signals/raw", ...
            {"/axes/time_s","/axes/node_id"}, {'time_s','node_id'});
    end
    h5write(this.fn,'/signals/raw', Y);
end
function write_tf_coeffs(this, C, freq_hz, tf_attrs)
% --- shape & axes
if ndims(C)==3, C = reshape(C,[1 size(C)]); end
[L,F,T,N] = size(C);
tAxis = numel(h5read(this.fn,"/axes/time_s"));
nAxis = numel(h5read(this.fn,"/axes/node_id"));
assert(tAxis==T && nAxis==N, "bct:ShapeMismatch","(T,N) mismatch for TF.");

% --- layer axis (ensure exists; default layer id 0 if absent)
if ~bct.internal.Util.pathExists(this.fn,"/axes/layer_id")
    h5create(this.fn,'/axes/layer_id',[max(L,1) 1],'Datatype','int32');
    h5write(this.fn,'/axes/layer_id', int32((0:max(L,1)-1)'));
else
    Laxis = numel(h5read(this.fn,"/axes/layer_id"));
    if Laxis ~= L
        % if file has L=1 and we're writing L>1 (or vice versa), you can extend or error.
        % For now, enforce equality for safety:
        assert(Laxis==L, "bct:LayerCountMismatch","L=%d vs layer_id len=%d", L, Laxis);
    end
end

% --- freq axis
if ~bct.internal.Util.pathExists(this.fn,"/axes/freq_hz")
    h5create(this.fn,'/axes/freq_hz',[F 1],'Datatype','single');
    h5write(this.fn,'/axes/freq_hz', single(freq_hz(:)));
else
    assert(numel(h5read(this.fn,"/axes/freq_hz"))==F,'bct:FreqCountMismatch');
end

% --- ensure group exists
bct.internal.Util.ensureGroup(this.fn, '/decomp/time_freq');

% --- datasets (split): create if missing; else validate shape and overwrite
paths = {"/decomp/time_freq/coeffs_real","/decomp/time_freq/coeffs_imag"};
csz   = [1 min(F,16) min(T,1024) min(N,128)];

for p = 1:2
    dpath = paths{p};
    if bct.internal.Util.pathExists(this.fn, dpath)
        info = h5info(this.fn, dpath);
        assert(isequal(info.Dataspace.Size, [L F T N]), ...
            "bct:TFShapeMismatch","Existing %s has shape [%s], expected [%s].", ...
            dpath, num2str(info.Dataspace.Size), num2str([L F T N]));
    else
        h5create(this.fn, dpath, [L F T N], 'Datatype','single', ...
            'ChunkSize', csz, 'Deflate',5, 'Shuffle',true);
    end
end

% --- write real/imag
h5write(this.fn, paths{1}, single(real(C)));
h5write(this.fn, paths{2}, single(imag(C)));

% --- (re)attach dim scales (safe to repeat)
bct.internal.DimScale.attach(this.fn, paths{1}, ...
   {"/axes/layer_id","/axes/freq_hz","/axes/time_s","/axes/node_id"}, ...
   {'layer_id','freq_hz','time_s','node_id'});
bct.internal.DimScale.attach(this.fn, paths{2}, ...
   {"/axes/layer_id","/axes/freq_hz","/axes/time_s","/axes/node_id"}, ...
   {'layer_id','freq_hz','time_s','node_id'});

% --- attrs
grp = '/decomp/time_freq';
bct.internal.Util.ensureGroup(this.fn, grp);

if isfield(tf_attrs,'transform')
    bct.internal.Attr.write(this.fn, grp, 'transform', tf_attrs.transform);
end
if isfield(tf_attrs,'pr_exact')
    bct.internal.Attr.write(this.fn, grp, 'pr_exact', tf_attrs.pr_exact);    % logical -> uint8
end
if isfield(tf_attrs,'padding')
    bct.internal.Attr.write(this.fn, grp, 'padding', tf_attrs.padding);
end
if isfield(tf_attrs,'params_json')
    bct.internal.Attr.write(this.fn, grp, 'params_json', tf_attrs.params_json);
end
bct.internal.Attr.write(this.fn, grp, 'tf_complex_storage', 'split');

end
function Y = read_tf_band(this, fHz, tSpan, nIdx, layers)
% Returns (Lsel × Tsel × Nsel) reconstructed band-limited signal
if nargin < 5 || isempty(layers), layers = this.get_default_layer(); end
if ischar(nIdx) && nIdx==':', nIdx = [1 this.N]; end

freqs = h5read(this.fn,'/axes/freq_hz');
fIdx = [find(freqs >= fHz(1),1,'first'), find(freqs <= fHz(2),1,'last')];
assert(all(~isnan(fIdx)) && fIdx(1) <= fIdx(2), 'bct:BandNotFound');

st = [layers(1) fIdx(1) tSpan(1) nIdx(1)];
ct = [numel(layers) fIdx(2)-fIdx(1)+1 tSpan(2)-tSpan(1)+1 nIdx(end)-nIdx(1)+1];

R = h5read(this.fn,'/decomp/time_freq/coeffs_real', st, ct);
I = h5read(this.fn,'/decomp/time_freq/coeffs_imag', st, ct);
Cband = complex(R, I);                       % (L,F,T,N)

% --- Synthesis ---
% Replace this with the true inverse for your transform (weights/OLA/etc.)
Y = squeeze(sum(Cband, 2));                  % naive sum over F → (L,T,N)
end
function write_tf_coeffs_layer(this, Cftn, freq_hz, tf_attrs, layerOpt)
% Cftn: (F,T,N) complex single/double
if nargin < 5 || isempty(layerOpt), layerOpt = this.get_default_layer(); end
L = numel(h5read(this.fn,'/axes/layer_id'));
% ensure (and if needed, init) the big arrays using write_tf_coeffs once,
% then write a hyperslab at [layerOpt,:,:,:]
% (for brevity not shown here; use h5write with Start=[layerOpt 1 1 1], Count=[1 F T N])
end

    function report = validate(this)
      report = bct.internal.Validator.validateAll(this.fn, this.schema);
    end
  end
 methods (Static)
  function obj = fromAdjacency(A, coords)
    obj = bct.bct();

    obj.cache.A = bct.cleanAdj(A);   % internal structural adjacency
    N_val = size(obj.cache.A,1);
    
    % Create Manifold object
    obj.Manifold = bct.manifold.Manifold(obj.cache.A);
    
    % Set deprecated property for backward compatibility
    obj.N = N_val;

    if nargin>1 && ~isempty(coords)
      obj.cache.Vertices = double(coords);
    end
  end

  function obj = fromEdges(E, N, coords, w)
    obj = bct.bct();

    E = bct.cleanEdges(E);
    if nargin<2 || isempty(N), N = max(E(:)); end
    N_val = double(N);
    
    obj.cache.E = int32(E);

    if nargin>4 && ~isempty(w), obj.cache.w = double(w(:)); end

    % Seed structural adjacency from edges (undirected)
    A = sparse(E(:,1),E(:,2),true,N_val,N_val);
    A = A + A.';  A = A - diag(diag(A));
    obj.cache.A = spones(A)>0;
    
    % Create Manifold object
    obj.Manifold = bct.manifold.Manifold(obj.cache.A);
    
    % Set deprecated property for backward compatibility
    obj.N = N_val;

    if nargin>2 && ~isempty(coords)
      obj.cache.Vertices = double(coords);
    end
  end

  function obj = fromMesh(V,F)
    obj = bct.bct();

    % Create Manifold object for topology/geometry
    obj.Manifold = bct.manifold.Manifold(double(V), int32(F));
    
    % Set deprecated properties for backward compatibility
    obj.N = size(V,1);
    obj.F = size(F,1);
  end
end
% Signal management methods
methods
  function addSignal(this, signal_obj)
    % Add a Signal object to the Signals array
    %
    %   B.addSignal(signal_obj) adds a bct.signal.Signal object
    %
    %   The signal dimensions are validated against B.Manifold
    
    % Validate input
    if ~isa(signal_obj, 'bct.signal.Signal')
      error('bct:InvalidSignalType', ...
        'Input must be a bct.signal.Signal object');
    end
    
    % Validate signal matches manifold
    this.validateSignalDimensions(signal_obj);
    
    % Add to array
    if isempty(this.Signals)
      this.Signals = signal_obj;
    else
      this.Signals(end+1) = signal_obj;
    end
  end
  
  function removeSignal(this, index_or_label)
    % Remove a signal by index or label
    %
    %   B.removeSignal(idx) removes signal at index idx
    %   B.removeSignal('label') removes signal with matching label
    
    if isempty(this.Signals)
      warning('bct:NoSignals', 'No signals to remove');
      return;
    end
    
    if isnumeric(index_or_label)
      idx = index_or_label;
      if idx < 1 || idx > length(this.Signals)
        error('bct:SignalIndexOutOfRange', ...
          'Signal index %d out of range (1-%d)', idx, length(this.Signals));
      end
    else
      % Find by label
      labels = arrayfun(@(s) s.Label, this.Signals);
      idx = find(labels == string(index_or_label), 1);
      if isempty(idx)
        error('bct:SignalLabelNotFound', ...
          'Signal with label "%s" not found', string(index_or_label));
      end
    end
    
    % Remove from array
    this.Signals(idx) = [];
  end
  
  function sig = getSignalByLabel(this, label)
    % Get signal object by label
    %
    %   sig = B.getSignalByLabel('label') returns the first Signal
    %   with matching label, or empty if not found
    
    if isempty(this.Signals)
      sig = bct.signal.Signal.empty();
      return;
    end
    
    labels = arrayfun(@(s) s.Label, this.Signals);
    idx = find(labels == string(label), 1);
    
    if isempty(idx)
      sig = bct.signal.Signal.empty();
    else
      sig = this.Signals(idx);
    end
  end
  
  function clearSignalsNew(this)
    % Clear all Signal objects
    %
    %   B.clearSignalsNew() removes all signals from B.Signals
    
    this.Signals = bct.signal.Signal.empty();
  end
  
  function validateSignalDimensions(this, signal_obj)
    % Validate that signal dimensions match manifold
    %
    %   B.validateSignalDimensions(signal_obj)
    %
    %   Checks that signal.N matches B.Manifold.N and if signal is
    %   dynamic, that signal.T matches B.Manifold.Time.T
    
    if isempty(this.Manifold)
      error('bct:NoManifold', ...
        'BCT object must have a Manifold before adding signals');
    end
    
    % Check spatial dimensions
    if signal_obj.N ~= this.Manifold.N
      error('bct:SignalDimensionMismatch', ...
        'Signal N (%d) does not match Manifold.N (%d)', ...
        signal_obj.N, this.Manifold.N);
    end
    
    % Check temporal dimensions if signal is dynamic
    if signal_obj.IsDynamic
      if isempty(this.Manifold.Time)
        error('bct:NoManifoldTime', ...
          'Dynamic signal requires Manifold.Time to be set');
      end
      if signal_obj.T ~= this.Manifold.Time.T
        error('bct:SignalDimensionMismatch', ...
          'Signal T (%d) does not match Manifold.Time.T (%d)', ...
          signal_obj.T, this.Manifold.Time.T);
      end
    end
  end
  
  function buildSpectralGrid(this, lambda_band, opts)
    % buildSpectralGrid - Construct joint mesh-time spectral grid
    %
    % Builds a 2D spectral grid combining spatial eigenvalues (from
    % Manifold.meshFourier) with temporal axis (from Time object) for
    % joint mesh-time spectral analysis.
    %
    % Syntax:
    %   B.buildSpectralGrid(lambda_band)
    %   B.buildSpectralGrid(lambda_band, opts)
    %
    % Inputs:
    %   lambda_band - [lambda_min lambda_max] frequency band for eigenvalues
    %                 or vector of specific eigenvalues to use
    %   opts        - (optional) Structure with fields:
    %                 .numModes - Number of modes to compute (if lambda_band is range)
    %                             Default: min(200, NumVertices-1)
    %
    % The spectral grid is stored in B.SpectralGrid with fields:
    %   lambda_grid - [numModes × T] grid of eigenvalues
    %   t_grid      - [numModes × T] grid of time points
    %   lambda_band - [numModes × 1] vector of eigenvalues used
    %   t           - [T × 1] time vector (0:T-1)/fs
    %
    % Example:
    %   % Build grid for eigenvalue band [0.1, 10] Hz
    %   B.buildSpectralGrid([0.1, 10]);
    %   
    %   % Access the grid
    %   lambda_grid = B.SpectralGrid.lambda_grid;
    %   t_grid = B.SpectralGrid.t_grid;
    %
    % See also: bct.manifold.Manifold.meshFourier, bct.manifold.Time
    
    % Validate prerequisites
    if isempty(this.Manifold)
      error('bct:NoManifold', 'Manifold must be set before building spectral grid');
    end
    if this.Manifold.Type ~= "mesh"
      error('bct:InvalidManifoldType', 'SpectralGrid requires mesh manifold');
    end
    if isempty(this.Time) || isempty(this.Time.T) || isempty(this.Time.fs)
      error('bct:NoTime', 'Time object must be set with T and fs before building spectral grid');
    end
    
    % Parse inputs
    if nargin < 3, opts = struct(); end
    if ~isfield(opts, 'numModes')
      opts.numModes = min(200, this.Manifold.N - 1);
    end
    
    % Get eigenvalues from Manifold
    if numel(lambda_band) == 2
      % Band specified as [lambda_min, lambda_max]
      % Use meshFourier with band filtering
      meshOpts = struct();
      meshOpts.lambda_low = lambda_band(1);
      meshOpts.lambda_high = lambda_band(2);
      meshOpts.sigma = mean(lambda_band);
      meshOpts.mode = 'smallestabs';
      
      [~, lambda_vec] = this.Manifold.meshFourier(opts.numModes, meshOpts);
    else
      % Specific eigenvalues provided
      lambda_vec = lambda_band(:);
    end
    
    % Build time vector
    T_val = this.Time.T;
    fs_val = this.Time.fs;
    t = (0:T_val-1)' / fs_val;  % Column vector [T × 1]
    
    % Build joint spectral grid using ndgrid
    % ndgrid creates grids where rows vary along first dimension (lambda)
    % and columns vary along second dimension (time)
    [lambda_grid, t_grid] = ndgrid(lambda_vec, t);
    
    % Store in SpectralGrid property
    this.SpectralGrid.lambda_grid = lambda_grid;  % [numModes × T]
    this.SpectralGrid.t_grid = t_grid;            % [numModes × T]
    this.SpectralGrid.lambda_band = lambda_vec;   % [numModes × 1]
    this.SpectralGrid.t = t;                      % [T × 1]
    
    % Display info
    fprintf('[bct] Built spectral grid: %d modes × %d time points\n', ...
      length(lambda_vec), T_val);
    fprintf('[bct] Eigenvalue range: [%.4f, %.4f]\n', ...
      min(lambda_vec), max(lambda_vec));
    fprintf('[bct] Time range: [%.4f, %.4f] s\n', t(1), t(end));
  end
  
  function clearSpectralGrid(this)
    % clearSpectralGrid - Clear the spectral grid
    %
    %   B.clearSpectralGrid() removes the stored spectral grid
    
    this.SpectralGrid = struct('lambda_grid', [], 't_grid', [], 'lambda_band', [], 't', []);
  end
  
  function tf = hasSpectralGrid(this)
    % hasSpectralGrid - Check if spectral grid has been built
    %
    %   tf = B.hasSpectralGrid() returns true if spectral grid exists
    
    tf = ~isempty(this.SpectralGrid.lambda_grid) && ...
         ~isempty(this.SpectralGrid.t_grid);
  end
end

methods (Access=private)
  function A = i_need_A(this)
    if isfield(this.cache,'A'), A = this.cache.A; return; end

    % Prefer file-backed W if present (build structure from it)
    try
      G = this.read_graph_gsp();
      if ~isempty(G) && isfield(G,'W') && ~isempty(G.W)
        A = spones(0.5*(G.W+G.W.'))>0;
        A = A - diag(diag(A));
        this.cache.A = A; return;
      end
    catch, end

    if isfield(this.cache,'W')
      A = spones(0.5*(this.cache.W + this.cache.W.'))>0;
      A = A - diag(diag(A));
      this.cache.A = A; return;
    end

    if isfield(this.cache,'E')
      N = this.N; E = this.cache.E;
      A = sparse(E(:,1),E(:,2),true,N,N); A = A + A.'; A = A - diag(diag(A));
      this.cache.A = spones(A)>0; return;
    end

    F = this.Faces;
    if ~isempty(F)
      e = unique(sort([F(:,[1 2]); F(:,[2 3]); F(:,[3 1])],2),'rows');
      N = max(F(:));
      A = sparse(e(:,1),e(:,2),true,N,N); A = A + A.'; A = A - diag(diag(A));
      this.cache.A = spones(A)>0; return;
    end

    A = sparse(this.N,this.N); this.cache.A = A;
  end
end

methods (Static)
  function A = cleanAdj(A)
    if ~issparse(A), A = sparse(A); end
    A = (A|A.'); A = A - diag(diag(A));
    A = spones(A)>0;
  end
  function E = cleanEdges(E)
    E = double(E); if size(E,2)>2, E = E(:,1:2); end
    E = sort(E,2); E(E(:,1)==E(:,2),:) = [];
    E = unique(E,'rows');
  end
end

end
