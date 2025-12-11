function kernel_fh = bandpass()
  % bandpass - Returns bandpass filter kernel function handle
  %
  % Syntax:
  %   kernel_fh = bct.filters.kernels.bandpass()
  %
  % Returns:
  %   kernel_fh - Function handle: @(x, low, high, varargin)
  %               Evaluates bandpass window: 1 if low <= x <= high, else 0
  %               Optional Hann tapering for smooth transitions
  %
  % Description:
  %   Bandpass window kernel - domain-agnostic mathematical function.
  %   Returns 1 within the band [low, high], 0 outside.
  %   Optionally applies Hann window tapering for smooth spectral transitions.
  %   
  %   Commonly used as bandpass filter on frequency domains (Lambda, Omega).
  %
  % Parameters (when evaluating):
  %   x    - Evaluation points [N×1] (typically frequency)
  %   low  - Lower cutoff (scalar)
  %   high - Upper cutoff (scalar)
  %
  % Name-Value Parameters:
  %   'taper' - Apply Hann window tapering (default: false)
  %             When true, applies smooth cosine taper to band edges
  %
  % Example (rectangular bandpass):
  %   bp = bct.filters.kernels.bandpass();
  %   omega = linspace(0, 50, 1000);
  %   H = bp(omega, 8, 12);  % Alpha band 8-12 Hz (ideal)
  %
  % Example (Hann-tapered bandpass):
  %   H = bp(omega, 8, 12, 'taper', true);  % Smooth transitions
  %
  % See also: bct.filters.Filter, bct.filters.kernels.lowpass,
  %           bct.filters.kernels.highpass
  
  kernel_fh = @bandpass_kernel;
  
  function h = bandpass_kernel(x, low, high, varargin)
    % Parse optional tapering parameter
    p = inputParser;
    addParameter(p, 'taper', false, @islogical);
    parse(p, varargin{:});
    use_taper = p.Results.taper;
    
    % Rectangular bandpass window
    h = double(x >= low & x <= high);
    
    % Apply Hann tapering if requested
    if use_taper && sum(h) > 0
      % Find indices within band
      band_idx = find(h > 0);
      n_band = length(band_idx);
      
      if n_band > 1
        % Generate Hann window for band region
        hann_window = 0.5 * (1 - cos(2*pi*(0:n_band-1)' / (n_band-1)));
        
        % Apply taper to band region only
        h(band_idx) = hann_window;
      end
    end
  end
end
