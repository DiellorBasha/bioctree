function x_t = travelingWave(Phi, lam, centerVertex, t, params)
% TRAVELINGWAVE  Generate a global traveling wave on a manifold
% starting from a Kronecker delta initial condition.
%
% INPUTS:
%   Phi           [N x K]   eigenvectors
%   lam           [K x 1]   eigenvalues
%   centerVertex  scalar    index of initial disturbance
%   t             scalar    time
%   params.v      propagation speed
%
% OUTPUT:
%   x_t           [N x 1]   wave at time t
%
% EXAMPLE:
%   x = travelingWave(Phi, lam, 500, 0.1, struct('v', 0.8));

% unpack
v = params.v;

% ----- STEP 1: delta → spectral -----
A = Phi(centerVertex, :).';   % coefficients from delta

% ----- STEP 2: compute eigenfrequencies -----
omega = v * sqrt(lam);

% ----- STEP 3: evolve in time -----
c_t = A .* cos(omega * t);

% ----- STEP 4: inverse transform -----
x_t = Phi * c_t;

end
