clear 
path = 'test-data\freesurfer\fsaverage\surf\rh.pial';
B = bct.io.import.mesh(path);
B = B.computeEigenbasis(100);
B.Time = bct.Time(linspace(0,1,50)', 50);
B.Omega = B.Time.dual;
B = B.createJoint('Lambda', 'Omega');

% Access joint coordinates
[M, N] = B.Joint.size();  % [100, 50]
lambda_grid = B.Joint.A_grid;  % [100×50]
omega_grid = B.Joint.B_grid;   % [100×50]
B.Manifold.Resolution;
B.Time

% Create figure and panel
fig = uifigure;
panel = uipanel(fig);

% Show mesh inside the panel
B.showMesh('Parent', panel);

path = 'toolbox\data\fsaverage_rh_pial.mat';
BR= bct.io.import.mesh(path);
fig = uifigure;
p = uipanel(fig, 'Position', [10 10 500 400]);

% Create a viewer INSIDE the panel
viewer = viewer3d('Parent', p);

% Display your surface mesh
surfaceMeshShowInParent(B, 'Parent', viewer, 'Title', 'My Mesh');

% Display default gray mesh
BR.showMesh();

B2.Manifold
B2.Manifold.Resolution
B2.Time = bct.manifold.Time(100, 100);  % 1 sec @ 100 Hz
G=bct.manifold.toGspGraph(B2.Manifold)
g =  gsp_design_mexican_hat(G, 6);


% Access resolution
R = B.Manifold.Resolution;

%% --- Eigen decomposition (first 200 modes) ---
k = 200;
[U, D] = eigs(B2.Manifold.Laplacian, k, 'smallestabs');
lambda = diag(D);

%% --- Temporal axis ---
T  = 1000;
fs = 1000;
t = (0:T-1)/fs;

%% --- Define DGW components ---
sx = 5; st = 20; omega0 = 2*pi*10;

psi_graph = @(lambda) lambda .* exp(-lambda/sx);
phi_time  = @(t) exp(-(t.^2)/st^2) .* cos(omega0*t);
K         = @(lambda, t) exp(-t .* lambda);
[Wf,filtertype] = gsp_jtv_design_dgw(G,K,psi_graph,phi_time);
%% --- Evaluate kernels over joint spectrum ---
[lamk, Tgrid] = ndgrid(lambda, t);
Psi_graph = psi_graph(lambda);        % k×1
Psi_time  = psi_time(t);              % 1×T
K_eval    = K(lamk, Tgrid);              % k×T

%% --- Build spectral filter ---
H = (Psi_graph .* K_eval) .* Psi_time;

%% --- Create synthetic spectral excitation ---
X_hat = randn(k, T);

%% --- Apply DGW filter ---
Y_hat = H .* X_hat;

%% --- Return to manifold ---
Y = U * Y_hat;      % Y is N × T MEG-like wave packet


viewer = viewer3d;
viewer.BackgroundGradient="off"
viewer.BackgroundColor = [ 0 0 0];
sMesh.VertexColors = x2rgb(xrec(:,1));  % Returns [N×1] single array
viewer.CameraPosition= [-183.6051 88.9012 36.8928];
viewer.CameraTarget= [27.8792 31.2832 -15.8640];
viewer.CameraUpVector=  [-0.4032 -0.0570 0.9134];
viewer.CameraZoom= 1.3550;
surfaceMeshShow(sMesh,Parent=viewer,Title="Surface Mesh With Viewer")

for k= 1:100
viewer.Children.Color = x2rgb(xrec(:,k));
drawnow
end

for k = 7:10
sMesh.VertexColors = x2rgb(xrec(:,k));  % Returns [N×1] single array
surfaceMeshShow(sMesh,Parent=viewer,Title="Surface Mesh With Viewer")
end

viewer = viewer3d;
viewer.BackgroundColor = [0 0 0];

S = images.ui.graphics.Surface( ...
        Parent = viewer, ...
        Faces = F, ...
        Vertices = V, ...
        VertexColors = x2rgb(xrec(:,1)) );


%% 

sMeshDS.VertexColors = x2rgb(xrec(idx, 1));
surfaceMeshShow(sMeshDS)

% sMesh = bct.manifold.toSurfaceMesh(B.Manifold);
% sMesh.VertexColors=x2rgb(xrec(:, 1));
% surfaceMeshShow(sMesh)
F=sMesh.Faces; V=sMesh.Vertices; 
hMesh = patch('Faces',F,'Vertices',V,...
              'FaceVertexCData',C,...
              'FaceColor','interp',...
              'EdgeColor','none');
%% 
% Import the mesh
path = 'test-data\freesurfer\fsaverage\surf\lh.pial';
B = bct.io.import.mesh(path);

% Precompute eigenbasis for efficiency (optional but recommended)
B.Manifold.meshFourier(300);  % Compute 300 eigenmodes

% Example 1: Basic smooth heat signal (large tau = strong smoothing)
B = bct.sim.heat(B, 2.0, 'label', 'smooth_heat');

% Example 2: Rough heat signal (small tau = preserve high frequencies)
B = bct.sim.heat(B, 0.05, 'label', 'rough_heat');

% Example 3: Medium smoothness
B = bct.sim.heat(B, 0.5, 'label', 'medium_heat');

% Example 4: Band-limited heat signal (only 20-60 mm wavelengths)
B = bct.sim.heat(B, 1.0, 'band', [20, 60], 'label', 'bandlimited_heat');

% Example 5: Generate multiple signals with different smoothness
for tau_val = [0.1, 0.5, 1.0, 2.0, 5.0]
    label = sprintf('heat_tau%.1f', tau_val);
    B = bct.sim.heat(B, tau_val, 'label', label);
end

% Example 6: Get raw output without adding to bct object
[~, x, a] = bct.sim.heat(B, 1.0, 'return_raw', true);
% x = vertex signal, a = spectral coefficients

% Visualize the signals
B.Signal(1).plot();  % Plot first signal
title('Smooth Heat Signal (tau=2.0)');

%% 
k=2
xrec=B.Signals(k).Data;
viewer = viewer3d;
viewer.BackgroundGradient="off"
viewer.BackgroundColor = [ 0 0 0];
sMesh.VertexColors = x2rgb(xrec(:,1));  % Returns [N×1] single array

viewer.CameraPosition= [-183.6051 88.9012 36.8928];
viewer.CameraTarget= [27.8792 31.2832 -15.8640];
viewer.CameraUpVector=  [-0.4032 -0.0570 0.9134];
viewer.CameraZoom= 1.3550;
surfaceMeshShow(sMesh,Parent=viewer,Title="Surface Mesh With Viewer")


B = bct.sim.heat(B, 0.1, 'band', [10, 20], 'label', 'bandlimited_heat');
[~, x, a] = bct.sim.heat(B, 0.01, 'return_raw', true);
viewer.Children.Color = x2rgb(x);
drawnow
%%

G=bct.manifold.toGspGraph (B2.Manifold);
%% 

% Setup your Bct object
clear
% Example 1: Pre-compute modes (faster for multiple filters)
B = bct.io.import.mesh('test-data\freesurfer\fsaverage\surf\lh.pial');
B.Manifold.meshFourier(600);  % Pre-compute 200 modes
B.Time = bct.manifold.Time(100, 100);  % 1 sec @ 100 Hz

%% 
B.reset
% The temporal class now has f_pos property
% Create separable spatial-temporal filter
filt = bct.filters.Filter('Separable');
filt.Manifold = B.Manifold;
filt.Time = B.Time;

% Design Gaussian spatial kernel (wavenumber-based)
k0 = 8;          % Center wavenumber (rad/mm)
sigma_k = 3.5;   % Spatial bandwidth (rad/mm)
[g_spatial, params_spatial] = bct.filters.design.manifold.gaussian(B.Manifold, 'k0', k0, 'sigma_k', sigma_k);

% Design Gabor temporal kernel
omega0 = 2*pi*10;      % 10 Hz center frequency
sigma_t = 0.05;        % Temporal bandwidth (s)
g_temporal = bct.filters.design.time.gabor('omega0', omega0, 'sigma_t', sigma_t);

% Create separable filter: H(λ,ω) = H_λ(λ) * H_ω(ω)
filt.g = @(lambda, omega) g_spatial(lambda) .* g_temporal(omega);
filt.lambda_band = params_spatial.lambda_band;
filt.KernelType = "gaussian_gabor";

% Add to Bct object and generate signal
B.addFilter(filt);
B.Synthesize(1);
sig = B.Generate('label', 'spatiotemporal_signal');

%%
B.reset
% Highly localized quantum wave
k_min = 0.1;   % Very low wavenumber
k_max = 1.0;   % Narrow band
lambda_band = [k_min^2, k_max^2];
mass = 20.0;   
hbar = 0.2;    

filt.g = bct.filters.design.joint.dynamic.schrodinger(B.Manifold, ...
    'hbar', hbar, 'mass', mass);
filt.lambda_band = lambda_band;

B.addFilter(filt);
B.Synthesize(1);
sig = B.Generate('label', 'wave');



%% 

sMesh=bct.manifold.toSurfaceMesh(B.Manifold);

viewer = viewer3d;
viewer.BackgroundGradient="off"
viewer.BackgroundColor = [ 0 0 0];
sMesh.VertexColors = x2rgb(real(sig.Data(:,1)));  % Returns [N×1] single array
viewer.CameraPosition= [-183.6051 88.9012 36.8928];
viewer.CameraTarget= [27.8792 31.2832 -15.8640];
viewer.CameraUpVector=  [-0.4032 -0.0570 0.9134];
viewer.CameraZoom= 1.3550;
surfaceMeshShow(sMesh,Parent=viewer,Title="Surface Mesh With Viewer")
%% 

for k= 1:100
viewer.Children.Color = x2rgb(sig.Data(:,k));
drawnow
end


%%
B.Time = bct.manifold.Time(100, 100);  % 1 sec @ 100 Hz
% The temporal class now has f_pos property
% Test your separable filter code:

% Create separable spatial-temporal filter
filt = bct.filters.Filter('Separable');
filt.Manifold = B.Manifold;
filt.Time = B.Time;

% Design Gaussian spatial kernel (wavenumber-based)
k0 = 8;          % Center wavenumber (rad/mm)
sigma_k = 3.5;   % Spatial bandwidth (rad/mm)
[g_spatial, params_spatial] = bct.filters.design.manifold.gaussian(B.Manifold, 'k0', k0, 'sigma_k', sigma_k);

% Design Gabor temporal kernel
omega0 = 2*pi*10;      % 10 Hz center frequency
sigma_t = 0.05;        % Temporal bandwidth (s)
g_temporal = bct.filters.design.time.gabor('omega0', omega0, 'sigma_t', sigma_t);

% Create separable filter: H(λ,ω) = H_λ(λ) * H_ω(ω)
filt.g = @(lambda, omega) g_spatial(lambda) .* g_temporal(omega);
filt.lambda_band = params_spatial.lambda_band;
filt.KernelType = "gaussian_gabor";

% Add to Bct object and generate signal
B.addFilter(filt);
B.Synthesize(2);
sig = B.Generate('label', 'spatiotemporal_signal', 'rms', 1.0);

%%
B.reset
% 2. Create Schrödinger filter
filt = bct.filters.Filter('Dynamic');
filt.Manifold = B.Manifold;
filt.Time = B.Time;

% Design propagator: K(λ,t) = exp(-i*(ħλ/(2m))*t)
filt.g = bct.filters.design.joint.dynamic.schrodinger(B.Manifold, 'hbar', 1.0, 'mass', 2.0);
filt.lambda_band = [4, 100];  % Eigenvalue band
filt.KernelType = "schrodinger";

% 3. Synthesize and Generate
B.addFilter(filt);
B.Synthesize(1);
sig = B.Generate('label', 'quantum_wave');
%%
% Load mesh and setup
B.reset

% Create dispersing blob
filt = bct.filters.Filter('Dynamic');
filt.Manifold = B.Manifold;
filt.Time = B.Time;
filt.g = bct.filters.design.joint.dynamic.heat(B.Manifold, 'D', 0.01);
filt.lambda_band = [1, 25];  % Medium spatial scales
filt.KernelType = "heat";

B.addFilter(filt);
B.Synthesize(1);
sig = B.Generate('label', 'dispersing_blob', 'output', 'real');

%%
B.reset
% Create traveling wave
filt = bct.filters.Filter('Dynamic');
filt.Manifold = B.Manifold;
filt.Time = B.Time;
filt.g = bct.filters.design.joint.dynamic.wave(B.Manifold, 'c', 2.0);
filt.lambda_band = [4, 100];  % Medium-high frequencies
filt.KernelType = "wave";

B.addFilter(filt);
B.Synthesize(1);
sig = B.Generate('label', 'traveling_wave', 'output', 'real');
