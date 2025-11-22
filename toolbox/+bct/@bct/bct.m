classdef bct < handle
  % bct: BioCTree object for brain connectivity analysis
  %
  % Properties:
  %   Manifold - Surface mesh domain (bct.Manifold)
  %   Lambda   - Spectral domain, dual of Manifold (bct.Lambda)
  %   Time     - Temporal domain (bct.Time)
  %   Omega    - Frequency domain, dual of Time (bct.Omega)
  %   Joint    - Joint domain combining two canonical domains (bct.Joint)
  %   Signals  - Array of Signal objects (bct.Signal)
  %   Viewer   - Visualization handle
  %
  % Domain Axes (accessed via domain.axis):
  %   B.Manifold.axis - Vertex indices [N×1]
  %   B.Lambda.axis   - Eigenvalues (wavenumber by default) [K×1]
  %   B.Time.axis     - Time points (seconds) [T×1]
  %   B.Omega.axis    - Frequency points (Hz by default) [T×1]
  
properties (Access=private, Transient)
    cache struct = struct();     % holds legacy A, W, E, mesh, mgraph, gsp, w
end

properties (SetObservable, AbortSet)
    % Manifold object encapsulates mesh/graph topology
    % Preferred way to access mesh geometry and topology
    % Access as: B.Manifold.Vertices, B.Manifold.Faces, B.Manifold.Laplacian, etc.
    Manifold bct.Manifold  % New @Manifold domain class
    
    % Time domain - temporal properties for time-varying signals
    % Dual of Omega domain, linked automatically when Time is set
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
    
    % Joint domain - combines two canonical domains
    % Can combine any pair: Lambda×Omega, Manifold×Time, etc.
    % Access as: B.Joint.A_grid, B.Joint.B_grid, B.Joint.size(), etc.
    Joint bct.Joint = bct.Joint.empty()  % Joint domain for multi-dimensional analysis
    
    % Signals defined on the Manifold
    % Can be a single bct.Signal object or an array of Signal objects
    % All signals must have dimensions matching B.Manifold (N and optionally T)
    Signals bct.Signal = bct.Signal.empty()
    
    % Viewer handle for 3D visualization
    % Stores viewer3d handle created by showMesh method
    % Access as: B.Viewer to interact with the visualization
    Viewer = []  % viewer3d handle for visualization
end

