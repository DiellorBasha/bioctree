function kernel_fh = separable()
  % separable - Returns separable 2D filter kernel
  %
  % Syntax:
  %   kernel_fh = bct.filters.kernels.joint.separable()
  %
  % Returns:
  %   kernel_fh - Function handle: @(X, Y, kernel_x, kernel_y, params_x, params_y)
  %               Evaluates H(X,Y) = kernel_x(X, params_x) * kernel_y(Y, params_y)
  %
  % Description:
  %   Constructs separable 2D filter as product of two 1D filters.
  %   Useful for combining spatial and temporal filters efficiently.
  %
  % Parameters (when evaluating):
  %   X         - First coordinate grid [M×N]
  %   Y         - Second coordinate grid [M×N]
  %   kernel_x  - 1D kernel function for X dimension
  %   kernel_y  - 1D kernel function for Y dimension
  %   params_x  - Cell array of parameters for kernel_x
  %   params_y  - Cell array of parameters for kernel_y
  %
  % Example:
  %   sep = bct.filters.kernels.joint.separable();
  %   heat_k = bct.filters.kernels.spatial.heat();
  %   gauss_k = bct.filters.kernels.temporal.gaussian();
  %   
  %   [Lambda, Omega] = meshgrid(0:0.1:10, 0:0.1:50);
  %   H = sep(Lambda, Omega, heat_k, gauss_k, {0.1}, {10, 2});
  %   % H(λ,ω) = exp(-0.1*λ) * exp(-(ω-10)^2/(2*2^2))
  %
  % See also: bct.filters.Filter, bct.Joint
  
  kernel_fh = @(X, Y, kernel_x, kernel_y, params_x, params_y) ...
    kernel_x(X, params_x{:}) .* kernel_y(Y, params_y{:});
end
