bioctree_init();

% Create or open a BCT file
fn = 'demo_default_growth.bct.h5';
if exist(fn,'file'), delete(fn); end
B = bct.bct.create(fn);

% Generate default growth signal (T=100, fs=10)
% Note: Requires B.Manifold to be set
X_TN = bct.sim.gaussian_growth(B, 'T', 100, 'fs', 10);     % T×N

% Write to /signals/raw
fs = 10;  % Hz
B.write_raw(X_TN, fs);
fprintf('Written growth series to /signals/raw\n');

% Quick sanity: read a time slice back
N = size(B.Manifold.V, 1);
tSpan = [1 1]; nodeIdx = [1 N];      % first time step
x1 = B.read_raw(tSpan, nodeIdx);       % 1×N
fprintf('Read back a slice: size = [%d %d]\n', size(x1,1), size(x1,2));
