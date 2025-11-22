classdef bct < handle
  % bct: BioCTree object for brain connectivity analysis
  %
  % Properties:
  %   Manifold - Surface mesh domain (bct.Manifold)
  %   Lambda   - Spectral domain, dual of Manifold (bct.Lambda)
  %   Time     - Temporal domain (bct.Time)
  %   Omega    - Frequency domain, dual of Time (bct.Omega)
  %   Signals  - Array of Signal objects (bct.signal.Signal)
  %   Viewer   - Visualization handle
  
properties (Access=private, Transient)
    cache struct = struct();     % holds legacy A, W, E, mesh, mgraph, gsp, w
end

properties
    % Manifold object encapsulates mesh/graph topology
    % Preferred way to access mesh geometry and topology
    % Access as: B.Manifold.Vertices, B.Manifold.Faces, B.Manifold.Laplacian, etc.
    Manifold bct.Manifold  % New @Manifold domain class
    
    % Time domain - temporal properties for time-varying signals
    % Dual of Omega domain, linked automatically on construction
    % Access as: B.Time.T, B.Time.fs, B.Time.axis, etc.
    Time bct.Time = bct.Time.empty()  % Time domain
    
    % Lambda domain - spectral decomposition of Manifold Laplacian
    % Dual of Manifold domain, linked automatically on construction
    % Stores eigenvalues, eigenvectors from meshFourier
    % Access as: B.Lambda.lambda, B.Lambda.U, B.Lambda.axis, etc.
    Lambda bct.Lambda = bct.Lambda.empty()  % Spectral domain
    
    % Omega domain - temporal frequency spectrum
    % Dual of Time domain, linked automatically on construction
    % Access as: B.Omega.omega, B.Omega.freq, B.Omega.axis, etc.
    Omega bct.Omega = bct.Omega.empty()  % Temporal frequency domain
    
    % Signals defined on the Manifold
    % Can be a single bct.signal.Signal object or an array of Signal objects
    % All signals must have dimensions matching B.Manifold (N and optionally T)
    Signals bct.signal.Signal = bct.signal.Signal.empty()
    
    % Viewer handle for 3D visualization
    % Stores viewer3d handle created by showMesh method
    % Access as: B.Viewer to interact with the visualization
    Viewer = []  % viewer3d handle for visualization
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
    %% -------- Factory methods for creating bct instances
    
  function obj = fromAdjacency(A, coords)
    % Create bct instance from adjacency matrix
    %
    %   B = bct.fromAdjacency(A) creates a bct object from adjacency matrix A
    %   B = bct.fromAdjacency(A, coords) also sets vertex coordinates
    %
    %   Inputs:
    %     A      - [N×N] sparse or full adjacency matrix (undirected)
    %     coords - [N×3] vertex coordinates (optional)
    %
    %   The function creates a graph-based Manifold domain without mesh geometry
    
    obj = bct.bct();
    
    % Clean and store adjacency matrix
    A_clean = bct.cleanAdj(A);
    obj.cache.A = A_clean;
    
    % Create graph Manifold from adjacency matrix
    % Note: bct.Manifold can accept adjacency matrix for graph-based analysis
    graphStruct = struct('A', A_clean);
    
    if nargin > 1 && ~isempty(coords)
      graphStruct.coords = double(coords);
      obj.cache.Vertices = double(coords);
    end
    
    % Create Manifold - will detect graph structure and compute graph Laplacian
    obj.Manifold = bct.Manifold(graphStruct);
    
    % Create Lambda domain (dual of Manifold) using estimated max eigenvalue
    lambda_max_est = obj.Manifold.estimateLambdaMax();
    
    % Create placeholder Lambda with estimated range
    eigenStruct = struct();
    eigenStruct.eigenvalues = linspace(0, lambda_max_est, 100)';
    eigenStruct.eigenvectors = [];  % Will be populated when needed
    obj.Lambda = bct.Lambda(eigenStruct);
    
    % Link Manifold ↔ Lambda as dual domains
    obj.Manifold.setDual(obj.Lambda);
    
    % Initialize transforms (note: MFT/IMFT won't be set until eigenvectors computed)
    obj.Manifold.initializeTransform();
    obj.Lambda.initializeTransform();
  end

  function obj = fromEdges(E, N, coords, w)
    % Create bct instance from edge list
    %
    %   B = bct.fromEdges(E) creates a bct object from edge list E
    %   B = bct.fromEdges(E, N) specifies number of nodes (default: max(E))
    %   B = bct.fromEdges(E, N, coords) also sets vertex coordinates
    %   B = bct.fromEdges(E, N, coords, w) specifies edge weights
    %
    %   Inputs:
    %     E      - [M×2] edge list (pairs of node indices, 1-based)
    %     N      - Number of nodes (default: max(E(:)))
    %     coords - [N×3] vertex coordinates (optional)
    %     w      - [M×1] edge weights (optional, default: all ones)
    %
    %   The function constructs an adjacency matrix from edges and creates
    %   a graph-based Manifold domain
    
    obj = bct.bct();
    
    % Clean edges and determine number of nodes
    E = bct.cleanEdges(E);
    if nargin < 2 || isempty(N)
      N = max(E(:));
    end
    N_val = double(N);
    
    % Store edge information in cache
    obj.cache.E = int32(E);
    
    if nargin > 3 && ~isempty(w)
      obj.cache.w = double(w(:));
    end
    
    % Build adjacency matrix from edges (undirected graph)
    A = sparse(E(:,1), E(:,2), true, N_val, N_val);
    A = A + A.';  % Make symmetric
    A = A - diag(diag(A));  % Remove self-loops
    obj.cache.A = spones(A) > 0;  % Binary adjacency
    
    % Create graph Manifold from adjacency matrix
    graphStruct = struct('A', obj.cache.A);
    
    if nargin > 2 && ~isempty(coords)
      graphStruct.coords = double(coords);
      obj.cache.Vertices = double(coords);
    end
    
    % Create Manifold - will detect graph structure and compute graph Laplacian
    obj.Manifold = bct.Manifold(graphStruct);
    
    % Create Lambda domain (dual of Manifold) using estimated max eigenvalue
    lambda_max_est = obj.Manifold.estimateLambdaMax();
    
    % Create placeholder Lambda with estimated range
    eigenStruct = struct();
    eigenStruct.eigenvalues = linspace(0, lambda_max_est, 100)';
    eigenStruct.eigenvectors = [];  % Will be populated when needed
    obj.Lambda = bct.Lambda(eigenStruct);
    
    % Link Manifold ↔ Lambda as dual domains
    obj.Manifold.setDual(obj.Lambda);
    
    % Initialize transforms (note: MFT/IMFT won't be set until eigenvectors computed)
    obj.Manifold.initializeTransform();
    obj.Lambda.initializeTransform();
  end

  function obj = fromMesh(V,F)
    % Create bct instance from triangle mesh
    %
    %   B = bct.fromMesh(V, F) creates a bct object from mesh vertices and faces
    %
    %   Inputs:
    %     V - [N×3] vertex coordinates
    %     F - [M×3] face connectivity (triangle indices, 1-based)
    %
    %   Creates Manifold domain with cotangent Laplacian and automatically
    %   links to Lambda spectral domain
    
    obj = bct.bct();

    % Create new @Manifold domain object
    meshStruct = struct('V', double(V), 'F', int32(F));
    obj.Manifold = bct.Manifold(meshStruct);
    
    % Create Lambda domain (dual of Manifold) using estimated max eigenvalue
    % This provides initial axis without costly eigendecomposition
    lambda_max_est = obj.Manifold.estimateLambdaMax();
    
    % Create placeholder Lambda with estimated range [0, lambda_max_est]
    % Actual eigenvalues will be computed when meshFourier is called
    eigenStruct = struct();
    eigenStruct.eigenvalues = linspace(0, lambda_max_est, 100)';  % Placeholder
    eigenStruct.eigenvectors = [];  % Will be populated by meshFourier
    obj.Lambda = bct.Lambda(eigenStruct);
    
    % Link Manifold ↔ Lambda as dual domains using inherited setDual method
    obj.Manifold.setDual(obj.Lambda);
    
    % Initialize transforms (note: MFT/IMFT won't be set until eigenvectors computed)
    obj.Manifold.initializeTransform();
    obj.Lambda.initializeTransform();
  end
end

% Eigendecomposition orchestration
methods
  function obj = computeEigenbasis(obj, varargin)
    % computeEigenbasis - Compute eigenvectors and eigenvalues for Lambda domain
    %
    % Orchestrates the eigendecomposition by passing MassMatrix and 
    % CotangentMatrix from Manifold to Lambda, then re-initializes
    % transforms for both domains.
    %
    % Syntax:
    %   obj = obj.computeEigenbasis()
    %   obj = obj.computeEigenbasis(numModes)
    %   obj = obj.computeEigenbasis(numModes, Name, Value)
    %
    % Inputs:
    %   numModes - (optional) Number of eigenmodes to compute
    %              Default: min(600, N-1)
    %
    % Name-Value Parameters:
    %   'sigma'  - Eigenvalue shift (default: 1e-6)
    %   'tol'    - Convergence tolerance (default: 1e-10)
    %   'maxit'  - Maximum iterations (default: 5000)
    %   'mode'   - Eigenvalue selection (default: 'smallestabs')
    %
    % Outputs:
    %   obj - Updated bct object with:
    %         .Lambda.U      - Eigenvectors
    %         .Lambda.lambda - Eigenvalues
    %         .Lambda.K      - Number of modes
    %         Both Manifold and Lambda transforms re-initialized
    %
    % Example:
    %   B = bct.bct.fromMesh(V, F);
    %   B = B.computeEigenbasis(500);
    %   
    %   % Now transforms are available:
    %   signal = randn(size(V,1), 1);
    %   coeffs = B.Manifold.transform.forward(signal);
    %   reconstructed = B.Lambda.transform.forward(coeffs);
    %
    % See also: bct.Lambda.eigenbasis, bct.Manifold.meshFourier
    
    % Validate Manifold and Lambda exist
    if isempty(obj.Manifold)
      error('bct:NoManifold', 'Manifold domain must be initialized before computing eigenbasis');
    end
    if isempty(obj.Lambda)
      error('bct:NoLambda', 'Lambda domain must be initialized before computing eigenbasis');
    end
    
    % Validate dual linking
    if obj.Manifold.dual ~= obj.Lambda
      error('bct:DualNotLinked', 'Manifold and Lambda must be linked as dual domains');
    end
    
    % Get MassMatrix and CotangentMatrix from Manifold
    M = obj.Manifold.MassMatrix;
    K = obj.Manifold.CotangentMatrix;
    
    if isempty(M) || isempty(K)
      error('bct:NoMatrices', ...
        'Manifold MassMatrix and CotangentMatrix must be computed before eigenbasis');
    end
    
    % Compute eigenbasis using Lambda method
    obj.Lambda = obj.Lambda.eigenbasis(M, K, varargin{:});
    
    % Re-initialize transforms for both Manifold and Lambda
    % Now that eigenvectors are computed, MFT and IMFT will be created
    obj.Manifold.initializeTransform();
    obj.Lambda.initializeTransform();
    
    % Verify transforms were created
    if isempty(obj.Manifold.transform)
      warning('bct:NoMFT', 'Manifold transform (MFT) was not initialized');
    end
    if isempty(obj.Lambda.transform)
      warning('bct:NoIMFT', 'Lambda transform (IMFT) was not initialized');
    end
    
    fprintf('[bct] Eigenbasis computed and transforms initialized\n');
    if isempty(obj.Manifold.transform)
      fprintf('      Manifold.transform: empty\n');
    else
      fprintf('      Manifold.transform: %s\n', class(obj.Manifold.transform));
    end
    if isempty(obj.Lambda.transform)
      fprintf('      Lambda.transform: empty\n');
    else
      fprintf('      Lambda.transform: %s\n', class(obj.Lambda.transform));
    end
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
  
  function showMesh(this, varargin)
    % showMesh - Display the mesh with light gray vertex colors
    %
    % Syntax:
    %   B.showMesh()
    %   B.showMesh('Parent', parentContainer)
    %   B.showMesh('ColorMap', 'gray')
    %   B.showMesh('WireFrame', true)
    %
    % Creates a viewer3d window and displays the mesh from B.Manifold
    % with light gray default coloring. The viewer handle is stored in
    % B.Viewer for later use with showSignal or showAnimation.
    %
    % Name-Value Parameters:
    %   'Parent'    - Parent container for the viewer (e.g., uipanel)
    %   'ColorMap'  - Colormap to use (default: 'gray')
    %   'WireFrame' - Show wireframe (true/false)
    %   'Center'    - Center mesh at origin (true/false), default: true
    %   'Title'     - Figure title
    %
    % Example:
    %   B.showMesh();
    %   B.showMesh('Parent', myPanel);
    %   B.showMesh('WireFrame', true);
    %
    % See also: showSignal, showAnimation
    
    % Pass all arguments to bct.show.mesh
    this.Viewer = bct.show.mesh(this, varargin{:});
  end
  
  function showSignal(this, varargin)
    % showSignal - Display a static signal on the mesh
    %
    % Syntax:
    %   B.showSignal()                    % Shows first signal
    %   B.showSignal(idx)                 % Shows signal at index idx
    %   B.showSignal(idx, 'Parent', p)    % Shows in parent container
    %   B.showSignal(idx, 'TimePoint', t) % Shows time point t
    %
    % Displays a signal from B.Signals as vertex colors on the mesh.
    % For time-varying signals, displays only the specified time point.
    % Use showAnimation for time-varying visualization.
    %
    % Name-Value Parameters:
    %   'Parent'     - Parent container for the viewer
    %   'ColorMap'   - Colormap to use (default: 'parula')
    %   'TimePoint'  - Time point to display (default: 1)
    %
    % Example:
    %   B.showSignal();
    %   B.showSignal(1);
    %   B.showSignal(1, 'TimePoint', 50);
    %   B.showSignal(1, 'Parent', myPanel);
    %
    % See also: showMesh, showAnimation
    
    % Pass all arguments to bct.show.signal
    this.Viewer = bct.show.signal(this, varargin{:});
  end
  
  function showAnimation(this, signalIndex)
    % showAnimation - Animate a time-varying signal on the mesh
    %
    % Syntax:
    %   B.showAnimation()       % Animates first signal
    %   B.showAnimation(idx)    % Animates signal at index idx
    %
    % Animates a signal from B.Signals over time using the time vector
    % from B.Time. Updates vertex colors for each time point.
    %
    % Requires B.Time to have a time vector (time-varying signal).
    % For static signals, use showSignal instead.
    %
    % Example:
    %   B.showMesh();
    %   B.showAnimation(1);
    %
    % See also: showMesh, showSignal
    
    % Default to first signal
    if nargin < 2
      signalIndex = 1;
    end
    
    % Validate prerequisites
    if isempty(this.Signals) || signalIndex > length(this.Signals)
      error('bct:InvalidSignalIndex', ...
        'Signal index %d out of range (1-%d)', signalIndex, length(this.Signals));
    end
    
    if isempty(this.Time) || isempty(this.Time.t_vec)
      error('bct:NoTimeVector', ...
        'B.Time must have a time vector for animation. Use showSignal for static display.');
    end
    
    % Create viewer if needed
    if isempty(this.Viewer)
      this.Viewer = bct.show.mesh(this);
    end
    
    % Animate the signal
    sig = this.Signals(signalIndex);
    bct.show.animate(this, this.Viewer, sig);
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
    
    this.SpectralGrid = struct('lambda_grid', [], 'omega_grid', [], 't_grid', [], ...
                               'lambda_band', [], 'omega', [], 'coeffs', [], ...
                               'filter_type', '', 'filter_used', '', 'synthesis_params', struct());
  end
  
  function tf = hasSpectralGrid(this)
    % hasSpectralGrid - Check if spectral grid has been built
    %
    %   tf = B.hasSpectralGrid() returns true if spectral grid exists
    %
    %   For different filter types:
    %   - Manifold: Requires lambda_band
    %   - Time: Requires omega (or AxisOmega)
    %   - Separable/Spectral/Dynamic: Requires lambda_grid and omega_grid (or t_grid)
    
    % Check if SpectralGrid exists and has coefficients
    if ~isstruct(this.SpectralGrid) || ~isfield(this.SpectralGrid, 'coeffs')
      tf = false;
      return;
    end
    
    % Check based on what's stored
    has_lambda_band = isfield(this.SpectralGrid, 'lambda_band') && ~isempty(this.SpectralGrid.lambda_band);
    has_grids = isfield(this.SpectralGrid, 'lambda_grid') && ~isempty(this.SpectralGrid.lambda_grid);
    
    tf = has_lambda_band || has_grids;
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
  
  function reset(this)
    % reset - Clear filterbank and spectral grid (start fresh)
    %
    %   B.reset() removes all filters and clears spectral grids
    %
    %   This is useful when you want to start fresh with new filters
    %   without losing the Manifold, Time, or Signals data.
    %
    % Example:
    %   B.reset();  % Clear filters and grids
    %   % Now add new filters...
    %
    % See also: clearFilterbank, clearSpectralGrid
    
    this.Filterbank = [];
    this.SpectralGrid = struct('lambda_grid', [], 'omega_grid', [], 't_grid', [], ...
                               'lambda_band', [], 'omega', [], 'coeffs', [], ...
                               'filter_type', '', 'filter_used', '', 'synthesis_params', struct());
    fprintf('[bct] Reset complete: filterbank and spectral grid cleared\n');
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
    % Synthesize - Generate spectral coefficients using axis-based filter architecture
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
    %
    % Description:
    %   Generates spectral coefficients based on filter type:
    %
    %   Filter Types and Grid Generation:
    %   
    %   1. Manifold (H(λ)):
    %      - Creates lambda axis from filter.lambda_band
    %      - Evaluates H(lambda_vec) to get spatial power spectrum
    %      - Generates A_k [K × 1] with random phases
    %
    %   2. Time (H(ω)):
    %      - Creates omega axis from AxisOmega
    %      - Evaluates H(omega_vec) to get temporal power spectrum
    %      - Generates A_l [T × 1] with random phases
    %
    %   3. Separable (H(λ,ω) = Hλ(λ)·Hω(ω)):
    %      - Creates meshgrid(lambda, omega) → [T × K]
    %      - Evaluates Hλ and Hω separately, forms outer product
    %      - Generates A_kl [K × T] with random phases
    %
    %   4. Spectral (H(λ,ω) non-separable):
    %      - Creates meshgrid(lambda, omega) → [T × K]
    %      - Evaluates H(lambda_grid, omega_grid) at all grid points
    %      - Generates A_kl [K × T] with random phases
    %
    %   5. Dynamic (K(λ,t)):
    %      - Creates ndgrid(lambda, t) → [K × T]
    %      - Evaluates K(lambda_grid, t_grid) to get propagator
    %      - Generates initial conditions, applies K to get A_kt [K × T]
    %
    % Example:
    %   % Manifold filter
    %   filt = bct.filters.Filter('Manifold');
    %   filt.g = bct.filters.design.manifold.heat(B.Manifold, 'tau', 0.1);
    %   B.Synthesize(filt);
    %
    %   % Separable filter
    %   filt = bct.filters.Filter('Separable');
    %   B.Synthesize(filt, 'envelope', 'gaussian');
    %
    % See also: Generate, designFilter, buildSpectralGrid, bct.resolution.Axis
    
    % Validate prerequisites
    if isempty(this.Manifold)
      error('bct:NoManifold', 'Manifold must be set before synthesis');
    end
    if isempty(this.Filterbank)
      error('bct:NoFilters', 'Filterbank is empty. Design a filter first.');
    end
    
    % Get filter
    filt = this.getFilter(filter_identifier);
    
    % Parse parameters
    p = inputParser;
    addParameter(p, 'numModes', [], @isnumeric);
    addParameter(p, 'envelope', 'none', @(x) ischar(x) || isstring(x));
    addParameter(p, 't0', [], @isnumeric);
    addParameter(p, 'sigma_t', [], @isnumeric);
    parse(p, varargin{:});
    
    % Extract parameters
    envelope_type = string(p.Results.envelope);
    
    % Determine filter type and validate requirements
    filter_type = string(filt.Type);
    
    % Validate Time requirement for temporal filters
    requires_time = ismember(filter_type, ["Time", "Separable", "Spectral", "Dynamic"]);
    if requires_time
      if isempty(this.Time) || isempty(this.Time.T) || isempty(this.Time.fs)
        error('bct:NoTime', 'Time must be set for %s filters', filter_type);
      end
      % Initialize axes if not done yet
      if isempty(this.AxisOmega)
        this.initializeAxes();
      end
    end
    
    % Determine spatial modes from filter lambda_band
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
    
    % Get eigenvalues in filter band
    % Check if we can use pre-computed eigenmodes from Manifold
    if numel(lambda_band) == 2
      % Band specified as [lambda_min, lambda_max]
      
      % Check if Manifold has pre-computed eigenvalues in this band
      if ~isempty(this.Manifold.Eigenvalues) && this.Manifold.NumModes > 0
        % Try to use pre-computed eigenmodes
        all_lambda = this.Manifold.Eigenvalues;
        in_band = all_lambda >= lambda_band(1) & all_lambda <= lambda_band(2);
        
        if sum(in_band) >= numModes
          % We have enough pre-computed modes in the band
          lambda_vec = all_lambda(in_band);
          
          % Limit to numModes if we have more than needed
          if length(lambda_vec) > numModes
            lambda_vec = lambda_vec(1:numModes);
          end
          
          fprintf('[bct] Using %d pre-computed eigenmodes in band [%.4f, %.4f]\n', ...
            length(lambda_vec), lambda_band(1), lambda_band(2));
        else
          % Not enough pre-computed modes, need to compute more
          fprintf('[bct] Pre-computed modes insufficient (%d < %d), computing eigenmodes...\n', ...
            sum(in_band), numModes);
          meshOpts = struct();
          meshOpts.lambda_low = lambda_band(1);
          meshOpts.lambda_high = lambda_band(2);
          meshOpts.sigma = mean(lambda_band);
          meshOpts.mode = 'smallestabs';
          
          [~, lambda_vec] = this.Manifold.meshFourier(numModes, meshOpts);
        end
      else
        % No pre-computed modes, compute them now
        fprintf('[bct] Computing %d eigenmodes in band [%.4f, %.4f]...\n', ...
          numModes, lambda_band(1), lambda_band(2));
        meshOpts = struct();
        meshOpts.lambda_low = lambda_band(1);
        meshOpts.lambda_high = lambda_band(2);
        meshOpts.sigma = mean(lambda_band);
        meshOpts.mode = 'smallestabs';
        
        [~, lambda_vec] = this.Manifold.meshFourier(numModes, meshOpts);
      end
    else
      % Specific eigenvalues provided
      lambda_vec = lambda_band(:);
    end
    
    K = length(lambda_vec);
    
    % Generate spectral coefficients based on filter type
    switch filter_type
      
      case 'Manifold'
        % H(λ): Spatial spectral filter
        % Grid: lambda_vec [K × 1]
        % Output: A_k [K × 1]
        
        % Evaluate filter at lambda values
        H_lambda = filt.getResponse(lambda_vec);  % [K × 1]
        P_space = abs(H_lambda).^2;
        P_space = P_space / sum(P_space);  % Normalize
        
        % Generate real coefficients for real-valued signals
        % Use Gaussian random values weighted by filter power
        A_kl = randn(K, 1) .* sqrt(P_space);  % [K × 1] real
        
        T = 1;  % Single "time" point for spatial-only
        
        fprintf('[bct] Synthesized Manifold filter: %d modes\n', K);
        fprintf('[bct] Lambda range: [%.4f, %.4f]\n', min(lambda_vec), max(lambda_vec));
        
      case 'Time'
        % H(ω): Temporal filter
        % Grid: omega_vec [T × 1]
        % Output: A_l [T × 1]
        
        omega_vec = this.AxisOmega.Values;  % [T × 1]
        T = length(omega_vec);
        
        % Evaluate filter at omega values
        H_omega = filt.getResponse(omega_vec);  % [T × 1]
        P_time = abs(H_omega).^2;
        P_time = P_time / sum(P_time);  % Normalize
        
        % Generate temporal coefficients
        phase_l = rand(T, 1) * 2*pi;
        A_l = sqrt(P_time) .* exp(1i * phase_l);  % [T × 1]
        
        % Store as [1 × T] for consistency (will be broadcast in Generate)
        A_kl = A_l';  % [1 × T]
        K = 1;
        
        fprintf('[bct] Synthesized Time filter: %d time points\n', T);
        fprintf('[bct] Omega range: [%.4f, %.4f] rad/s\n', omega_vec(1), omega_vec(end));
        
      case 'Separable'
        % H(λ,ω) = Hλ(λ) · Hω(ω)
        % Grid: meshgrid(lambda, omega) → [T × K]
        % Output: A_kl [K × T]
        
        omega_vec = this.AxisOmega.Values;  % [T × 1]
        T = length(omega_vec);
        
        % Create meshgrid
        [lambda_grid, omega_grid] = meshgrid(lambda_vec, omega_vec);  % [T × K]
        
        % Evaluate separable filter
        % For separable filters, g(lambda, omega) should accept both arguments
        if nargin(filt.g) == 2
          % Two-argument filter function: g(lambda, omega)
          H_joint = filt.g(lambda_grid, omega_grid);  % [T × K]
          P_joint = abs(H_joint').^2;  % [K × T]
          P_joint = P_joint / sum(P_joint(:));
        else
          % Single-argument: assume returns {Hlambda, Homega}
          response = filt.g(lambda_grid(:));
          if iscell(response) && numel(response) == 2
            H_lambda = response{1}(:);  % [K × 1]
            H_omega = response{2}(:);   % [T × 1]
            P_space = abs(H_lambda).^2 / sum(abs(H_lambda).^2);
            P_time = abs(H_omega).^2 / sum(abs(H_omega).^2);
            P_joint = P_space * P_time';  % [K × T] outer product
          else
            error('bct:Synthesize:InvalidSeparable', ...
              'Separable filter g must accept 2 args or return {Hlambda, Homega}');
          end
        end
        
        % Generate coefficients with random phases
        phase_kl = rand(K, T) * 2*pi;
        A_kl = sqrt(P_joint) .* exp(1i * phase_kl);  % [K × T]
        
        % Store grid in SpectralGrid
        this.SpectralGrid.lambda_grid = lambda_grid;
        this.SpectralGrid.omega_grid = omega_grid;
        
        fprintf('[bct] Synthesized Separable filter: %d modes × %d time points\n', K, T);
        
      case 'Spectral'
        % H(λ,ω): Non-separable joint spectral filter
        % Grid: meshgrid(lambda, omega) → [T × K]
        % Output: A_kl [K × T]
        
        omega_vec = this.AxisOmega.Values;  % [T × 1]
        T = length(omega_vec);
        
        % Create meshgrid
        [lambda_grid, omega_grid] = meshgrid(lambda_vec, omega_vec);  % [T × K]
        
        % Evaluate non-separable filter at all grid points
        H_joint = filt.g(lambda_grid, omega_grid);  % [T × K]
        P_joint = abs(H_joint').^2;  % [K × T]
        P_joint = P_joint / sum(P_joint(:));
        
        % Generate coefficients with random phases
        phase_kl = rand(K, T) * 2*pi;
        A_kl = sqrt(P_joint) .* exp(1i * phase_kl);  % [K × T]
        
        % Store grid
        this.SpectralGrid.lambda_grid = lambda_grid;
        this.SpectralGrid.omega_grid = omega_grid;
        
        fprintf('[bct] Synthesized Spectral filter: %d modes × %d time points\n', K, T);
        
      case 'Dynamic'
        % K(λ,t): Time-domain propagator
        % Grid: ndgrid(lambda, t) → [K × T]
        % Output: A_kt [K × T] from propagating initial conditions
        
        t_vec = this.AxisTime.Values;  % [T × 1]
        T = length(t_vec);
        
        % Create ndgrid for dynamic propagators
        [lambda_grid, t_grid] = ndgrid(lambda_vec, t_vec);  % [K × T]
        
        % Evaluate propagator K(λ,t)
        % Dynamic filters g should accept two arguments: g(lambda, t)
        K_propagator = filt.g(lambda_grid, t_grid);  % [K × T]
        
        % Generate random initial conditions in spectral domain
        A_0 = randn(K, 1) + 1i*randn(K, 1);  % [K × 1]
        A_0 = A_0 / norm(A_0);  % Normalize
        
        % Apply propagator: A(λ,t) = K(λ,t) · A_0(λ)
        A_kl = K_propagator .* A_0;  % [K × T]
        
        % Store grid
        this.SpectralGrid.lambda_grid = lambda_grid;
        this.SpectralGrid.t_grid = t_grid;
        
        fprintf('[bct] Synthesized Dynamic filter: %d modes × %d time points\n', K, T);
        
      otherwise
        error('bct:UnknownFilterType', 'Unknown filter type: %s', filter_type);
    end
    
    % Apply temporal envelope (for temporal/joint filters)
    if T > 1 && strcmpi(envelope_type, 'gaussian')
      t = this.AxisTime.Values;
      t0 = p.Results.t0;
      if isempty(t0), t0 = t(end)/2; end
      
      sigma_t = p.Results.sigma_t;
      if isempty(sigma_t), sigma_t = t(end)/6; end
      
      env_t = exp(-0.5 * ((t - t0) ./ sigma_t).^2);
      
      if filter_type == "Time"
        A_kl = A_kl .* env_t';  % [1 × T]
      else
        A_kl = A_kl .* env_t';  % [K × T] broadcast
      end
    end
    
    % Store coefficients and metadata in SpectralGrid
    this.SpectralGrid.coeffs = A_kl;
    this.SpectralGrid.lambda_band = lambda_vec;
    this.SpectralGrid.filter_type = filter_type;
    this.SpectralGrid.filter_used = filter_identifier;
    this.SpectralGrid.synthesis_params = p.Results;
    
    if T == 1
      fprintf('[bct] Spatial band: [%.4f, %.4f] eigenvalues\n', lambda_band(1), lambda_band(2));
    else
      % Get time/omega info for display
      if filter_type == "Dynamic"
        t_vec = this.AxisTime.Values;
        fprintf('[bct] Lambda: [%.4f, %.4f], Time: [%.4f, %.4f] s\n', ...
          min(lambda_vec), max(lambda_vec), t_vec(1), t_vec(end));
      else
        omega_vec = this.AxisOmega.Values;
        fprintf('[bct] Lambda: [%.4f, %.4f], Omega: [%.4f, %.4f] rad/s\n', ...
          min(lambda_vec), max(lambda_vec), omega_vec(1), omega_vec(end));
      end
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
    addParameter(p, 'output', 'auto', @(x) ischar(x) || isstring(x));  % 'auto', 'real', 'imag', 'magnitude', 'complex'
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
      % Spatiotemporal: check if time-domain (Dynamic) or frequency-domain
      is_time_domain = isfield(this.SpectralGrid, 't_grid') && ~isempty(this.SpectralGrid.t_grid);
      
      if is_time_domain
        % Dynamic filter: coefficients already in time domain
        % A_kl is [K × T] time-domain coefficients
        % Directly reconstruct: x = U * A_time
        x_wt = U * A_kl;  % [N × T]
        
      else
        % Separable/Spectral: inverse temporal FFT then graph synthesis
        
        % Step 1: Inverse temporal FFT on each spatial mode
        % Need to reconstruct full FFT spectrum from positive frequencies
        T_full = this.Time.T;  % Full number of time points
        
        if T ~= T_full
          % We have only positive frequencies - reconstruct full spectrum
          % For real signals: X[N-k] = conj(X[k])
          A_full = zeros(K, T_full);
          A_full(:, 1:T) = A_kl;  % Positive frequencies
          
          % Fill negative frequencies (Hermitian symmetry for real output)
          if mod(T_full, 2) == 0
            % Even: conjugate symmetric around Nyquist
            for k_idx = 2:(T-1)
              A_full(:, T_full - k_idx + 2) = conj(A_kl(:, k_idx));
            end
          else
            % Odd: conjugate symmetric, no Nyquist bin
            for k_idx = 2:T
              A_full(:, T_full - k_idx + 2) = conj(A_kl(:, k_idx));
            end
          end
          
          A_time = ifft(A_full, [], 2, 'symmetric');  % [K × T_full] - real output
        else
          % We already have full spectrum
          if p.Results.symmetric
            A_time = ifft(A_kl, [], 2, 'symmetric');  % [K × T] - real output
          else
            A_time = ifft(A_kl, [], 2);  % [K × T] - complex output
          end
        end
        
        % Step 2: Reconstruct into vertex domain (inverse graph Fourier)
        x_wt = U * A_time;  % [N × T]
      end
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
    
    % Handle complex-valued signals (e.g., from Schrödinger filter)
    output_type = string(p.Results.output);
    if output_type == "auto"
      % Auto: keep complex for Dynamic filters, real for others
      is_time_domain = isfield(this.SpectralGrid, 't_grid') && ~isempty(this.SpectralGrid.t_grid);
      if is_time_domain && ~isreal(xrec)
        % Keep complex for Dynamic propagators
        output_type = "complex";
      else
        % Force real for frequency-domain filters
        output_type = "real";
      end
    end
    
    % Apply output type conversion
    switch output_type
      case "real"
        xrec = real(xrec);
      case "imag"
        xrec = imag(xrec);
      case "magnitude"
        xrec = abs(xrec);
      case "complex"
        % Keep as-is
      otherwise
        warning('Unknown output type "%s", keeping complex', output_type);
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
