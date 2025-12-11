classdef JointKernelEditor < bct.ui.KernelEditor
  % JointKernelEditor - Interactive editor for joint domain filters
  %
  % Implements KernelEditor for Joint domains (e.g., Lambda×Omega, Lambda×Time),
  % supporting both separable and non-separable kernels.
  %
  % For SEPARABLE kernels:
  %   - Independently control kernels on each domain (A and B)
  %   - Center_A, Width_A for first domain
  %   - Center_B, Width_B for second domain
  %
  % For NON-SEPARABLE kernels (e.g., velocity_gabor):
  %   - Control coupling parameters: Velocity, Dispersion
  %   - These parameters define relationships between domains
  %   - Example: ω = v√λ + Dλ (velocity + dispersion relation)
  %
  % Properties (inherited):
  %   Center - Primary center (domain A or coupling center)
  %   Width  - Primary width (domain A or coupling width)
  %   Domain - Joint domain object
  %   Filter - Associated filter object
  %
  % Additional Properties:
  %   Center_B     - Center for domain B (separable kernels)
  %   Width_B      - Width for domain B (separable kernels)
  %   Velocity     - Velocity parameter v (non-separable kernels)
  %   Dispersion   - Dispersion parameter D (non-separable kernels)
  %   KernelType   - 'separable' or 'nonseparable'
  %
  % Methods (inherited):
  %   shiftForward()  - Shift center in domain A (or velocity for nonseparable)
  %   shiftBackward() - Shift center backward
  %   expand()        - Increase width
  %   contract()      - Decrease width
  %
  % Additional Methods:
  %   shiftForward_B()   - Shift center in domain B (separable only)
  %   shiftBackward_B()  - Shift center backward in domain B
  %   expand_B()         - Increase width in domain B
  %   contract_B()       - Decrease width in domain B
  %   setVelocity(v)     - Set velocity parameter (nonseparable only)
  %   setDispersion(D)   - Set dispersion parameter (nonseparable only)
  %
  % Example - Separable Gabor on Lambda×Omega:
  %   joint = B.createJoint('Lambda', 'Omega');
  %   filt = bct.filters.Filter(joint, 'gabor', ...
  %       'center_x', 50, 'center_y', 10, ...
  %       'sigma_x', 10, 'sigma_y', 2);
  %   
  %   editor = bct.filters.JointKernelEditor(joint, filt, 50, 10, ...
  %       'KernelType', 'separable', 'Center_B', 10, 'Width_B', 2);
  %   
  %   % Independent control
  %   editor.setCenter(60);      % Lambda center
  %   editor.setCenter_B(12);    % Omega center
  %
  % Example - Non-separable velocity Gabor:
  %   filt = bct.filters.Filter(joint, 'velocity_gabor', ...
  %       'v', 0.5, 'sigma_w', 10, 'lambda0', 50, 'sigma_l', 20);
  %   
  %   editor = bct.filters.JointKernelEditor(joint, filt, 50, 20, ...
  %       'KernelType', 'nonseparable', 'Velocity', 0.5, 'Dispersion', 0);
  %   
  %   % Coupling control
  %   editor.setVelocity(0.7);      % Change tilt
  %   editor.setDispersion(0.01);   % Add curvature
  %
  % See also: bct.ui.KernelEditor, bct.Joint, bct.filters.Filter
  
  properties
    Center_B       % Center for domain B (separable kernels)
    Width_B        % Width for domain B (separable kernels)
    Velocity       % Velocity parameter v (nonseparable: ω ∝ v√λ)
    Dispersion     % Dispersion parameter D (nonseparable: ω ∝ Dλ)
    KernelType     % 'separable' or 'nonseparable'
  end
  
  properties (Access = private)
    StepSize_B     % Navigation step for domain B
  end
  
  methods
    function obj = JointKernelEditor(jointDomain, filter, center, width, varargin)
      % Constructor
      %
      % Syntax:
      %   editor = JointKernelEditor(joint, filter, center, width)
      %   editor = JointKernelEditor(..., 'KernelType', 'separable')
      %   editor = JointKernelEditor(..., 'Velocity', 0.5, 'Dispersion', 0)
      %
      % Inputs:
      %   jointDomain - bct.Joint domain object
      %   filter      - bct.filters.Filter object
      %   center      - Initial center (domain A or spatial center)
      %   width       - Initial width (domain A or spatial width)
      %
      % Name-Value Parameters:
      %   'KernelType'  - 'separable' or 'nonseparable' (default: 'separable')
      %   'Center_B'    - Center for domain B (separable, default: 0)
      %   'Width_B'     - Width for domain B (separable, default: width)
      %   'Velocity'    - Velocity parameter (nonseparable, default: 0.5)
      %   'Dispersion'  - Dispersion parameter (nonseparable, default: 0)
      
      % Validate joint domain
      if ~isa(jointDomain, 'bct.Joint')
        error('JointKernelEditor:InvalidDomain', ...
          'Domain must be a bct.Joint object');
      end
      
      % Call superclass constructor
      obj@bct.ui.KernelEditor(jointDomain, filter, center, width);
      
      % Parse joint-specific parameters
      p = inputParser;
      addParameter(p, 'KernelType', 'separable', ...
        @(x) ismember(x, {'separable', 'nonseparable'}));
      addParameter(p, 'Center_B', 0, @isnumeric);
      addParameter(p, 'Width_B', width, @isnumeric);
      addParameter(p, 'Velocity', 0.5, @isnumeric);
      addParameter(p, 'Dispersion', 0, @isnumeric);
      parse(p, varargin{:});
      
      obj.KernelType = p.Results.KernelType;
      obj.Center_B = p.Results.Center_B;
      obj.Width_B = p.Results.Width_B;
      obj.Velocity = p.Results.Velocity;
      obj.Dispersion = p.Results.Dispersion;
      
      % Set step size for domain B
      domainB = jointDomain.B;
      if isprop(domainB, 'dt')
        obj.StepSize_B = domainB.dt;
      elseif isprop(domainB, 'df')
        obj.StepSize_B = domainB.df;
      elseif length(domainB.axis) > 1
        obj.StepSize_B = mean(diff(domainB.axis));
      else
        obj.StepSize_B = 1;
      end
    end
    
    %% Domain B Navigation (Separable Kernels)
    
    function shiftForward_B(obj, nSteps)
      % Move center forward in domain B
      %
      % Syntax:
      %   editor.shiftForward_B()      % Move 1 step
      %   editor.shiftForward_B(5)     % Move 5 steps
      
      if nargin < 2, nSteps = 1; end
      
      if strcmp(obj.KernelType, 'separable')
        obj.Center_B = obj.Center_B + nSteps * obj.StepSize_B;
        obj.update();
      else
        warning('JointKernelEditor:NotSeparable', ...
          'shiftForward_B only applies to separable kernels');
      end
    end
    
    function shiftBackward_B(obj, nSteps)
      % Move center backward in domain B
      
      if nargin < 2, nSteps = 1; end
      
      if strcmp(obj.KernelType, 'separable')
        obj.Center_B = obj.Center_B - nSteps * obj.StepSize_B;
        obj.update();
      else
        warning('JointKernelEditor:NotSeparable', ...
          'shiftBackward_B only applies to separable kernels');
      end
    end
    
    function expand_B(obj, factor)
      % Increase width in domain B
      
      if strcmp(obj.KernelType, 'separable')
        if nargin < 2
          obj.Width_B = obj.Width_B + obj.StepSize_B;
        else
          obj.Width_B = obj.Width_B * factor;
        end
        obj.update();
      else
        warning('JointKernelEditor:NotSeparable', ...
          'expand_B only applies to separable kernels');
      end
    end
    
    function contract_B(obj, factor)
      % Decrease width in domain B
      
      if strcmp(obj.KernelType, 'separable')
        if nargin < 2
          newWidth = obj.Width_B - obj.StepSize_B;
          obj.Width_B = max(newWidth, obj.StepSize_B);
        else
          obj.Width_B = obj.Width_B * factor;
        end
        obj.update();
      else
        warning('JointKernelEditor:NotSeparable', ...
          'contract_B only applies to separable kernels');
      end
    end
    
    function setCenter_B(obj, value)
      % Set center for domain B (separable kernels)
      %
      % Syntax:
      %   editor.setCenter_B(15)
      
      if strcmp(obj.KernelType, 'separable')
        obj.Center_B = value;
        obj.update();
      else
        warning('JointKernelEditor:NotSeparable', ...
          'setCenter_B only applies to separable kernels');
      end
    end
    
    function setWidth_B(obj, value)
      % Set width for domain B (separable kernels)
      
      if strcmp(obj.KernelType, 'separable')
        obj.Width_B = value;
        obj.update();
      else
        warning('JointKernelEditor:NotSeparable', ...
          'setWidth_B only applies to separable kernels');
      end
    end
    
    %% Coupling Parameter Control (Non-separable Kernels)
    
    function setVelocity(obj, v)
      % Set velocity parameter (non-separable kernels)
      %
      % The velocity parameter v controls the tilt of the kernel ridge
      % in joint space, defining the dispersion relation ω = v√λ + Dλ
      %
      % Syntax:
      %   editor.setVelocity(0.7)  % Increase slope
      %
      % Inputs:
      %   v - Velocity parameter (scalar)
      
      if strcmp(obj.KernelType, 'nonseparable')
        obj.Velocity = v;
        obj.update();
      else
        warning('JointKernelEditor:NotNonseparable', ...
          'setVelocity only applies to nonseparable kernels');
      end
    end
    
    function setDispersion(obj, D)
      % Set dispersion parameter (non-separable kernels)
      %
      % The dispersion parameter D controls the curvature of the kernel
      % ridge in joint space: ω = v√λ + Dλ
      %
      % Syntax:
      %   editor.setDispersion(0.01)  % Add curvature
      %
      % Inputs:
      %   D - Dispersion coefficient (scalar)
      
      if strcmp(obj.KernelType, 'nonseparable')
        obj.Dispersion = D;
        obj.update();
      else
        warning('JointKernelEditor:NotNonseparable', ...
          'setDispersion only applies to nonseparable kernels');
      end
    end
    
    function shiftVelocity(obj, delta)
      % Adjust velocity by small increment
      %
      % Syntax:
      %   editor.shiftVelocity(0.05)   % Increase velocity
      %   editor.shiftVelocity(-0.05)  % Decrease velocity
      
      if strcmp(obj.KernelType, 'nonseparable')
        obj.Velocity = obj.Velocity + delta;
        obj.update();
      end
    end
    
    function shiftDispersion(obj, delta)
      % Adjust dispersion by small increment
      
      if strcmp(obj.KernelType, 'nonseparable')
        obj.Dispersion = obj.Dispersion + delta;
        obj.update();
      end
    end
    
    %% Abstract Method Implementation
    
    function kernel = computeKernel(obj)
      % Compute joint kernel on joint domain grids
      %
      % Returns:
      %   kernel - [M×N] kernel values on joint grids
      
      % Get joint grids
      lambda_grid = obj.Domain.A_grid;  % Spatial domain grid
      omega_grid = obj.Domain.B_grid;   % Temporal/frequency domain grid
      
      switch obj.KernelType
        case 'separable'
          % Separable kernel: product of 1D kernels
          kernel = obj.computeSeparableKernel(lambda_grid, omega_grid);
          
        case 'nonseparable'
          % Non-separable kernel with coupling (velocity/dispersion)
          kernel = obj.computeNonseparableKernel(lambda_grid, omega_grid);
          
        otherwise
          error('JointKernelEditor:UnknownKernelType', ...
            'Unknown kernel type: %s', obj.KernelType);
      end
      
      % Normalize
      if sum(kernel(:)) > 0
        kernel = kernel / sum(kernel(:));
      end
    end
  end
  
  methods (Access = private)
    function kernel = computeSeparableKernel(obj, X, Y)
      % Compute separable kernel: K(x,y) = K_x(x) * K_y(y)
      %
      % Uses Gaussian kernels on each domain independently
      
      % Kernel on domain A (e.g., Lambda)
      K_A = exp(-((X - obj.Center).^2) / (2 * obj.Width^2));
      
      % Kernel on domain B (e.g., Omega)
      K_B = exp(-((Y - obj.Center_B).^2) / (2 * obj.Width_B^2));
      
      % Separable product
      kernel = K_A .* K_B;
    end
    
    function kernel = computeNonseparableKernel(obj, lambda, omega)
      % Compute non-separable kernel with velocity and dispersion
      %
      % K(λ,ω) = exp(-((ω - (v√λ + Dλ))² / (2σ_w²))) · exp(-((λ - λ₀)² / (2σ_λ²)))
      %
      % This creates a tilted/curved ridge in joint space
      
      v = obj.Velocity;
      D = obj.Dispersion;
      lambda0 = obj.Center;     % Center eigenvalue
      sigma_l = obj.Width;      % Spatial bandwidth
      sigma_w = obj.Width_B;    % Temporal bandwidth
      
      % Dispersion relation: ω_ridge(λ) = v√λ + Dλ
      omega_ridge = v * sqrt(abs(lambda)) + D * lambda;
      
      % Temporal ridge kernel (follows dispersion relation)
      ridge = exp(-((omega - omega_ridge).^2) / (2 * sigma_w^2));
      
      % Spatial bandpass kernel
      spatial_bandpass = exp(-((lambda - lambda0).^2) / (2 * sigma_l^2));
      
      % Non-separable product
      kernel = ridge .* spatial_bandpass;
    end
  end
  
  methods (Access = protected)
    function updateFilter(obj, kernel)
      % Update filter with joint kernel parameters
      %
      % Overrides base class to handle both separable and nonseparable cases
      
      switch obj.KernelType
        case 'separable'
          % Update separable parameters (center_x, center_y, sigma_x, sigma_y)
          obj.Filter.setParameter('center_x', obj.Center);
          obj.Filter.setParameter('sigma_x', obj.Width);
          obj.Filter.setParameter('center_y', obj.Center_B);
          obj.Filter.setParameter('sigma_y', obj.Width_B);
          
        case 'nonseparable'
          % Update nonseparable parameters (v, sigma_w, lambda0, sigma_l, D)
          obj.Filter.setParameter('v', obj.Velocity);
          obj.Filter.setParameter('sigma_w', obj.Width_B);
          obj.Filter.setParameter('lambda0', obj.Center);
          obj.Filter.setParameter('sigma_l', obj.Width);
          
          % Add dispersion if filter supports it
          if isfield(obj.Filter.Parameters, 'D')
            obj.Filter.setParameter('D', obj.Dispersion);
          end
      end
      
      % Invalidate filter cache
      obj.Filter.invalidateCache();
    end
  end
end
