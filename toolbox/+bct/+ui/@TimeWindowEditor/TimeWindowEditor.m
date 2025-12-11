classdef TimeWindowEditor < bct.ui.KernelEditor
  % TimeWindowEditor - Interactive time window editor for temporal signals
  %
  % Implements KernelEditor for Time domain, providing a Gaussian window
  % that can be navigated through time. Useful for time scrubbers in GUIs
  % that display temporal signals with a moving analysis window.
  %
  % The window is a normalized Gaussian centered at a specific time point
  % with adjustable width (standard deviation).
  %
  % Properties (inherited):
  %   Center - Current time point (seconds)
  %   Width  - Window width/sigma (seconds)
  %   Domain - Time domain object
  %   Filter - Associated filter object
  %
  % Methods (inherited):
  %   shiftForward()  - Advance window by dt
  %   shiftBackward() - Move window back by dt
  %   expand()        - Increase window width
  %   contract()      - Decrease window width
  %   setCenter(t)    - Jump to specific time
  %   setWidth(w)     - Set window width
  %
  % Example - Time scrubber for GUI:
  %   B = bct();
  %   B.Time = bct.Time(0:0.001:2, 1000);  % 2s at 1kHz
  %   
  %   % Create Gaussian filter on Time domain
  %   filt = bct.filters.Filter(B.Time, 'gaussian', ...
  %       'center', 1.0, 'sigma', 0.05);
  %   
  %   % Create editor for interactive control
  %   editor = bct.filters.TimeWindowEditor(B.Time, filt, 1.0, 0.05);
  %   
  %   % GUI slider callback:
  %   editor.setCenter(sliderValue);  % Update window position
  %   
  %   % Keyboard navigation:
  %   editor.shiftForward();   % Right arrow
  %   editor.shiftBackward();  % Left arrow
  %
  % See also: bct.ui.KernelEditor, bct.Time, bct.filters.Filter
  
  properties
    WindowType = 'gaussian'  % 'gaussian', 'hann', 'hamming', 'tukey'
  end
  
  methods
    function obj = TimeWindowEditor(timeDomain, filter, center, width, varargin)
      % Constructor
      %
      % Syntax:
      %   editor = TimeWindowEditor(timeDomain, filter, center, width)
      %   editor = TimeWindowEditor(..., 'WindowType', 'hann')
      %
      % Inputs:
      %   timeDomain - bct.Time domain object
      %   filter     - bct.filters.Filter object
      %   center     - Initial time point (seconds)
      %   width      - Initial window width/sigma (seconds)
      %
      % Name-Value Parameters:
      %   'WindowType' - Window function: 'gaussian' (default), 'hann', 
      %                  'hamming', 'tukey'
      
      % Call superclass constructor
      obj@bct.ui.KernelEditor(timeDomain, filter, center, width);
      
      % Parse optional parameters
      p = inputParser;
      addParameter(p, 'WindowType', 'gaussian', ...
        @(x) ismember(x, {'gaussian', 'hann', 'hamming', 'tukey'}));
      parse(p, varargin{:});
      
      obj.WindowType = p.Results.WindowType;
    end
    
    function kernel = computeKernel(obj)
      % Compute time window kernel
      %
      % Returns:
      %   kernel - [N×1] normalized window values on time axis
      
      t = obj.Domain.axis;
      
      switch obj.WindowType
        case 'gaussian'
          % Gaussian window: exp(-((t-center)^2)/(2*sigma^2))
          kernel = exp(-((t - obj.Center).^2) / (2 * obj.Width^2));
          
        case 'hann'
          % Hann window (raised cosine)
          kernel = obj.hannWindow(t);
          
        case 'hamming'
          % Hamming window
          kernel = obj.hammingWindow(t);
          
        case 'tukey'
          % Tukey window (tapered cosine)
          kernel = obj.tukeyWindow(t);
          
        otherwise
          error('TimeWindowEditor:UnknownWindowType', ...
            'Unknown window type: %s', obj.WindowType);
      end
      
      % Normalize to unit integral (for proper filtering)
      kernel = kernel / sum(kernel);
    end
  end
  
  methods (Access = private)
    function w = hannWindow(obj, t)
      % Hann window implementation
      halfWidth = 2 * obj.Width;  % Support is ±2σ
      mask = abs(t - obj.Center) <= halfWidth;
      w = zeros(size(t));
      
      if any(mask)
        t_local = (t(mask) - obj.Center) / halfWidth;
        w(mask) = 0.5 * (1 + cos(pi * t_local));
      end
    end
    
    function w = hammingWindow(obj, t)
      % Hamming window implementation
      halfWidth = 2 * obj.Width;
      mask = abs(t - obj.Center) <= halfWidth;
      w = zeros(size(t));
      
      if any(mask)
        t_local = (t(mask) - obj.Center) / halfWidth;
        w(mask) = 0.54 + 0.46 * cos(pi * t_local);
      end
    end
    
    function w = tukeyWindow(obj, t)
      % Tukey window (tapered cosine)
      alpha = 0.5;  % Taper fraction
      halfWidth = 2 * obj.Width;
      mask = abs(t - obj.Center) <= halfWidth;
      w = zeros(size(t));
      
      if any(mask)
        t_local = abs(t(mask) - obj.Center) / halfWidth;
        
        % Flat top in middle
        w(mask) = 1;
        
        % Cosine taper on edges
        taper_mask = t_local > (1 - alpha);
        if any(taper_mask)
          t_taper = t_local(taper_mask);
          w(mask(taper_mask)) = 0.5 * (1 + cos(pi * (t_taper - (1-alpha)) / alpha));
        end
      end
    end
  end
end
