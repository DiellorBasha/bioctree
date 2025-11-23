function kernel_fh = heat_wavenumber()
  % heat_wavenumber - Heat diffusion kernel in wavenumber space for Lambda domain
  %
  % Syntax:
  %   kernel_fh = bct.filters.kernels.heat_wavenumber()
  %
  % Returns:
  %   kernel_fh - Function handle: @(k, tau)
  %               Evaluates heat kernel: exp(-tau * k^2)
  %
  % Description:
  %   Heat diffusion kernel for spatial low-pass filtering on mesh manifolds.
  %   Works with WAVENUMBER k = sqrt(lambda), giving proper heat equation
  %   solution: exp(-tau * λ) = exp(-tau * k^2).
  %
  % Parameters (when evaluating):
  %   k   - Wavenumber axis [K×1] (rad/mm) - from Lambda.axis
  %   tau - Diffusion time parameter (scalar, tau > 0)
  %
  % Physical Interpretation:
  %   Larger tau → more diffusion → stronger low-pass filtering
  %   Heat kernel smooths signals by diffusing high spatial frequencies
  %
  % Example:
  %   % Lambda.axis returns wavenumber k = sqrt(lambda) by default
  %   h = bct.filters.kernels.heat_wavenumber();
  %   k = B.Lambda.axis;  % Wavenumber in rad/mm
  %   H = h(k, 0.1);      % Heat diffusion with tau=0.1
  %
  % Mathematical Form:
  %   H(k) = exp(-tau * k²)
  %   
  %   This is equivalent to exp(-tau * lambda) since k = sqrt(lambda)
  %
  % Notes:
  %   - Classic heat equation solution on graphs
  %   - Low-pass filter: attenuates high spatial frequencies
  %   - Smooth, monotonic decay from DC (k=0)
  %
  % Reference:
  %   Hammond, D. K., Vandergheynst, P., & Gribonval, R. (2011).
  %   Wavelets on graphs via spectral graph theory.
  %   Applied and Computational Harmonic Analysis, 30(2), 129-150.
  %
  % See also: bct.filters.kernels.gaussian_wavenumber,
  %           bct.Lambda, bct.filters.Filter
  
  kernel_fh = @(k, tau) exp(-tau * k.^2);
end
