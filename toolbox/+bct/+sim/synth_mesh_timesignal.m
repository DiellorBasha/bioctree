function [xrec, A_kl, f_space, f_time] = synth_mesh_timesignal(Manifold, spec_space, spec_time, packet)
% SYNTH_MESH_TIMESIGNAL
% Build a spatiotemporal signal x(x_i, t_j) on a mesh using the joint
% (Laplacian eigenbasis × temporal Fourier basis) with optional wave-packet structure.
%
% INPUTS:
%   Manifold    : struct from B.Manifold with fields:
%                 Eigenvectors [N x K], Eigenvalues [K x 1], MassMatrix, Time.T, Time.fs
%
%   spec_space  : struct describing spatial spectral shape
%                 (same format as your original synth_mesh_signal)
%                 Example:
%                    spec_space.type = 'narrowband';
%                    spec_space.f0   = 0.015;   % cycles/mm
%                    spec_space.bw   = 0.005;
%
%   spec_time   : struct describing temporal spectral shape
%                 Example:
%                    spec_time.type = 'narrowband';
%                    spec_time.f0   = 10;    % Hz
%                    spec_time.bw   = 2;     % Hz
%
%   packet      : struct describing packet envelope and velocity
%                 Fields:
%                    packet.type      = 'gaussian';  % temporal envelope
%                    packet.t0        = 0.5;         % center time (sec)
%                    packet.sigma_t   = 0.1;         % spread of packet
%                    packet.velocity  = 0;           % group velocity map, mm/s (0 = standing packet)
%                 Optional: packet.direction = [dx dy dz] (unit vector)
%
% OUTPUTS:
%   xrec   : [N x T] spatiotemporal signal
%   A_kl   : [K x T] joint spectral coefficients
%   f_space: [K x 1] spatial cycles/mm
%   f_time : [T x 1] temporal frequencies (Hz)
%
%
% DEVELOPER:
%   This extends synth_mesh_signal to time, using tensor-product filtering
%   and packet envelopes.

%% --- 1. Extract manifold structures ---
U    = Manifold.Eigenvectors;     % [N x K]
lam  = Manifold.Eigenvalues;      % [K x 1]
d    = diag(Manifold.MassMatrix); % mass diag
T    = Manifold.Time.T;
fs   = Manifold.Time.fs;

N = size(U,1);
K = length(lam);

%% --- 2. Spatial frequencies (cycles/mm) ---
f_space = sqrt(lam) / (2*pi);   % approximate spatial cycles/mm

%% --- 3. Temporal frequencies via FFT (Hz) ---
f_time = (0:T-1)' * (fs/T);

%% --- 4. Design spatial power P_space(k) ---
P_space = bct.sim.design_power(f_space, spec_space);   % reuses your helper logic

%% --- 5. Design temporal power P_time(l) ---
P_time  = bct.sim.design_power(f_time,  spec_time);

%% --- 6. Outer product creates joint power P(k,l) ---
P_joint = P_space(:) * P_time(:)';   % [K x T]

%% --- 7. Random phases (spatial × temporal)
phase_kl = rand(K, T) * 2*pi;      
A_kl = sqrt(P_joint) .* exp(1i * phase_kl);   % complex coefficients

%% --- 8. Wave packet envelope in time (optional)
if isfield(packet,'type') && strcmpi(packet.type,'gaussian')
    t = (0:T-1)/fs;
    env_t = exp(-0.5 * ((t - packet.t0) ./ packet.sigma_t).^2);  % [1 x T]
else
    env_t = ones(1,T);   % no envelope (continuous wave)
end

A_kl = A_kl .* env_t;   % apply time envelope

%% --- 9. Optional: traveling wave velocity
if isfield(packet,'velocity') && packet.velocity ~= 0

    % group velocity measured in mm/s
    v = packet.velocity;

    % Project vertices onto direction vector
    if isfield(packet,'direction')
        dir = packet.direction(:)' / norm(packet.direction);
    else
        dir = [1 0 0]; % default direction in x
    end

    xcoords = Manifold.V * dir';         % [N x 1] projected coordinates
    U_phase = U' * xcoords;              % spatial phase shift per mode (approx)

    for l = 1:T
        % Temporal modulation: exp(i k * x - i w t)
        A_kl(:,l) = A_kl(:,l) .* exp(1i * U_phase(:) * (2*pi*f_time(l)/v));
    end
end

%% --- 10. Build signal in spatial domain ---
% Step 1: inverse temporal FFT on each spatial mode
A_time = ifft(A_kl, [], 2, 'symmetric');   % [K x T]

% Step 2: reconstruct into vertex domain
x_wt = U * A_time;                         % [N x T] weighted by eigenmodes

% Step 3: apply M^(+1/2)
S = spdiags(sqrt(d),0,N,N);
xrec = S * x_wt;

end
