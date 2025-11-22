function kernel_fh = heat()
  % heat - Returns heat diffusion kernel function handle
  %
  % Syntax:
  %   kernel_fh = bct.filters.kernels.spatial.heat()
  %
  % Returns:
  %   kernel_fh - Function handle: @(lambda, tau)
  %               Evaluates heat kernel: exp(-tau * lambda)
  %
  % Description:
  %   Heat diffusion kernel for graph spectral filtering.
  %   Used on Lambda (eigenvalue) domain for low-pass spatial filtering.
  %   Larger tau = more diffusion (lower frequency cutoff).
  %
  % Parameters (when evaluating):
  %   lambda - Eigenvalues [K×1]
  %   tau    - Diffusion time parameter (scalar, tau > 0)
  %
  % Example:
  %   h = bct.filters.kernels.spatial.heat();
  %   lambda = linspace(0, 100, 50);
  %   H = h(lambda, 0.1);  % Heat kernel with tau=0.1
  %
  % Reference:
  %   Hammond, D. K., Vandergheynst, P., & Gribonval, R. (2011).
  %   Wavelets on graphs via spectral graph theory.
  %
  % See also: bct.filters.Filter
  
  kernel_fh = @(lambda, tau) exp(-tau * lambda);
end
