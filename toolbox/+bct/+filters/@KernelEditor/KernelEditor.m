classdef (Abstract) KernelEditor < handle
  % KernelEditor - Abstract base class for interactive filter parameter editing
  %
  % KernelEditor provides a unified interface for modifying Filter objects
  % through GUI interactions such as time scrubbers, spatial windows, or
  % frequency band selectors. It bridges user interactions (e.g., slider
  % movements) to Filter parameter updates.
  %
  % The abstract design allows domain-specific subclasses to define their
  % own kernel computation rules while inheriting common navigation and
  % update logic.
  %
  % Properties:
  %   Center - Current center position in domain coordinates
  %   Width  - Current width/bandwidth in domain units
  %   Domain - Reference to bct.Domain (Time, Omega, Lambda, etc.)
  %   Filter - Associated bct.filters.Filter object
  %
  % Abstract Methods (must be implemented by subclasses):
  %   kernel = computeKernel(obj)
  %     - Returns kernel values evaluated on domain
  %     - Domain-specific logic (e.g., Gaussian on Time, heat on Lambda)
  %
  % Common Methods:
  %   shiftForward()   - Move center forward by domain step
  %   shiftBackward()  - Move center backward by domain step
  %   expand()         - Increase width by domain step
  %   contract()       - Decrease width by domain step
  %   update()         - Recompute kernel and update filter
  %   setCenter(val)   - Set center position
  %   setWidth(val)    - Set width/bandwidth
  %
  % Events:
  %   KernelChanged - Fired when kernel is updated
  %
  % Use Cases:
  %   1. Time Scrubber:
  %      - Navigate through temporal signal using time-windowing kernel
  %      - Center: current time point
  %      - Width: window duration
  %
  %   2. Spatial Patch Selector:
  %      - Define region of interest on Manifold
  %      - Center: spatial eigenmode number
  %      - Width: spatial bandwidth
  %
  %   3. Frequency Band Editor:
  %      - Interactively adjust bandpass filter on Omega domain
  %      - Center: center frequency
  %      - Width: bandwidth
  %
  % Example - Time Window Editor (subclass):
  %   editor = TimeWindowEditor(timeDomain, timeFilter);
  %   editor.setCenter(0.5);      % Center at t=0.5s
  %   editor.setWidth(0.1);       % 100ms window
  %   editor.shiftForward();      % Move window forward
  %   % Filter is automatically updated
  %
  % Subclass Implementation Pattern:
  %   classdef TimeWindowEditor < bct.filters.KernelEditor
  %     methods
  %       function kernel = computeKernel(obj)
  %         % Gaussian window on time axis
  %         t = obj.Domain.axis;
  %         kernel = exp(-((t - obj.Center).^2) / (2*obj.Width^2));
  %       end
  %     end
  %   end
  %
  % See also: bct.filters.Filter, bct.Domain, bct.Signal
  
  properties
    Center          % Current center position (domain coordinates)
    Width           % Current width/bandwidth (domain units)
    Domain          % Reference to bct.Domain object
    Filter          % Associated bct.filters.Filter object
  end
  
  properties (Access = protected)
    StepSize        % Navigation step size (default: domain spacing)
  end
  
  events
    KernelChanged   % Fired when kernel parameters change
  end
  
  methods (Abstract)
    % Compute kernel values on domain
    %
    % Must be implemented by subclasses to define domain-specific
    % kernel computation (e.g., Gaussian on Time, heat on Lambda)
    %
    % Returns:
    %   kernel - [N×1] vector of kernel values on domain.axis
    kernel = computeKernel(obj)
  end
  
  methods
    function obj = KernelEditor(domain, filter, center, width)
      % Constructor
      %
      % Syntax:
      %   editor = KernelEditor(domain, filter, center, width)
      %
      % Inputs:
      %   domain - bct.Domain object (Time, Lambda, Omega, etc.)
      %   filter - bct.filters.Filter object to control
      %   center - Initial center position (domain coordinates)
      %   width  - Initial width/bandwidth (domain units)
      
      obj.Domain = domain;
      obj.Filter = filter;
      obj.Center = center;
      obj.Width = width;
      
      % Set default step size to domain spacing
      if isprop(domain, 'dt')
        obj.StepSize = domain.dt;  % Time domain
      elseif isprop(domain, 'df')
        obj.StepSize = domain.df;  % Omega domain
      elseif length(domain.axis) > 1
        obj.StepSize = mean(diff(domain.axis));  % Generic spacing
      else
        obj.StepSize = 1;  % Fallback
      end
      
      % Initial update
      obj.update();
    end
    
    %% Navigation Methods
    
    function shiftForward(obj, nSteps)
      % Move center forward by domain step(s)
      %
      % Syntax:
      %   editor.shiftForward()      % Move 1 step forward
      %   editor.shiftForward(5)     % Move 5 steps forward
      %
      % Inputs:
      %   nSteps - (Optional) Number of steps (default: 1)
      
      if nargin < 2
        nSteps = 1;
      end
      
      obj.Center = obj.Center + nSteps * obj.StepSize;
      obj.update();
    end
    
    function shiftBackward(obj, nSteps)
      % Move center backward by domain step(s)
      %
      % Syntax:
      %   editor.shiftBackward()     % Move 1 step backward
      %   editor.shiftBackward(3)    % Move 3 steps backward
      %
      % Inputs:
      %   nSteps - (Optional) Number of steps (default: 1)
      
      if nargin < 2
        nSteps = 1;
      end
      
      obj.Center = obj.Center - nSteps * obj.StepSize;
      obj.update();
    end
    
    function expand(obj, factor)
      % Increase width by step or factor
      %
      % Syntax:
      %   editor.expand()       % Increase by 1 step
      %   editor.expand(1.5)    % Multiply width by 1.5
      %
      % Inputs:
      %   factor - (Optional) Multiplicative factor (default: 1 step increase)
      
      if nargin < 2
        obj.Width = obj.Width + obj.StepSize;
      else
        obj.Width = obj.Width * factor;
      end
      
      obj.update();
    end
    
    function contract(obj, factor)
      % Decrease width by step or factor
      %
      % Syntax:
      %   editor.contract()     % Decrease by 1 step
      %   editor.contract(0.8)  % Multiply width by 0.8
      %
      % Inputs:
      %   factor - (Optional) Multiplicative factor (default: 1 step decrease)
      
      if nargin < 2
        newWidth = obj.Width - obj.StepSize;
        obj.Width = max(newWidth, obj.StepSize);  % Don't go below 1 step
      else
        obj.Width = obj.Width * factor;
      end
      
      obj.update();
    end
    
    %% Parameter Setters
    
    function setCenter(obj, value)
      % Set center position
      %
      % Syntax:
      %   editor.setCenter(0.5)
      %
      % Inputs:
      %   value - New center position (domain coordinates)
      
      obj.Center = value;
      obj.update();
    end
    
    function setWidth(obj, value)
      % Set width/bandwidth
      %
      % Syntax:
      %   editor.setWidth(0.1)
      %
      % Inputs:
      %   value - New width (domain units)
      
      obj.Width = value;
      obj.update();
    end
    
    function setStepSize(obj, value)
      % Set navigation step size
      %
      % Syntax:
      %   editor.setStepSize(0.01)
      %
      % Inputs:
      %   value - Step size for shiftForward/shiftBackward
      
      obj.StepSize = value;
    end
    
    %% Update Logic
    
    function update(obj)
      % Recompute kernel and update associated filter
      %
      % This method:
      %   1. Calls computeKernel() (implemented by subclass)
      %   2. Updates filter parameters based on kernel
      %   3. Notifies listeners that kernel changed
      %
      % Called automatically by navigation and setter methods.
      
      % Compute new kernel using subclass implementation
      kernel = obj.computeKernel();
      
      % Update filter parameters
      % Subclasses may override this method for custom filter updates
      obj.updateFilter(kernel);
      
      % Notify listeners
      notify(obj, 'KernelChanged');
    end
  end
  
  methods (Access = protected)
    function updateFilter(obj, kernel)
      % Update filter object with new kernel
      %
      % Default implementation updates common filter parameters.
      % Subclasses can override for domain-specific behavior.
      %
      % Inputs:
      %   kernel - [N×1] kernel values
      
      % Update filter parameters if they exist
      if isprop(obj.Filter, 'center') || isfield(obj.Filter.Parameters, 'center')
        obj.Filter.setParameter('center', obj.Center);
      end
      
      if isprop(obj.Filter, 'sigma') || isfield(obj.Filter.Parameters, 'sigma')
        obj.Filter.setParameter('sigma', obj.Width);
      elseif isprop(obj.Filter, 'width') || isfield(obj.Filter.Parameters, 'width')
        obj.Filter.setParameter('width', obj.Width);
      end
      
      % Invalidate filter cache to force re-evaluation
      obj.Filter.invalidateCache();
    end
  end
end
