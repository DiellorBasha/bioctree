function kernel_fh = bandpass()
  % bandpass - Returns rectangular window kernel function handle
  %
  % Syntax:
  %   kernel_fh = bct.filters.kernels.bandpass()
  %
  % Returns:
  %   kernel_fh - Function handle: @(x, low, high)
  %               Evaluates rectangular window: 1 if low <= x <= high, else 0
  %
  % Description:
  %   Pure rectangular window kernel - domain-agnostic mathematical function.
  %   Returns 1 within the band [low, high], 0 outside.
  %   Commonly used as bandpass filter on frequency domains.
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
