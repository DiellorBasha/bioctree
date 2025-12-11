function x_t = travelingWavePacket(Phi, lam, centerVertex, t, params)
% TRAVELINGWAVEPACKET  Generate a traveling wave packet on a manifold
% using the Kronecker delta and a spectral Gaussian envelope.
%
% INPUTS:
%   Phi           [N x K]   eigenvectors of Laplacian
%   lam           [K x 1]   eigenvalues
%   centerVertex  scalar    index of center vertex for initial delta
%   t             scalar    current time
%   params.sigma  width of Gaussian envelope in lambda-domain
%   params.lambda0 center frequency (lambda)
%   params.v      propagation speed
%
% OUTPUT:
%   x_t           [N x 1]   signal on manifold at time t
%
% EXAMPLE:
%   x = travelingWavePacket(Phi, lam, 1000, 0.2, struct('sigma',10,'lambda0',20,'v',1.0));

% unpack parameters
sigma   = params.sigma;
lambda0 = params.lambda0;
v       = params.v;

% ----- STEP 1: delta projection into spectral domain -----
c0 = Phi(centerVertex, :).';   % projection of delta

% ----- STEP 2: spectral envelope (Gaussian in lambda) -----
envelope = exp( - (lam - lambda0).^2 / (2 * sigma^2) );

% ----- STEP 3: spectral phase evolution (dispersion) -----
omega = v * sqrt(lam);              % wave dispersion relation
phase = exp(1i * omega * t);        % traveling phase

% ----- STEP 4: combine -----
c_t = envelope .* c0 .* phase;

% ----- STEP 5: inverse transform -----
x_t = Phi * c_t;

end
