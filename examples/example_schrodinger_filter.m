%% Example: Schrödinger Quantum Diffusion Filter
% Demonstrates how to create and use a dynamic Schrödinger propagator
% for quantum-like wave evolution on a brain surface

clear; close all;

%% Setup: Load mesh and set time
fprintf('=== Schrödinger Filter Example ===\n\n');

% Load brain mesh
B = bct.io.import.mesh('test-data\freesurfer\fsaverage\surf\lh.pial');

% Pre-compute eigenmodes
B.Manifold.meshFourier(200);  % 200 modes for quantum evolution

% Set up time domain
B.Time = bct.manifold.Time(100, 100);  % 1 second @ 100 Hz
fprintf('Time domain: %d samples @ %d Hz (%.2f s)\n', B.Time.T, B.Time.fs, B.Time.T/B.Time.fs);

%% Create Schrödinger filter
fprintf('\n=== Creating Schrödinger Filter ===\n');

% Create Dynamic filter
filt = bct.filters.Filter('Dynamic');
filt.Manifold = B.Manifold;
filt.Time = B.Time;

% Design Schrödinger propagator: K(λ,t) = exp(-i*(ħλ/(2m))*t)
hbar = 1.0;   % Reduced Planck constant (controls oscillation rate)
mass = 2.0;   % Effective mass (larger = slower evolution)

filt.g = bct.filters.design.joint.dynamic.schrodinger(B.Manifold, ...
    'hbar', hbar, 'mass', mass);
filt.KernelType = "schrodinger";

% Set spatial frequency band (which modes to include)
k_min = 2;    % Minimum wavenumber (rad/mm)
k_max = 10;   % Maximum wavenumber (rad/mm)
lambda_band = [k_min^2, k_max^2];  % Convert to eigenvalues
filt.lambda_band = lambda_band;

fprintf('Schrödinger propagator parameters:\n');
fprintf('  ħ (hbar) = %.2f\n', hbar);
fprintf('  m (mass) = %.2f\n', mass);
fprintf('  Wavenumber band: k ∈ [%.1f, %.1f] rad/mm\n', k_min, k_max);
fprintf('  Eigenvalue band: λ ∈ [%.1f, %.1f]\n', lambda_band(1), lambda_band(2));

%% Synthesize and Generate
fprintf('\n=== Synthesizing Signal ===\n');

B.addFilter(filt);
B.Synthesize(1);  % Propagates random initial conditions

fprintf('\n=== Generating Time-Domain Signal ===\n');
sig = B.Generate('label', 'quantum_wave', 'normalize', true);

%% Visualize results
fprintf('\n=== Visualizing Quantum Wave Evolution ===\n');

figure('Position', [100 100 1400 800]);

% Show signal at 4 time points
time_points = [1, 25, 50, 75];  % 0s, 0.24s, 0.49s, 0.74s
for i = 1:4
    subplot(2,4,i);
    t_idx = time_points(i);
    t_sec = (t_idx-1) / B.Time.fs;
    
    B.Manifold.plot('data', real(sig.Data(:,t_idx)), 'shading', 'interp');
    colormap(jet); 
    colorbar;
    title(sprintf('Real Part: t = %.2f s', t_sec));
    axis equal tight off;
    view([-90 0]);
    caxis([-1 1]*max(abs(sig.Data(:))));
end

% Show imaginary part at same times
for i = 1:4
    subplot(2,4,i+4);
    t_idx = time_points(i);
    t_sec = (t_idx-1) / B.Time.fs;
    
    B.Manifold.plot('data', imag(sig.Data(:,t_idx)), 'shading', 'interp');
    colormap(jet);
    colorbar;
    title(sprintf('Imag Part: t = %.2f s', t_sec));
    axis equal tight off;
    view([-90 0]);
    caxis([-1 1]*max(abs(sig.Data(:))));
end

sgtitle('Schrödinger Wave Evolution on Brain Surface');

%% Time evolution at a single vertex
figure('Position', [100 100 1200 500]);

% Pick a vertex in an interesting region
vertex_idx = round(B.Manifold.N / 3);

subplot(1,2,1);
t = (0:B.Time.T-1) / B.Time.fs;
plot(t, real(sig.Data(vertex_idx,:)), 'b-', 'LineWidth', 1.5);
hold on;
plot(t, imag(sig.Data(vertex_idx,:)), 'r-', 'LineWidth', 1.5);
plot(t, abs(sig.Data(vertex_idx,:)), 'k--', 'LineWidth', 2);
xlabel('Time (s)');
ylabel('Amplitude');
title(sprintf('Quantum Wave at Vertex %d', vertex_idx));
legend('Real', 'Imaginary', 'Magnitude', 'Location', 'best');
grid on;

% Phase evolution
subplot(1,2,2);
phase = angle(sig.Data(vertex_idx,:));
plot(t, phase, 'g-', 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Phase (radians)');
title(sprintf('Phase Evolution at Vertex %d', vertex_idx));
grid on;
ylim([-pi pi]);

%% Power spectrum analysis
fprintf('\n=== Spectral Analysis ===\n');

figure('Position', [100 100 800 600]);

% FFT of time series at sample vertex
Y = fft(sig.Data(vertex_idx,:));
f = (0:B.Time.T-1) * (B.Time.fs / B.Time.T);
P = abs(Y).^2 / B.Time.T;

% Plot only positive frequencies
f_pos = f(1:floor(B.Time.T/2)+1);
P_pos = P(1:floor(B.Time.T/2)+1);

plot(f_pos, 10*log10(P_pos), 'b-', 'LineWidth', 1.5);
xlabel('Frequency (Hz)');
ylabel('Power (dB)');
title(sprintf('Power Spectrum at Vertex %d', vertex_idx));
grid on;
xlim([0 B.Time.fs/2]);

% Theoretical quantum oscillation frequency
omega_theoretical = hbar * lambda_band(1) / (2 * mass);  % Minimum frequency
f_theoretical = omega_theoretical / (2*pi);
hold on;
xline(f_theoretical, 'r--', 'LineWidth', 2, 'Label', sprintf('Min ω/2π = %.2f Hz', f_theoretical));

fprintf('Theoretical frequency range:\n');
fprintf('  ω_min = ħλ_min/(2m) = %.2f rad/s (%.2f Hz)\n', ...
    hbar*lambda_band(1)/(2*mass), hbar*lambda_band(1)/(2*mass)/(2*pi));
fprintf('  ω_max = ħλ_max/(2m) = %.2f rad/s (%.2f Hz)\n', ...
    hbar*lambda_band(2)/(2*mass), hbar*lambda_band(2)/(2*mass)/(2*pi));

%% Summary statistics
fprintf('\n=== Signal Statistics ===\n');
fprintf('Signal dimensions: %d vertices × %d time points\n', size(sig.Data,1), size(sig.Data,2));
fprintf('Signal type: %s\n', class(sig.Data));
fprintf('Real part range: [%.4f, %.4f]\n', min(real(sig.Data(:))), max(real(sig.Data(:))));
fprintf('Imag part range: [%.4f, %.4f]\n', min(imag(sig.Data(:))), max(imag(sig.Data(:))));
fprintf('Magnitude range: [%.4f, %.4f]\n', min(abs(sig.Data(:))), max(abs(sig.Data(:))));
fprintf('Total power: %.4f\n', sum(abs(sig.Data(:)).^2));

fprintf('\n=== Example Complete ===\n');

