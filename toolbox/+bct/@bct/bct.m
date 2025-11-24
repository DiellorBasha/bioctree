classdef bct < handle
  % bct: BioCTree object for brain connectivity analysis
  %
  % Properties:
  %   Manifold   - Surface mesh domain (bct.Manifold)
  %   Lambda     - Spectral domain, dual of Manifold (bct.Lambda)
  %   Time       - Temporal domain (bct.Time)
  %   Omega      - Frequency domain, dual of Time (bct.Omega)
  %   Joint      - Joint domain combining two canonical domains (bct.Joint)
  %   Filterbank - Collection of filters for multi-band analysis (bct.filters.FilterBank)
  %   Viewer     - Visualization handle
  %
  % Automatic Domain Creation:
  %   When Time is set (B.Time = bct.Time(...)):
  %     - Omega dual is automatically created (Time ↔ Omega)
  %     - Joint Manifold_Time domain auto-created if Manifold exists
  %     - Joint.dual = Lambda_Omega (automatic dual relationship)
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
    % Setting Time also auto-creates Joint Manifold_Time if Manifold exists
    % Access as: B.Time.T, B.Time.fs, B.Time.axis, etc.
    Time bct.Time = bct.Time.empty()  % Time domain
    
    % Lambda domain - spectral decomposition of Manifold Laplacian
    % Dual of Manifold domain, linked automatically on construction
    % Stores eigenvalues, eigenvectors from bct.Lambda.eigenbasis
    % Access as: B.Lambda.lambda, B.Lambda.U, B.Lambda.axis, etc.
    Lambda bct.Lambda = bct.Lambda.empty()  % Spectral domain
    
    % Omega domain - temporal frequency spectrum
    % Dual of Time domain, linked automatically on construction
    % Access as: B.Omega.omega, B.Omega.freq, B.Omega.axis, etc.
    Omega bct.Omega = bct.Omega.empty()  % Temporal frequency domain
    
    % Joint domain - combines two canonical domains
    % Automatically created as Manifold_Time when Time is set
    % Dual Lambda_Omega created automatically with bidirectional link
    % Can also create manually: B.createJoint('Lambda', 'Omega')
    % Access as: B.Joint.A_grid, B.Joint.B_grid, B.Joint.N, etc.
    Joint bct.Joint = bct.Joint.empty()  % Joint domain for multi-dimensional analysis
    
    % Viewer handle for 3D visualization
    % Stores viewer3d handle created by showMesh method
    % Access as: B.Viewer to interact with the visualization
    Viewer = []  % viewer3d handle for visualization
end

properties (SetAccess=private)
    % Filterbank - collection of filters for multi-band analysis
    % Uses bct.filters.FilterBank for proper filter management
    % Access filters via: B.Filterbank.get(label), B.Filterbank.list(), etc.
    % Add filters with FilterDesigner: designer.spatial(...) then B.Filterbank.add(filt)
    Filterbank bct.filters.FilterBank
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
    % Actual eigenvalues will be computed when bct.Lambda.eigenbasis is called
    eigenStruct = struct();
    eigenStruct.eigenvalues = linspace(0, lambda_max_est, 100)';  % Placeholder
    eigenStruct.eigenvectors = [];  % Will be populated by eigenbasis
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
    
    % Initialize Filterbank
    obj.Filterbank = bct.filters.FilterBank();
    
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
    % See also: bct.Lambda.eigenbasis
    
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
    %   [M, N] = B.Joint.N;  % [100, 50]
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
    
    % Automatically create dual Joint domain if constituent domains have duals
    if ~isempty(domainA.dual) && ~isempty(domainB.dual)
      % Create dual Joint domain (e.g., Manifold_Time ↔ Lambda_Omega)
      dualJoint = bct.Joint(domainA.dual, domainB.dual);
      
      % Set bidirectional dual relationship
      obj.Joint.dual = dualJoint;
      dualJoint.dual = obj.Joint;
      
      fprintf('[bct] Joint domain created: %s ↔ %s (dual)\n', ...
        obj.Joint.Domain, dualJoint.Domain);
    else
      fprintf('[bct] Joint domain created: %s\n', obj.Joint.Domain);
      if isempty(domainA.dual)
        fprintf('      Warning: %s has no dual domain\n', domainA_name);
      end
      if isempty(domainB.dual)
        fprintf('      Warning: %s has no dual domain\n', domainB_name);
      end
    end
    
    fprintf('      Grid size: [%d×%d] = %d points\n', ...
      obj.Joint.N, obj.Joint.numel());
    fprintf('      Units: %s\n', obj.Joint.units);
  end
