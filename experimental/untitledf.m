bioctree_start
%% Build Bct
B = bct_fsaverage;
B.Time = bct.Time(1000,250);  
B = B.computeEigenbasis(400);

%% Regenerate delta using the new time size
delta_data = zeros(B.Manifold.N, B.Time.N);  
delta_data(4443, 50) = 1;

% Spatial transform
U = B.Lambda.U;
lambda = B.Lambda.axis;
omega  = B.Omega.axis;

F_lambda = U' * delta_data;       % 399×100
F_lambda_omega = fft(F_lambda,[],2);   % 399×100

% Velocity kernel
v = 4;
lambda0 = lambda(floor(0.01*length(lambda)));
sigma_l = lambda(floor(0.9*length(lambda)));

omega0  = omega(floor(0.5*length(omega)));
sigma_w = omega(floor(0.1*length(omega)));

[LL,WW] = ndgrid(lambda,omega);
velocityKernel = @(lambda,omega,v,lambda0,sigma_l,omega0,sigma_w) ...
    exp(-((omega - (omega0 + v.*sqrt(lambda))).^2)/(2*sigma_w^2)) .* ...
    exp(-((lambda - lambda0).^2)/(2*sigma_l^2));

H = velocityKernel(LL, WW, v, lambda0, sigma_l, omega0, sigma_w);

% Sizes now match:
% H:              399 × 100
% F_lambda_omega: 399 × 100

G_lambda_omega = F_lambda_omega .* H;     % OK
G_lambda_time = ifft(G_lambda_omega,[],2,'symmetric');

% Inverse spatial transform
packet = U * G_lambda_time;  % 163842×100


B.showMesh;   % returns a viewer3d handle
ax = B.Viewer;           % for clarity

colors = @(x) double(bct.show.x2rgb(x, 'Colormap', 'hot'));   % shorthand

fps = 10;               % frames per second
dt  = 1 / fps;          % pause duration

for k = 1:B.Time.N
    ax.Children.Color = colors(packet(:,k));  
    drawnow limitrate nocallbacks % smoother + lower CPU
    pause(dt);                     % control animation speed
end
%% 
figure;
imagesc(omega, lambda, H);
axis xy;
xlabel('\omega (rad/s)');
ylabel('\lambda (wavenumber)');
title('Velocity Kernel H(\lambda,\omega)');
colorbar;
%%
%%% STEP 0: axes
t = B.Time.axis;           % [100×1]
lambda = B.Lambda.axis;    % [399×1]
U = B.Lambda.U;           
N = B.Manifold.N;
T = B.Time.N;

%%% STEP 1: spatial Gaussian in eigenmode index space
L = length(lambda);
lambda0_idx = floor(0.3 * L);
sigma_l_idx = 40;
gL = exp(-((1:L) - lambda0_idx).^2 / (2*sigma_l_idx^2));
spatial_bump = U * gL.';           % [N×1] non-zero!

%%% STEP 2: temporal Gabor
center_t = 50;
sigma_t = 5;
omega0 = 2*pi*10;

temporal_bump = exp(-(t - t(center_t)).^2/(2*sigma_t^2)) .* cos(omega0 * t);
temporal_bump = temporal_bump.';   % [1×100]

%%% STEP 3: spatiotemporal source
f = spatial_bump * temporal_bump;  % [N×T]

%%% Continue with your filtering pipeline...
F_lambda = U' * f;       % 399×100
F_lambda_omega = fft(F_lambda,[],2);   % 399×100

% Velocity kernel
v = 12;
lambda0 = lambda(floor(0.9*length(lambda)));
sigma_l = lambda(floor(0.8*length(lambda)));

omega0  = omega(floor(0.4*length(omega)));
sigma_w = omega(floor(0.2*length(omega)));

[LL,WW] = ndgrid(lambda,omega);
velocityKernel = @(lambda,omega,v,lambda0,sigma_l,omega0,sigma_w) ...
    exp(-((omega - (omega0 + v.*sqrt(lambda))).^2)/(2*sigma_w^2)) .* ...
    exp(-((lambda - lambda0).^2)/(2*sigma_l^2));

H = velocityKernel(LL, WW, v, lambda0, sigma_l, omega0, sigma_w);

% Sizes now match:
% H:              399 × 100
% F_lambda_omega: 399 × 100

G_lambda_omega = F_lambda_omega .* H;     % OK
G_lambda_time = ifft(G_lambda_omega,[],2,'symmetric');

% Inverse spatial transform
packet = U * G_lambda_time;  % 163842×100
figure (1);
imagesc(omega, lambda, H);
axis xy;
xlabel('\omega (rad/s)');
ylabel('\lambda (wavenumber)');
title('Velocity Kernel H(\lambda,\omega)');
colorbar;

B.showMesh;   % returns a viewer3d handle
ax = B.Viewer;           % for clarity

colors = @(x) double(bct.show.x2rgb(x, 'Colormap', 'hot'));   % shorthand

fps = 10;               % frames per second
dt  = 1 / fps;          % pause duration

