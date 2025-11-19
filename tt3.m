clear B
path = 'test-data\freesurfer\fsaverage\surf\lh.pial';
B2 = bct.io.import.mesh(path);
B2.Manifold
B2.Manifold.Resolution
B2.Time = bct.manifold.Time(100, 100);  % 1 sec @ 100 Hz
G=bct.manifold.toGspGraph(B2.Manifold);
G=gsp_jtv_graph(G, B2.Time.T, B2.Time.fs);

filter_params = gsp_jtv_filterbank('heat', [1, 2, 4], G);

[F, filterType] = gsp_jtv_design_diffusion(G);
[Fw, filterTypeW] = gsp_jtv_design_wave(G, 0.01);
[Fd, filtertype] = gsp_jtv_design_damped_wave(G, 0.01);


% Compute eigenvalues
B2.Manifold.meshFourier(600);

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

%%
% Compute Fourier basis
[U, lam] = B.Manifold.meshFourier(600);

% Narrowband signal
spec.type = 'narrowband';
spec.f0 = 0.1;
spec.bw_abs = 0.02;
[x, coeffs, freqs] = bct.sim.synth_mesh_signal(B, spec);

% 1/f noise
spec.type = 'powerlaw';
spec.alpha = 1;
x = bct.sim.synth_mesh_signal(B, spec, 'k', 300);

%% Define frequency range and bands
% Convert eigenvalues to spatial frequencies (cycles/mm)
% Assumes B.Manifold.V is in mm units
% Frequency range actually covered by your current eigenpairs

%path = 'test-data\freesurfer\fsaverage\surf\lh.pial';
%B = bct.io.import.mesh(path);
% Compute Fourier basis
%[U, lam] = B.Manifold.meshFourier(600);
f_all = sqrt(lam)/(2*pi);
fmin = min(f_all(f_all>0));
fmax = max(f_all);

% Keep a little margin away from edges so the Gaussian isn't clipped
lo = 1.15;          % 15% above fmin
hi = 0.85;          % 15% below fmax
f_lo = lo*fmin;
f_hi = hi*fmax;

%% Example 1 - 5 bands with different bandwidth
% Choose 5 log-spaced centers from long -> short wavelengths
nBands = 5;
f0s = logspace(log10(f_lo), log10(f_hi), nBands);  % centers (cyc/mm)
bw_frac = 0.20;     % bandwidth as a fraction of center (i.e., sigma = 0.2*f0)
rng(7);             % reproducibility for random coefficient signs

%% Generate signals for each band
X = cell(nBands, 1);
P_spec = cell(nBands, 1);
FreqBands = cell(nBands, 1);
for i = 1:nBands
    f0 = f0s(i);
    % Create narrowband power spectrum
    spec = struct('type', 'narrowband', ...
                  'f0', f0, ...
                  'bw_frac', bw_frac);
    [x_i, P_i, freq_i] = bct.sim.synth_mesh_signal(B, spec, 'k', k, 'verbose', false);
    X{i} = x_i;              % Synthesized signal on mesh
    P_spec{i} = P_i;         % Power spectrum (eigenmode coefficients squared)
    FreqBands{i} = freq_i;   % Spatial frequencies for each mode
end


%%
% --- Plot spectra overlay (simple frequency vs power)
figure(1); clf; hold on
for i = 1:nBands
    [fs, idx] = sort(FreqBands{i});
    plot(fs, P_spec{i}(idx), '.-');    % plain overlay; no special colors needed
end
grid on
xlabel('spatial frequency (cycles/mm)');
ylabel('power');
title('Five narrowband designed spectra (long \rightarrow short wavelengths)');
legend(arrayfun(@(c) sprintf('f0=%.4f', c), f0s, 'uni', 0), 'Location','best');
%% 
% --- Show reconstructed fields on the mesh (one figure per band)
for i = 1:nBands
    xrec = X{i};
    RGB = x2rgb(xrec);                 % your helper to colorize vertex data
    B.mesh.VertexColors = RGB; 
    surfaceMeshShow(B.mesh);
    axis image off
    title(sprintf('Narrowband ~ f0=%.4f cyc/mm (bw=%.4f)', f0s(i), bw_frac*f0s(i)));
end

%% Visualize the bands
figure('Position', [100 100 1400 800]);
for i = 1:nBands
    % Plot signal on mesh
    subplot(2, nBands, i);
    sm = bct.manifold.toSurfaceMesh(B.Manifold);
    sm.VertexColors = (X{i} - min(X{i})) / (max(X{i}) - min(X{i}));  % Normalize
    h = surfaceMeshShow(sm);
    axis equal off; view(3); lighting gouraud; camlight;
    title(sprintf('Band %d: f_0=%.3f', i, f0s(i)));
    
    % Plot power spectrum
    subplot(2, nBands, nBands + i);
    plot(FreqBands{i}, P_spec{i}, 'LineWidth', 1.5);
    xlabel('Frequency (cyc/mm)'); ylabel('Power');
    title(sprintf('Power Spectrum'));
    grid on; xlim([f_lo f_hi]);
    set(gca, 'XScale', 'log');  % Log scale for better visualization