end

%% Visualization methods

methods
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
  
  function showSignal(this, signal, varargin)
    % showSignal - Display a signal on the mesh
    %
    % Syntax:
    %   B.showSignal(signal)
    %   B.showSignal(signal, 'TimePoint', t)
    %   B.showSignal(signal, 'Parent', parentContainer)
    %   B.showSignal(signal, 'ColorMap', 'turbo')
    %
    % Displays a signal defined on the Manifold domain or Joint Manifold-Time
    % domain on the mesh. For Joint domain signals, you can specify which
    % time point to display.
    %
    % Inputs:
    %   signal - bct.Signal object with domain:
    %            - Manifold: displays scalar field [N×1]
    %            - Joint (Manifold×Time): displays time slice [N×1] at TimePoint
    %
    % Name-Value Parameters:
    %   'TimePoint'  - Time point to display (default: 1) for Joint signals
    %   'Parent'     - Parent container for the viewer (e.g., uipanel)
    %   'ColorMap'   - Colormap to use (default: 'parula')
    %   'Title'      - Figure title
    %
    % Example:
    %   % Display signal on Manifold
    %   S = bct.Signal(B.Manifold, randn(B.Manifold.N, 1), 'test');
    %   B.showSignal(S);
    %
    %   % Display time point 50 of spatiotemporal signal
    %   S_st = bct.Signal(B.Joint, randn(B.Joint.N), 'spatiotemporal');
    %   B.showSignal(S_st, 'TimePoint', 50);
    %
    % See also: showMesh, showAnimation, bct.Signal
    
    % Validate signal
    if ~isa(signal, 'bct.Signal')
        error('bct:InvalidSignal', 'Input must be a bct.Signal object');
    end
    
    % Parse additional arguments
    p = inputParser;
    addParameter(p, 'TimePoint', 1, @(x) isnumeric(x) && x > 0);
    addParameter(p, 'Parent', [], @(x) isempty(x) || isgraphics(x));
    addParameter(p, 'ColorMap', 'parula', @(x) ischar(x) || isstring(x) || isnumeric(x));
    addParameter(p, 'Title', '', @(x) ischar(x) || isstring(x));
    parse(p, varargin{:});
    
    % Extract signal data based on domain
    if isa(signal.Domain, 'bct.Joint')
        % Joint domain signal - extract time slice
        timePoint = p.Results.TimePoint;
        
        if isa(signal.Domain.A, 'bct.Manifold')
            % Manifold is first domain [N × T]
            if size(signal.Data, 2) < timePoint
                error('bct:InvalidTimePoint', ...
                    'Time point %d out of range (1-%d)', timePoint, size(signal.Data, 2));
            end
            signalData = signal.Data(:, timePoint);
        else
            error('bct:UnsupportedJoint', ...
                'Can only visualize Joint signals with Manifold as first domain');
        end
        
        % Set default title if not provided
        if isempty(p.Results.Title)
            titleStr = sprintf('%s (t=%d)', signal.Label, timePoint);
        else
            titleStr = p.Results.Title;
        end
        
    elseif isa(signal.Domain, 'bct.Manifold')
        % Signal on Manifold domain [N × 1]
        signalData = signal.Data;
        if size(signalData, 2) > 1
            signalData = signalData(:, 1);
        end
        
        % Set default title
        if isempty(p.Results.Title)
            titleStr = signal.Label;
        else
            titleStr = p.Results.Title;
        end
        
    else
        error('bct:UnsupportedDomain', ...
            'Can only visualize signals on Manifold or Joint (Manifold×Time) domains');
    end
    
    % Build visualizer arguments
    vizArgs = {'SignalData', signalData, 'ColorMap', p.Results.ColorMap};
    
    if ~isempty(p.Results.Parent)
        vizArgs = [vizArgs, {'Parent', p.Results.Parent}];
    end
    
    if ~isempty(titleStr)
        vizArgs = [vizArgs, {'Title', titleStr}];
    end
    
    % Create visualization
    this.Viewer = bct.show.visualizer(this, vizArgs{:});
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
  
  %% Filter management methods
  
  function addFilter(this, filt)
    % addFilter - Add filter to filterbank (delegates to FilterBank)
    %
    %   B.addFilter(filt) adds filter to B.Filterbank
    %
    % Inputs:
    %   filt - bct.filters.Filter object with optional Label property
    %
    % Note: This is a convenience wrapper. Use FilterDesigner for creating filters:
    %   designer = bct.filters.FilterDesigner(B);
    %   filt = designer.spatial('gaussian', 'center', 50, 'sigma', 10, 'label', 'myfilter');
    %   B.addFilter(filt);
    %
    % Or add directly:
    %   B.Filterbank.add(filt);
    
    this.Filterbank.add(filt);
  end
  
  function filt = getFilter(this, identifier)
    % getFilter - Retrieve filter from filterbank (delegates to FilterBank)
    %
    %   filt = B.getFilter(label) gets filter by label
    %   filt = B.getFilter(index) gets filter by index
    %
    % Inputs:
    %   identifier - String label or integer index
    %
    % Returns:
    %   filt - bct.filters.Filter object
    %
    % Note: This is a convenience wrapper. Access directly with:
    %   B.Filterbank.get('label') or B.Filterbank.get(index)
    
    filt = this.Filterbank.get(identifier);
  end
  
  function removeFilter(this, identifier)
    % removeFilter - Remove filter from filterbank (delegates to FilterBank)
    %
    %   B.removeFilter(label) removes filter by label
    %   B.removeFilter(index) removes filter by index
    %
    % Inputs:
    %   identifier - String label or integer index
    %
    % Note: This is a convenience wrapper. Use directly:
    %   B.Filterbank.remove(identifier)
    
    this.Filterbank.remove(identifier);
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
  
  function sig = createImpulse(this, v0, t0)
    % createImpulse - Create Kronecker delta (impulse) signal for filter characterization
    %
    % Syntax:
    %   sig = B.createImpulse(v0)        % Spatial impulse at vertex v0
    %   sig = B.createImpulse(v0, t0)    % Spatiotemporal impulse at (v0, t0)
    %
    % In signal processing, a filter is fully characterized by its impulse response.
    % This method creates a delta signal (1 at specified location, 0 elsewhere).
    %
    % Inputs:
    %   v0 - Vertex index for spatial impulse (1 to Manifold.N)
    %   t0 - Optional time index for temporal impulse (1 to Time.N)
    %
    % Returns:
    %   sig - bct.Signal object containing the delta signal
    %         Can be transformed and filtered using domain transforms
    %
    % Workflow for filter characterization:
    %   1. Create impulse: delta = B.createImpulse(v0, t0)
    %   2. Apply filter:   response = delta.applyFilter(filt, B.Manifold, B.Lambda)
    %   3. Visualize:      B.showSignal(response)
    %
    % Examples:
    %   % Spatial impulse response of spectral filter
    %   delta = B.createImpulse(100);
    %   designer = bct.filters.FilterDesigner(B);
    %   filt = designer.spatial('heat_wavenumber', 'tau', 0.1);
    %   response = delta.applyFilter(filt, B.Manifold, B.Lambda);
    %   
    %   % Spatiotemporal impulse
    %   delta = B.createImpulse(50, 25);  % Vertex 50, time 25
    %
    % See also: bct.Signal.createDelta, synthesizeFilteredSignal
    
    if nargin < 3
      t0 = [];
    end
    
    if isempty(t0)
      % Spatial impulse only
      sig = bct.Signal.createDelta(this.Manifold, v0);
    else
      % Spatiotemporal impulse
      if isempty(this.Time)
        error('bct:NoTime', 'Time domain must be set for spatiotemporal impulse');
      end
      sig = bct.Signal.createDelta(this.Manifold, v0, this.Time, t0);
    end
  end
  
  function sig_out = applyFilter(obj, filter_obj, signal_in)
    % applyFilter - Apply filter to signal using domain transforms
    %
    % Orchestrates the complete filtering workflow:
    %   1. Forward transform: signal from source domain to filter domain
    %   2. Apply filter: multiply by filter response in filter domain
    %   3. Inverse transform: back to source domain
    %
    % Syntax:
    %   sig_out = B.applyFilter(filter, signal)
    %
    % Inputs:
    %   filter_obj - bct.filters.Filter object (defines filter domain)
    %   signal_in  - bct.Signal object (can be on any domain)
    %
    % Returns:
    %   sig_out - Filtered signal in same domain as input
    %
    % Examples:
    %   % Spatial filtering (Manifold → Lambda → Manifold)
    %   delta = bct.Signal.createDelta(B.Manifold, 100);
    %   filt = designer.lambda('gaussian', 'center', 10, 'sigma', 2);
    %   filtered = B.applyFilter(filt, delta);
    %   
    %   % Temporal filtering (Time → Omega → Time)
    %   timesig = bct.Signal(B.Time, randn(B.Time.N,1), 'noise');
    %   filt = designer.omega('bandpass', 'low', 5, 'high', 15);
    %   filtered = B.applyFilter(filt, timesig);
    %
    % See also: bct.filters.Filter, bct.Signal, bct.filters.FilterDesigner
    
    % Validate inputs
    if ~isa(filter_obj, 'bct.filters.Filter')
      error('bct:InvalidFilter', 'filter_obj must be a bct.filters.Filter');
    end
    if ~isa(signal_in, 'bct.Signal')
      error('bct:InvalidSignal', 'signal_in must be a bct.Signal');
    end
    
    % Get source domain from signal
    source_domain = signal_in.Domain;
    
    % Get filter domain
    filter_domain = filter_obj.Domain;
    
    % Determine filtering strategy based on domains
    if isa(filter_domain, 'bct.Lambda')
      % Spatial spectral filtering
      if ~isa(source_domain, 'bct.Manifold')
        error('bct:DomainMismatch', ...
          'Lambda filter requires Manifold signal (got %s)', class(source_domain));
      end
      
      % Check transforms initialized
      if isempty(obj.Manifold.transform) || isempty(obj.Lambda.transform)
        error('bct:NoTransform', ...
          'Transforms not initialized. Run computeEigenbasis() first.');
      end
      
      % Forward: Manifold → Lambda (MFT)
      coeffs = obj.Manifold.transform.forward(signal_in.Data);
      
      % Filter: multiply by filter response
      H = filter_obj.evaluate();
      filtered_coeffs = coeffs(:) .* H(:);
      
      % Inverse: Lambda → Manifold (IMFT.forward, not IMFT.inverse!)
      data_out = obj.Lambda.transform.forward(filtered_coeffs);
      
      % Create output signal
      label_out = sprintf('%s_filtered', signal_in.Label);
      sig_out = bct.Signal(obj.Manifold, data_out, label_out);
      
    elseif isa(filter_domain, 'bct.Omega')
      % Temporal frequency filtering
      if ~isa(source_domain, 'bct.Time')
        error('bct:DomainMismatch', ...
          'Omega filter requires Time signal (got %s)', class(source_domain));
      end
      
      % Check transforms initialized
      if isempty(obj.Time.transform) || isempty(obj.Omega.transform)
        error('bct:NoTransform', ...
          'Transforms not initialized for Time/Omega.');
      end
      
      % Forward: Time → Omega (FFT)
      coeffs = obj.Time.transform.forward(signal_in.Data);
      
      % Filter: multiply by filter response
      H = filter_obj.evaluate();
      filtered_coeffs = coeffs(:) .* H(:);
      
      % Inverse: Omega → Time (IFFT)
      data_out = obj.Omega.transform.inverse(filtered_coeffs);
      
      % Create output signal
      label_out = sprintf('%s_filtered', signal_in.Label);
      sig_out = bct.Signal(obj.Time, data_out, label_out);
      
    elseif isa(filter_domain, 'bct.Joint')
      % Joint domain filtering (2D)
      error('bct:NotImplemented', ...
        'Joint domain filtering not yet implemented');
        
    else
      error('bct:UnsupportedFilterDomain', ...
        'Filter domain must be Lambda, Omega, or Joint (got %s)', class(filter_domain));
    end
  end
  
  function sig = synthesizeFilteredSignal(this, filter_obj, input_sig)
    % synthesizeFilteredSignal - Modern signal synthesis using filter and domain transforms
    %
    % Syntax:
    %   sig = B.synthesizeFilteredSignal(filter, input_signal)
    %
    % This is the modern replacement for the deprecated Synthesize/Generate methods.
    % Applies a filter using domain transforms following signal processing principles:
    %   1. Transform input signal to filter's domain
    %   2. Multiply by filter response
    %   3. Inverse transform back to Manifold domain
    %
    % Inputs:
    %   filter_obj - bct.filters.Filter object (must be evaluated on spectral domain)
    %   input_sig  - bct.Signal object (optional, defaults to impulse at vertex 1)
    %
    % Returns:
    %   sig - Filtered signal in Manifold domain
    %
    % Architecture follows separation of concerns:
    %   - Domains own transforms (Manifold.transform, Lambda.transform, etc.)
    %   - Filters define kernels (Filter.evaluate())
    %   - Signals hold data (Signal.Data)
    %   - BCT orchestrates the workflow
    %
    % Examples:
    %   % Filter an impulse with spatial lowpass
    %   designer = bct.filters.FilterDesigner(B);
    %   filt = designer.spatial('heat_wavenumber', 'tau', 0.1);
    %   delta = B.createImpulse(100);
    %   filtered = B.synthesizeFilteredSignal(filt, delta);
    %   B.showSignal(filtered);
    %   
    %   % Default: Use impulse at vertex 1
    %   filtered = B.synthesizeFilteredSignal(filt);
    %
    % See also: createImpulse, bct.Signal.applyFilter, bct.filters.Filter.evaluate
    
    % Default input: impulse at vertex 1
    if nargin < 3 || isempty(input_sig)
      input_sig = bct.Signal.createDelta(this.Manifold, 1);
    end
    
    % Validate filter
    if ~isa(filter_obj, 'bct.filters.Filter')
      error('bct:InvalidFilter', 'filter_obj must be a bct.filters.Filter object');
    end
    
    % Determine transform domains based on filter domain
    filter_domain = filter_obj.Domain;
    
    if isa(filter_domain, 'bct.Lambda')
      % Spectral filter: Manifold -> Lambda (filter) -> Manifold
      sig = input_sig.applyFilter(filter_obj, this.Manifold, this.Lambda);
      
    elseif isa(filter_domain, 'bct.Omega')
      % Temporal frequency filter: Time -> Omega (filter) -> Time
      sig = input_sig.applyFilter(filter_obj, this.Time, this.Omega);
      
    elseif isa(filter_domain, 'bct.Joint')
      % Joint filter: Need to handle 2D transform
      error('bct:JointFilterNotImplemented', ...
        ['Joint domain filtering requires 2D transforms. ', ...
         'Use Filter.evaluate() directly and manual transform for now.']);
         
    else
      error('bct:UnsupportedFilterDomain', ...
        'Filter domain must be Lambda, Omega, or Joint');
    end
  end
end

methods (Access=private)
  %% Property Change Listeners
  
  function onTimeSet(obj, ~, ~)
    % Listener callback when Time property is set
    % Automatically creates and links Omega dual domain
    % Also creates default Joint Manifold_Time domain if Manifold exists
    %
    % This is called when: B.Time = bct.Time(...)
    % Results in: 
    %   - B.Omega being automatically created and linked
    %   - B.Joint = Manifold_Time (with dual Lambda_Omega) if Manifold exists
    
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
    
    % Auto-create Joint Manifold_Time domain if Manifold exists
    if ~isempty(obj.Manifold)
      obj = obj.createJoint('Manifold', 'Time');
      fprintf('      (Joint domain created automatically)\n');
    end
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
