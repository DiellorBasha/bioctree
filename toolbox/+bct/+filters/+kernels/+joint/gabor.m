function kernel_fh = gabor()
  % gabor - Returns 2D Gabor filter kernel function handle
  %
  % Syntax:
  %   kernel_fh = bct.filters.kernels.joint.gabor()
  %
  % Returns:
  %   kernel_fh - Function handle: @(X, Y, center_x, center_y, sigma_x, sigma_y)
  %               Evaluates 2D Gabor filter
  %
  % Description:
  %   2D Gabor filter for joint spectral-temporal filtering.
  %   Localized in both spatial frequency (lambda) and temporal frequency (omega).
  %   Ideal for detecting oscillatory patterns with specific spatiotemporal scales.
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