for k = 1:3
    ax.Children.Color = colors(packet(:,k));  
    drawnow limitrate nocallbacks % smoother + lower CPU
    pause(dt);                     % control animation speed
end

%% 
%% STEP 0 — Axes and Basic Objects
% =============================================================
t = B.Time.axis;              % [100×1] physical time axis
lambda = B.Lambda.axis;       % [399×1] Laplace-Beltrami eigenvalues
U = B.Lambda.U;               % [163842×399]
N = B.Manifold.N;             % vertices
T = B.Time.N;                 % time samples
L = length(lambda);

% ============================================================
%  STEP 0b — Correct FFT frequency axis (CRITICAL FIX)
% =============================================================
fs = B.Time.fs;           % sampling rate from Time object
Nfreq = T;                % number of FFT points

% True FFT frequencies (Hz)
freqs = (0:Nfreq-1) * (fs/Nfreq);
freqs(Nfreq/2+1:end) = freqs(Nfreq/2+1:end) - fs;

% Convert to angular frequency (rad/s)
omega = 2*pi * freqs(:);     % [100×1]

% ============================================================
%  STEP 1 — Spatial Gaussian in eigenvalue index space
% =============================================================
lambda0_idx  = floor(0.6 * L);   % center in eigenmode index (higher = finer scale)
sigma_l_idx  = 40;               % width in modes

gL = exp(-((1:L) - lambda0_idx).^2 / (2*sigma_l_idx^2));  % [1×399]

% Expand spatially
spatial_bump = U * gL.';         % [N×1] spatial Gaussian on mesh

% ============================================================
%  STEP 2 — Temporal Gabor burst
% =============================================================
center_t = 50;
sigma_t = 8;
f0 = 8;                          % temporal carrier frequency (Hz)
omega0_t = 2*pi*f0;              % rad/s

temporal_bump = exp(-(t - t(center_t)).^2/(2*sigma_t^2)) .* cos(omega0_t * t);
temporal_bump = temporal_bump.';   % [1×100]

% ============================================================
%  STEP 3 — Spatiotemporal source f(x,t)
% =============================================================
f = spatial_bump * temporal_bump;    % [N×T]

%============================================================
%  STEP 4 — Transform to λ–ω domain
% =============================================================
F_lambda = U' * f;                    % [399×100]
F_lambda_omega = fft(F_lambda, [], 2); % [399×100]

% ============================================================
%  STEP 5 — Velocity Kernel (working ridge)
% =============================================================
% Convert lambda0_idx to actual lambda0
lambda0_idx_c=lambda0_idx-100
lambda0 = lambda(lambda0_idx_c);

% Good spatial bandwidth
sigma_l = (lambda(end)-lambda(1)) / 12;
%sigma_l = (lambda(end)-lambda(1)) ;

% Choose temporal center in positive frequency band
omega0 = omega(round(0.3*length(omega)));

% Temporal width
sigma_w = (max(omega)-min(omega)) / 16;

% IMPORTANT: choose v to match ridge slope
v = omega0 / sqrt(lambda0);
v=400
% Create meshgrid for kernel
[LL, WW] = ndgrid(lambda, omega);

% Velocity kernel definition
velocityKernel = @(lambda,omega,v,lambda0,sigma_l,omega0,sigma_w) ...
    exp(-((omega - (omega0 + v.*sqrt(lambda))).^2)/(2*sigma_w^2)) .* ...
    exp(-((lambda - lambda0).^2)/(2*sigma_l^2));

% Evaluate kernel
H = velocityKernel(LL, WW, v, lambda0, sigma_l, omega0, sigma_w);

%============================================================
%  STEP 6 — Apply velocity filter
% =============================================================
G_lambda_omega = F_lambda_omega .* H;
G_lambda_time  = ifft(G_lambda_omega, [], 2, 'symmetric');

% ============================================================
%  STEP 7 — Inverse spatial transform
% =============================================================
packet = U * G_lambda_time;     % [163842×100]

% ============================================================
%  STEP 8 — Plot the velocity kernel
% =============================================================
figure(1);
imagesc(omega, lambda, H);
axis xy;
xlabel('\omega (rad/s)');
ylabel('\lambda (wavenumber)');
title('Velocity Kernel H(\lambda,\omega)');
colorbar;

% ============================================================
%  STEP 9 — Visualize traveling wave
% =============================================================
B.showMesh;
ax = B.Viewer;

colors = @(x) double(bct.show.x2rgb(x, 'Colormap', 'hot'));

fps = 12;
dt = 1/fps;

for k = 1:T
    ax.Children.Color = colors(packet(:,k));
    drawnow limitrate nocallbacks
    pause(dt);
end
%
%% 
% =============================================================
B.showMesh;
ax = B.Viewer;


% --- Setup video writer ---
v = VideoWriter('wavepacket_video6.mp4','MPEG-4');
v.FrameRate = 1/dt;        % match your animation speed
open(v);

