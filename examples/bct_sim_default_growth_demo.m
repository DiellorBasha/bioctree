bioctree_init();

% Create or open a BCT file
fn = 'demo_default_growth.bct.h5';
if exist(fn,'file'), delete(fn); end
B = bct.bct.create(fn);

% Build simulator (auto-creates bunny graph in file if missing)
S = bct.sim.sim(B);

% Generate default growth signal (T=100, fs=10) and write it
X_TN = S.gaussian_growth_default();     % T×N
layer_id = S.write_layer(X_TN);         % initializes axes if needed
fprintf('Appended growth series as layer %d (1-based)\n', layer_id);

% Make it the default layer and copy to /signals/raw for fast access
B.set_default_layer(layer_id);

% Quick sanity: read a time slice back
tSpan = [1 1]; nodeIdx = [1 B.N];      % first time step
x1 = B.read_raw(tSpan, nodeIdx);       % 1×N
fprintf('Read back a slice: size = [%d %d]\n', size(x1,1), size(x1,2));
