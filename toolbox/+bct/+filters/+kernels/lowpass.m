function kernel_fh = lowpass()
  % lowpass - Returns ideal low-pass filter kernel function handle
  %
  % Syntax:
  %   kernel_fh = bct.filters.kernels.lowpass()
  %
  % Returns:
  %   kernel_fh - Function handle: @(x, cutoff)
  %               Evaluates ideal low-pass: 1 if x < cutoff, else 0
  %
  % Description:
  %   Pure rectangular low-pass kernel - domain-agnostic mathematical function.
  %   Returns 1 for values below cutoff, 0 otherwise.
  %   
  %   On Lambda (spectral) domain: retains low-frequency spatial modes (smoothing)
  %   On Omega (temporal freq): retains low temporal frequencies
  %   On Manifold: equivalent to spatial smoothing/blurring
  %
  % Parameters (when evaluating):
  %   x      - Evaluation points [N×1] (eigenvalues or frequencies)
  %   cutoff - Cutoff threshold (scalar)
  %
  % Example:
  %   lp = bct.filters.kernels.lowpass();
  %   lambda = linspace(0, 100, 50);
  %   H = lp(lambda, 30);  % Low-pass at lambda=30
  %
  % See also: bct.filters.Filter, bct.filters.kernels.highpass,
  %           bct.filters.kernels.bandpass
  
  kernel_fh = @(x, cutoff) double(x < cutoff);
end
