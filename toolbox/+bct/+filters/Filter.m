classdef Filter < handle
  % Filter - Kernel function bound to a BCT domain with parameters
  %
  % A Filter combines:
  %   - A kernel (mathematical function)
  %   - A domain (where the kernel is evaluated)
  %   - Parameters (kernel-specific values)
  %
  % The Filter class supports dynamic parameter updates for interactive
  % applications. Parameters can be changed directly via property access
  % (e.g., filt.center = 10), and the filter will automatically invalidate
  % its cached response.
  %
  % Properties:
  %   Domain          - bct.Domain object (Manifold, Time, Omega, Lambda, Joint)
  %   KernelName      - String identifying kernel type
  %   KernelFunction  - Function handle from kernels package
  %   Parameters      - Struct of kernel parameters
  %   Label           - Optional user label
  %
  % Dependent Properties (for convenient parameter access):
  %   center    - Center parameter (for Gaussian, bandpass, etc.)
  %   sigma     - Sigma parameter (for Gaussian, Gabor, etc.)
  %   tau       - Tau parameter (for heat kernel)
  %   low       - Lower bound (for bandpass)
  %   high      - Upper bound (for bandpass)
  %   Response  - Cached filter response (auto-computed when needed)
  %
  % Events:
  %   ParametersChanged - Fired when any parameter changes
  %
  % Methods:
  %   Filter(domain, kernel_name, ...)  - Constructor
  %   setParameter(name, value)         - Set single parameter
  %   setParameters(...)                - Set multiple parameters
  %   evaluate(points)                  - Evaluate filter response
  %   invalidateCache()                 - Mark cached response as invalid
  %
  % Example - Create Gaussian filter on Omega domain:
  %   B = bct();
  %   B.Time = bct.Time(0:0.01:1, 100);
  %   B.Omega = B.Time.dual;
  %   
  %   filt = bct.filters.Filter(B.Omega, 'gaussian', ...
  %       'center', 10, 'sigma', 2, 'label', 'alpha');
  %   
  %   % Evaluate filter
  %   H = filt.evaluate();  % Uses Omega.axis
  %   
  %   % Update parameters (for GUI sliders)
  %   filt.center = 12;    % Direct property access
  %   filt.sigma = 3;      % Automatically invalidates cache
  %   H_new = filt.evaluate();
  %
  % Example - Create heat filter on Lambda domain:
  %   B.Lambda = B.Manifold.dual;
  %   filt = bct.filters.Filter(B.Lambda, 'heat', 'tau', 0.1);
  %   H = filt.evaluate();
  %
  % Example - Create Gabor filter on Joint domain:
  %   joint = B.createJoint('Lambda', 'Omega');
  %   filt = bct.filters.Filter(joint, 'gabor', ...
  %       'center_x', 5, 'center_y', 10, ...
  %       'sigma_x', 1, 'sigma_y', 2);
  %   H = filt.evaluate();  % Returns [M×N] on joint grid
  %
  % See also: bct.filters.FilterDesigner, bct.filters.FilterBank,
  %           bct.Domain, bct.Joint
  
  properties
    Domain          % bct.Domain object (Manifold/Lambda/Time/Omega/Joint)
    KernelName      % String: 'gaussian', 'heat', 'gabor', etc.
    KernelFunction  % Function handle from kernels package
    Label           % Optional user label
  end
  
  properties (SetObservable, AbortSet)
    Parameters      % Struct of kernel parameters
  end
  
  properties (Dependent)
    % Convenient direct access to common parameters
    center          % For Gaussian, bandpass, etc.
    sigma           % For Gaussian, Gabor, etc.
    tau             % For heat kernel
    low             % Lower bound for bandpass
    high            % Upper bound for bandpass
    Response        % Cached filter response
  end
  
  properties (Access = private)
    CachedResponse       % Stored evaluation result
    CacheValid = false   % Whether cache is up-to-date
    AutoEvaluate = false % Whether to auto-recompute on param change
  end
  
  events
    ParametersChanged   % Fired when any parameter changes
  end
  
  methods
    function obj = Filter(domain, kernel_name, varargin)
      % Constructor
      %
      % Syntax:
      %   filt = Filter(domain, kernel_name, 'param', value, ...)
      %
      % Inputs:
      %   domain      - bct.Domain object (Manifold/Lambda/Time/Omega/Joint)
      %   kernel_name - String identifying kernel type
      %   varargin    - Parameter name-value pairs
      %
      % Name-Value Parameters:
      %   'label'        - Optional filter label (default: auto-generated)
      %   'AutoEvaluate' - Auto-recompute on parameter change (default: false)
      %   
      %   Kernel-specific parameters (depends on kernel_name):
      %   For 'gaussian': 'center', 'sigma'
      %   For 'heat': 'tau'
      %   For 'bandpass': 'low', 'high'
      %   For 'gabor': 'center_x', 'center_y', 'sigma_x', 'sigma_y'
      
      obj.Domain = domain;
      obj.KernelName = string(kernel_name);
      
      % Load appropriate kernel based on domain type
      obj.KernelFunction = obj.loadKernel(domain, kernel_name);
      
      % Parse and store parameters
      obj.Parameters = obj.parseParameters(kernel_name, varargin{:});
      
      % Extract special parameters
      if isfield(obj.Parameters, 'AutoEvaluate')
        obj.AutoEvaluate = obj.Parameters.AutoEvaluate;
        obj.Parameters = rmfield(obj.Parameters, 'AutoEvaluate');
      end
      
      if isfield(obj.Parameters, 'label')
        obj.Label = obj.Parameters.label;
        obj.Parameters = rmfield(obj.Parameters, 'label');
      else
        obj.Label = sprintf('%s_%s', class(domain), kernel_name);
      end
      
      % Add listener for parameter changes
      addlistener(obj, 'Parameters', 'PostSet', ...
        @(src, evt) obj.onParametersChanged(evt));
    end
    
    %% Parameter Management
    
    function setParameter(obj, param_name, value)
      % Set a single parameter and invalidate cache
      %
      % Syntax:
      %   filt.setParameter('center', 15);
      %   filt.setParameter('sigma', 3);
      %
      % This is the preferred method for programmatic parameter updates
      
      if ~isfield(obj.Parameters, param_name)
        warning('Filter:UnknownParameter', ...
          'Parameter "%s" does not exist, adding it', param_name);
      end
      
      obj.Parameters.(param_name) = value;
      obj.invalidateCache();
      
      % Notify listeners
      notify(obj, 'ParametersChanged');
    end
    
    function setParameters(obj, varargin)
      % Set multiple parameters at once
      %
      % Syntax:
      %   filt.setParameters('center', 15, 'sigma', 3);
      
      p = inputParser;
      p.KeepUnmatched = true;
      parse(p, varargin{:});
      
      % Update all parameters
      fields = fieldnames(p.Unmatched);
      for i = 1:length(fields)
        obj.Parameters.(fields{i}) = p.Unmatched.(fields{i});
      end
      
      obj.invalidateCache();
      notify(obj, 'ParametersChanged');
    end
    
    %% Dependent Property Getters/Setters
    
    function val = get.center(obj)
      if isfield(obj.Parameters, 'center')
        val = obj.Parameters.center;
      else
        val = [];
      end
    end
    
    function set.center(obj, val)
      obj.setParameter('center', val);
    end
    
    function val = get.sigma(obj)
      if isfield(obj.Parameters, 'sigma')
        val = obj.Parameters.sigma;
      else
        val = [];
      end
    end
    
    function set.sigma(obj, val)
      obj.setParameter('sigma', val);
    end
    
    function val = get.tau(obj)
      if isfield(obj.Parameters, 'tau')
        val = obj.Parameters.tau;
      else
        val = [];
      end
    end
    
    function set.tau(obj, val)
      obj.setParameter('tau', val);
    end
    
    function val = get.low(obj)
      if isfield(obj.Parameters, 'low')
        val = obj.Parameters.low;
      else
        val = [];
      end
    end
    
    function set.low(obj, val)
      obj.setParameter('low', val);
    end
    
    function val = get.high(obj)
      if isfield(obj.Parameters, 'high')
        val = obj.Parameters.high;
      else
        val = [];
      end
    end
    
    function set.high(obj, val)
      obj.setParameter('high', val);
    end
    
    function H = get.Response(obj)
      % Get cached response, computing if necessary
      if ~obj.CacheValid || isempty(obj.CachedResponse)
        obj.CachedResponse = obj.evaluate();
        obj.CacheValid = true;
      end
      H = obj.CachedResponse;
    end
    
    %% Evaluation
    
    function response = evaluate(obj, points)
      % Evaluate filter at given points or domain axis
      %
      % Syntax:
      %   H = filt.evaluate()        % Uses domain.axis
      %   H = filt.evaluate(x)       % Custom evaluation points
      %
      % Inputs:
      %   points - (Optional) Evaluation points
      %            For 1D domains: vector [N×1]
      %            For Joint domains: cell {X_grid, Y_grid} or omit for domain grids
      %
      % Returns:
      %   response - Filter response values
      %              1D domains: [N×1] vector
      %              Joint domains: [M×N] matrix
      
      if nargin < 2
        % Use domain axis/grids by default
        if isa(obj.Domain, 'bct.Joint')
          % For Joint domains, use grids not axis
          points = {obj.Domain.A_grid, obj.Domain.B_grid};
        else
          % For 1D domains, use axis
          points = obj.Domain.axis;
        end
      end
      
      % Evaluate based on domain dimensionality
      if isa(obj.Domain, 'bct.Joint')
        % 2D evaluation on joint domain
        response = obj.evaluateJoint(points);
      else
        % 1D evaluation on canonical domain
        response = obj.evaluateCanonical(points);
      end
      
      % Update cache if using default evaluation
      if nargin < 2
        obj.CachedResponse = response;
        obj.CacheValid = true;
      end
    end
    
    function invalidateCache(obj)
      % Mark cache as invalid
      %
      % Automatically called when parameters change.
      % Can be called manually if domain changes.
      
      obj.CacheValid = false;
      
      % Auto-reevaluate if enabled
      if obj.AutoEvaluate
        obj.CachedResponse = obj.evaluate();
        obj.CacheValid = true;
      end
    end
  end
  
  methods (Access = private)
    function onParametersChanged(obj, ~)
      % Called when Parameters property changes
      obj.invalidateCache();
    end
    
    function kernel_fh = loadKernel(~, ~, kernel_name)
      % Load kernel function (domain-agnostic)
      %
      % Loads the kernel function from the kernel package.
      % Kernels are pure mathematical functions - domain specificity
      % is determined by binding to the Domain object, not by the kernel itself.
      
      % All kernels are in root package (domain-agnostic)
      pkg = 'bct.filters.kernels';
      
      % Get kernel function
      try
        kernel_fh = feval(sprintf('%s.%s', pkg, kernel_name));
      catch ME
        error('Filter:KernelNotFound', ...
          'Kernel "%s" not found in package "%s".\nOriginal error: %s', ...
          kernel_name, pkg, ME.message);
      end
    end
    
    function params = parseParameters(~, kernel_name, varargin)
      % Parse kernel-specific parameters
      %
      % Defines default parameters for each kernel type and parses
      % user-provided values.
      
      p = inputParser;
      p.KeepUnmatched = true;
      
      % Common parameters
      addParameter(p, 'label', '', @(x) ischar(x) || isstring(x));
      addParameter(p, 'AutoEvaluate', false, @islogical);
      
      % Kernel-specific parameters
      switch kernel_name
        case 'gaussian'
          addParameter(p, 'center', 0, @isnumeric);
          addParameter(p, 'sigma', 1, @isnumeric);
          
        case 'heat'
          addParameter(p, 'tau', 0.1, @isnumeric);
          
        case 'mexican_hat'
          addParameter(p, 'scale', 1, @isnumeric);
          
        case 'bandpass'
          addParameter(p, 'low', 0, @isnumeric);
          addParameter(p, 'high', Inf, @isnumeric);
          
        case 'gabor'
          addParameter(p, 'center_x', 0, @isnumeric);
          addParameter(p, 'center_y', 0, @isnumeric);
          addParameter(p, 'sigma_x', 1, @isnumeric);
          addParameter(p, 'sigma_y', 1, @isnumeric);
          
        case 'separable'
          addParameter(p, 'kernel_x', [], @(x) isa(x, 'function_handle'));
          addParameter(p, 'kernel_y', [], @(x) isa(x, 'function_handle'));
          addParameter(p, 'params_x', {}, @iscell);
          addParameter(p, 'params_y', {}, @iscell);
          
        otherwise
          % Allow arbitrary parameters for custom kernels
          warning('Filter:UnknownKernel', ...
            'Unknown kernel "%s". Accepting arbitrary parameters.', kernel_name);
      end
      
      parse(p, varargin{:});
      params = p.Results;
    end
    
    function H = evaluateCanonical(obj, x)
      % Evaluate on 1D domain
      %
      % Extracts parameters from Parameters struct and calls kernel function.
      
      % Get parameter names and values (excluding label, AutoEvaluate)
      param_names = fieldnames(obj.Parameters);
      param_values = cell(length(param_names), 1);
      
      for i = 1:length(param_names)
        param_values{i} = obj.Parameters.(param_names{i});
      end
      
      % Call kernel function with parameters
      H = obj.KernelFunction(x, param_values{:});
    end
    
    function H = evaluateJoint(obj, points)
      % Evaluate on 2D joint domain
      %
      % Uses joint domain grids or custom grid points.
      
      if nargin < 2 || isempty(points)
        % Use joint grids from domain
        X = obj.Domain.A_grid;
        Y = obj.Domain.B_grid;
      elseif iscell(points) && length(points) == 2
        % Custom grids provided
        X = points{1};
        Y = points{2};
      else
        % Assume domain axis for 1D evaluation (shouldn't happen for Joint)
        error('Filter:InvalidJointPoints', ...
          'Joint domain requires 2D grid points as cell {X, Y}');
      end
      
      % Extract parameters
      param_names = fieldnames(obj.Parameters);
      param_values = cell(length(param_names), 1);
      
      for i = 1:length(param_names)
        param_values{i} = obj.Parameters.(param_names{i});
      end
      
      % Evaluate joint kernel
      H = obj.KernelFunction(X, Y, param_values{:});
    end
  end
end
