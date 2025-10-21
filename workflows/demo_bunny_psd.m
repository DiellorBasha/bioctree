function demo_bunny_psd()
% DEMO_BUNNY_PSD  Graph and Joint Time–Vertex PSD on Stanford bunny
%
% This demo estimates:
%   1) Graph PSD p(λ): power vs. graph Laplacian eigenvalues (spatial scale)
%   2) JTV PSD p(λ, f): power vs. (graph-scale × temporal frequency)
%
% Data: Stanford bunny graph + MEG-like matrix X (rows must match bunny vertices).
% If needed, rows are replicated/wrapped to match N=2503 (demo purpose).

fprintf('=== Bioctree PSD Demo: Stanford Bunny ===\n\n');

%% 1) Setup & Data
fprintf('1. Loading data and preparing graph...\n');

[G, X, fs, t] = load_bunny_psd_data();             % same spirit as your loader
fprintf('   Graph: %d vertices, %d edges\n', G.N, G.Ne);
fprintf('   Signal: %d samples at %.1f Hz (N×T = %d×%d)\n', numel(t), fs, size(X,1), size(X,2));

% Basic signal stats
noise_level = estimate_noise_level(X);
signal_power = mean(X.^2, 2);
snr_db = 10*log10(mean(signal_power) / (noise_level^2));
fprintf('   Noise (MAD-based): %.2e | Approx. SNR: %.1f dB\n', noise_level, snr_db);

%% 2) Graph PSD p(λ)
fprintf('\n2. Estimating graph PSD p(λ)...\n');

param_psd = struct;
param_psd.Nfilt = 96;                % number of translated graph windows (λ-resolution)
param_psd.order = 60;                % Chebyshev order (if fast polynomial filtering is used)
if ~isfield(G, 'U')
gsp_compute_fourier_basis(G);        % ensure eigenpairs available for plotting
end
% --- slice first; then call (avoids colon inside function args) ---
Xsub = X(:, 1:1200);

lam = G.e(:);   % eigenvalues (ascending)

% Estimate PSD
psd_g = gsp_estimate_psd(G, Xsub, param_psd);

% Resolve to samples on lam for plotting
if isa(psd_g, 'function_handle')
    % Evaluate the PSD handle at the eigenvalues
    psd_vals = psd_g(lam);                 % column vector
elseif isstruct(psd_g) && isfield(psd_g,'eval')
    psd_vals = psd_g.eval(lam);
elseif isnumeric(psd_g) && isvector(psd_g)
    if numel(psd_g) == numel(lam)
        psd_vals = psd_g(:);
    else
        lmax = max(lam);
        xi = linspace(0, lmax, numel(psd_g));
        psd_vals = interp1(xi, psd_g(:), lam, 'linear', 'extrap');
    end
else
    error('Unexpected gsp_estimate_psd return type: %s', class(psd_g));
end

% Normalize and plot
psd_vals_n = psd_vals / max(psd_vals + eps);
figure; plot(lam, psd_vals_n, 'LineWidth',1.5); grid on
xlabel('\lambda'); ylabel('Normalized PSD'); title('Graph PSD p(\lambda)');
%% 3) Joint Time–Vertex PSD p(λ, f)
fprintf('\n3. Estimating joint time–vertex PSD p(λ, f)...\n');

% Bartlett-like segmentation (no overlap for simplicity)
% Choose R and implied window length L
R    = 6;
T    = size(Xsub,2);
Tseg = floor(T / R);

% Use only the first Tuse samples so Tuse = R*L exactly
Tuse      = Tseg * R;
Xuse      = Xsub(:, 1:Tuse);
param_jtv = struct;
param_jtv.L = Tseg;           % <-- REQUIRED: window length L
 G = gsp_jtv_graph(G,T,fs,param_jtv);
[psd_jtv, ft] = gsp_jtv_estimate_psd(G, Xuse, param_jtv);


% Axes
ng = size(psd_jtv,1);
nw = size(psd_jtv,2);
if ng == numel(lam)
    lam_axis = lam;
else
    lam_axis = linspace(0, max(lam), ng).';
end
freq_axis = (0:nw-1) * (fs / nw);        % Hz

% Consistency check: marginalize JTV over f and compare to graph PSD shape
psd_jtv_lam = mean(psd_jtv, 2);
psd_jtv_lam = psd_jtv_lam / max(psd_jtv_lam + eps);

fprintf('   JTV PSD estimated (%d λ samples × %d freq bins).\n', ng, nw);

%% 4) Quick readouts
% Where is energy concentrated?
lam_cut = prctile(lam_axis, 25);                % low-λ threshold
f_cut   = 12;                                   % example temporal cut (alpha-ish)
low_lam = lam_axis <= lam_cut;
low_f   = (freq_axis <= f_cut) | (freq_axis >= fs - f_cut);  % two-sided real spectrum

E_tot   = sum(psd_jtv(:));
E_lowL  = sum(psd_jtv(low_lam, :), 'all') / E_tot;
E_lowF  = sum(psd_jtv(:, low_f), 'all') / E_tot;

fprintf('   Energy fractions: low-λ = %.2f, low-f = %.2f\n', E_lowL, E_lowF);

