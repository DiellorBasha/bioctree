function kernel_fh = heat()
  % heat - Returns exponential decay kernel function handle
  %
  % Syntax:
  %   kernel_fh = bct.filters.kernels.heat()
  %
  % Returns:
  %   kernel_fh - Function handle: @(x, tau)
  %               Evaluates exponential decay: exp(-tau * x)
  %
  % Description:
  %   Pure exponential decay kernel - domain-agnostic mathematical function.
  %   Commonly used as heat diffusion on Lambda domain (low-pass spatial).
  %   Larger tau = faster decay.
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
