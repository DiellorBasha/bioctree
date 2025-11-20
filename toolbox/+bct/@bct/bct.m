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
    % Fundamental Axis objects (used internally by filters and transforms)
    % Filters are always defined on Lambda (manifold) and Omega (temporal)
    AxisTime bct.resolution.Axis = bct.resolution.Axis.empty()      % Time axis (seconds)
    AxisOmega bct.resolution.Axis = bct.resolution.Axis.empty()     % Angular frequency (rad/s) - fundamental for filters
    AxisVertices bct.resolution.Axis = bct.resolution.Axis.empty()  % Vertex indices (1:N)
    AxisLambda bct.resolution.Axis = bct.resolution.Axis.empty()    % Eigenvalue axis - fundamental for filters
    
    % Derived scale axes (for human-readable interactions and visualization)
    AxisFrequency bct.resolution.Axis = bct.resolution.Axis.empty()      % Frequency (Hz) - derived from Omega
    AxisTemporalScale bct.resolution.Axis = bct.resolution.Axis.empty()  % Temporal scale (seconds) - derived from Omega
    AxisWavelength bct.resolution.Axis = bct.resolution.Axis.empty()     % Spatial wavelength (mm) - derived from Lambda
    AxisSpatialScale bct.resolution.Axis = bct.resolution.Axis.empty()   % Spatial scale (mm) - derived from Lambda
    
    % Joint mesh-time spectral grid
    % Built from Lambda and Omega axes using meshgrid(lambda, omega)
    % Access as: B.SpectralGrid.lambda_grid, B.SpectralGrid.omega_grid
    SpectralGrid struct = struct('lambda_grid', [], 'omega_grid', [], 'lambda_band', [], 'omega', [])
    
    % Filterbank - collection of designed filters
    % Array of bct.filters.Filter or bct.filters.JointFilter objects
    % Access as: B.Filterbank(i) or B.getFilter(label)
    Filterbank = []
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
      if isempty(this.Time)
        error('bct:NoTime', ...
          'Dynamic signal requires Time to be set');
      end
      if signal_obj.T ~= this.Time.T
        error('bct:SignalDimensionMismatch', ...
          'Signal T (%d) does not match Time.T (%d)', ...
          signal_obj.T, this.Time.T);
      end
    end
  end
  
  function initializeAxes(this)
    % initializeAxes - Create fundamental and derived Axis objects
    %
    % Creates all Axis objects needed for Bct workflows:
    %   Fundamental: Time, Omega, Vertices, Lambda
    %   Derived: Frequency, TemporalScale, Wavelength, SpatialScale
    %
    % Syntax:
    %   B.initializeAxes()
    %
    % Note: Requires Manifold and Time to be set with Resolution
    
    % Validate prerequisites
    if isempty(this.Manifold)
      error('bct:NoManifold', 'Manifold must be set before initializing axes');
    end
    if isempty(this.Time)
      error('bct:NoTime', 'Time must be set before initializing axes');
    end
    
    % Fundamental axes
    this.AxisTime = bct.resolution.Axis.time(this.Time);
    this.AxisVertices = bct.resolution.Axis.vertex(this.Manifold);
    
    % Spectral axes require Resolution
    if ~isempty(this.Manifold.Resolution)
      this.AxisLambda = bct.resolution.Axis.lambda(this.Manifold.Resolution);
      this.AxisWavelength = bct.resolution.Axis.wavelength(this.Manifold.Resolution);
      this.AxisSpatialScale = bct.resolution.Axis.scale(this.Manifold.Resolution);
    end
    
    if ~isempty(this.Time.Resolution)
      this.AxisOmega = bct.resolution.Axis.omega(this.Time);
      this.AxisFrequency = bct.resolution.Axis.frequency(this.Time);
      % Temporal scale: s = 1/omega (approximately)
      omega_vals = this.AxisOmega.Values;
      temporal_scale = 1 ./ (omega_vals + eps);  % Avoid division by zero
      this.AxisTemporalScale = bct.resolution.Axis('TemporalScale', temporal_scale, 'Temporal Scale', 's');
    end
    
    fprintf('[bct] Initialized Axis objects\n');
  end
  
  function buildSpectralGrid(this, lambda_band, opts)
    % buildSpectralGrid - Construct joint mesh-time spectral grid
    %
    % Builds a 2D spectral grid combining Lambda and Omega axes using
    % meshgrid(lambda, omega). This is the fundamental grid for joint
    % spectral-temporal analysis.
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
    %   lambda_grid - [T × K] grid of eigenvalues (from meshgrid)
    %   omega_grid  - [T × K] grid of angular frequencies (from meshgrid)
    %   lambda_band - [K × 1] vector of eigenvalues used
    %   omega       - [T × 1] angular frequency vector (rad/s)
    %
    % Example:
    %   % Build grid for eigenvalue band [0.1, 10]
    %   B.buildSpectralGrid([0.1, 10]);
    %   
    %   % Access the grid
    %   lambda_grid = B.SpectralGrid.lambda_grid;
    %   omega_grid = B.SpectralGrid.omega_grid;
    %
    % See also: bct.manifold.Manifold.meshFourier, initializeAxes
    
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
    
    % Initialize axes if not already done
    if isempty(this.AxisLambda) || isempty(this.AxisOmega)
      this.initializeAxes();
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
    
    % Get omega vector from Time Resolution
    omega_vec = this.AxisOmega.Values;  % Angular frequency (rad/s)
    
    % Build joint spectral grid using meshgrid(lambda, omega)
    % meshgrid creates grids where:
    %   - rows correspond to different omega values (temporal)
    %   - columns correspond to different lambda values (spatial)
    [lambda_grid, omega_grid] = meshgrid(lambda_vec, omega_vec);
    
    % Store in SpectralGrid property
    this.SpectralGrid.lambda_grid = lambda_grid;  % [T × K]
    this.SpectralGrid.omega_grid = omega_grid;    % [T × K]
    this.SpectralGrid.lambda_band = lambda_vec;   % [K × 1]
    this.SpectralGrid.omega = omega_vec;          % [T × 1]
    
    % Display info
    fprintf('[bct] Built spectral grid: %d omega × %d lambda points\n', ...
      length(omega_vec), length(lambda_vec));
    fprintf('[bct] Lambda range: [%.4f, %.4f]\n', ...
      min(lambda_vec), max(lambda_vec));
    fprintf('[bct] Omega range: [%.4f, %.4f] rad/s\n', omega_vec(1), omega_vec(end));
  end
  
  function clearSpectralGrid(this)
    % clearSpectralGrid - Clear the spectral grid
    %
    %   B.clearSpectralGrid() removes the stored spectral grid
    
    this.SpectralGrid = struct('lambda_grid', [], 'omega_grid', [], 'lambda_band', [], 'omega', []);
  end
  
  function tf = hasSpectralGrid(this)
    % hasSpectralGrid - Check if spectral grid has been built
    %
    %   tf = B.hasSpectralGrid() returns true if spectral grid exists
    
    tf = ~isempty(this.SpectralGrid.lambda_grid) && ...
         ~isempty(this.SpectralGrid.omega_grid);
  end
  
  %% Filter design and management methods
  
  function filt = designFilter(this, range, quantity, kernelType, varargin)
    % designFilter - Design a spatial filter using spectral quantity
    %
    % Syntax:
    %   filt = B.designFilter(range, quantity, kernelType)
    %   filt = B.designFilter(range, quantity, kernelType, 'param', value, ...)
    %
    % Inputs:
    %   range      - [low, high] spectral range
    %   quantity   - Spectral quantity type:
    %                'lambda'      - Eigenvalue λ
    %                'wavelength'  - Spatial wavelength L (mm)
    %                'wavenumber'  - Wavenumber k (rad/mm)
    %                'freq'        - Spatial frequency f (cycles/mm)
    %   kernelType - Filter kernel: 'ideal', 'band', 'heat', 'mexican_hat'
    %
    % Parameters:
    %   'label'  - String label for filter (optional)
    %   'add'    - Add to Filterbank (default: true)
    %   Additional kernel-specific parameters (see bct.filters.Filter.design)
    %
    % Returns:
    %   filt - bct.filters.Filter object
    %
    % Example:
    %   % Design bandpass for 5-50mm wavelengths
    %   filt = B.designFilter([5, 50], 'wavelength', 'band', 'taper', 'hann');
    %   
    %   % Design heat diffusion filter
    %   filt = B.designFilter([0.01, 1], 'lambda', 'heat', 'time', 0.5);
    %   
    %   % Design using wavenumber
    %   filt = B.designFilter([0.1, 2], 'wavenumber', 'band');
    %
    % See also: designJointFilter, bct.filters.Filter, bct.resolution.Quantity
    
    % Validate manifold
    if isempty(this.Manifold)
      error('bct:NoManifold', 'Manifold must be set before designing filters');
    end
    
    % Parse optional parameters
    p = inputParser;
    p.KeepUnmatched = true;
    addParameter(p, 'label', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'add', true, @islogical);
    parse(p, varargin{:});
    
    filter_label = string(p.Results.label);
    add_to_bank = p.Results.add;
    
    % Convert quantity string to enum
    quantity_enum = this.convertQuantityString(quantity);
    
    % Create filter
    filt = bct.filters.Filter(this.Manifold);
    
    % Set band using quantity
    filt.setBand(range, quantity_enum);
    
    % Design kernel with remaining parameters
    kernel_params = [fieldnames(p.Unmatched), struct2cell(p.Unmatched)]';
    filt.design(kernelType, kernel_params{:});
    
    % Add label if provided
    if ~isempty(filter_label)
      filt.KernelParams.label = filter_label;
    end
    
    % Add to filterbank if requested
    if add_to_bank
      this.addFilter(filt, filter_label);
    end
  end
  
  function filt = designJointFilter(this, spatial_range, spatial_quantity, temporal_range, temporal_quantity, varargin)
    % designJointFilter - Design a joint mesh-time filter
    %
    % Syntax:
    %   filt = B.designJointFilter(spatial_range, spatial_quantity, temporal_range, temporal_quantity)
    %   filt = B.designJointFilter(..., 'param', value, ...)
    %
    % Inputs:
    %   spatial_range    - [low, high] spatial spectral range
    %   spatial_quantity - 'lambda', 'wavelength', 'wavenumber', 'freq'
    %   temporal_range   - [low, high] temporal spectral range
    %   temporal_quantity - 'frequency', 'period'
    %
    % Parameters:
    %   'type'   - Joint filter type: 'diffusion', 'wave', 'separable'
    %            Default: 'diffusion'
    %   'label'  - String label for filter
    %   'add'    - Add to Filterbank (default: true)
    %   Additional design-specific parameters
    %
    % Returns:
    %   filt - bct.filters.JointFilter object
    %
    % Example:
    %   % Diffusion filter: 10-50mm wavelength, 8-12 Hz
    %   filt = B.designJointFilter([10, 50], 'wavelength', [8, 12], 'frequency', ...
    %       'type', 'diffusion', 'label', 'alpha_band');
    %   
    %   % Wave filter using wavenumber
    %   filt = B.designJointFilter([0.1, 1], 'wavenumber', [5, 15], 'frequency', ...
    %       'type', 'wave', 'velocity', 5);
    %
    % See also: designFilter, bct.filters.design.diffusion, bct.filters.design.wave
    
    % Validate manifold and time
    if isempty(this.Manifold)
      error('bct:NoManifold', 'Manifold must be set before designing joint filters');
    end
    if isempty(this.Time)
      error('bct:NoTime', 'Time must be set before designing joint filters');
    end
    
    % Parse parameters
    p = inputParser;
    p.KeepUnmatched = true;
    addParameter(p, 'type', 'diffusion', @(x) ischar(x) || isstring(x));
    addParameter(p, 'label', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'add', true, @islogical);
    parse(p, varargin{:});
    
    filter_type = string(p.Results.type);
    filter_label = string(p.Results.label);
    add_to_bank = p.Results.add;
    
    % Convert spatial range to lambda
    spatial_quantity_enum = this.convertQuantityString(spatial_quantity);
    lambda_range = this.convertToLambda(spatial_range, spatial_quantity_enum);
    
    % Convert temporal range to frequency (Hz)
    temporal_quantity_enum = this.convertQuantityString(temporal_quantity);
    freq_range = this.convertToFrequency(temporal_range, temporal_quantity_enum);
    
    % Call appropriate design function
    design_params = [fieldnames(p.Unmatched), struct2cell(p.Unmatched)]';
    
    switch lower(filter_type)
      case 'diffusion'
        filt = bct.filters.design.diffusion(this, ...
          'lambda_band', lambda_range, ...
          'freq_band', freq_range, ...
          design_params{:});
          
      case 'wave'
        filt = bct.filters.design.wave(this, ...
          'lambda_band', lambda_range, ...
          'freq_band', freq_range, ...
          design_params{:});
          
      case 'separable'
        filt = bct.filters.design.separable(this, ...
          'lambda_band', lambda_range, ...
          'freq_band', freq_range, ...
          design_params{:});
          
      otherwise
        error('bct:UnknownFilterType', 'Unknown joint filter type: %s', filter_type);
    end
    
    % Add label if provided
    if ~isempty(filter_label) && isfield(filt, 'KernelParams')
      filt.KernelParams.label = filter_label;
    end
    
    % Add to filterbank if requested
    if add_to_bank
      this.addFilter(filt, filter_label);
    end
  end
  
  function addFilter(this, filt, label)
    % addFilter - Add filter to filterbank
    %
    %   B.addFilter(filt) adds filter to filterbank
    %   B.addFilter(filt, label) adds with a label
    %
    % Inputs:
    %   filt  - bct.filters.Filter or bct.filters.JointFilter object
    %   label - Optional string label
    
    if nargin < 3, label = ''; end
    label = string(label);
    
    % Add label to filter params if provided
    if ~isempty(label) && isfield(filt, 'KernelParams')
      filt.KernelParams.label = label;
    end
    
    % Initialize filterbank if empty
    if isempty(this.Filterbank)
      this.Filterbank = filt;
    else
      this.Filterbank(end+1) = filt;
    end
    
    fprintf('[bct] Added filter to filterbank (index: %d', length(this.Filterbank));
    if ~isempty(label)
      fprintf(', label: "%s"', label);
    end
    fprintf(')\n');
  end
  
  function filt = getFilter(this, identifier)
    % getFilter - Retrieve filter from filterbank
    %
    %   filt = B.getFilter(index) gets filter by index
    %   filt = B.getFilter(label) gets filter by label
    %
    % Inputs:
    %   identifier - Integer index or string label
    %
    % Returns:
    %   filt - bct.filters.Filter or bct.filters.JointFilter object
    
    if isempty(this.Filterbank)
      error('bct:EmptyFilterbank', 'Filterbank is empty');
    end
    
    if isnumeric(identifier)
      % Get by index
      idx = round(identifier);
      if idx < 1 || idx > length(this.Filterbank)
        error('bct:FilterIndexOutOfRange', ...
          'Filter index %d out of range [1, %d]', idx, length(this.Filterbank));
      end
      filt = this.Filterbank(idx);
    else
      % Get by label
      label = string(identifier);
      found = false;
      for i = 1:length(this.Filterbank)
        if isfield(this.Filterbank(i).KernelParams, 'label') && ...
           this.Filterbank(i).KernelParams.label == label
          filt = this.Filterbank(i);
          found = true;
          break;
        end
      end
      if ~found
        error('bct:FilterNotFound', 'No filter with label "%s" found', label);
      end
    end
  end
  
  function removeFilter(this, identifier)
    % removeFilter - Remove filter from filterbank
    %
    %   B.removeFilter(index) removes filter by index
    %   B.removeFilter(label) removes filter by label
    %
    % Inputs:
    %   identifier - Integer index or string label
    
    if isempty(this.Filterbank)
      warning('bct:EmptyFilterbank', 'Filterbank is already empty');
      return;
    end
    
    if isnumeric(identifier)
      % Remove by index
      idx = round(identifier);
      if idx < 1 || idx > length(this.Filterbank)
        error('bct:FilterIndexOutOfRange', ...
          'Filter index %d out of range [1, %d]', idx, length(this.Filterbank));
      end
      this.Filterbank(idx) = [];
    else
      % Remove by label
      label = string(identifier);
      found = false;
      for i = 1:length(this.Filterbank)
        if isfield(this.Filterbank(i).KernelParams, 'label') && ...
           this.Filterbank(i).KernelParams.label == label
          this.Filterbank(i) = [];
          found = true;
          break;
        end
      end
      if ~found
        error('bct:FilterNotFound', 'No filter with label "%s" found', label);
      end
    end
    
    fprintf('[bct] Removed filter from filterbank\n');
  end
  
  function clearFilterbank(this)
    % clearFilterbank - Remove all filters from filterbank
    %
    %   B.clearFilterbank() removes all filters
    
    this.Filterbank = [];
    fprintf('[bct] Filterbank cleared\n');
  end
  
  function listFilters(this)
    % listFilters - Display all filters in filterbank
    %
    %   B.listFilters() prints a summary of all filters
    
    if isempty(this.Filterbank)
      fprintf('Filterbank is empty\n');
      return;
    end
    
    fprintf('\nFilterbank contains %d filter(s):\n', length(this.Filterbank));
    fprintf('%-5s %-15s %-20s %-30s\n', 'Index', 'Label', 'Type', 'Band');
    fprintf('%s\n', repmat('-', 1, 70));
    
    for i = 1:length(this.Filterbank)
      filt = this.Filterbank(i);
      
      % Get label
      if isfield(filt.KernelParams, 'label')
        label_str = char(filt.KernelParams.label);
      else
        label_str = '-';
      end
      
      % Get type
      if isprop(filt, 'KernelType') && ~isempty(filt.KernelType)
        type_str = char(filt.KernelType);
      else
        type_str = class(filt);
      end
      
      % Get band
      if isprop(filt, 'lambda_band') && ~isempty(filt.lambda_band)
        band_str = sprintf('[%.4f, %.4f]', filt.lambda_band(1), filt.lambda_band(2));
      else
        band_str = '-';
      end
      
      fprintf('%-5d %-15s %-20s %-30s\n', i, label_str, type_str, band_str);
    end
    fprintf('\n');
  end
  
  %% Signal synthesis methods
  
  function Synthesize(this, filter_identifier, varargin)
    % Synthesize - Generate spectral coefficients based on filter specifications
    %
    % Syntax:
    %   B.Synthesize(filter_identifier)
    %   B.Synthesize(filter_identifier, 'param', value, ...)
    %
    % Inputs:
    %   filter_identifier - Filter index or label from Filterbank
    %
    % Parameters:
    %   'numModes'    - Number of spatial modes (default: auto from filter band)
    %   'envelope'    - Temporal envelope type: 'none', 'gaussian' (default: 'none')
    %   't0'          - Center time for envelope in seconds (default: mid-point)
    %   'sigma_t'     - Temporal spread for Gaussian envelope (default: T/6)
    %   'velocity'    - Traveling wave velocity in mm/s (default: 0 = standing)
    %   'direction'   - Wave direction [x y z] (default: [1 0 0])
    %
    % Description:
    %   Generates joint spectral coefficients A_kl [K × T] in the SpectralGrid
    %   based on the filter's spectral band. The coefficients are created with
    %   random phases and power distributed according to the filter kernel.
    %   
    %   For spatial filters: Uses filter.lambda_band to determine spatial modes
    %   For joint filters: Uses both spatial and temporal bands
    %
    % Example:
    %   % Design filter and synthesize
    %   B.designFilter([10, 50], 'wavelength', 'band', 'label', 'alpha');
    %   B.Synthesize('alpha', 'envelope', 'gaussian', 't0', 0.5);
    %   
    %   % Synthesize with traveling wave
    %   B.Synthesize(1, 'velocity', 5, 'direction', [1 0 0]);
    %
    % See also: Generate, designFilter, buildSpectralGrid
    
    % Validate prerequisites
    if isempty(this.Manifold)
      error('bct:NoManifold', 'Manifold must be set before synthesis');
    end
    if isempty(this.Filterbank)
      error('bct:NoFilters', 'Filterbank is empty. Design a filter first.');
    end
    
    % Get filter
    filt = this.getFilter(filter_identifier);
    
    % Detect if this is a spatial-only filter or joint filter
    is_joint_filter = isa(filt, 'bct.filters.JointFilter');
    has_temporal_band = isprop(filt, 'freq_band') && ~isempty(filt.freq_band);
    is_spatial_only = ~is_joint_filter && ~has_temporal_band;
    
    % Validate Time only if needed for temporal filters
    if ~is_spatial_only
      if isempty(this.Time) || isempty(this.Time.T) || isempty(this.Time.fs)
        error('bct:NoTime', 'Time must be set for joint or temporal filters');
      end
    end
    
    % Parse parameters
    p = inputParser;
    addParameter(p, 'numModes', [], @isnumeric);
    addParameter(p, 'envelope', 'none', @(x) ischar(x) || isstring(x));
    addParameter(p, 't0', [], @isnumeric);
    addParameter(p, 'sigma_t', [], @isnumeric);
    addParameter(p, 'velocity', 0, @isnumeric);
    addParameter(p, 'direction', [1 0 0], @isnumeric);
    parse(p, varargin{:});
    
    % Extract parameters
    envelope_type = string(p.Results.envelope);
    velocity = p.Results.velocity;
    direction = p.Results.direction(:)' / norm(p.Results.direction);
    
    % Get dimensions based on filter type
    if is_spatial_only
      T = 1;  % Spatial-only: single "time" point
      fs = 1; % Dummy sampling rate
    else
      T = this.Time.T;
      fs = this.Time.fs;
    end
    
    % Determine spatial modes from filter
    if isprop(filt, 'lambda_band') && ~isempty(filt.lambda_band)
      lambda_band = filt.lambda_band;
    else
      error('bct:NoLambdaBand', 'Filter must have lambda_band property');
    end
    
    % Determine number of modes
    if isempty(p.Results.numModes)
      % Auto-select modes within the filter band
      all_lambda = this.Manifold.Eigenvalues;
      mode_mask = all_lambda >= lambda_band(1) & all_lambda <= lambda_band(2);
      numModes = sum(mode_mask);
      if numModes == 0
        numModes = min(50, length(all_lambda));
        warning('bct:NoModesInBand', ...
          'No modes in filter band [%.4f, %.4f]. Using %d modes.', ...
          lambda_band(1), lambda_band(2), numModes);
      end
    else
      numModes = p.Results.numModes;
    end
    
    % Build spectral grid with filter's lambda band
    this.buildSpectralGrid(lambda_band, struct('numModes', numModes));
    
    % Get eigendecomposition
    U = this.Manifold.Eigenvectors;
    lambda_vec = this.SpectralGrid.lambda_band;  % [K × 1]
    K = length(lambda_vec);
    
    % Compute spatial frequency (cycles/mm)
    f_space = sqrt(lambda_vec) / (2*pi);
    
    % Compute temporal frequencies (Hz)
    f_time = (0:T-1)' * (fs/T);
    
    % Get filter power in spatial domain using filter's response
    if isa(filt, 'bct.filters.Filter')
      % Spatial filter: evaluate g(λ) at actual eigenvalues returned
      g_vals = filt.getResponse(lambda_vec);  % [K × 1]
      P_space = abs(g_vals).^2;  % Power from filter response
      
      % Check if filter response is too weak (most values near zero)
      if sum(P_space > max(P_space)*0.01) < max(5, K*0.1)
        warning('bct:WeakFilterResponse', ...
          'Filter response is weak at actual eigenvalues. Only %d/%d modes have significant power.\n%s', ...
          sum(P_space > max(P_space)*0.01), K, ...
          'Consider: (1) Wider lambda band, or (2) Using "ideal" kernel instead of "band" taper.');
      end
    elseif isa(filt, 'bct.filters.JointFilter')
      % Joint filter: evaluate spatial kernel
      if ~isempty(filt.psi_mesh)
        psi_vals = filt.psi_mesh(lambda_vec);
        P_space = abs(psi_vals).^2;
      else
        P_space = ones(K, 1);
      end
    else
      % Fallback: uniform power
      P_space = ones(K, 1);
    end
    
    % Normalize spatial power to sum to 1
    P_space = P_space(:) / sum(P_space);
    
    if is_spatial_only
      % Spatial-only: use random signs (±1) for real signals
      % This creates a real-valued signal with proper spatial structure
      sgn = sign(randn(K, T));  % Random ±1
      A_kl = sgn .* sqrt(P_space);  % [K × 1] real coefficients
    else
      % Joint/temporal filters: create spatiotemporal spectrum
      
      % Temporal power
      if isa(filt, 'bct.filters.JointFilter') && ~isempty(filt.phi_time)
        % Evaluate temporal kernel
        t_vec = (0:T-1)' / fs;
        phi_vals = filt.phi_time(t_vec);
        P_time = abs(phi_vals).^2;
      elseif isprop(filt, 'freq_band') && ~isempty(filt.freq_band)
        % Bandpass in temporal frequency
        freq_band = filt.freq_band;
        P_time = double(f_time >= freq_band(1) & f_time <= freq_band(2));
      else
        % Uniform temporal power
        P_time = ones(T, 1);
      end
      
      % Normalize temporal power
      P_time = P_time(:) / sum(P_time);
      
      % Joint power spectrum: outer product [K × T]
      P_joint = P_space(:) * P_time(:)';
      
      % Random phases for complex coefficients
      phase_kl = rand(K, T) * 2*pi;
      A_kl = sqrt(P_joint) .* exp(1i * phase_kl);
    end
    
    % Apply temporal envelope
    t = (0:T-1)/fs;
    if strcmpi(envelope_type, 'gaussian')
      t0 = p.Results.t0;
      if isempty(t0), t0 = t(end)/2; end
      
      sigma_t = p.Results.sigma_t;
      if isempty(sigma_t), sigma_t = t(end)/6; end
      
      env_t = exp(-0.5 * ((t - t0) ./ sigma_t).^2);
      A_kl = A_kl .* env_t;
    end
    
    % Apply traveling wave phase shift
    if velocity ~= 0
      % Project vertices onto direction
      V = this.Manifold.V;
      xcoords = V * direction';  % [N × 1]
      
      % Get mode indices used in SpectralGrid
      [~, mode_idx] = ismember(lambda_vec, this.Manifold.Eigenvalues);
      U_modes = U(:, mode_idx);  % [N × K]
      
      % Spatial phase per mode (approximate)
      U_phase = U_modes' * xcoords;  % [K × 1]
      
      % Apply phase shift: exp(i k·x - i ω t)
      for l = 1:T
        A_kl(:, l) = A_kl(:, l) .* exp(1i * U_phase(:) * (2*pi*f_time(l)/velocity));
      end
    end
    
    % Store coefficients in SpectralGrid
    this.SpectralGrid.coeffs = A_kl;  % [K × T]
    
    % Store metadata
    this.SpectralGrid.filter_used = filter_identifier;
    this.SpectralGrid.synthesis_params = p.Results;
    
    fprintf('[bct] Synthesized spectral coefficients: %d modes × %d time points\n', K, T);
    fprintf('[bct] Spatial band: [%.4f, %.4f] eigenvalues\n', lambda_band(1), lambda_band(2));
    if isprop(filt, 'freq_band') && ~isempty(filt.freq_band)
      fprintf('[bct] Temporal band: [%.2f, %.2f] Hz\n', filt.freq_band(1), filt.freq_band(2));
    end
  end
  
  function sig = Generate(this, varargin)
    % Generate - Reconstruct signal from spectral coefficients
    %
    % Syntax:
    %   sig = B.Generate()
    %   sig = B.Generate('param', value, ...)
    %
    % Parameters:
    %   'label'      - Label for the generated Signal object (default: auto)
    %   'add'        - Add to Signals array (default: true)
    %   'symmetric'  - Use symmetric IFFT for real output (default: true)
    %
    % Returns:
    %   sig - bct.signal.Signal object with reconstructed data [N × T]
    %
    % Description:
    %   Reconstructs spatial-temporal signal from spectral coefficients in
    %   SpectralGrid using inverse graph Fourier transform and inverse FFT.
    %   
    %   Process:
    %   1. Inverse temporal FFT: A_kl [K × T] → A_time [K × T]
    %   2. Graph synthesis: x_wt = U * A_time [N × T]
    %   3. Mass normalization: xrec = M^(1/2) * x_wt
    %
    % Example:
    %   % Complete workflow
    %   B.designFilter([10, 50], 'wavelength', 'band', 'label', 'alpha');
    %   B.Synthesize('alpha', 'envelope', 'gaussian');
    %   sig = B.Generate('label', 'alpha_wave');
    %
    % See also: Synthesize, bct.signal.Signal
    
    % Validate prerequisites
    if ~this.hasSpectralGrid()
      error('bct:NoSpectralGrid', 'SpectralGrid not built. Call Synthesize first.');
    end
    if ~isfield(this.SpectralGrid, 'coeffs') || isempty(this.SpectralGrid.coeffs)
      error('bct:NoCoefficients', 'No spectral coefficients. Call Synthesize first.');
    end
    
    % Parse parameters
    p = inputParser;
    addParameter(p, 'label', '', @(x) ischar(x) || isstring(x));
    addParameter(p, 'add', true, @islogical);
    addParameter(p, 'symmetric', true, @islogical);
    addParameter(p, 'normalize', true, @islogical);  % Unit RMS normalization
    parse(p, varargin{:});
    
    % Extract spectral coefficients
    A_kl = this.SpectralGrid.coeffs;  % [K × T]
    [K, T] = size(A_kl);
    
    % Get eigendecomposition
    lambda_vec = this.SpectralGrid.lambda_band;  % [K × 1]
    [~, mode_idx] = ismember(lambda_vec, this.Manifold.Eigenvalues);
    U = this.Manifold.Eigenvectors(:, mode_idx);  % [N × K]
    
    % Get mass matrix diagonal
    d = diag(this.Manifold.MassMatrix);  % [N × 1]
    N = length(d);
    
    % Reconstruction depends on whether spatial-only or spatiotemporal
    if T == 1
      % Spatial-only: direct reconstruction (no temporal FFT needed)
      % A_kl is already real with random signs from Synthesize
      a = A_kl(:);  % [K × 1] real coefficients
      
      % Reconstruct: xw = U * a
      x_wt = U * a;  % [N × 1]
      
    else
      % Spatiotemporal: inverse temporal FFT then graph synthesis
      
      % Step 1: Inverse temporal FFT on each spatial mode
      if p.Results.symmetric
        A_time = ifft(A_kl, [], 2, 'symmetric');  % [K × T] - real output
      else
        A_time = ifft(A_kl, [], 2);  % [K × T] - complex output
      end
      
      % Step 2: Reconstruct into vertex domain (inverse graph Fourier)
      x_wt = U * A_time;  % [N × T]
    end
    
    % Step 3: Apply M^(+1/2) mass normalization
    S = spdiags(sqrt(d), 0, N, N);
    xrec = S * x_wt;  % [N × T] or [N × 1]
    
    % Step 4: Normalize to unit RMS in M-inner product (optional)
    if p.Results.normalize
      M_diag = spdiags(d, 0, N, N);
      if T == 1
        % Spatial-only: Ex = x' * M * x
        Ex = xrec' * (M_diag * xrec);
      else
        % Spatiotemporal: Ex = sum over time of x(:,t)' * M * x(:,t)
        Ex = sum(sum((M_diag * xrec) .* xrec, 1));
      end
      if Ex > 0
        xrec = xrec / sqrt(Ex);
      end
    end
    
    % For spatial-only filters (T=1), squeeze to [N×1]
    if T == 1
      xrec = xrec(:);  % [N×1] spatial-only signal
    end
    
    % Generate label
    if isempty(p.Results.label)
      if isfield(this.SpectralGrid, 'filter_used')
        label_str = sprintf('generated_%s', string(this.SpectralGrid.filter_used));
      else
        label_str = sprintf('generated_%s', datestr(now, 'HHMMss'));
      end
    else
      label_str = string(p.Results.label);
    end
    
    % Create Signal object (pass Time only for dynamic signals)
    if T == 1
      sig = bct.signal.Signal(this.Manifold, xrec, label_str);  % Spatial-only
    else
      sig = bct.signal.Signal(this.Manifold, xrec, label_str, this.Time);  % Dynamic
    end
    
    % Add to Signals array if requested
    if p.Results.add
      this.addSignal(sig);
    end
    
    if T == 1
      fprintf('[bct] Generated spatial signal "%s": %d vertices\n', label_str, N);
    else
      fprintf('[bct] Generated signal "%s": %d vertices × %d time points\n', label_str, N, T);
    end
    fprintf('[bct] Signal range: [%.4f, %.4f]\n', min(xrec(:)), max(xrec(:)));
  end
