classdef FilterDesigner < handle
  % FilterDesigner - Factory for creating filters with domain validation
  %
  % FilterDesigner provides convenient methods for creating Filter objects
  % with automatic domain validation and kernel loading. It simplifies the
  % filter creation process by providing domain-specific factory methods.
  %
  % Properties:
  %   BCT - Reference to bct object for accessing domains
  %
  % Methods:
  %   FilterDesigner(bct_obj)           - Constructor
  %   spatial(kernel_name, ...)         - Create filter on Lambda domain
  %   temporal(kernel_name, ...)        - Create filter on Omega domain
  %   joint(kernel_name, ...)           - Create filter on Joint domain
  %   custom(domain, kernel_name, ...)  - Create filter on custom domain
  %
  % Example - Basic usage:
  %   B = bct();
  %   B.Time = bct.Time(0:0.01:1, 100);
  %   B.Omega = B.Time.dual;
  %   B.Lambda = B.Manifold.dual;
  %   
  %   designer = bct.filters.FilterDesigner(B);
  %   
  %   % Design filters
  %   filt1 = designer.temporal('gaussian', 'center', 10, 'sigma', 2);
  %   filt2 = designer.spatial('heat', 'tau', 0.1);
  %   filt3 = designer.joint('gabor', ...
  %       'center_x', 5, 'center_y', 10, ...
  %       'sigma_x', 1, 'sigma_y', 2);
  %
  % Example - With automatic Joint domain creation:
  %   filt = designer.joint('gabor', ...
  %       'domains', {'Lambda', 'Omega'}, ...  % Auto-creates Joint
  %       'center_x', 5, 'center_y', 10, ...
  %       'sigma_x', 1, 'sigma_y', 2);
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
      
      if ~isa(bct_obj, 'bct')
        error('FilterDesigner:InvalidInput', ...
          'Input must be a bct object');
      end
      
      obj.BCT = bct_obj;
    end
    
    function filt = spatial(obj, kernel_name, varargin)
      % Design filter on Lambda (spectral) domain
      %
      % Syntax:
      %   filt = designer.spatial(kernel_name, 'param', value, ...)
      %
      % Inputs:
      %   kernel_name - Kernel type: 'heat', 'mexican_hat', etc.
      %   varargin    - Parameter name-value pairs
      %
      % Returns:
      %   filt - bct.filters.Filter object on Lambda domain
      %
      % Example:
      %   filt = designer.spatial('heat', 'tau', 0.1, 'label', 'lowpass');
      
      if isempty(obj.BCT.Lambda)
        error('FilterDesigner:NoLambda', ...
          'Lambda domain not initialized. Compute eigendecomposition first.');
      end
      
      filt = bct.filters.Filter(obj.BCT.Lambda, kernel_name, varargin{:});
    end
    
    function filt = temporal(obj, kernel_name, varargin)
      % Design filter on Omega (frequency) domain
      %
      % Syntax:
      %   filt = designer.temporal(kernel_name, 'param', value, ...)
      %
      % Inputs:
      %   kernel_name - Kernel type: 'gaussian', 'bandpass', etc.
      %   varargin    - Parameter name-value pairs
      %
      % Returns:
      %   filt - bct.filters.Filter object on Omega domain
      %
      % Example:
      %   filt = designer.temporal('gaussian', ...
      %       'center', 10, 'sigma', 2, 'label', 'alpha');
      
      if isempty(obj.BCT.Omega)
        error('FilterDesigner:NoOmega', ...
          'Omega domain not initialized. Set B.Omega = B.Time.dual');
      end
      
      filt = bct.filters.Filter(obj.BCT.Omega, kernel_name, varargin{:});
    end
    
    function filt = joint(obj, kernel_name, varargin)
      % Design filter on Joint domain
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
      %   'domains' - Cell array {'DomainA', 'DomainB'} or Joint object
      %               Default: {'Lambda', 'Omega'}
      %
      % Returns:
      %   filt - bct.filters.Filter object on Joint domain
      %
      % Example:
      %   % Use existing Joint domain
      %   filt = designer.joint('gabor', ...
      %       'center_x', 5, 'center_y', 10);
      %   
      %   % Auto-create Joint domain
      %   filt = designer.joint('gabor', ...
      %       'domains', {'Lambda', 'Time'}, ...
      %       'center_x', 5, 'center_y', 0.5);
      
      % Parse domains parameter
      p = inputParser;
      p.KeepUnmatched = true;
      addParameter(p, 'domains', {'Lambda', 'Omega'}, ...
        @(x) iscell(x) || isa(x, 'bct.Joint'));
      parse(p, varargin{:});
      
      % Get or create Joint domain
      if isa(p.Results.domains, 'bct.Joint')
        joint = p.Results.domains;
      elseif iscell(p.Results.domains) && length(p.Results.domains) == 2
        % Create Joint domain from domain names
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
        error('FilterDesigner:InvalidDomains', ...
          'domains must be Joint object or cell array {''DomainA'', ''DomainB''}');
      end
      
      % Remove 'domains' from varargin before passing to Filter
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
      
      filt = bct.filters.Filter(joint, kernel_name, remaining_args{:});
    end
    
    function filt = custom(obj, domain, kernel_name, varargin)
      % Design filter on custom domain
      %
      % Syntax:
      %   filt = designer.custom(domain, kernel_name, 'param', value, ...)
      %
      % Inputs:
      %   domain      - Any bct.Domain object
      %   kernel_name - Kernel type
      %   varargin    - Parameter name-value pairs
      %
      % Returns:
      %   filt - bct.filters.Filter object on specified domain
      %
      % Example:
      %   filt = designer.custom(B.Time, 'gaussian', ...
      %       'center', 0.5, 'sigma', 0.1);
      
      if ~isa(domain, 'bct.Domain')
        error('FilterDesigner:InvalidDomain', ...
          'First argument must be a bct.Domain object');
      end
      
      filt = bct.filters.Filter(domain, kernel_name, varargin{:});
    end
  end
end
