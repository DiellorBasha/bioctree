function [X, info] = make_graph_signal_scenarios(G, T, fs, opts)
% MAKE_GRAPH_SIGNAL_SCENARIOS  Synthetic graph time-series with known structure
% 
% [X, info] = make_graph_signal_scenarios(G, T, fs, opts)
% 
% Inputs
%   G    : gsp graph (sparse G.W, G.L; G.coords optional but nice)
%   T    : total time samples
%   fs   : sampling rate (Hz)
%   opts : struct with optional fields:
%          .frac   = [0.25 0.25 0.30 0.20]   % time fractions per epoch (sum=1)
%          .f0     = 10                      % Hz, global synchrony frequency
%          .Kpatch = 3                       % number of local patches
%          .fpatch = [6 9 14]                % Hz for each patch (or scalar)
%          .noise  = 0.15                    % additive noise std (relative)
%          .src_ids = []                     % source vertex ids (default: random 2)
%          .snk_ids = []                     % sink vertex ids   (default: random 2)
%          .eps_poisson = 1e-3               % Poisson regularization
%          .use_len_norm = true              % gradient per-mm if coords exist
%
% Outputs
%   X    : N×T synthetic signal
%   info : struct with fields:
%          .epochs   = struct with t_idx for each epoch
%          .patch_id = N×1 integer labels (0 = unassigned) for local synchrony
%          .src_mask, .snk_mask : N×1 indicator vectors
%          .x_potential        : N×1 static source/sink spatial field
%          .notes : text describing each epoch
%
% Example
%   [X,info] = make_graph_signal_scenarios(G, 2000, 200);
%   % Then compute TV(t), Lx(t), etc. on X using your pipeline.

% ---- defaults
if nargin<4, opts = struct; end
def = struct('frac',[0.25 0.25 0.30 0.20], 'f0',10, 'Kpatch',3, ...
             'fpatch',10, 'noise',0.15, 'src_ids',[], 'snk_ids',[], ...
             'eps_poisson',1e-3, 'use_len_norm',true);
fn = fieldnames(def);
for k=1:numel(fn), if ~isfield(opts,fn{k}), opts.(fn{k})=def.(fn{k}); end, end

N = G.N; frac = opts.frac(:).'; frac = frac/sum(frac);
T_e = max(1, round(frac*T)); T_e(end) = T - sum(T_e(1:end-1));
t = (0:T-1)/fs;

% ===== Epoch 1: random (rough) =====
t1 = 1:T_e(1);
X1 = randn(N, numel(t1));

% ===== Epoch 2: global synchrony (smooth) =====
t2 = (t1(end)+1):(t1(end)+T_e(2));
phi0 = 2*pi*opts.f0*t(1:numel(t2));
X2 = sin(phi0);                       % 1×|t2|
X2 = repmat(X2, N, 1);                % same phase at all vertices
% add tiny spatial bias so it's not perfectly constant
if isfield(G,'U') && ~isempty(G.U)
    lowmode = G.U(:,1); lowmode = lowmode/norm(lowmode);
else
    lowmode = ones(N,1)/sqrt(N);
end
X2 = X2 + 0.05 * lowmode * sin(2*pi*opts.f0*t(1:numel(t2)));

% ===== Epoch 3: local synchrony (patches) =====
t3 = (t2(end)+1):(t2(end)+T_e(3));
K = opts.Kpatch;
patch_id = make_patches(G, K);         % N×1 labels in 1..K
fpatch = opts.fpatch; 
if isscalar(fpatch), fpatch = fpatch + (0:K-1); end
X3 = zeros(N, numel(t3));
ph = 2*pi*rand(1,K);                    % random phase per patch
tt = t(1:numel(t3));                    % time vector for this epoch

for k = 1:K
    idx = (patch_id==k);                % logical N×1 mask
    fk  = fpatch(min(k,numel(fpatch)));
    row = sin(2*pi*fk*tt + ph(k));      % 1×T3 row
    X3(idx,:) = repmat(row, nnz(idx), 1);  % replicate to match rows
end

% Smooth patch boundaries a bit to look realistic (heat kernel)
hk_tau = 0.5;
H = gsp_design_heat(G, hk_tau);
X3 = gsp_filter_analysis(G, H, X3);


