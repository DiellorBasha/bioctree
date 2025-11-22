function kernel_fh = bandpass()
  % bandpass - Returns ideal bandpass filter kernel function handle
  %
  % Syntax:
  %   kernel_fh = bct.filters.kernels.temporal.bandpass()
  %
  % Returns:
  %   kernel_fh - Function handle: @(x, low, high)
  %               Evaluates rectangular bandpass: 1 if low <= x <= high, else 0
  %
  % Description:
  %   Ideal rectangular bandpass filter kernel for frequency domain.
  %   Returns 1 within the band [low, high], 0 outside.
  %
  % Parameters (when evaluating):
  %   x    - Evaluation points [N×1] (typically frequency)
  %   low  - Lower cutoff (scalar)
  %   high - Upper cutoff (scalar)
  %
  % Example:
  %   bp = bct.filters.kernels.temporal.bandpass();
  %   omega = linspace(0, 50, 1000);
  %   H = bp(omega, 8, 12);  % Alpha band 8-12 Hz
  %
  % See also: bct.filters.Filter
  
  kernel_fh = @(x, low, high) double(x >= low & x <= high);
end
