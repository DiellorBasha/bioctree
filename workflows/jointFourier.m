cd C:\CodingProjects\bioctree
for k =1:10
  blocks(k).data=getData(k);
end
%%
F=[];
for k=1:length(blocks)
F=[F blocks(k).data.F];
end
fs=2400;
ImagingKernel=blocks(k).data.IK;
%% analyze FFT
winlen=round(4*fs);
[pxx, f4]=pwelch(F',winlen,[],[],fs, 'onesided');
plot(f4,pxx)
xlim([0 60]);
%% decompose

[C, T] = size(F);
 fb = cwtfilterbank('Wavelet', 'amor', ...
                   'SignalLength', T, ...
                   'VoicesPerOctave', 12, ...
                   'SamplingFrequency', fs, ...
                   'FrequencyLimits', [1 60]);
freqs = fb.centerFrequencies;
K = numel(freqs);

nFreq=numel(freqs)
Fcfs=zeros(C,nFreq,T);
% ---------------- process channel-by-channel ----------------
for ch = 1:C
    sig = F(ch, :);

    % CWT for this channel (K x nPad complex)
    cfsF(ch,:,:) = cwt(sig, 'FilterBank', fb);
end


%% 

newFs = 300;
Fds=(resample(F', newFs, fs))';

Lwin=round(4*fs);
[C,T]=size(Fds);
load("bioctree\test-data\gspgraph.mat");

param.NFFT= 2^nextpow2(Lwin);
param.transform = 'dft';
G=gsp_jtv_graph(G,T,newFs,param);

%%
[C, T] = size(Fds);
 fb = cwtfilterbank('Wavelet', 'amor', ...
                   'SignalLength', T, ...
                   'VoicesPerOctave', 12, ...
                   'SamplingFrequency', newFs, ...
                   'FrequencyLimits', [1 60]);
freqs = fb.centerFrequencies;
K = numel(freqs);

nFreq=numel(freqs)
cfs=zeros(C,nFreq,T);
% ---------------- process channel-by-channel ----------------
for ch = 1:C
    sig = X(ch, :);

    % CWT for this channel (K x nPad complex)
    cfs(ch,:,:) = cwt(sig, 'FilterBank', fb);
end

 %% 
% Reconstruct alpha-band waveforms (C x T)
X_alpha = icwt_band(cfs, fb, 8, 10);
X_beta = icwt_band(cfs, fb, 13, 30);
X_delta = icwt_band(cfs, fb, 8, 12);

%%
ImagingGrid=ImagingKernel*Fds;
%% functions for analyzing the structural properties

% f: vertex signal (N×1). G must have G.L and edge structure set by gsp_graph.
S_alpha=ImagingKernel*X_alpha;
Sig=S_alpha;

%% 

G = gsp_adj2vec(G);
Df = gsp_grad(G, Sig);
% edge-signal: size G.Ne×1
divDf = gsp_div(G, Df);          % vertex-signal: N×1
divMean = mean(divDf,2);
gsp_plot_signal(G, divMean)
ax=gca;
axis square
% Check the identity L f = -div(grad f)
fprintf('||G.L*f + divDf|| / ||G.L*f|| = %.2e\n', norm(G.L*f + divDf)/norm(G.L*f));

% Graph quadratic variation (smoothness)
quadvar = full(f.'*G.L*f);
edgenorm2 = sum(abs(Df).^2);
fprintf('f^T L f ≈ ||grad f||^2: %.6g vs %.6g\n', quadvar, edgenorm2);

% Separate persistent sources vs sinks
Div_source = mean(max(divDf,0), 2); % N×1 (average positive part)
Div_sink   = mean(max(-divDf,0), 2);% N×1 (average negative part)
%% 

% Envelope per vertex (analytic signal)
H = hilbert(Sig.').';
A = abs(H);         % N×T
phi = angle(H);
%% 
% Edge-wise phase differences via graph gradient (binary W ⇒ f_j - f_i)
Dphi = gsp_grad(G, phi);       % size: E×T (E = number of edges)
% Wrap to (-π, π] to respect circular phase
Dphi_Wrapped = wrapToPi(Dphi);

div_env   = gsp_div(G, gsp_grad(G, A));   % = -L * A
Div_source  = mean(max( div_env,0), 2);     % places where envelope tends to pool
Div_sink= mean(max(-div_env,0), 2);     % places where envelope tends to originate
%% 

G.plotting.vertex_size=5;
param.colormap=bone;
figure(1)
subplot(121)
gsp_plot_signal(G,Div_source, param)
axis square
xlabel('Candidate source')
subplot(122)
gsp_plot_signal(G,Div_sink)
axis square
xlabel('Candidate sink')
%% 
% Circular time-average per edge (mean signed offset + coherence)
Circm   = mean(cos(Dphi_wrapped), 2);    % E×1
Sm  = mean(sin(Dphi_wrapped), 2);    % E×1
dphi_mean = atan2(Sm, Circm);            % E×1 mean signed phase slope on each edge
plv_edge  = hypot(Circm, Sm);   

% Edge PLV -> symmetric "adjacency of PLV"
A_plv = gsp_vec2adj(G.A, plv_edge);    % E×1 (0..1) phase-locking value (stability)
% Degree (count of incident edges; for weighted graphs you can also use sum(G.W>0,2))
deg = full(sum(G.W>0, 2));                        % N×1
% Vertex PLV = mean of incident edge PLVs
plv_vertex = full(sum(A_plv, 2)) ./ max(deg, 1);  % N×1

% Edge PLV -> symmetric "adjacency of PLV"
A_phi = gsp_vec2adj(G.A, dphi_mean);    % E×1 (0..1) phase-locking value (stability)
% Degree (count of incident edges; for weighted graphs you can also use sum(G.W>0,2))
% Vertex PLV = mean of incident edge PLVs
dphi_vertex = full(sum(A_phi, 2)) ./ max(deg, 1);  % N×1

%% 
param.colormap="jet"
gsp_plot_signal(G,dphi_vertex, param)

%%
% dphi_mean is E×1 (edge orientation = the one used by gsp_grad)
div_phi = gsp_div(G, dphi_mean);    % N×1

% Sign convention in GSPBox:
%   gsp_div(gsp_grad(f)) = -L f
% Here: div_phi > 0 => sink-like (net inflow), div_phi < 0 => source-like (net outflow)

emitters  = max(-div_phi, 0);       % sources (net outward phase flow)
absorbers = max( div_phi, 0);       % sinks   (net inward phase flow)

figure; gsp_plot_signal(G, emitters);  colorbar; title('Emitters (net outward)');
figure; gsp_plot_signal(G, absorbers); colorbar; title('Absorbers (net inward)');

%% 

Jbar   = plv_edge .* dphi_mean;     % E×1: stability-weighted signed slope
DivJ   = gsp_div(G, Jbar);          % N×1

emit_w = max(-DivJ, 0);             % weighted emitters
absorb_w = max( DivJ, 0);           % weighted absorbers

figure; gsp_plot_signal(G, emit_w);   colorbar; title('Emitters (PLV-weighted)');
figure; gsp_plot_signal(G, absorb_w); colorbar; title('Absorbers (PLV-weighted)');
%%
MriFileSrc='C:\Users\diell\ownSyncFolder\PAD7_test\anat\sub-MTL0002\subjectimage_T1_reslice.mat'
map = divMean;
cond = 'Phase Gradient'
label = 'Mean Divergence of Alpha'
OutputFile = savemap2bst(MriFileSrc, map, ...
    'Condition',cond, ...
    'Comment',label, ...
    'TimeVector', t, ...
    'DisplayUnits','A', ...
    'SurfaceRegex','cortex_pial_low\.mat$', ...
    'ViewAfter', true);
%% 
% GFT and inverse
fhat = gsp_gft(G, f);           % fhat(ℓ) = U(:,ℓ)^T f
frec = gsp_igft(G, fhat);       % ≈ f
%%
Lwin=round(4*newFs)
param.NFFT= 2^nextpow2(Lwin);
param.transform = 'dft';
G=gsp_jtv_graph(G,T,newFs,param);

S=ImagingGrid;
NFFT = G.jtv.NFFT; Fs = G.jtv.fs;

% --- Joint Fourier transform (λ × F) ---
% gsp_jft does: GFT (space) then DFT (time) with your G.jtv settings.
Xhat = gsp_jft(G, S);               % size: N_modes × NFFT   (complex)

% Build the one-sided frequency axis (real signals)
f_all   = (0:NFFT-1) * (Fs/NFFT);           % two-sided index; we’ll take one-side
pos_idx = 1:floor(NFFT/2)+1;                % DC..Nyquist
f_pos   = f_all(pos_idx);
Xhat_pos= Xhat(:, pos_idx);                 % λ × F_pos

%% 

% Select 1..60 Hz
f_mask = (f_pos >= 1) & (f_pos <= 60);
f_60   = f_pos(f_mask);

% Joint power spectral density P(λ,f)  (per-bin power; normalize by T if you like)
P = abs(Xhat_pos(:, f_mask)).^2 / size(S,2);   % λ × F_60

% Optional: log-power for plotting
Plog = 10*log10(P + eps);


% Pick how many graph modes to display (top-left block of λ × f)
K = 15000;                       % e.g., first 400 modes (smooth → mid-scale)
K = min(K, size(P,1));

% λ-axis in physical units (eigenvalues) and normalized units
lambda = G.e(1:K);
lambda_norm = lambda / max(G.e);  % 0..1 for comparability
%% 


% Heatmap (λ × f)
figure('Color','w');
subplot(131)
imagesc(f_60, lambda_norm, Plog(1:K,:)); axis xy;
xlabel('Frequency (Hz)');
ylabel('\lambda / \lambda_{max}');
title('Joint spectrum: 1–60 Hz (log power)');
colormap(turbo); colorbar;
subplot(132)
plot(f_60, mean(P,1))
subplot(133)
plot(lambda_norm(1:K,:), mean(P,2))
%% 
% ==== Inputs you already have ====
% G : your graph with G.U, G.e, G.jtv.fs, etc.
% S : ImagingGrid, size N x T (here 15002 x 10800)

% -------- Parameters you can tweak --------
fmin = 1; fmax = 60;                % temporal band of interest (Hz)
K    = 600;                         % how many spatial modes to display
use_dB = true;                      % plot log-power for the heatmap

% -------- JFT (space = GFT, time = DFT) --------
if ~isfield(G,'jtv') || ~isfield(G.jtv,'fs'), error('Set G.jtv.fs'); end
Fs   = G.jtv.fs;
T    = size(S,2);
if ~isfield(G.jtv,'NFFT') || isempty(G.jtv.NFFT), G.jtv.NFFT = T; end
NFFT = G.jtv.NFFT;
G.jtv.transform = 'dft';   % make sure

Xhat = gsp_jft(G, S);               % size: N_modes x NFFT (complex)
Xhat_psd = gsp_jft(G, S);   % size: (#modes) × (floor(NFFT/2)+1)

% -------- One-sided frequencies & 1–60 Hz selection --------
f_all   = (0:NFFT-1) * (Fs/NFFT);
pos_idx = 1:floor(NFFT/2)+1;        % DC..Nyquist
f_pos   = f_all(pos_idx);
band    = (f_pos >= fmin) & (f_pos <= fmax);
f_band  = f_pos(band);

% -------- Joint power (λ x f) --------
Xhat_pos = Xhat(:, pos_idx);        % λ x Fpos
Xhat_pos = Xhat_psd(:, pos_idx);
P = abs(Xhat_pos(:, band)).^2 / T;  % per-bin power; normalize by T



% -------- Axes: spatial modes (λ) --------
lambda      = G.e(:);                       % λ_1..λ_N (λ_1=0)
            % show first K modes
%% 
% --- Build λ-windows (Gaussian tiles), energy-normalized (|g|^2 rows sum to 1) ---
% -------- Axes: spatial modes (λ) --------
lambda      = G.e(:);                       % λ_1..λ_N (λ_1=0)
lambda_norm = lambda ./ max(lambda);        % 0..1 for comparability
K           = min(K, size(Pplot,1));            % show first K modes

Nlam   = numel(lambda);
lmax   = max(lambda);
Sf     = 1500;                                 % # spatial windows (tune 20..80)
centers = linspace(lambda(max(2,1)), lmax, Sf);  % skip DC (λ=0)
bw      = 0.1* lmax;                       % bandwidth (~5% of spectrum span)

G2 = zeros(Nlam, Sf);                         % |g_s(λ)|^2 weights
for s = 1:Sf
    g = exp(-0.5*((lambda - centers(s))/bw).^2);
    G2(:,s) = g.^2;                           % energy weights
end
G2 = G2 ./ max(sum(G2,2), eps);               % row-normalize → ∑_s |g_s(λ)|^2 ≈ 1

% --- λ-smoothed joint spectrum (spatial “Welch”) ---
P_win = G2.' * P;                              % size: Sf × Fband (power/Hz)
lambda_norm = centers / lmax;                    % y-axis for plotting

% --- Smoothed marginals (and they preserve totals thanks to row-normalization) ---
P_freq_win   = sum(P_win, 1);                  % graph-averaged temporal spectrum (power/Hz)
P_lambda_win = sum(P_win, 2);                  % time-averaged spatial spectrum (power)


                       % spatial marginal: sum over f (1–60 Hz)

Pplot = P_win;
K=Sf;
% Pplot=P;
% K=size(Pplot,1)
% -------- Marginals --------
P_freq   = mean(Pplot(1:K,:), 1);                % temporal marginal: sum over λ
P_lambda = mean(Pplot, 2); 
% 
% Optional log-power for plotting
if use_dB
    Pplot = 10*log10(P + eps);
    zlabel = 'Power (dB/bin)';
else
    Pplot = P;
    zlabel = 'Power (per bin)';
end
%% 

% -------- Plot (heatmap + two marginals) --------
figure(1)
tl = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

% (1) Joint spectrum heatmap
ax(1)=nexttile(1);
imagesc(f_band, lambda_norm(1:K), Pplot(1:K,:)); axis xy;
xlabel('Frequency (Hz)'); ylabel('\lambda / \lambda_{max}');
title(sprintf('Joint spectrum (%d–%d Hz)', fmin, fmax));
colormap(turbo); cb = colorbar; ylabel(cb, zlabel);

% (2) Temporal marginal (graph-averaged spectrum)
ax(2)=nexttile(2);
plot(f_band, P_freq, 'LineWidth',1.25); grid on;
xlim([fmin fmax]);
xlabel('Frequency (Hz)');
ylabel('Power (sum over \lambda)');
title('Temporal spectrum (graph-averaged)');
linkaxes(ax,'x');
% (3) Spatial marginal (time-averaged over 1–60 Hz)
axs(1)=ax(1);
axs(2)=nexttile(4);
plot(P_lambda(1:K), lambda_norm(1:K), 'LineWidth',1.25); grid on;
xlabel('Power (sum over 1–60 Hz)'); ylabel('\lambda / \lambda_{max}');
title('Spatial spectrum (time-averaged)');
linkaxes(axs,'y');
% (Optional) leave tile 3 empty or use it for notes/legend
nexttile(3); axis off;
text(0,0.9, sprintf('N=%d, T=%d, NFFT=%d, Fs=%g Hz', G.N, T, NFFT, Fs), 'FontWeight','bold');
text(0,0.7, sprintf('Modes shown: %d of %d', K, numel(lambda)));
text(0,0.5, 'Tips:', 'FontWeight','bold');
text(0,0.35,'• Vertical ridges = temporal bands across many spatial scales');
text(0,0.22,'• Horizontal bands = preferred spatial scales');
text(0,0.09,'• Tilt = dispersion (f couples to \lambda)');

% -------- (Optional) Spatial scale in mm instead of normalized λ --------
% If G.coords are in meters (Brainstorm), convert to mm with *1000.
% Uncomment to replace the y-axis with approximate wavelength (mm):
% ei = G.v_in; ej = G.v_out;
% el = vecnorm(G.coords(ei,:) - G.coords(ej,:), 2, 2);
% a  = mean(el); dbar = mean(full(G.d)); units_per_mm = 1000;
% Lambda_mm = (2*pi) * (a*units_per_mm) .* sqrt(dbar ./ max(lambda, eps));
% Lambda_mm(lambda==0) = Inf;
% % Update heatmap Y axis:
% nexttile(1);
% imagesc(f_band, Lambda_mm(1:K), Pplot(1:K,:)); axis xy;
% ylabel('Approx. spatial wavelength (mm)');
% % Update spatial marginal Y axis:
% nexttile(4);
% plot(P_lambda(1:K), Lambda_mm(1:K), 'LineWidth',1.25); grid on;
% ylabel('Approx. spatial wavelength (mm)');


%% 
G.jtv.transform = 'psd';
G.jtv.seglen   = 1024;       % samples
G.jtv.noverlap = 512;        % 50%
G.jtv.NFFT     = 2048;       % ≥ seglen
G.jtv.window   = 'hann';


Xhat_psd = gsp_jft(G, ImagingGrid);   % size: (#modes) × (floor(NFFT/2)+1)
