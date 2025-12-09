function packet = bct_wavepacket(B, params)
% bct_wavepacket  Generate, filter, animate, and optionally save a traveling wave packet
%
% OPTIONAL params fields:
%   saveVideo   (false)
%   videoFile   ('wavepacket.mp4')
%   saveKernel  (false)
%   kernelFile  ('kernel.png')

%% ===============================================================
%  Set missing params to default values
% ===============================================================
defaults.lambda0_idx   = floor(0.6 * B.Lambda.N);
defaults.sigma_l_idx   = 40;

defaults.center_t      = floor(B.Time.N/2);
defaults.sigma_t       = 8;
defaults.f0            = 8;      % Hz

defaults.v             = [];

defaults.lambda0_frac  = 0.7;
defaults.sigma_l_frac  = 0.15;

defaults.omega0_frac   = 0.6;
defaults.sigma_w_frac  = 0.2;

defaults.fps           = 10;

defaults.saveVideo     = false;
defaults.videoFile     = 'wavepacket.mp4';

defaults.saveKernel    = false;
defaults.kernelFile    = 'kernel.png';

% Apply defaults
params = applyDefaults(params, defaults);

%% ===============================================================
%  STEP 0 — Extract Axes
% ===============================================================
t      = B.Time.axis;           % Tx1
lambda = B.Lambda.axis;         % Lx1
U      = B.Lambda.U;            % NxL
N      = B.Manifold.N;
T      = B.Time.N;
L      = length(lambda);

%% ===============================================================
%  STEP 0b — Correct FFT Angular Frequency Axis
% ===============================================================
fs = B.Time.fs;
freqs = (0:T-1)*(fs/T);
freqs(T/2+1:end) = freqs(T/2+1:end) - fs;
omega = 2*pi*freqs(:);   % rad/s, unsorted

%% ===============================================================
%  STEP 1 — Spatial Gaussian
% ===============================================================
gL = exp(-((1:L) - params.lambda0_idx).^2 / (2*params.sigma_l_idx^2));
spatial_bump = U * gL.';   % N×1

%% ===============================================================
%  STEP 2 — Temporal Gabor
% ===============================================================
omega0_t = 2*pi*params.f0;   % rad/s carrier

temporal_bump = exp(-(t - t(params.center_t)).^2/(2*params.sigma_t^2)) .* ...
                cos(omega0_t * t);

temporal_bump = temporal_bump.';   % 1×T

%% ===============================================================
%  STEP 3 — Spatiotemporal source
% ===============================================================
f = spatial_bump * temporal_bump;   % N×T

%% ===============================================================
%  STEP 4 — λ transform, then FFT
% ===============================================================
F_lambda        = U' * f;                % L×T
F_lambda_omega  = fft(F_lambda,[],2);     % L×T

%% ===============================================================
%  STEP 5 — Velocity Kernel
% ===============================================================
lambda0 = lambda(round(params.lambda0_frac * L));
sigma_l = (lambda(end) - lambda(1)) * params.sigma_l_frac;

omega0  = omega(round(params.omega0_frac * T));
sigma_w = (max(omega)-min(omega)) * params.sigma_w_frac;

% If v unspecified, auto-match ridge slope
if isempty(params.v)
    params.v = omega0 / sqrt(lambda0);
end

[LL, WW] = ndgrid(lambda, omega);

velocityKernel = @(lambda,omega,v,lambda0,sigma_l,omega0,sigma_w) ...
    exp(-((omega - (omega0 + v.*sqrt(lambda))).^2)/(2*sigma_w^2)) .* ...
    exp(-((lambda - lambda0).^2)/(2*sigma_l^2));

H = velocityKernel(LL, WW, params.v, lambda0, sigma_l, omega0, sigma_w);

% Correct visualization axis
omega_vis = fftshift(omega);
H_vis     = fftshift(H,2);

%% ===============================================================
%  STEP 6 — Apply filter
% ===============================================================
G_lambda_omega = F_lambda_omega .* H;
G_lambda_time  = ifft(G_lambda_omega,[],2,'symmetric');

%% ===============================================================
%  STEP 7 — Reconstruct packet
% ===============================================================
packet = U * G_lambda_time;   % N×T

%% ===============================================================
%  STEP 8 — Plot kernel (optional save)
% ===============================================================
figKernel = figure('Name','Velocity Kernel');
imagesc(omega_vis, lambda, H_vis);
axis xy;
xlabel('\omega (rad/s)');
ylabel('\lambda');
title('Velocity Kernel H(\lambda,\omega)');
colorbar;

if params.saveKernel
    saveas(figKernel, params.kernelFile);
end

%% ===============================================================
%  STEP 9 — Animate packet (optional video save)
% ===============================================================
B.showMesh;
viewer = B.Viewer;

fps = params.fps;
dt  = 1/fps;

colors = @(x) double(bct.show.x2rgb(x,'Colormap','hot'));

if params.saveVideo
    figMesh = ancestor(viewer,'figure');
    vOut = VideoWriter(params.videoFile,'MPEG-4');
    vOut.FrameRate = fps;
    open(vOut);
end

for k = 1:T
    viewer.Children.Color = colors(packet(:,k));
    drawnow limitrate nocallbacks;
    pause(dt);

    if params.saveVideo
        writeVideo(vOut, getframe(figMesh));
    end
end

if params.saveVideo
    close(vOut);
end

end


%% ===============================================================
% Helper — apply defaults
% ===============================================================
function params = applyDefaults(params, defaults)
    fields = fieldnames(defaults);
    for i = 1:numel(fields)
        f = fields{i};
        if ~isfield(params, f) || isempty(params.(f))
            params.(f) = defaults.(f);
        end
    end
end
