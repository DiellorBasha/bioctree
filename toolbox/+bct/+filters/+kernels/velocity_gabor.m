function kernel_fh = velocity_gabor()
  % velocity_gabor - Returns velocity-tuned joint Gabor kernel function handle
  %
  % Syntax:
  %   kernel_fh = bct.filters.kernels.velocity_gabor()
  %
  % Returns:
  %   kernel_fh - Function handle: @(lambda, omega, v, sigma_w, lambda0, sigma_l, D)
  %               Evaluates tilted/curved ridge kernel for traveling wave packets
  %
  % Description:
  %   Creates a joint spatiotemporal filter with a velocity-coupled ridge in (λ,ω) space.
  %   Like a 2D Gabor filter, but the frequency center follows: ω_center = omega0 + v√λ
  %   
  %   This kernel is a 2D Gaussian envelope with independent centers (λ₀, ω₀) and 
  %   bandwidths (σ_λ, σ_ω), but with velocity coupling that tilts the ridge.
  %
  %   Mathematical form:
  %     H(λ,ω) = exp[-((ω - (ω₀ + v√λ + Dλ))² / (2σ_ω²))] · exp[-((λ - λ₀)² / (2σ_λ²))]
  %
  %   Components:
  %     - Lambda axis: Gaussian centered at λ₀ with bandwidth σ_λ
  %     - Omega axis: Gaussian centered at (ω₀ + v√λ) with bandwidth σ_ω
  %     - Velocity coupling: v determines tilt, D adds curvature
  %
  % Parameters (when evaluating):
  %   lambda   - Eigenvalue grid [M×N] (spatial frequency meshgrid)
  %   omega    - Angular frequency grid [M×N] (temporal frequency meshgrid)
  %   v        - Group velocity (rad/mm/s) - controls tilt of ridge
  %   sigma_w  - Temporal bandwidth (rad/s) - width in omega direction
  %   lambda0  - Spatial center eigenvalue - center in lambda direction
  %   sigma_l  - Spatial bandwidth - width in lambda direction
  %   omega0   - Frequency center (optional, default: 0) - baseline frequency
  %   D        - Dispersion coefficient (optional, default: 0) - adds curvature
  %
  % Returns:
  %   H - [M×N] filter response matrix on Lambda×Omega grid
  %
  % Properties:
  %   ✓ Non-separable (both λ and ω appear in combined expression)
  %   ✓ Produces traveling wave packets (not standing waves)
  %   ✓ Spatially localized (controlled by σ_λ)
  %   ✓ Temporally localized (controlled by σ_ω)
  %   ✓ Directional (velocity determines propagation direction)
  %   ✓ Dispersive (D ≠ 0 creates curved ridge for dispersive waves)
  %
  % Example:
  %   % Create velocity-tuned filter
  %   vg = bct.filters.kernels.velocity_gabor();
  %   
  %   % Evaluate on Joint Lambda×Omega domain
  %   lambda = B.Lambda.axis;  % [K×1] eigenvalues
  %   omega  = B.Omega.axis;   % [F×1] angular frequencies
  %   
  %   v = 0.5;        % Group velocity: 0.5 rad/mm/s
  %   sigma_w = 10;   % Temporal bandwidth: 10 rad/s
  %   lambda0 = 50;   % Center eigenvalue
  %   sigma_l = 20;   % Spatial bandwidth
  %   
  %   H = vg(lambda, omega, v, sigma_w, lambda0, sigma_l);  % [K×F] matrix
  %   
  %   % Apply to BCT signal
  %   filt = bct.filters.Filter(B.Joint.dual, 'velocity_gabor', ...
  %       'v', v, 'sigma_w', sigma_w, 'lambda0', lambda0, 'sigma_l', sigma_l);
  %
  % Physics Interpretation:
  %   - The tilt ω = v√λ enforces a dispersion relation
  %   - v > 0: rightward/forward propagation
  %   - v < 0: leftward/backward propagation
  %   - v = 0: standing wave (reduces to standard Gabor)
  %   - Larger |v|: faster propagation
  %   - Larger σ_ω: more temporal spread (longer packet)
  %   - Larger σ_λ: broader spatial frequency band
  %
  % See also: bct.filters.Filter, bct.filters.kernels.gabor, bct.Joint
  
  % Kernel function with automatic broadcasting and optional dispersion
  kernel_fh = @(lambda, omega, v, sigma_w, lambda0, sigma_l, varargin) ...
      velocity_gabor_kernel(lambda, omega, v, sigma_w, lambda0, sigma_l, varargin{:});
end

function H = velocity_gabor_kernel(lambda, omega, v, sigma_w, lambda0, sigma_l, varargin)
  % Internal implementation with proper broadcasting and dispersion support
  
  % Parse optional parameters
  p = inputParser;
  addOptional(p, 'omega0', 0, @isnumeric);  % Frequency center (default: 0)
  addOptional(p, 'D', 0, @isnumeric);       % Dispersion coefficient (default: 0)
  parse(p, varargin{:});
  omega0 = p.Results.omega0;
  D = p.Results.D;
  
  % lambda and omega are already meshgrids [M×N] from evaluateJoint
  % No need to reshape - work with them directly like gabor does
  
  % Velocity kernel form: exp(-((ω - (ω₀ + v√λ + Dλ))² / (2σ_ω²))) · exp(-((λ - λ₀)² / (2σ_λ²)))
  % This is exactly like 2D Gabor but with coupled center: (ω₀ + v√λ) instead of fixed ω₀
  
  % Compute ridge component: exp[-((ω - (ω₀ + v√λ + Dλ))² / (2σ_ω²))]
  ridge = exp(-((omega - (omega0 + v * sqrt(abs(lambda)) + D * lambda)).^2) ./ (2 * sigma_w^2));
  
  % Compute spatial component: exp[-((λ - λ₀)² / (2σ_λ²))]
  spatial = exp(-((lambda - lambda0).^2) ./ (2 * sigma_l^2));
  
  % Combine both components (element-wise multiplication)
  H = ridge .* spatial;
end
