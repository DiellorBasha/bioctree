function [X, Gtv] = generate_synthetic_multiband(G, T, fs, Atlas)
% Generate synthetic multiband signal (delta, alpha, beta) on a graph
% using traveling wave patterns and biologically motivated regional rhythms.
%
% Inputs:
%   G     - Graph structure (GSPBox format, with G.N nodes)
%   T     - Number of timepoints
%   fs    - Sampling frequency (Hz)
%   Atlas - 1xN struct array with fields: Name, Scouts (e.g., from Brainstorm)
%
% Outputs:
%   X     - [G.N x T] synthetic multiband signal
%   Gtv   - Time-vertex graph from gsp_jtv_graph

% ---- Time vector ----
t = (0:T-1)/fs;
N = G.N;
X = zeros(N, T);

% ---- Find 'Desikan-Killiany' atlas ----
dk_index = find(strcmp({Atlas.Name}, 'Desikan-Killiany'), 1);
if isempty(dk_index)
    error('Desikan-Killiany atlas not found in Atlas structure.');
end
DK = Atlas(dk_index).Scouts;

% ---- Extract relevant vertex indices ----
get_vertices = @(label_name) ...
    [DK(contains({DK.Label}, label_name)).Vertices];

postcentral = get_vertices('postcentral');
precuneus   = get_vertices('precuneus');
calcarine   = get_vertices('calcarine');
supramarginal   = get_vertices('supramarginal');
triangularis   = get_vertices('triangularis');

precuneus=[precuneus calcarine supramarginal triangularis];
% ---- Use fallback if regions not found ----
if isempty(precuneus), precuneus = randperm(N, round(N/10)); end
if isempty(postcentral), postcentral = randperm(N, round(N/20)); end

for i = 1:N
        % 10% of vertices don't show beta
        X(i, :) = 0.5 * randn(1, T);
end

% ---- DELTA: global slow wave ----
delta_freq = 2;
delta_delays = linspace(0, 100/fs, N);  % up to 100 ms
for i = round(N/4):round(3*N/4)
    phase = 2*pi*delta_freq*(t + delta_delays(i));
    X(i,:) = X(i,:) + 1.5 * sin(phase);
end

% ---- ALPHA: sustained rhythm in precuneus ----
alpha_freq = 10;
alpha_delays = linspace(0, 30/fs, numel(precuneus));
for idx = 1:numel(precuneus)
    i = precuneus(idx);
    phase = 2*pi*alpha_freq*(t - alpha_delays(idx));
    X(i,:) = X(i,:) + 2 * sin(phase);
end

% ---- BETA: transient burst in postcentral ----
beta_freq = 20;
burst_duration = round(0.2 * fs);  % 200 ms
burst_center = round(T/2);
burst_window = zeros(1,T);
burst_window(burst_center - burst_duration/2 : burst_center + burst_duration/2) = 1;

beta_delays = linspace(0, 10/fs, numel(postcentral));
for idx = 1:numel(postcentral)
    i = postcentral(idx);
    phase = 2*pi*beta_freq*(t - beta_delays(idx));
    X(i,:) = X(i,:) + 3 * sin(phase) .* burst_window;
end

% ---- Add noise ----
X = X + 0.3*randn(size(X));

% ---- Time-vertex graph ----
Gtv = gsp_jtv_graph(G, T, fs);

end