% --- Animation loop with video capture ---
for k = 1:50 
    ax.Children.Color = colors(packet(:,k));  
    drawnow limitrate nocallbacks

    % grab the current frame
    frame = getframe(gcf); 
    writeVideo(v, frame);

    pause(dt);
end

% --- Finish ---
close(v);

%% 
% ============================================================
%  Create a figure with THREE panels
% =============================================================
fig = figure('Name','Dual View + Kernel','Position',[100 100 1800 700]);

panel_left  = uipanel(fig,'Position',[0     0   0.33 1]);   % lateral
panel_mid   = uipanel(fig,'Position',[0.33  0   0.33 1]);   % medial
panel_right = uipanel(fig,'Position',[0.66  0   0.34 1]);   % kernel image

%============================================================
%  Create TWO viewer3d objects
% =============================================================
viewer1 = viewer3d('Parent', panel_left, ...
                   'BackgroundColor',[0 0 0], ...
                   'BackgroundGradient',"off");

viewer2 = viewer3d('Parent', panel_mid, ...
                   'BackgroundColor',[0 0 0], ...
                   'BackgroundGradient',"off");

% ============================================================
%  Show the mesh in BOTH viewers
% =============================================================
% Get the surface mesh once
sMeshTemplate = B.showMesh;     % produces B.Viewer (we ignore it)

% Copy geometry into two independent viewer3d surfaces
s1 = surfaceMeshShow(sMeshTemplate, Parent=viewer1);
s2 = surfaceMeshShow(sMeshTemplate, Parent=viewer2);

% ============================================================
%  Apply the two camera views
% =============================================================

% LATERAL VIEW
viewer1.CameraPosition = [203.5730 -72.7343 41.1091];
viewer1.CameraTarget   = [-4.6668 2.2778 -1.7645];
viewer1.CameraUpVector = [0.5130 0.1698 0.8414];
viewer1.CameraZoom     = 1.2389;

% MEDIAL VIEW
viewer2.CameraPosition = [-222.9685 19.3550 49.3928];
viewer2.CameraTarget   = [-4.1259 5.6774 -3.0438];
viewer2.CameraUpVector = [-0.3643 0.2599 0.8943];
viewer2.CameraZoom     = 1.2389;

% ============================================================
%  Plot the velocity kernel H(λ,ω) in the right panel
% =============================================================
axes('Parent', panel_right);
imagesc(omega, lambda, H);
axis xy;
xlabel('\omega (rad/s)');
ylabel('\lambda');
title('Velocity Kernel (H(\lambda,\omega))');
colorbar;

% ============================================================
%  Synchronized Animation
% =============================================================
fps = 10;
dt = 1/fps;
colors = @(x) double(bct.show.x2rgb(x,'Colormap','hot'));

for k = 1:T
    frameColor = colors(packet(:,k));

    % update BOTH meshes
    s1.Color = frameColor;
    s2.Color = frameColor;

    drawnow limitrate nocallbacks
    pause(dt);
end
%% 
%% 
delta = zeros(N,1);
delta(path(k)) = 1;

delta_lambda = U' * delta;
filtered_lambda = H .* delta_lambda;
packet (:,k) = U * filtered_lambda;
%% 
%% ============================================================
%  STEP 0 — Setup Bct
% =============================================================
B = bct_fsaverage;
B.Time = bct.Time(100, 250);        % 100 frames, 250 Hz sampling
B = B.computeEigenbasis(400);

U      = B.Lambda.U;                % [N × 399]
lambda = B.Lambda.axis;             % [399 × 1]
N      = B.Manifold.N;
T      = B.Time.N;                  % 100 frames

%% ============================================================
%  STEP 1 — Define path of motion across mesh
% =============================================================
start_vertex = 15000;
end_vertex   = 14000;

% You can use any path method, below we do a straight vertex index path:
path = round(linspace(start_vertex, end_vertex, T));

% Optional: compute a geodesic path using gptoolbox or Dijkstra later.

%% ============================================================
%  STEP 2 — Heat kernel in spectral domain
% =============================================================
tau = 0.005;                   % smoothing strength
H = exp(-tau * lambda);        % [399×1]

%% ============================================================
%  STEP 3 — Build traveling patch
% =============================================================
packet = zeros(N, T);

for k = 1:T
    % (A) delta at current path vertex
    delta = zeros(N,1);
    delta(path(k)) = 1;

    % (B) spatial Fourier transform
    delta_lambda = U' * delta;      % 399×1

    % (C) filter with heat kernel
    filtered_lambda = H .* delta_lambda;

    % (D) inverse spectral transform = smoothed bump
    packet(:,k) = U * filtered_lambda;
end

%% ============================================================
%  STEP 4 — Visualize traveling patch on cortex
% =============================================================
B.showMesh;
ax = B.Viewer;

colors = @(x) double(bct.show.x2rgb(x, 'Colormap','hot'));
fps = 15;
dt = 1/fps;

for k = 1:T
    ax.Children.Color = colors(packet(:,k));
    drawnow limitrate nocallbacks
    pause(dt);
end
