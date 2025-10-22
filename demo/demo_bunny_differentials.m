function demo_bunny_differentials()
% DEMO_BUNNY_DIFFERENTIALS
% Differential-operator analysis on the Stanford bunny:
%   - Spatial gradient (edge-wise and node-aggregated)
%   - Divergence / Laplacian response (curvature proxy)
%   - Total Variation (TV) and Dirichlet energy (over time)
%
% Data: Brainstorm MEG sensors -> resized to bunny vertex count (demo purpose)
% Notes:
%   * Gradients are computed on the graph edges via an incidence operator.
%   * Optional length-normalization turns differences into "per-mm" units.
%   * TV(t) ≔ sum_edges |∇x| is a global roughness dial across time.

fprintf('=== Bioctree Differential Operators Demo: Stanford Bunny ===\n\n');

%% 1) Load data and build graph
fprintf('1) Loading MEG data and building bunny graph...\n');

% --- User paths (adjust as needed)
dataPath   = 'test-data/omega-tutorial/sub-0002/sensor/data_block002.mat';
kernelPath = 'test-data\omega-tutorial\sub-0002\results_dSPM-unscaled_MEG_KERNEL_251019_2352.mat';

% --- Load MEG (Brainstorm-like). Fallback to synthetic if missing.
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
    fs = 200; T = 2048; M = 900; ttmp = (0:T-1)/fs; %#ok<NASGU>
    megData = 0.5*randn(M,T) ...
            + (sin(2*pi*10*ttmp).*exp(-(ttmp-2).^2/0.7^2)) .* rand(M,1) * 3 ...
            + (sin(2*pi*5*ttmp)) .* ones(M,1) * 0.8;
end

% Optional: channel selection from ImagingKernel (e.g., Brainstorm "GoodChannel")
if exist(kernelPath,'file')
    ImagingKernel = load(kernelPath);
    if isfield(ImagingKernel,'GoodChannel') && ~isempty(ImagingKernel.GoodChannel)
        megData = megData(ImagingKernel.GoodChannel, :);
        fprintf('   Selected %d good channels from ImagingKernel.\n', numel(ImagingKernel.GoodChannel));
    end
end

% Sampling rate from Brainstorm file
if exist('S','var') && isfield(S,'Time')
    fs = round(1/diff(S.Time(1:2)));
else
    fs = 300; % sensible default for this dataset family
end

% --- Build full bunny graph
gsp_start;
G = gsp_bunny();
G = gsp_estimate_lmax(G);
G = gsp_compute_fourier_basis(G); % needed for some plots (eigs)

% --- Size-match rows (demo-only; geometry-ignorant replication)
N = G.N; [M, T] = size(megData);
if M < N
    X = megData(1 + mod(0:N-1, M), :);
else
    X = megData(1:N, :);
end

% --- Optional temporal downsampling (lighter plots/compute)
target = 64; down = max(1, round(fs/target));
idx_t = 1:down:T;
X = X(:, idx_t);
fs = fs / down;
t = (0:numel(idx_t)-1)/fs;

fprintf('   Graph: N=%d vertices, Ne=%d edges | Signal: %d×%d (fs=%.1f Hz)\n', ...
        G.N, G.Ne, size(X,1), size(X,2), fs);
%% 

T   = 2000; fs = 200;
[X, info] = make_graph_signal_scenarios(G, T, fs, struct('Kpatch',4,'f0',10));
t = (0:T-1)/fs;

%% 2) Build incidence operator (∇) and choose normalization
fprintf('\n2) Building incidence (gradient) operator...\n');

% By default, use edge-length normalization to report "per-mm" gradients.
use_length_norm = true;
[B, iE, jE, Lij] = build_edge_incidence(G, use_length_norm);

fprintf('   Edges: %d | Length-normalized: %s\n', size(B,1), string(use_length_norm));

%% 3) Pick a representative frame and compute maps
fprintf('\n3) Computing spatial maps on a representative frame...\n');

kShow = round(size(X,2)*0.5);         % middle frame
x  = X(:, kShow);

% Edge gradients and node-aggregated gradient magnitude (|∇x|)
gE = B * x;                            % edge-wise gradient (signed)
gNode = edge_to_node_magnitude(G, B, gE);

% Divergence via Laplacian (curvature-like response)
divx = G.L * x;                        % (area-normalized LB preferred if you have it)

% Total variation and Dirichlet at this frame
TV_frame  = sum(abs(gE));
Dir_frame = x' * G.L * x;

fprintf('   Frame %d: TV=%.3e, Dirichlet=%.3e\n', kShow, TV_frame, Dir_frame);

%% 4) Time-resolved TV and Dirichlet
fprintf('\n4) Computing time-resolved TV(t) and Dirichlet(t)...\n');

TV_t  = total_variation_time(B, X);
Dir_t = dirichlet_time(G, X);

%% 5) Visualizations
fprintf('\n5) Drawing figures...\n');

figure('Name','Differential Operators on Bunny','Position',[80 80 1500 900]);
param_plot.cp = [0.1223, -0.3828, 12.3666];

% A) Raw signal (frame)
subplot(2,3,1);
gsp_plot_signal(G, x, param_plot); colorbar; axis off
title(sprintf('Signal @ t=%.2fs', t(kShow)));

