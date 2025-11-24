function kernel_fh = velocity_gabor()
  % velocity_gabor - Returns velocity-tuned joint Gabor kernel function handle
  %
  % Syntax:
  %   kernel_fh = bct.filters.kernels.velocity_gabor()
  %
  % Returns:
  %   kernel_fh - Function handle: @(lambda, omega, v, sigma_w, lambda0, sigma_l)
  %               Evaluates tilted ridge kernel for traveling wave packets
  %
  % Description:
  %   Creates a joint spatiotemporal filter with a tilted ridge in (λ,ω) space.
  %   This kernel enforces the dispersion relation: ω ≈ v√λ
  %   
  %   The filter selects wave components that satisfy a group-velocity constraint,
  %   producing traveling wave packets when applied to a delta signal.
  %
  %   Mathematical form:
  %     H(λ,ω) = exp[-((ω - v√λ)² / (2σ_ω²))] · exp[-((λ - λ₀)² / (2σ_λ²))]
  %
  %   Components:
  %     - Tilted ridge: ω ≈ v√λ (encodes group velocity v)
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
  
  % Kernel function with automatic broadcasting
  kernel_fh = @(lambda, omega, v, sigma_w, lambda0, sigma_l) ...
      velocity_gabor_kernel(lambda, omega, v, sigma_w, lambda0, sigma_l);
end

function H = velocity_gabor_kernel(lambda, omega, v, sigma_w, lambda0, sigma_l)
  % Internal implementation with proper broadcasting
  
  % Ensure lambda is column vector [K×1]
  lambda = lambda(:);
  
  % Ensure omega is row vector [1×F]
  omega = omega(:).';
  
  % Compute tilted ridge component: exp[-((ω - v√λ)² / (2σ_ω²))]
  % omega is [1×F], sqrt(lambda) is [K×1], result is [K×F]
  ridge = exp(-((omega - v * sqrt(lambda)).^2) ./ (2 * sigma_w^2));
  
  % Compute spatial bandpass component: exp[-((λ - λ₀)² / (2σ_λ²))]
  % lambda is [K×1], result is [K×1], broadcasts to [K×F]
  spatial_bandpass = exp(-((lambda - lambda0).^2) ./ (2 * sigma_l^2));
  
  % Combine both components (element-wise multiplication with broadcasting)
  H = ridge .* spatial_bandpass;
end
