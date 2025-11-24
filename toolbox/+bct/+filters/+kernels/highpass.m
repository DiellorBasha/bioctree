function kernel_fh = highpass()
  % highpass - Returns ideal high-pass filter kernel function handle
  %
  % Syntax:
  %   kernel_fh = bct.filters.kernels.highpass()
  %
  % Returns:
  %   kernel_fh - Function handle: @(x, cutoff)
  %               Evaluates ideal high-pass: 1 if x > cutoff, else 0
  %
  % Description:
  %   Pure rectangular high-pass kernel - domain-agnostic mathematical function.
  %   Returns 1 for values above cutoff, 0 otherwise.
  %   
  %   On Lambda (spectral) domain: retains high-frequency spatial modes (edges)
  %   On Omega (temporal freq): retains high temporal frequencies
  %   On Manifold: highlights edges, gradients, fine spatial structure
  %
  % Parameters (when evaluating):
  %   x      - Evaluation points [N×1] (eigenvalues or frequencies)
  %   cutoff - Cutoff threshold (scalar)
  %
  % Example:
  %   hp = bct.filters.kernels.highpass();
  %   lambda = linspace(0, 100, 50);
  %   H = hp(lambda, 30);  % High-pass at lambda=30
  %
  % See also: bct.filters.Filter, bct.filters.kernels.lowpass,
  %           bct.filters.kernels.bandpass
  
  kernel_fh = @(x, cutoff) double(x > cutoff);
end