end

methods (Access=private)
  % Helper functions for filter design
  
  function quantity_enum = convertQuantityString(~, quantity_str)
    % Convert string to bct.resolution.Quantity enum
    quantity_str = lower(string(quantity_str));
    
    switch quantity_str
      case {'lambda', 'eigenvalue'}
        quantity_enum = bct.resolution.Quantity.lambda;
      case {'wavelength', 'l'}
        quantity_enum = bct.resolution.Quantity.wavelength;
      case {'wavenumber', 'k'}
        quantity_enum = bct.resolution.Quantity.k;
      case {'freq', 'frequency', 'f'}
        quantity_enum = bct.resolution.Quantity.freq;
      case 'period'
        quantity_enum = bct.resolution.Quantity.period;
      otherwise
        error('bct:UnknownQuantity', 'Unknown quantity: %s', quantity_str);
    end
  end
  
  function lambda_range = convertToLambda(this, range, quantity_enum)
    % Convert spectral range to lambda (eigenvalue)
    % Uses Manifold.Resolution if available
    
    % If already lambda, return as-is
    if quantity_enum == bct.resolution.Quantity.lambda
      lambda_range = range;
      return;
    end
    
    % Get Resolution object if available
    if ~isempty(this.Manifold) && isprop(this.Manifold, 'Resolution')
      res = this.Manifold.Resolution;
      
      % Convert using Resolution methods
      switch quantity_enum
        case bct.resolution.Quantity.wavelength
          lambda_range = res.wavelength2lambda(range);
        case bct.resolution.Quantity.k
          lambda_range = res.k2lambda(range);
        case bct.resolution.Quantity.freq
          lambda_range = res.freq2lambda(range);
        otherwise
          error('bct:UnsupportedConversion', ...
            'Cannot convert %s to lambda', string(quantity_enum));
      end
    else
      error('bct:NoResolution', 'Manifold.Resolution not available for conversion');
    end
  end
  
  function freq_range = convertToFrequency(~, range, quantity_enum)
    % Convert temporal range to frequency (Hz)
    
    switch quantity_enum
      case bct.resolution.Quantity.freq
        freq_range = range;
      case bct.resolution.Quantity.period
        % Period to frequency: f = 1/T
        freq_range = 1 ./ fliplr(range);  % Flip to maintain [low, high]
      otherwise
        error('bct:UnsupportedConversion', ...
          'Cannot convert %s to frequency', string(quantity_enum));
    end
  end
  
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
