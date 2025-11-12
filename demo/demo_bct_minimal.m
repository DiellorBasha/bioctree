bioctree_init();
outfn = fullfile(fileparts(mfilename('fullpath')),'..','data','bioctree_files','raw','demo_sub01.bct.h5');

% 1) Create empty bct
B = bct.bct.create(outfn);

% 2) Write graph (synthetic)
N = 32; coords = rand(N,3); E = [randi(N,64,1) randi(N,64,1)];
G = struct('coords',coords,'E',E,'lap_type','normalized','lmax',single(2.0));
B.write_graph(G);

% 3) Write raw signal
T=500; fs=100; X = randn(T,N,'single'); B.write_raw(X, fs);

% 4) Read a window
Xwin = B.read_raw([101 200],[1 8]); disp(size(Xwin));

% 5) Validate
B.validate(); disp('bct demo OK');
