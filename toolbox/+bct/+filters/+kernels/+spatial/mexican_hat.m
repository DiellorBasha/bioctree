function kernel_fh = mexican_hat()
  % mexican_hat - Returns Mexican hat (Ricker) wavelet kernel
  %
  % Syntax:
  %   kernel_fh = bct.filters.kernels.spatial.mexican_hat()
  %
  % Returns:
  %   kernel_fh - Function handle: @(lambda, scale)
  %               Evaluates Mexican hat wavelet in spectral domain
  %
  % Description:
  %   Band-pass filter shaped like Mexican hat wavelet.
  %   Used for detecting features at specific spatial scales.
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
