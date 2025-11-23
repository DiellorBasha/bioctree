function kernel_fh = mexican_hat_wavenumber()
  % mexican_hat_wavenumber - Mexican hat wavelet in wavenumber space for Lambda domain
  %
  % Syntax:
  %   kernel_fh = bct.filters.kernels.mexican_hat_wavenumber()
  %
  % Returns:
  %   kernel_fh - Function handle: @(k, k0, sigma_k)
  %               Evaluates Mexican hat (Ricker) wavelet
  %
  % Description:
  %   Mexican hat wavelet kernel for bandpass spatial filtering on meshes.
  %   Works with WAVENUMBER k = sqrt(lambda) for clean, oscillatory bandpass
  %   response with negative sidelobes. Ideal for detecting features at
  %   specific spatial scales.
  %
  % Parameters (when evaluating):
  %   k       - Wavenumber axis [K×1] (rad/mm) - from Lambda.axis
  %   k0      - Center wavenumber (rad/mm)
  %   sigma_k - Bandwidth in wavenumber space (rad/mm)
  %
  % Physical Interpretation:
  %   k0 = 8 rad/mm → detects features with wavelength ≈ 0.78 mm
  %   sigma_k controls selectivity (smaller = narrower bandpass)
  %
  % Example:
  %   % Lambda.axis returns wavenumber k = sqrt(lambda) by default
  %   mh = bct.filters.kernels.mexican_hat_wavenumber();
  %   k = B.Lambda.axis;  % Wavenumber in rad/mm
  %   H = mh(k, 8, 3);    % Mexican hat centered at k=8, width σ_k=3
  %
  % Mathematical Form:
  %   t = (k - k0) / sigma_k
  %   H(k) = (1 - t²) * exp(-t²/2)
  %
  % Properties:
  %   - Zero DC response (rejects k=0)
  %   - Peak at k ≈ k0
  %   - Negative sidelobes (for edge detection)
  %   - Compact support in wavenumber
  %
  % Notes:
  %   - Also called Ricker wavelet
  %   - Second derivative of Gaussian
  %   - Useful for multi-scale edge/feature detection
  %
  % Reference:
  %   Hammond, D. K., Vandergheynst, P., & Gribonval, R. (2011).
  %   Wavelets on graphs via spectral graph theory.
  %
  % See also: bct.filters.kernels.gaussian_wavenumber,
  %           bct.Lambda, bct.filters.Filter
  
  kernel_fh = @(k, k0, sigma_k) mexican_hat_impl(k, k0, sigma_k);
end

function H = mexican_hat_impl(k, k0, sigma_k)
  % Implementation of Mexican hat in wavenumber space
  t = (k - k0) ./ sigma_k;
  H = (1 - t.^2) .* exp(-t.^2 / 2);
end
