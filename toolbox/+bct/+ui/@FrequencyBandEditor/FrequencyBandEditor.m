classdef FrequencyBandEditor < bct.ui.KernelEditor
  % FrequencyBandEditor - Interactive frequency band selector for Omega domain
  %
  % Implements KernelEditor for Omega (frequency) domain, providing
  % bandpass filters for temporal frequency analysis. Useful for
  % interactively defining frequency bands of interest (delta, theta,
  % alpha, beta, gamma, etc.) in GUIs.
  %
  % The band is defined as a Gaussian centered at a specific frequency
  % with adjustable bandwidth, or as a sharp bandpass with cutoff frequencies.
  %
  % Properties (inherited):
  %   Center - Center frequency (Hz or rad/s, depends on domain mode)
  %   Width  - Bandwidth (Hz or rad/s)
  %   Domain - Omega domain object
  %   Filter - Associated filter object
  %
  % Methods (inherited):
  %   shiftForward()  - Move to higher frequencies
  %   shiftBackward() - Move to lower frequencies
  %   expand()        - Increase bandwidth
  %   contract()      - Decrease bandwidth
  %   setCenter(f)    - Jump to specific frequency
  %   setWidth(bw)    - Set bandwidth
  %
  % Example - Alpha band (8-12 Hz) selector:
  %   B = bct();
  %   B.Time = bct.Time(0:0.001:10, 1000);
  %   B.Omega = B.Time.dual;
  %   
  %   % Create bandpass filter on Omega
  %   filt = bct.filters.Filter(B.Omega, 'gaussian', ...
  %       'center', 10, 'sigma', 2);
  %   
  %   % Create editor
  %   editor = bct.filters.FrequencyBandEditor(B.Omega, filt, 10, 2);
  %   
  %   % Set to standard frequency bands:
  %   editor.setDelta();   % 1-4 Hz
  %   editor.setTheta();   % 4-8 Hz
  %   editor.setAlpha();   % 8-12 Hz
  %   editor.setBeta();    % 12-30 Hz
  %   editor.setGamma();   % 30-100 Hz
  %
  % Example - Custom band:
  %   editor.setBand(40, 60);  % 40-60 Hz bandpass
  %
  % See also: bct.ui.KernelEditor, bct.Omega, bct.Time
  
  properties
    BandType = 'gaussian'  % 'gaussian', 'butterworth', 'ideal'
    BandOrder = 4          % Filter order for Butterworth
  end
  
  methods
    function obj = FrequencyBandEditor(omegaDomain, filter, center, width, varargin)
      % Constructor
      %
      % Syntax:
      %   editor = FrequencyBandEditor(omegaDomain, filter, center, width)
      %   editor = FrequencyBandEditor(..., 'BandType', 'butterworth')
      %
      % Inputs:
      %   omegaDomain - bct.Omega domain object
      %   filter      - bct.filters.Filter object
      %   center      - Initial center frequency (Hz or rad/s)
      %   width       - Initial bandwidth (Hz or rad/s)
      %
      % Name-Value Parameters:
      %   'BandType'  - Filter type: 'gaussian' (default), 'butterworth', 'ideal'
      %   'BandOrder' - Order for Butterworth filter (default: 4)
      
      % Call superclass constructor
      obj@bct.ui.KernelEditor(omegaDomain, filter, center, width);
      
      % Parse optional parameters
      p = inputParser;
      addParameter(p, 'BandType', 'gaussian', ...
        @(x) ismember(x, {'gaussian', 'butterworth', 'ideal'}));
      addParameter(p, 'BandOrder', 4, @(x) isnumeric(x) && x > 0);
      parse(p, varargin{:});
      
      obj.BandType = p.Results.BandType;
      obj.BandOrder = p.Results.BandOrder;
    end
    
    function kernel = computeKernel(obj)
      % Compute frequency band kernel
      %
      % Returns:
      %   kernel - [F×1] bandpass kernel on frequency axis
      
      freq = obj.Domain.axis;  % Frequency axis (Hz or rad/s)
      
      switch obj.BandType
        case 'gaussian'
          % Gaussian bandpass
          kernel = exp(-((freq - obj.Center).^2) / (2 * obj.Width^2));
          
        case 'butterworth'
          % Butterworth bandpass
          kernel = obj.butterworthBand(freq);
          
        case 'ideal'
          % Ideal (brick-wall) bandpass
          low = obj.Center - obj.Width;
          high = obj.Center + obj.Width;
          kernel = double(freq >= low & freq <= high);
          
        otherwise
          error('FrequencyBandEditor:UnknownBandType', ...
            'Unknown band type: %s', obj.BandType);
      end
      
      % Normalize
      if sum(kernel) > 0
        kernel = kernel / sum(kernel);
      end
    end
    
    %% Standard Frequency Band Presets
    
    function setDelta(obj)
      % Set to delta band (1-4 Hz)
      obj.setBand(1, 4);
    end
    
    function setTheta(obj)
      % Set to theta band (4-8 Hz)
      obj.setBand(4, 8);
    end
    
    function setAlpha(obj)
      % Set to alpha band (8-12 Hz)
      obj.setBand(8, 12);
    end
    
    function setBeta(obj)
      % Set to beta band (12-30 Hz)
      obj.setBand(12, 30);
    end
    
    function setGamma(obj)
      % Set to gamma band (30-100 Hz)
      obj.setBand(30, 100);
    end
    
    function setHighGamma(obj)
      % Set to high gamma band (60-120 Hz)
      obj.setBand(60, 120);
    end
    
    function setBand(obj, fLow, fHigh)
      % Set custom frequency band
      %
      % Syntax:
      %   editor.setBand(8, 12)  % 8-12 Hz
      %
      % Inputs:
      %   fLow  - Lower frequency bound
      %   fHigh - Upper frequency bound
      
      obj.Center = (fLow + fHigh) / 2;
      obj.Width = (fHigh - fLow) / 2;
      obj.update();
    end
  end
  
  methods (Access = private)
    function kernel = butterworthBand(obj, freq)
      % Butterworth bandpass implementation
      %
      % Inputs:
      %   freq - Frequency axis
      %
      % Returns:
      %   kernel - Butterworth bandpass response
      
      fLow = obj.Center - obj.Width;
      fHigh = obj.Center + obj.Width;
      n = obj.BandOrder;
      
      % Avoid division by zero
      fLow = max(fLow, eps);
      fHigh = max(fHigh, eps);
      
      % Butterworth bandpass: product of low-pass and high-pass
      % High-pass (attenuate below fLow)
      H_hp = 1 ./ (1 + (fLow ./ (freq + eps)).^(2*n));
      
      % Low-pass (attenuate above fHigh)
      H_lp = 1 ./ (1 + (freq / fHigh).^(2*n));
      
      % Bandpass is product
      kernel = H_hp .* H_lp;
    end
  end
end
