function kernel_fh = gabor()
  % gabor - Returns 2D Gabor (2D Gaussian) kernel function handle
  %
  % Syntax:
  %   kernel_fh = bct.filters.kernels.gabor()
  %
  % Returns:
  %   kernel_fh - Function handle: @(X, Y, center_x, center_y, sigma_x, sigma_y)
  %               Evaluates 2D Gaussian kernel
  %
  % Description:
  %   Pure 2D Gaussian kernel - domain-agnostic mathematical function.
  %   Localized in both dimensions with independent center and spread.
  %   Becomes a joint filter when bound to a Joint domain (e.g., Lambda×Omega).
  %
  % Parameters (when evaluating):
  %   X        - First coordinate grid [M×N] (e.g., lambda)
  %   Y        - Second coordinate grid [M×N] (e.g., omega)
  %   center_x - Center along X axis (scalar)
  %   center_y - Center along Y axis (scalar)
  %   sigma_x  - Spread along X axis (scalar)
  %   sigma_y  - Spread along Y axis (scalar)
  %
  % Example:
  %   gb = bct.filters.kernels.joint.gabor();
  %   [Lambda, Omega] = meshgrid(0:0.1:10, 0:0.1:50);
  %   H = gb(Lambda, Omega, 5, 10, 1, 2);  % Centered at (5,10)
  %
  % See also: bct.filters.Filter, bct.Joint
  
  kernel_fh = @(X, Y, center_x, center_y, sigma_x, sigma_y) ...
    exp(-((X - center_x).^2 / (2*sigma_x^2) + (Y - center_y).^2 / (2*sigma_y^2)));
end
