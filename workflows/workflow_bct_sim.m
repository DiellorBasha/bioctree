%% BIOCTREE — Simulator end-to-end demo (B-bound, aligned with your bct workflow)
% This single script mirrors the style of your CWT demo:
%  - Uses bct.bct to create the file and do ALL I/O.
%  - Lets bct.sim.sim auto-create a default graph if none exists (gsp_bunny + lmax).
%  - Generates a default growth series X(T×N) with T=100 @ fs=10 Hz (width increases over time).
%  - Writes X to /signals/raw using B.write_raw (your typical pattern).
%  - Initializes /signals/raw_stack and appends layers using B.append_raw_layer.
%  - Sets the default layer with B.set_default_layer so /signals/raw is kept in sync.

%% 0) Setup: path + init + file
bioctree_start;
bioctree_init();                                      % put +bct on path

outfn = 'sub-01_sim_demo.bct.h5';                     % will be placed under /data via Paths.underData
if exist(outfn,'file'), delete(outfn); end
B = bct.bct.create(outfn);                            % new, schema-correct file

%% 1) Simulator (B-bound)
% If the file has no graph, S will:
%  - create default bunny graph (gsp_bunny), estimate lmax
%  - persist coords + edges via B.write_graph(...)
S = bct.sim.sim(B);

%% 2) Generate the DEFAULT growth series: T=100, fs=10 Hz (time × nodes)
% The Gaussian width starts tiny at t=1 and grows linearly to t=100.
X_TN = S.gaussian_growth_default();                   % size: [100 × N], single
fs   = 10;                                            % Hz

% -- Write this as the "typical" default layer (/signals/raw), like your CWT demo
B.write_raw(X_TN, fs);                                % creates /axes/time_s and /signals/raw

% Report axes
T = numel(B.read_axis('time_s'));
N = numel(B.read_axis('node_id'));
fprintf('[sim] Axes established: T=%d, N=%d, fs=%.3f Hz\n', T, N, fs);

%% 3) Initialize /signals/raw_stack and layer_id, then append layers
% NOTE: Your B.append_raw_layer initializes /signals/raw_stack (L=1) the first time it's called,
%       but it writes ONLY the provided layer on first init. To keep the stack consistent with
%       the already-written default layer, we append the growth series as layer 0, then append
%       any additional layers (e.g., a static Gaussian) as layer 1, 2, ...

% 3a) Ensure the growth series also exists in the stack as layer 0 (0-based)
B.append_raw_layer(X_TN, 0);                          % creates /signals/raw_stack with L=1 (layer_id=0)

% 3b) Create a STATIC Gaussian (single frame) and append it as layer 1
center_node = min(250, N);                            % clamp example index to valid range
x_static_N  = S.gaussian('center', center_node, 'sigma', 3);  % N×1
B.append_raw_layer(reshape(x_static_N, 1, N), 1);     % store as T=1 × N, layer_id=1

% 3c) Set default layer (copy chosen stack layer into /signals/raw for fast access)
%     Pick which one you want to be "default": 1-based when calling set_default_layer
%     layer 1-based = 1 → growth series (layer_id 0-based), = 2 → static Gaussian
B.set_default_layer(1);                               % keep "growth" as the /signals/raw view
fprintf('[sim] raw_stack initialized with 2 layers; default set to layer 1 (growth)\n');

%% 4) Sanity checks (read slices like in your CWT demo)
% First and last frames (narrow vs wide)
x_t1   = B.read_raw([1 1],    1:N);                   % (1×N)
x_tEnd = B.read_raw([T T],    1:N);                   % (1×N)
fprintf('[sim] max@t=1 = %.3f, max@t=%d = %.3f\n', max(x_t1), T, max(x_tEnd));

% Quick plots
figure('Name','Growth series sanity (default layer view)');
subplot(1,2,1); plot(x_t1);    title('t=1 (narrow)'); xlabel('node'); ylabel('ampl.');
subplot(1,2,2); plot(x_tEnd);  title(sprintf('t=%d (wide)', T)); xlabel('node'); ylabel('ampl.');

%% 5) Switch default to the static layer (optional)
% Demonstrate flipping the default-layer view and reading back
B.set_default_layer(2);                                   % 1-based → static Gaussian (layer_id=1)
x_static_read = B.read_raw([1 1], 1:N);                   % should match x_static_N (up to single precision)
fprintf('[sim] Default layer switched to layer 2 (static). Readback size: %dx%d\n', size(x_static_read));

% Restore default to growth if desired
B.set_default_layer(1);

%% 6) Windowed read example (just like your typical workflows)
% Read a time window (t = 10..20) from the current default layer (growth)
t0 = min(10, T); t1 = min(20, T);
Xwin = B.read_raw([t0 t1], 1:N);                          % (t1-t0+1) × N
fprintf('[sim] Read window [%d..%d] → %dx%d\n', t0, t1, size(Xwin,1), size(Xwin,2));

figure('Name','Window trace (growth default layer)');
plot(t0:t1, Xwin(:, ceil(N/2)), '-o'), grid on
xlabel('time (samples)'); ylabel('amplitude');
title(sprintf('Node %d, window [%d..%d]', ceil(N/2), t0, t1));

%% 7) Final validation (optional)
try
    rep = B.validate(); %#ok<NASGU>
    disp('[sim] BCT file validates successfully.');
catch ME
    warning('[sim] Validation reported an issue: %s', ME.message);
end

% End of demo
