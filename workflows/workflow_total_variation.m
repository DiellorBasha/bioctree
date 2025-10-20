%% GSPBox demo: Time-varying Total Variation on gsp_bunnyG
% Requirements: GSPBox on path (run gsp_start.m)

%% Time-varying TV on gsp_bunny (fixed)
% Prereq: GSPBox on path (run gsp_start)

g = gsp_bunny();                       % graph with g.W, g.coords (N×3)
g = gsp_graph_default_parameters(g);   % fills g.L, g.Ne, etc.

% --- Synthesise a moving Gaussian bump on nodes (N x T) ---
N = g.N;
T = 400;
X = zeros(N,T);

center1 = 100; 
center2 = 250;
lambda  = linspace(0, 1, T);          % <--- define lambda (0..1)

% Spatial scale from coord distances (gsp_distanz expects d×n samples)
d_to_c1 = gsp_distanz(g.coords', g.coords(center1,:)');  % N×1
sigma   = 0.03 * max(d_to_c1);                           % heuristic width

for t = 1:T
    c  = (1 - lambda(t)) * g.coords(center1,:)' + lambda(t) * g.coords(center2,:)';  % 3×1
    Dc = gsp_distanz(g.coords', c);                         % N×1 euclidean distances
    X(:,t) = exp(-(Dc.^2) / (2*sigma^2));                   % Gaussian bump on graph nodes
end

% Optional: add a small global oscillation (keeps neighbors similar → lowers TV)
X = X + 0.15 * sin(2*pi*(1:T)/40);

% --- Compute TV(t) via GSPBox gradient ---
g = gsp_adj2vec(g)
Gedge = gsp_grad(g, X);                 % E×T weighted oriented edge differences
TV_t  = sum(abs(Gedge), 1) / g.Ne;      % L1 over edges, normalized

% --- Dirichlet energy (x^T L x) for context ---
E2_t = sum((g.L * X) .* X, 1) / g.Ne;
%% 

% --- Plots ---
figure; 
plot(TV_t, 'LineWidth', 1.5); hold on;
plot(E2_t, 'LineWidth', 1.5); grid on;
xlabel('Time (samples)'); ylabel('Normalized variation per edge');
legend('TV (L1 on edges)','Dirichlet energy (x^T L x)','Location','best');
title('Time-varying spatial variation on gsp\_bunny');
%% 

% Visual check of the signal on the bunny
frames = [1, round(T/3), round(2*T/3), T];
figure;
for k = 1:numel(frames)
    subplot(2,2,k);
    gsp_plot_signal(g, X(:,frames(k)));
    title(sprintf('t = %d', frames(k))); axis square
end
colormap parula

%% 

%% === Visualize the actual data driving TV ===

Fs = 1;                    % set your sampling rate if you have it (Hz)
t  = (0:T-1)/Fs;

% --- 1) imagesc of node signals (z-scored per node) ---
Xz = zscore(X, 0, 2);      % z-score across time for each node
% Optional: order nodes along a coordinate axis to reveal spatial bands/fronts
[~, ord] = sort(g.coords(:,1), 'ascend');  % left→right in x
figure('Name','Node signals (imagesc)');
imagesc(t, 1:N, Xz(ord,:));
axis xy; xlabel('Time (s)'); ylabel('Node (sorted by x)');
title('Z-scored node signals (imagesc)');
colormap parula; colorbar;

% --- 2) Stacked time series of the K most variable nodes ---
K = 16;                                     % how many traces to show
[~, ixVar] = maxk(var(X,0,2), K);           % top-K variable nodes
Xsel = X(ixVar, :);

% Build offsets so traces don't overlap
rng(0);                                     % reproducible ordering
offset = (K:-1:1) * (0.9*max(std(Xsel,0,2)));   % simple vertical spacing
Xoff   = Xsel + offset(:);

figure('Name','Stacked node time series');
plot(t, Xoff', 'LineWidth', 1); grid on;
xlabel('Time (s)'); ylabel('Node (ranked by variance)');
title(sprintf('Top-%d node time series (stacked)', K));

% Add y-ticks with node IDs
yticks(offset);
yticklabels(string(ixVar(:)'));
