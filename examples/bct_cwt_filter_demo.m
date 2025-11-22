%% Example: CWT filterbank band-pass & TF write (B-bound)
% Assumes you have a BCT file with /signals/raw written already.

addpath(genpath('toolbox'));
bioctree_init();

% Create a small demo if missing:
fn = 'demo_cwt_filters.bct.h5';
if ~exist(fullfile('data','bioctree_files','raw',fn),'file')
    B = bct.bct.create(fn);
    % Graph (toy)
    N = 32; coords = rand(N,3,'single'); E = [ (1:N-1)' (2:N)' ];
    G = struct('coords',coords,'E',E,'lap_type','normalized','lmax',single(2));
    B.write_graph(G);
    % Raw
    fs = 200; T = 2000; t = (0:T-1)'/fs;
    X = 0.1*randn(T,N,'single');
    X(:,1:4) = X(:,1:4) + single(sin(2*pi*10*t)).*single(t>2 & t<6);
    X(:,5:8) = X(:,5:8) + 0.5*single(sin(2*pi*40*t));
    B.write_raw(X, fs);
    B.validate();
else
    B = bct.bct.open(fullfile('data','bioctree_files','raw',fn));
end

% Build filter once (default layer)
F = bct.filters.CWT(B,'VoicesPerOctave',12);

% Band-pass alpha (8–12 Hz) on nodes 1..12, cache under /results
y = F.bandpass([8 12], 'Nodes', 1:12, 'Tag', 'alpha', 'WriteCache', true);

% Quick look
t = (0:B.T-1)'/B.fs;
figure;
subplot(2,1,1);
imagesc(t,1:12,abs(y').^0.5); axis xy;
title('Alpha band (8–12 Hz) | nodes 1..12'); xlabel('Time (s)'); ylabel('Node'); colorbar
subplot(2,1,2);
plot(t, y(:,1), 'r'); grid on; xlabel('Time (s)'); ylabel('Amplitude'); title('Node 1 alpha band')

% Optionally write full TF (may take longer)
% F.writeTF();
% B.validate();

