function kernel_fh = gaussian_wavenumber()
  % gaussian_wavenumber - Gaussian kernel in wavenumber space for Lambda domain
  %
  % Syntax:
  %   kernel_fh = bct.filters.kernels.gaussian_wavenumber()
  %
  % Returns:
  %   kernel_fh - Function handle: @(k, k0, sigma_k)
  %               Evaluates Gaussian in wavenumber space
  %
  % Description:
  %   Gaussian kernel designed for spatial filtering on mesh manifolds.
  %   Works with WAVENUMBER k = sqrt(lambda) for physically meaningful
  %   spatial frequency filtering. Produces smooth bandpass characteristics
  %   without high-frequency artifacts.
  %
  % Parameters (when evaluating):
  %   k       - Wavenumber axis [K×1] (rad/mm) - from Lambda.axis
  %   k0      - Center wavenumber (rad/mm)
  %   sigma_k - Bandwidth in wavenumber space (rad/mm)
  %
  % Physical Interpretation:
  %   k0 = 5 rad/mm → spatial wavelength ≈ 1.26 mm
  %   sigma_k = 2 rad/mm → bandwidth of ±2 rad/mm around center
  %
  % Example:
  %   % Lambda.axis returns wavenumber k = sqrt(lambda) by default
  %   g = bct.filters.kernels.gaussian_wavenumber();
  %   k = B.Lambda.axis;  % Wavenumber in rad/mm
  %   H = g(k, 5, 2);     % Gaussian centered at k=5, width σ_k=2
  %
  % Notes:
  %   - Lambda.displayCoordinateMode defaults to Wavenumber
  %   - This gives LINEAR spatial frequency response (not quadratic like λ)
  %   - Produces clean, smooth signals without speckle artifacts
  %
  % See also: bct.filters.kernels.heat_wavenumber, 
  %           bct.filters.kernels.mexican_hat_wavenumber,
  %           bct.Lambda, bct.filters.Filter
  
  kernel_fh = @(k, k0, sigma_k) exp(-0.5 * ((k - k0) ./ sigma_k).^2);
end