% B) Node-aggregated |∇x|
subplot(2,3,2);
gsp_plot_signal(G, gNode, param_plot); colorbar; axis off
ttl = '|∇x| (node-aggregated)';
if use_length_norm, ttl = [ttl '  [per mm]']; end
title(ttl);

% C) Divergence (≈ Lx)
subplot(2,3,3);
gsp_plot_signal(G, divx, param_plot); colorbar; axis off
title('Divergence / Laplacian response (Lx)');

% D) TV(t)
subplot(2,3,4);
plot(t, TV_t, 'k', 'LineWidth', 1.1); grid on
xlabel('Time (s)'); ylabel('TV(t)');
title('Total Variation over time');

% E) Dirichlet(t)
subplot(2,3,5);
plot(t, Dir_t, 'b', 'LineWidth', 1.1); grid on
xlabel('Time (s)'); ylabel('x^T L x');
title('Dirichlet energy over time');

% F) Histogram of |∇x| (frame)
subplot(2,3,6);
histogram(gNode, 60, 'FaceColor',[0.2 0.6 1], 'EdgeColor','none'); grid on
xlabel('|∇x| (node)');
if use_length_norm, xlabel('|∇x| (per mm)'); end
title('Distribution of node gradient magnitudes');
colormap("hot")
sgtitle('Gradient, Divergence, and Total Variation on the Stanford Bunny');


%% 6) Optional: alpha-band TV(t) (illustration) + space×time imagesc

fprintf('\n6) Optional: alpha-band TV(t) illustration...\n');
try
    [b,a] = butter(4, [8 12] / (fs/2), 'bandpass');
    Xa = filtfilt(b,a,double(X.')).';       % N×T alpha-band signal
    TV_alpha = total_variation_time(B, Xa);

    figure('Name','Alpha TV','Position',[200 200 800 700]);  % taller figure
    tiledlayout(2,1,'Padding','compact','TileSpacing','compact');

    % Top: TV(t) traces
    nexttile;
    plot(t, TV_t,     'k', 'LineWidth', 1.1, 'DisplayName','Broadband'); hold on
    plot(t, TV_alpha, 'r', 'LineWidth', 1.2, 'DisplayName','Alpha (8–12 Hz)');
    grid on; xlabel('Time (s)'); ylabel('TV(t)'); legend('Location','best');
    title('Total Variation over Time');

    % Bottom: space×time map of the (alpha) signal
    nexttile;
    Xm = Xa;               % Option A: raw alpha
    % Xm = zscore(Xa,0,2); % Option B: per-vertex z-score (uncomment if preferred)
    imagesc(t, 1:size(Xm,1), Xm); axis xy tight
    colormap("parula"); colorbar
    xlabel('Time (s)'); ylabel('Vertex index');
    ttl = 'Alpha-band Signal (space × time)';
    % if using z-score, you can set:
    % ttl = 'Alpha-band (per-vertex z-scored)';
    title(ttl);

catch
    fprintf('   (Skipping alpha TV/imagesc: Signal Processing Toolbox likely missing.)\n');
end


end

% ============================ HELPERS ============================

function [B, iE, jE, Lij] = build_edge_incidence(G, length_normalize)
% Build an oriented edge-incidence matrix B (|E|×N).
% If length_normalize is true and coords exist, scale differences by edge length (per-mm).
    if nargin < 2, length_normalize = false; end

    % Use upper triangle to list each undirected edge once
    [ii, jj, ww] = find(triu(G.W, 1)); %#ok<ASGLU>
    m = numel(ii);

    if length_normalize && isfield(G, 'coords') && ~isempty(G.coords)
        Lij = vecnorm(G.coords(ii,:) - G.coords(jj,:), 2, 2);  % Euclidean length
        wscale = 1 ./ max(Lij, eps);                           % divide by length
    else
        Lij = ones(m,1);
        wscale = ones(m,1);
    end

    % Oriented incidence: +1 at i, -1 at j (scaled)
    B = sparse([(1:m)'; (1:m)'], [ii; jj], [wscale; -wscale], m, G.N);

    % Return edge lists for convenience
    iE = ii; jE = jj;
end

function gNode = edge_to_node_magnitude(G, B, gE)
% Aggregate edge gradient magnitudes to nodes (sum of incident |∇x|).
    absEdge = abs(gE);
    % Accumulate |∇x| to edge endpoints using |B|'s absolute pattern
    A = abs(B)';                          % N×|E|
    gNode = A * absEdge;                  % sum of incident edge magnitudes
    % Degree-normalize (optional, stabilizes across irregular valences)
    deg = full(sum(G.W,2));
    gNode = gNode ./ max(deg, eps);
end

function TV_t = total_variation_time(B, X)
% Total Variation as a time series: TV(t) = sum_edges |(B*X)(:,t)|.
    E = B * X;                 % |E| × T
    TV_t = sum(abs(E), 1);     % 1 × T
    TV_t = TV_t(:);
end

function D_t = dirichlet_time(G, X)
% Dirichlet energy over time: x(t)^T L x(t).
    % Compute in one pass: sum over columns of (X .* (L*X))
    LX = G.L * X;
    D_t = sum(X .* LX, 1);
    D_t = D_t(:);
end