%% 5) Visualizations
fprintf('\n4. Creating PSD visualizations...\n');

figure('Name','Bunny PSD Demo','Position',[80 80 1500 900]);

% A) Graph PSD
subplot(2,3,1);
plot(lam, psd_vals_n, 'LineWidth',1.5);
grid on; xlabel('\lambda (graph eigenvalue)'); ylabel('Normalized PSD');
title('Graph PSD p(\lambda)');
text(0.02*max(lam),0.9,'Low \lambda = smooth/global, High \lambda = rough/local');

% B) JTV PSD heatmap (log scale for dynamic range)
subplot(2,3,2);
imagesc(freq_axis, lam_axis, log10(psd_jtv + eps)); axis xy
xlabel('Temporal frequency (Hz)'); ylabel('\lambda');
title('log_{10} JTV PSD p(\lambda, f)'); colorbar; colormap turbo

% C) Consistency: JTV marginal over f vs Graph PSD
subplot(2,3,3);
plot(lam_axis, psd_jtv_lam, 'LineWidth',1.6, 'DisplayName','JTV marginal over f'); hold on
plot(lam, psd_vals_n, '--', 'LineWidth',1.4, 'DisplayName','Graph PSD');
grid on; xlabel('\lambda'); ylabel('Normalized PSD');
legend('Location','best'); title('Consistency check');

% D) Example vertex time trace and Welch PSD (sanity)
[~, vpk] = max(signal_power);
subplot(2,3,4);
plot(t, X(vpk,:), 'k'); grid on
xlabel('Time (s)'); ylabel('Amplitude');
title(sprintf('Example vertex %d time trace', vpk));

subplot(2,3,5);
[pxx, f] = pwelch(X(vpk,:), [], [], [], fs);
semilogy(f, pxx, 'k'); grid on
xlabel('Frequency (Hz)'); ylabel('PSD (Welch)');
title('Temporal PSD at example vertex');

% E) Mean map for context
subplot(2,3,6);
gsp_plot_signal(G, mean(X,2)); colorbar; axis off
title('Mean signal over time on bunny');

sgtitle('Graph & Joint Time–Vertex PSD on the Stanford Bunny');

%% 6) Summary
fprintf('\n5. Summary\n');
fprintf('   Graph PSD peaks at low λ? %s\n', ternary(mean(psd_vals_n(1:round(end*0.2))) > mean(psd_vals_n(end-round(end*0.2):end)),'yes','no'));
fprintf('   JTV PSD shows power near alpha band? %s\n', ternary(any(freq_axis(low_f) >= 8 & freq_axis(low_f) <= 12),'maybe (inspect heatmap)','not obvious'));
fprintf('\n=== PSD demo completed! ===\n');

end

% -------------------------- Helpers (same style) --------------------------

function [G, X, fs, t] = load_bunny_psd_data()
% LOAD_BUNNY_PSD_DATA  Bunny graph + MEG matrix X with dimension match.
% Edit the path below to load your own MEG data; otherwise a synthetic X is used.

% Try loading your MEG file (M x T). If not present, synthesize.
% Try loading your MEG file (M x T). If not present, synthesize.
dataPath = 'test-data/omega-tutorial/sub-0002/sensor/data_block002.mat';
kernelPath='test-data\omega-tutorial\sub-0002\results_dSPM-unscaled_MEG_KERNEL_251019_2352.mat';
if exist(dataPath,'file')
    S = load(dataPath);
    if isfield(S,'F')
        megData = S.F;
    else
        fn = fieldnames(S);
        megData = S.(fn{1});
    end
else
    fprintf('   (No MEG file found, synthesizing demo data)\n');
    fs = 200; T = 2048; M = 900; t = (0:T-1)/fs;
    megData = 0.5*randn(M,T) ...
            + (sin(2*pi*10*t).*exp(-(t-2).^2/0.7^2)) .* rand(M,1) * 3 ...
            + (sin(2*pi*5*t)) .* ones(M,1) * 0.8;
end
ImagingKernel=load(kernelPath);
%
megData=megData(ImagingKernel.GoodChannel,:);
fs=round(1/diff(S.Time(1:2)));

% Build full bunny graph
G = gsp_bunny();
G = gsp_estimate_lmax(G);
G = gsp_compute_fourier_basis(G);

% Size-match rows (demo convenience; geometry-ignorant replication)
N = G.N; [M, T] = size(megData);
if M < N
    X = megData(1 + mod(0:N-1, M), :);   % wrap-around copy
else
    X = megData(1:N, :);
end

% Temporal downsample to reasonable length for plots (optional)
if ~exist('fs','var'); fs = 200; end
down = max(1, round(300/64));             % e.g., ~64 Hz target if original ~300 Hz
idx_t = 1:down:T;
X = X(:, idx_t);
fs = fs / down;
t = (0:numel(idx_t)-1)/fs;
end

function noise_level = estimate_noise_level(X)
% Robust noise proxy using temporal first differences
X_diff = diff(X, 1, 2);
noise_level = median(abs(X_diff(:))) / 0.6745;
end

function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end