end

%% Combine bands (e.g., sum with different weights)
weights = ones(nBands, 1);  % Equal weights
x_combined = zeros(size(X{1}));
for i = 1:nBands
    x_combined = x_combined + weights(i) * X{i};
end

% Visualize combined signal
figure('Name', 'Combined Multi-band Signal');
sm.VertexColors = (x_combined - min(x_combined)) / (max(x_combined) - min(x_combined));
surfaceMeshShow(sm);
axis equal off; view(3); lighting gouraud; camlight;
title('Combined Signal (5 bands)');
colorbar;
%% Project signal onto Fourier basis
% Get mass matrix inverse for proper inner product
d = full(diag(mani.MassMatrix));
Sinv = spdiags(1./sqrt(d), 0, length(d), length(d));

% Project: coefficients = U' * Sinv * signal
coeffs = mani.Eigenvectors' * (Sinv * signal);

% Low-pass filter: keep only first 50 modes
nModes = 50;
coeffs_lowpass = coeffs;
coeffs_lowpass(nModes+1:end) = 0;

% Reconstruct
signal_filtered = mani.Eigenvectors * coeffs_lowpass;

% Visualize filtered signal
subplot(1,3,2);
trisurf(F, V(:,1), V(:,2), V(:,3), signal_filtered, 'EdgeColor', 'none');
axis equal off; colorbar; title(sprintf('Low-pass (%d modes)', nModes));
view(3); lighting gouraud; camlight;

% Visualize difference (high-frequency component)
subplot(1,3,3);
trisurf(F, V(:,1), V(:,2), V(:,3), signal - signal_filtered, 'EdgeColor', 'none');
axis equal off; colorbar; title('High-frequency component');
view(3); lighting gouraud; camlight;

%% Access cached properties
fprintf('\nCached properties:\n');
fprintf('  Eigenvectors: [%d x %d]\n', size(mani.Eigenvectors));
fprintf('  Eigenvalues: [%d x 1]\n', length(mani.Eigenvalues));
fprintf('  MassMatrix: [%d x %d] (nnz=%d)\n', size(mani.MassMatrix), nnz(mani.MassMatrix));

%% Visualize some eigenmodes (Fourier basis functions)
figure('Name', 'First 6 Eigenmodes');
for i = 1:6
    subplot(2,3,i);
    trisurf(F, V(:,1), V(:,2), V(:,3), mani.Eigenvectors(:,i), ...
        'EdgeColor', 'none', 'FaceColor', 'interp');
    axis equal off;
    title(sprintf('Mode %d (\\lambda=%.4f)', i, mani.Eigenvalues(i)));
    view(3); lighting gouraud; camlight;
end

%%
clear B
path = 'test-data\freesurfer\fsaverage\surf\lh.pial';
B = bct.io.import.mesh(path);
% Compute Fourier basis
[U, lam] = B.Manifold.meshFourier(600);

spec.type = 'narrowband';
spec.f0 = 0.1;
spec.bw_abs = 0.02;

% No k needed - uses all 600 cached modes!
B = bct.sim.synth_mesh_signal(B, spec);
%% 


% Setup temporal dimension
B.Manifold.Time = bct.manifold.Time(100, 100);  % 1 sec @ 100 Hz

% Spatial pattern spec
spec.type = 'narrowband';
spec.f0 = 0.1;

% Temporal dynamics
timespec.type = 'sinusoid';
timespec.freq = 10;  % 10 Hz oscillation

% Generate
[B_out, spatial, temporal] = bct.sim.synth_mesh_signal_dynamic(B, spec, timespec);


sMesh = bct.manifold.toSurfaceMesh(B.Manifold);
sMesh.VertexColors = x2rgb(B.Signals(1).Data);  % Returns [N×1] single array

viewer = viewer3d;
viewer.BackgroundGradient="off"
viewer.BackgroundColor = [ 0 0 0]
for k = 1:10
sMesh.VertexColors = x2rgb(B.Signals(3).Data(:,k));  % Returns [N×1] single array

surfaceMeshShow(sMesh,Parent=viewer,Title="Surface Mesh With Viewer")
end

%% 

spec_space.type = 'narrowband';
spec_space.f0   = 0.02;      % cycles/mm
spec_space.bw   = 0.01;

spec_time.type = 'narrowband';
spec_time.f0   = 10;         % Hz
spec_time.bw   = 2;

packet.type    = 'gaussian';
packet.t0      = 0.5;
packet.sigma_t = 0.1;
packet.velocity = 0;         % standing packet

[xrec,~,~,~] = bct.sim.synth_mesh_timesignal(B.Manifold, spec_space, spec_time, packet);
sMesh = bct.manifold.toSurfaceMesh(B.Manifold);
sMesh.VertexColors = x2rgb(xrec(:,1));  % Returns [N×1] single array

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
