classdef FilterDesigner < handle
  % FilterDesigner - Domain-agnostic factory for creating Filter objects
  %
  % FilterDesigner creates filters by combining:
  %   1. A kernel function (mathematical shape: gaussian, heat, gabor, etc.)
  %   2. A domain (where the kernel is evaluated: Lambda, Omega, Joint, etc.)
  %   3. Parameters (center, sigma, tau, etc.)
  %
  % The filter is domain-agnostic at creation but domain-aware at evaluation.
  %
  % Properties:
  %   BCT - Reference to bct object for accessing domains
  %
  % Methods:
  %   FilterDesigner(bct_obj)              - Constructor
  %   create(domain, kernel_name, ...)     - Create filter on any domain
  %   lambda(kernel_name, ...)             - Shortcut for B.Lambda
  %   omega(kernel_name, ...)              - Shortcut for B.Omega  
  %   joint(kernel_name, ...)              - Shortcut for B.Joint
  %
  % Core Design Principle:
  %   A filter's shape (e.g., Gaussian) is independent of domain.
  %   A filter's meaning (e.g., Gaussian on λ vs k vs ω) depends on domain.
  %   Therefore: create(domain, kernel) explicitly binds shape to meaning.
  %
  % Example - Explicit domain specification:
  %   designer = bct.filters.FilterDesigner(B);
  %   
  %   % Gaussian filter on Lambda domain (spectral filtering)
  %   filt1 = designer.create(B.Lambda, 'gaussian', 'center', 50, 'sigma', 10);
  %   
  %   % Same Gaussian shape, but on Omega domain (temporal filtering)
  %   filt2 = designer.create(B.Omega, 'gaussian', 'center', 10, 'sigma', 2);
  %   
  %   % Joint filter on Lambda×Omega
  %   filt3 = designer.create(B.Joint, 'gabor', ...
  %       'center_x', 50, 'center_y', 10, ...
  %       'sigma_x', 10, 'sigma_y', 2);
  %
  % Example - Using shortcuts (cleaner but same result):
  %   filt1 = designer.lambda('gaussian', 'center', 50, 'sigma', 10);
  %   filt2 = designer.omega('gaussian', 'center', 10, 'sigma', 2);
  %   filt3 = designer.joint('gabor', ...
  %       'center_x', 50, 'center_y', 10, ...
  %       'sigma_x', 10, 'sigma_y', 2);
  %
  % Example - Custom domains:
  %   % Create filter on Time domain (not Omega)
  %   filt = designer.create(B.Time, 'gaussian', 'center', 0.5, 'sigma', 0.1);
  %   
  %   % Create filter on Manifold (vertex space, not spectral)
  %   filt = designer.create(B.Manifold, 'delta', 'location', 1000);
  %
  % See also: bct.filters.Filter, bct.filters.FilterBank
  
  properties
    BCT  % Reference to bct object for accessing domains
  end
  
  methods
    function obj = FilterDesigner(bct_obj)
      % Constructor
      %
      % Syntax:
      %   designer = FilterDesigner(bct_obj)
      %
      % Inputs:
      %   bct_obj - bct object with configured domains
      
      if ~isa(bct_obj, 'bct.bct')
        error('FilterDesigner:InvalidInput', ...
          'Input must be a bct object');
      end
      
      obj.BCT = bct_obj;
    end
    
    function filt = create(obj, domain, kernel_name, varargin)
      % Create filter on any domain (MAIN METHOD)
      %
      % Syntax:
      %   filt = designer.create(domain, kernel_name, 'param', value, ...)
      %
      % Inputs:
      %   domain      - bct.Domain object (Lambda, Omega, Joint, Time, Manifold, etc.)
      %   kernel_name - Kernel type: 'gaussian', 'heat', 'gabor', 'bandpass', etc.
      %   varargin    - Parameter name-value pairs (kernel-specific)
      %
      % Returns:
      %   filt - bct.filters.Filter object bound to specified domain
      %
      % Examples:
      %   % Spectral filter (on eigenvalues)
      %   filt = designer.create(B.Lambda, 'gaussian', 'center', 50, 'sigma', 10);
      %   
      %   % Temporal filter (on angular frequency)
      %   filt = designer.create(B.Omega, 'gaussian', 'center', 2*pi*10, 'sigma', 2*pi*2);
      %   
      %   % Joint spatiotemporal filter
      %   filt = designer.create(B.Joint, 'gabor', ...
      %       'center_x', 50, 'center_y', 2*pi*10, ...
      %       'sigma_x', 10, 'sigma_y', 2*pi*2);
      %
      % See also: lambda, omega, joint
      
      if ~isa(domain, 'bct.Domain')
        error('FilterDesigner:InvalidDomain', ...
          'First argument must be a bct.Domain object (Lambda, Omega, Joint, etc.)');
      end
      
      % Create filter with domain, kernel, and parameters
      filt = bct.filters.Filter(domain, kernel_name, varargin{:});
    end
    
    function filt = lambda(obj, kernel_name, varargin)
      % Create filter on Lambda (spectral) domain - SHORTCUT
      %
      % Syntax:
      %   filt = designer.lambda(kernel_name, 'param', value, ...)
      %
      % Inputs:
      %   kernel_name - Kernel type: 'gaussian', 'heat', 'mexican_hat', etc.
      %   varargin    - Parameter name-value pairs
      %
      % Returns:
      %   filt - bct.filters.Filter object on B.Lambda
      %
      % Example:
      %   filt = designer.lambda('gaussian', 'center', 50, 'sigma', 10, 'label', 'bandpass');
      %
      % Note: Equivalent to designer.create(B.Lambda, kernel_name, ...)
      
      if isempty(obj.BCT.Lambda)
        error('FilterDesigner:NoLambda', ...
          'Lambda domain not initialized. Compute eigendecomposition first: B = B.computeEigenbasis(k)');
      end
      
      filt = obj.create(obj.BCT.Lambda, kernel_name, varargin{:});
    end
    
    function filt = omega(obj, kernel_name, varargin)
      % Create filter on Omega (frequency) domain - SHORTCUT
      %
      % Syntax:
      %   filt = designer.omega(kernel_name, 'param', value, ...)
      %
      % Inputs:
      %   kernel_name - Kernel type: 'gaussian', 'bandpass', etc.
      %   varargin    - Parameter name-value pairs
      %
      % Returns:
      %   filt - bct.filters.Filter object on B.Omega
      %
      % Example:
      %   filt = designer.omega('gaussian', 'center', 2*pi*10, 'sigma', 2*pi*2, 'label', 'alpha');
      %
      % Note: Equivalent to designer.create(B.Omega, kernel_name, ...)
      
      if isempty(obj.BCT.Omega)
        error('FilterDesigner:NoOmega', ...
          'Omega domain not initialized. Omega is auto-created when Time is set: B.Time = bct.Time(...)');
      end
      
      filt = obj.create(obj.BCT.Omega, kernel_name, varargin{:});
    end
    
    function filt = joint(obj, kernel_name, varargin)
      % Create filter on Joint domain - SHORTCUT
      %
      % Syntax:
      %   filt = designer.joint(kernel_name, 'param', value, ...)
      %   filt = designer.joint(kernel_name, 'domains', {domA, domB}, ...)
      %
      % Inputs:
      %   kernel_name - Kernel type: 'gabor', 'separable', etc.
      %   varargin    - Parameter name-value pairs
      %
      % Name-Value Parameters:
      %   'domains' - Cell array {'DomainA', 'DomainB'} to create Joint
      %               Default: uses existing B.Joint
      %
      % Returns:
      %   filt - bct.filters.Filter object on Joint domain
      %
      % Examples:
      %   % Use existing Joint domain
      %   filt = designer.joint('gabor', ...
      %       'center_x', 50, 'center_y', 2*pi*10, ...
      %       'sigma_x', 10, 'sigma_y', 2*pi*2);
      %   
      %   % Auto-create Joint domain from Lambda×Time
      %   filt = designer.joint('gabor', ...
      %       'domains', {'Lambda', 'Time'}, ...
      %       'center_x', 50, 'center_y', 0.5, ...
      %       'sigma_x', 10, 'sigma_y', 0.1);
      %
      % Note: Equivalent to designer.create(B.Joint, kernel_name, ...)
      
      % Parse domains parameter
      p = inputParser;
      p.KeepUnmatched = true;
      addParameter(p, 'domains', {}, @iscell);
      parse(p, varargin{:});
      
      % Get or create Joint domain
      if ~isempty(p.Results.domains)
        % User specified domains to combine
        if length(p.Results.domains) ~= 2
          error('FilterDesigner:InvalidDomains', ...
            'domains must be cell array with 2 elements: {''DomainA'', ''DomainB''}');
        end
        
        domA_name = p.Results.domains{1};
        domB_name = p.Results.domains{2};
        
        % Check if Joint already exists with these domains
        if ~isempty(obj.BCT.Joint) && ...
            strcmp(obj.BCT.Joint.A.name, domA_name) && ...
            strcmp(obj.BCT.Joint.B.name, domB_name)
          joint = obj.BCT.Joint;
        else
          % Create new Joint domain
          joint = obj.BCT.createJoint(domA_name, domB_name);
        end
      else
        % Use existing Joint domain
        if isempty(obj.BCT.Joint)
          error('FilterDesigner:NoJoint', ...
            'Joint domain not initialized. Create with B.createJoint(''Lambda'', ''Omega'') or specify ''domains'' parameter');
        end
        joint = obj.BCT.Joint;
      end
      
      % Remove 'domains' from varargin before passing to create()
      remaining_args = {};
      skip_next = false;
      for i = 1:length(varargin)
        if skip_next
          skip_next = false;
          continue;
        end
        if ischar(varargin{i}) && strcmp(varargin{i}, 'domains')
          skip_next = true;
          continue;
        end
        remaining_args{end+1} = varargin{i}; %#ok<AGROW>
      end
      
      filt = obj.create(joint, kernel_name, remaining_args{:});
    end
    
    %% Legacy methods (DEPRECATED - use create() instead)
    
    function filt = spatial(obj, kernel_name, varargin)
      % DEPRECATED: Use lambda() or create(B.Lambda, ...) instead
      warning('FilterDesigner:Deprecated', ...
        'spatial() is deprecated. Use lambda() or create(B.Lambda, ...) for clarity');
      filt = obj.lambda(kernel_name, varargin{:});
    end
    
    function filt = temporal(obj, kernel_name, varargin)
      % DEPRECATED: Use omega() or create(B.Omega, ...) instead
      warning('FilterDesigner:Deprecated', ...
        'temporal() is deprecated. Use omega() or create(B.Omega, ...) for clarity');
      filt = obj.omega(kernel_name, varargin{:});
    end
  end
end
