clear B
path = 'test-data\freesurfer\fsaverage\surf\lh.pial';
B = bct.io.import.mesh(path);
B.Manifold
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
lambda_space = B.Manifold.Eigenvalues;   % [NumModes x 1]
T = B.Manifold.Time.T;                   % number of time points
fs = B.Manifold.Time.fs;                 % sampling rate
f = (0:T-1)' * (fs/T);   % frequencies 0 → Nyquist
omega_time = 2*pi*f;      % convert to angular frequency
[Lambda_space, Omega_time] = ndgrid(lambda_space, omega_time);
JointSpectrum = Lambda_space + Omega_time;   % [NumModes x T]
Manifold.Joint.Index = @(k,l) lambda_space(k) + omega_time(l);

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

%%
texH = 2048;    % height
texW = 4096;    % width
UV = B.Manifold.UV;
uPix = round(UV(:,1) * (texW-1)) + 1;
vPix = round((1 - UV(:,2)) * (texH-1)) + 1;   % flip v-axis for images

 tex = nan(texH, texW);
    idx = sub2ind([texH texW], vPix, uPix);
    tex(idx) = values;
    
    % Fill missing pixels by nearest neighbor
    tex = fillmissing(tex, 'nearest');

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