% ===== Epoch 4: source/sink potential field =====
t4 = (t3(end)+1):T;
% pick sources / sinks if not provided
if isempty(opts.src_ids), opts.src_ids = randperm(N,2); end
if isempty(opts.snk_ids), opts.snk_ids = randperm(N,2); end
s = zeros(N,1); s(opts.src_ids) = +1; s(opts.snk_ids) = -1;
% (L + eps I) x = s  → static spatial potential with strong divergence at seeds
A = G.L + opts.eps_poisson*speye(N);
xpot = A \ s;
% time modulation to see divergence bursts
env = sin(2*pi*0.5*t(1:numel(t4))).^2;   % 0.5 Hz envelope
X4 = xpot * env;

% ===== Concatenate and add noise =====
X = [X1 X2 X3 X4];
X = X + opts.noise * std(X(:)) * randn(size(X));

% Normalize overall scale (optional)
X = X / (std(X(:)) + eps);

% ===== Pack info =====
info.epochs.random.t_idx   = t1;
info.epochs.global.t_idx   = t2;
info.epochs.local.t_idx    = t3;
info.epochs.srcsink.t_idx  = t4;
info.patch_id  = patch_id;
info.src_mask  = accumarray(opts.src_ids(:),1,[N,1])>0;
info.snk_mask  = accumarray(opts.snk_ids(:),1,[N,1])>0;
info.x_potential = xpot;
info.t = t; info.fs = fs;
info.notes.random  = 'i.i.d. rough field (high TV)';
info.notes.global  = 'global sinusoid, same phase (low TV, low |∇x|)';
info.notes.local   = sprintf('%d patch sinusoids (|∇x| at boundaries)', K);
info.notes.srcsink = 'Poisson potential from source(+)/sink(−) seeds (high |div| near seeds)';

% ===== Optional quick QC visualization (uncomment) =====
%{
[B,~,~,~] = build_incidence(G, opts.use_len_norm);
TV = sum(abs(B*X),1);
figure; 
subplot(3,1,1); imagesc(t,1:N,zscore(X,0,2)); axis xy; title('Signal (z-scored per vertex)'); xlabel('s'); ylabel('v');
subplot(3,1,2); plot(t, TV, 'k'); grid on; title('TV(t)'); xline(t(t1(end)),'--'); xline(t(t2(end)),'--'); xline(t(t3(end)),'--');
subplot(3,1,3); gsp_plot_signal(G, info.x_potential); title('Source/Sink potential (static)'); colorbar
%}
end

% ------- helpers (lightweight, no extra toolboxes) --------

function patch_id = make_patches(G, K)
% Assign K spatially coherent patches using k-means on coords (or spectral)
N = G.N; patch_id = ones(N,1);
if isfield(G,'coords') && ~isempty(G.coords)
    C = G.coords;
else
    % fall back to first few eigenvectors as an embedding
    if ~isfield(G,'U') || isempty(G.U), gsp_compute_fourier_basis(G); end
    C = G.U(:,2:4);  % skip DC
end
% kmeans++ (repeat a few times for stability)
opts = statset('MaxIter',200,'UseParallel',false);
try
    patch_id = kmeans(C, K, 'Replicates',5, 'Start','plus', 'Options',opts);
catch
    % if Statistics toolbox is unavailable, do greedy seeding + assign
    seed = C(randperm(size(C,1),K),:);
    D = pdist2(C, seed);
    [~,patch_id] = min(D, [], 2);
end
end

function [B, iE, jE, Lij] = build_incidence(G, length_normalize)
% Oriented edge incidence; optional per-mm scaling using coords
if nargin<2, length_normalize = false; end
[i,j] = find(triu(G.W,1));
m = numel(i);
if length_normalize && isfield(G,'coords') && ~isempty(G.coords)
    Lij = vecnorm(G.coords(i,:) - G.coords(j,:), 2, 2);
    w = 1./max(Lij, eps);
else
    Lij = ones(m,1); w = ones(m,1);
end
B = sparse([(1:m)';(1:m)'], [i;j], [w;-w], m, G.N);
iE=i; jE=j;
end
