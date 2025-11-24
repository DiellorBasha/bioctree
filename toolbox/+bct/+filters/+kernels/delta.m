function kernel_fh = delta()
  % delta - Returns Kronecker delta (impulse) kernel function handle
  %
  % Syntax:
  %   kernel_fh = bct.filters.kernels.delta()
  %
  % Returns:
  %   kernel_fh - Function handle: @(x, x0, varargin)
  %               Evaluates Kronecker delta centered at x0
  %
  % Description:
  %   Kronecker delta kernel - the most fundamental test kernel.
  %   Returns 1 at exactly one location, 0 everywhere else.
  %   
  %   Critical for:
  %   - Impulse responses and Green's functions
  %   - Wave excitation at single vertex/mode
  %   - Testing transform pairs
  %   
  %   Domain-specific behavior:
  %   - Manifold: impulse at vertex → global λ-excitation
  %   - Lambda: impulse in λ → global spatial oscillation
  %   - Time: impulse in time → flat temporal spectrum
  %   - Omega: impulse in frequency → pure sinusoid in time
  %
  % Parameters (when evaluating):
  %   x       - Evaluation points [N×1] (discrete indices or continuous values)
  %   x0      - Impulse location (scalar)
  %   
  % Name-Value Parameters:
  %   'tol'   - Tolerance for continuous domains (default: eps)
  %             For discrete: uses exact equality
  %             For continuous: |x - x0| < tol
  %
  % Example (discrete domain - vertex indices):
  %   d = bct.filters.kernels.delta();
  %   vertices = 1:10000;
  %   H = d(vertices, 5000);  % Impulse at vertex 5000
  %
  % Example (continuous domain - eigenvalues):
  %   lambda = linspace(0, 100, 50);
  %   H = d(lambda, 25, 'tol', 1e-6);  % Impulse near lambda=25
  %
  % Example (wave excitation on manifold):
  %   % Single vertex excitation → excites all spatial modes
  %   signal_vertex = bct.Signal(B.Manifold, delta_impulse);
  %   signal_lambda = B.Manifold.transform(signal_vertex);
  %   % Result: broadband in Lambda domain
  %
  % See also: bct.filters.Filter, bct.Signal
  
  kernel_fh = @delta_kernel;
  
  function h = delta_kernel(x, x0, varargin)
    % Parse optional tolerance parameter
    p = inputParser;
    addParameter(p, 'tol', eps, @(t) isnumeric(t) && isscalar(t) && t > 0);
    parse(p, varargin{:});
    tol = p.Results.tol;
    
    % Determine if discrete or continuous domain
    if all(x == round(x)) && x0 == round(x0)
      % Discrete domain: exact equality
      h = double(x == x0);
    else
      % Continuous domain: tolerance-based
      h = double(abs(x - x0) < tol);
    end
    
    % Normalize so sum = 1 (preserve energy)
    if sum(h) > 0
      h = h / sum(h);
    end
  end
end
