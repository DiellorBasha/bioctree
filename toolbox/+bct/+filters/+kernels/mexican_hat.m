function kernel_fh = mexican_hat()
  % mexican_hat - Returns Mexican hat (Ricker) wavelet kernel
  %
  % Syntax:
  %   kernel_fh = bct.filters.kernels.mexican_hat()
  %
  % Returns:
  %   kernel_fh - Function handle: @(x, scale)
  %               Evaluates Mexican hat wavelet: sqrt(x/scale) * exp(-x/(2*scale))
  %
  % Description:
  %   Pure Mexican hat (Ricker) wavelet kernel - domain-agnostic function.
  %   Band-pass shaped kernel useful for multi-scale analysis.
  %   Commonly used on Lambda domain for spatial feature detection.
  %
  % Parameters (when evaluating):
  %   lambda - Eigenvalues [K×1]
  %   scale  - Scale parameter (scalar, scale > 0)
  %
  % Example:
  %   mh = bct.filters.kernels.spatial.mexican_hat();
  %   lambda = linspace(0, 100, 50);
  %   H = mh(lambda, 10);  % Mexican hat at scale=10
  %
  % See also: bct.filters.Filter
  
  kernel_fh = @(lambda, scale) sqrt(lambda/scale) .* exp(-lambda/(2*scale));
end
