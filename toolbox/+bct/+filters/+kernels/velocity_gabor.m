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
  %   Creates a joint spatiotemporal filter with a tilted/curved ridge in (λ,ω) space.
  %   This kernel enforces the dispersion relation: ω ≈ v√λ + Dλ
  %   
  %   The filter selects wave components that satisfy a group-velocity constraint,
  %   producing traveling wave packets when applied to a delta signal.
  %
  %   Mathematical form:
  %     H(λ,ω) = exp[-((ω - (v√λ + Dλ))² / (2σ_ω²))] · exp[-((λ - λ₀)² / (2σ_λ²))]
  %
  %   Components:
  %     - Ridge: ω ≈ v√λ + Dλ (velocity + dispersion)
  %     - Spatial bandpass: Gaussian centered at λ₀ with width σ_λ
  %     - Temporal selectivity: Controlled by σ_ω along the ridge
  %
  % Parameters (when evaluating):
  %   lambda   - Eigenvalue grid [K×1] or [K×F] (spatial frequency)
  %   omega    - Angular frequency grid [1×F] or [K×F] (temporal frequency)
  %   v        - Group velocity (rad/mm/s) - controls tilt of ridge
  %   sigma_w  - Temporal bandwidth along ridge (rad/s)
  %   lambda0  - Center eigenvalue (controls spatial scale)
  %   sigma_l  - Spatial bandwidth (controls packet size)
  %   D        - Dispersion coefficient (optional, default: 0) - controls curvature
  %
  % Returns:
  %   H - [K×F] filter response matrix on Lambda×Omega grid
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
  
  % Parse optional dispersion parameter
  p = inputParser;
  addOptional(p, 'D', 0, @isnumeric);  % Dispersion coefficient (default: 0)
  parse(p, varargin{:});
  D = p.Results.D;
  
  % Ensure lambda is column vector [K×1]
  lambda = lambda(:);
  
  % Ensure omega is row vector [1×F]
  omega = omega(:).';
  
  % Compute dispersion relation ridge: ω_ridge(λ) = v√λ + Dλ
  % omega is [1×F], omega_ridge is [K×1], result is [K×F]
  omega_ridge = v * sqrt(abs(lambda)) + D * lambda;
  
  % Compute ridge component: exp[-((ω - ω_ridge)² / (2σ_ω²))]
  ridge = exp(-((omega - omega_ridge).^2) ./ (2 * sigma_w^2));
  
  % Compute spatial bandpass component: exp[-((λ - λ₀)² / (2σ_λ²))]
  % lambda is [K×1], result is [K×1], broadcasts to [K×F]
  spatial_bandpass = exp(-((lambda - lambda0).^2) ./ (2 * sigma_l^2));
  
  % Combine both components (element-wise multiplication with broadcasting)
  H = ridge .* spatial_bandpass;
end