properties (SetAccess=private)
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
  function obj = bct(varargin)
    % Constructor for bct object
    %
    % Creates empty BCT object and sets up property listeners for
    % automatic dual domain creation
    
    if nargin == 0
      % Add property listener for Time to auto-create Omega
      addlistener(obj, 'Time', 'PostSet', @obj.onTimeSet);
    end
  end
  
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
  
  function obj = createJoint(obj, domainA_name, domainB_name)
    % createJoint - Create joint domain from two canonical domains
    %
    % Creates a Joint domain by combining any two canonical BCT domains.
    % The Joint domain provides 2D meshgrids for multi-dimensional analysis
    % (e.g., space-time-frequency filtering, spatiotemporal decomposition).
    %
    % Syntax:
    %   obj = obj.createJoint('Lambda', 'Omega')
    %   obj = obj.createJoint('Manifold', 'Time')
    %
    % Inputs:
    %   domainA_name - Name of first domain: 'Manifold', 'Lambda', 'Time', or 'Omega'
    %   domainB_name - Name of second domain: 'Manifold', 'Lambda', 'Time', or 'Omega'
    %
    % Outputs:
    %   obj - Updated bct object with:
    %         .Joint - Joint domain object (bct.Joint)
    %
    % Common Joint Domain Combinations:
    %   'Lambda'   × 'Omega'   - Space-time-frequency analysis (spectral filtering)
    %   'Manifold' × 'Time'    - Spatiotemporal signals on mesh
    %   'Lambda'   × 'Time'    - Spectral-temporal evolution
    %   'Manifold' × 'Omega'   - Spatial-frequency decomposition
    %   'Time'     × 'Omega'   - Time-frequency analysis
    %
    % Example:
    %   % Create space-time-frequency joint domain
    %   B = bct.bct.fromMesh(V, F);
    %   B = B.computeEigenbasis(100);
    %   B.Time = bct.Time(linspace(0,1,50)', 50);
    %   B.Omega = B.Time.dual;
    %   B = B.createJoint('Lambda', 'Omega');
    %   
    %   % Now access joint coordinates:
    %   [M, N] = B.Joint.size();  % [100, 50]
    %   lambda_grid = B.Joint.A_grid;  % [100×50]
    %   omega_grid = B.Joint.B_grid;   % [100×50]
    %
    % See also: bct.Joint, bct.Lambda, bct.Manifold, bct.Time, bct.Omega
    
    % Validate domain names
    validDomains = {'Manifold', 'Lambda', 'Time', 'Omega'};
    if ~ismember(domainA_name, validDomains)
      error('bct:InvalidDomain', ...
        'domainA_name must be one of: %s', strjoin(validDomains, ', '));
    end
    if ~ismember(domainB_name, validDomains)
      error('bct:InvalidDomain', ...
        'domainB_name must be one of: %s', strjoin(validDomains, ', '));
    end
    
    % Get domain objects
    domainA = obj.(domainA_name);
    domainB = obj.(domainB_name);
    
    % Validate domains exist
    if isempty(domainA)
      error('bct:DomainNotInitialized', ...
        '%s domain must be initialized before creating joint domain', domainA_name);
    end
    if isempty(domainB)
      error('bct:DomainNotInitialized', ...
        '%s domain must be initialized before creating joint domain', domainB_name);
    end
    
    % Create joint domain
    obj.Joint = bct.Joint(domainA, domainB);
    
    fprintf('[bct] Joint domain created: %s\n', obj.Joint.Domain);
    fprintf('      Grid size: [%d×%d] = %d points\n', ...
      obj.Joint.size(), obj.Joint.numel());
    fprintf('      Units: %s\n', obj.Joint.units);
  end
end

% Signal management methods
methods
  function addSignal(this, signal_obj)
    % Add a Signal object to the Signals array
    %
    %   B.addSignal(signal_obj) adds a bct.Signal object
    %
    %   The signal dimensions are validated against B.Manifold
    
    % Validate input
    if ~isa(signal_obj, 'bct.Signal')
      error('bct:InvalidSignalType', ...
        'Input must be a bct.Signal object');
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
      sig = bct.Signal.empty();
      return;
    end
    
    labels = arrayfun(@(s) s.Label, this.Signals);
    idx = find(labels == string(label), 1);
    
    if isempty(idx)
      sig = bct.Signal.empty();
    else
      sig = this.Signals(idx);
    end
  end
  
  function clearSignalsNew(this)
    % Clear all Signal objects
    %
    %   B.clearSignalsNew() removes all signals from B.Signals
    
    this.Signals = bct.Signal.empty();
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
    % initializeAxes - DEPRECATED: Use domain.axis properties instead
    %
    % This method is deprecated. Axes are now managed by domain objects:
    %   - Time axis: this.Time.axis
    %   - Omega axis: this.Omega.axis
    %   - Manifold axis: this.Manifold.axis
    %   - Lambda axis: this.Lambda.axis
    %
    % Example migration:
    %   OLD: this.initializeAxes(); t = this.AxisTime.Values;
    %   NEW: t = this.Time.axis;
    %
    % See also: bct.Time, bct.Omega, bct.Manifold, bct.Lambda
    
    warning('bct:DeprecatedMethod', ...
      'initializeAxes is deprecated. Use domain.axis properties instead (e.g., B.Time.axis, B.Lambda.axis)');
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
    % See also: clearFilterbank
    
    this.Filterbank = [];
    fprintf('[bct] Reset complete: filterbank cleared\n');
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
  
  function Synthesize(this, ~, varargin)
    % Synthesize - DEPRECATED: Will be redesigned to use Joint domain
    %
    % This method is deprecated and will be redesigned to use the new
    % Joint domain infrastructure (B.Joint) instead of SpectralGrid.
    %
    % The new filtering workflow will:
    %   1. Use B.createJoint('Lambda', 'Omega') to create joint grid
    %   2. Apply filters directly to joint coordinates
    %   3. Use domain transforms for synthesis
    %
    % See also: bct.Joint, createJoint
    
    error('bct:DeprecatedMethod', ...
      ['Synthesize is deprecated and will be redesigned. ', ...
       'The filtering workflow is being updated to use Joint domain. ', ...
       'Use B.createJoint(''Lambda'', ''Omega'') to create joint grids.']);
  end
  
  function sig = Generate(this, varargin)
    % Generate - DEPRECATED: Will be redesigned to use Joint domain
    %
    % This method is deprecated and will be redesigned to use the new
    % Joint domain infrastructure (B.Joint) instead of SpectralGrid.
    %
    % The new signal generation workflow will:
    %   1. Use B.createJoint('Lambda', 'Omega') for joint coordinates
    %   2. Generate coefficients on joint grid
    %   3. Use domain transforms (B.Lambda.transform, B.Time.transform) for synthesis
    %
    % See also: bct.Joint, createJoint, Synthesize
    
    error('bct:DeprecatedMethod', ...
      ['Generate is deprecated and will be redesigned. ', ...
       'The filtering workflow is being updated to use Joint domain. ', ...
       'Use domain transforms for signal reconstruction.']);
  end
end

methods (Access=private)
  %% Property Change Listeners
  
  function onTimeSet(obj, ~, ~)
    % Listener callback when Time property is set
    % Automatically creates and links Omega dual domain
    %
    % This is called when: B.Time = bct.Time(...)
    % Results in: B.Omega being automatically created and linked
    
    % Only proceed if Time is not empty
    if isempty(obj.Time)
      return;
    end
    
    % Create Omega domain from Time
    omegaDomain = bct.Omega(obj.Time);
    
    % Link Time ↔ Omega as dual domains
    obj.Time.setDual(omegaDomain);
    
    % Assign Omega to BCT object
    obj.Omega = omegaDomain;
    
    % Initialize transforms (FFT/IFFT)
    obj.Time.initializeTransform();
    omegaDomain.initializeTransform();
  end
  
  %% Helper functions for filter design
  
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
