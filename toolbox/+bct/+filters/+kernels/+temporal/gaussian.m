function kernel_fh = gaussian()
  % gaussian - Returns Gaussian kernel function handle
  %
  % Syntax:
  %   kernel_fh = bct.filters.kernels.temporal.gaussian()
  %
  % Returns:
  %   kernel_fh - Function handle: @(x, center, sigma)
  %               Evaluates Gaussian: exp(-(x - center)^2 / (2*sigma^2))
  %
  % Description:
  %   Pure Gaussian kernel function for temporal/frequency domain filtering.
  %   Domain-agnostic - can be used on Time or Omega domains.
  %
  % Parameters (when evaluating):
  %   x      - Evaluation points [N×1] (time or frequency)
  %   center - Center of Gaussian (scalar)
  %   sigma  - Standard deviation (scalar)
  %
  % Example:
  %   g = bct.filters.kernels.temporal.gaussian();
  %   x = linspace(0, 10, 100);
  %   H = g(x, 5, 1);  % Gaussian centered at 5 with sigma=1
  %
  % See also: bct.filters.Filter
  
  kernel_fh = @(x, center, sigma) exp(-(x - center).^2 / (2*sigma^2));
end
