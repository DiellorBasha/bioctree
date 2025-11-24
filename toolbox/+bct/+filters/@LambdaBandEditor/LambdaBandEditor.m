classdef LambdaBandEditor < bct.filters.KernelEditor
  % LambdaBandEditor - Interactive spectral band selector for Lambda domain
  %
  % Implements KernelEditor for Lambda (spectral) domain, providing
  % a bandpass kernel for selecting spatial frequency bands. Operates on
  % the eigenvalue spectrum (λ₁, λ₂, ..., λₖ), not on the Manifold itself.
  %
  % The spectral band is defined as a Gaussian bandpass centered at a specific
  % eigenmode with adjustable bandwidth in eigenvalue space.
  %
  % Properties (inherited):
  %   Center - Center eigenmode index
  %   Width  - Spectral bandwidth (number of modes)
  %   Domain - Lambda domain object
  %   Filter - Associated filter object
  %
  % Methods (inherited):
  %   shiftForward()  - Move to higher spatial frequencies
  %   shiftBackward() - Move to lower spatial frequencies
  %   expand()        - Increase spatial bandwidth
  %   contract()      - Decrease spatial bandwidth
  %   setCenter(k)    - Jump to specific eigenmode
  %   setWidth(w)     - Set bandwidth
  %
  % Example - Spectral band selector for Lambda domain:
  %   B = bct.bct.fromMesh(V, F);
  %   B.Lambda = B.Lambda.eigenbasis(B.Manifold.MassMatrix, ...
  %                                    B.Manifold.CotangentMatrix, 500);
  %   
  %   % Create Gaussian filter on Lambda domain
  %   filt = bct.filters.Filter(B.Lambda, 'gaussian', ...
  %       'center', 50, 'sigma', 10);
  %   
  %   % Create editor for interactive control
  %   editor = bct.filters.LambdaBandEditor(B.Lambda, filt, 50, 10);
  %   
  %   % GUI slider callback:
  %   editor.setCenter(sliderValue);  % Update frequency band
  %   
  %   % Select low spatial frequencies (smooth patterns):
  %   editor.setCenter(20);
  %   editor.setWidth(5);
  %
% Example - Heat kernel for diffusion:
%   % Heat kernel variant using tau parameter
%   filt = bct.filters.Filter(B.Lambda, 'heat', 'tau', 0.1);
%   editor = bct.filters.LambdaBandEditor(B.Lambda, filt, 0, 0.1, ...
%       'KernelType', 'heat');
%
% Note: This operates on Lambda (spectral domain). For spatial patches
% on the Manifold itself, use ManifoldPatchEditor (requires shift operation).
%
% See also: bct.filters.KernelEditor, bct.Lambda, bct.Manifold
  
  properties
    KernelType = 'gaussian'  % 'gaussian', 'heat', 'mexican_hat'
  end
  
  methods
    function obj = LambdaBandEditor(lambdaDomain, filter, center, width, varargin)
      % Constructor
      %
      % Syntax:
      %   editor = LambdaBandEditor(lambdaDomain, filter, center, width)
      %   editor = LambdaBandEditor(..., 'KernelType', 'heat')
      %
      % Inputs:
      %   lambdaDomain - bct.Lambda domain object
      %   filter       - bct.filters.Filter object
      %   center       - Initial eigenmode center
      %   width        - Initial bandwidth/tau
      %
      % Name-Value Parameters:
      %   'KernelType' - Kernel function: 'gaussian' (default), 'heat', 
      %                  'mexican_hat'
      
      % Call superclass constructor
      obj@bct.filters.KernelEditor(lambdaDomain, filter, center, width);
      
      % Parse optional parameters
      p = inputParser;
      addParameter(p, 'KernelType', 'gaussian', ...
        @(x) ismember(x, {'gaussian', 'heat', 'mexican_hat'}));
      parse(p, varargin{:});
      
      obj.KernelType = p.Results.KernelType;
    end
    
    function kernel = computeKernel(obj)
      % Compute spectral band kernel on Lambda (eigenvalue) domain
      %
      % Returns:
      %   kernel - [K×1] kernel values on eigenvalue axis
      
      lambda = obj.Domain.axis;  % Eigenvalue axis
      
      switch obj.KernelType
        case 'gaussian'
          % Gaussian bandpass in spectral domain
          % Centered at eigenmode, width = bandwidth
          kernel = exp(-((lambda - obj.Center).^2) / (2 * obj.Width^2));
          
        case 'heat'
          % Heat kernel: exp(-tau * lambda)
          % Width parameter is tau (diffusion time)
          tau = obj.Width;
          kernel = exp(-tau * lambda);
          
        case 'mexican_hat'
          % Mexican hat (Laplacian of Gaussian) for edge detection
          sigma = obj.Width;
          normalized_lambda = (lambda - obj.Center) / sigma;
          kernel = (1 - normalized_lambda.^2) .* ...
                   exp(-normalized_lambda.^2 / 2);
          
        otherwise
          error('LambdaBandEditor:UnknownKernelType', ...
            'Unknown kernel type: %s', obj.KernelType);
      end
      
      % Normalize for proper filtering
      kernel = kernel / sum(kernel);
    end
    
    function setLowPass(obj, cutoff)
      % Configure as low-pass filter (smooth patterns on manifold)
      %
      % Syntax:
      %   editor.setLowPass(30)  % Keep eigenmodes 1-30 (low spatial frequencies)
      %
      % Inputs:
      %   cutoff - Eigenmode cutoff (low spatial frequencies)
      
      obj.Center = cutoff / 2;
      obj.Width = cutoff / 4;
      obj.update();
    end
    
    function setHighPass(obj, cutoff)
      % Configure as high-pass filter (detailed patterns on manifold)
      %
      % Syntax:
      %   editor.setHighPass(100)  % Keep eigenmodes > 100 (high spatial frequencies)
      %
      % Inputs:
      %   cutoff - Eigenmode cutoff (high spatial frequencies)
      
      maxMode = max(obj.Domain.axis);
      obj.Center = (cutoff + maxMode) / 2;
      obj.Width = (maxMode - cutoff) / 4;
      obj.update();
    end
    
    function setBandPass(obj, low, high)
      % Configure as band-pass filter
      %
      % Syntax:
      %   editor.setBandPass(50, 150)  % Keep modes 50-150
      %
      % Inputs:
      %   low  - Lower eigenmode bound
      %   high - Upper eigenmode bound
      
      obj.Center = (low + high) / 2;
      obj.Width = (high - low) / 4;
      obj.update();
    end
  end
  
  methods (Access = protected)
    function updateFilter(obj, kernel)
      % Update filter with spectral band parameters
      %
      % Overrides base class to handle heat kernel tau parameter
      
      switch obj.KernelType
        case 'heat'
          % Update tau parameter for heat kernel
          obj.Filter.setParameter('tau', obj.Width);
          
        otherwise
          % Use default center/sigma update
          updateFilter@bct.filters.KernelEditor(obj, kernel);
      end
    end
  end
end
