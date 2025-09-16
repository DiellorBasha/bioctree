%GSP_DEMO_WAVELET Introduction to spectral graph wavelet with the GSPBox
% 
%   The wavelets are a special type of filterbank. In this demo, we will
%   show how you can very easily construct a wavelet frame and apply it to
%   a signal. If you want to do find an interactive demo of the wavelet, we
%   encourage you to use the sgwt_demo2 of the sgwt toolbox. It can be
%   downloaded at:

%% Initialization

close all;

%% Load the graph of the cortical mesh
data = getData();
V = data.anat.Vertices;       % [15002 x 3] flipped to work with Fast Marching
F = data.anat.Faces;             % [29988 x 3]
VertConn=data.anat.VertConn;
nVertices = size(Vertices,2);
nFaces=size(Faces,2);
sourceTS = data.sourceTS;            % [15002 x 9600]
% Extract all triangle edges
edges = [F(:,[1 2]); F(:,[2 3]); F(:,[3 1])];  % 3M x 2 matrix
G = graph(edges(:,1), edges(:,2));
Gs=simplify(G);
endpoints = Gs.Edges.EndNodes;  % Size: [numEdges x 2]
i = endpoints(:,1);
j = endpoints(:,2);
xyz_i = V(i, :);  % N_edges x 3
xyz_j = V(j, :);  % N_edges x 3
% Euclidean distance for each edge
edge_lengths = sqrt(sum((xyz_i - xyz_j).^2, 2));
Gs.Edges.Weight = edge_lengths;
D = distances(Gs, 'Method', 'positive');  % uses your edge weights

sigma = prctile(D(D > 0), 10);  % Choose a local scale (10th percentile)
W_geo = exp(-D.^2 / (2 * sigma^2));
W_geo(D == 0) = 0;  % Remove self-connections

%% Using https://www.mathworks.com/help/signal/ug/graph-signal-processing-and-brain-signal-analysis.html
Ac= hModelBrainConnectivity(V);
figure(1)
plotBrainConnectivity(Ac)
%% Estimate the geodesic between two points using the high res cortex mesh

G = gsp_graph(VertConn, V);
G = gsp_estimate_lmax(G);
% Step 1: Compute edge weights (Euclidean distances between neighbors)

%% Heat kernel
taus = [1,10,100,1000];  % Now these are meaningful
 % Now these are meaningful
Hk = gsp_design_heat(G, taus);
%% 

S = zeros(G.N, 1);
vertex_delta = 1800;
S(vertex_delta) = 1;

Sf_vec = gsp_filter_analysis(G, Hk, S);
Sf = gsp_vec2mat(Sf_vec, length(taus));

%% 
figure(1)
param_plot.cp = [0.2223, -5, 12.3666];
param_plot.vertex_size=0.7;
param_plot.vertex_highlight=vertex_delta;
subplot(221)
gsp_plot_signal(G,Sf(:,1), param_plot);
axis square
title(sprintf('Heat diffusion tau = %d', taus(1)));
subplot(222)
gsp_plot_signal(G,Sf(:,2), param_plot);
axis square
title(sprintf('Heat diffusion tau = %d', taus(2)));
subplot(223)
gsp_plot_signal(G,Sf(:,3), param_plot);
axis square
title(sprintf('Heat diffusion tau = %d', taus(3)));
subplot(224)
gsp_plot_signal(G,Sf(:,4), param_plot);
axis square
title(sprintf('Heat diffusion tau = %d', taus(4)));


%% Wavelets
Nf = 6;

 Wk = gsp_design_mexican_hat(G, Nf);

%Wk = gsp_design_meyer(G, Nf);

figure;
gsp_plot_filter(G,Wk);

param_filter.filter = Wk;
Wkw = gsp_design_warped_translates(G,Nf,param_filter);

figure;
gsp_plot_filter(G,Wkw);


%% 
vertex_delta=2000
S = zeros(G.N*Nf,Nf);
S(vertex_delta) = 1;
for ii=1:Nf
    S(vertex_delta+(ii-1)*G.N,ii) = 1;
end

Sf = gsp_filter_synthesis(G,Wk,S);

param_plot.vertex_highlight = vertex_delta;
wv=1
figure(1);
subplot(221)
gsp_plot_signal(G,Sf(:,wv), param_plot);
axis square
mu = mean(Sf(:,wv));
sigma = std(Sf(:,wv));
c_scale = 4;
caxis([mu - c_scale*sigma, mu + c_scale*sigma]);
 title(sprintf('Wavelet %d', wv));
subplot(222)
gsp_plot_signal(G,Sf(:,2), param_plot);
axis square
mu = mean(Sf(:,2));
sigma = std(Sf(:,2));
caxis([mu - c_scale*sigma, mu + c_scale*sigma]);
title('Wavelet 2');
subplot(223)
gsp_plot_signal(G,Sf(:,3), param_plot);
axis square
mu = mean(Sf(:,3));
sigma = std(Sf(:,3));
caxis([mu - c_scale*sigma, mu + c_scale*sigma]);
title('Wavelet 3');
subplot(224)
gsp_plot_signal(G,Sf(:,4), param_plot);
axis square
mu = mean(Sf(:,4));
sigma = std(Sf(:,4));
caxis([mu - c_scale*sigma, mu + c_scale*sigma]);
title('Wavelet 4');

%% Curvature estimation

s_map = G.coords;
s_map_out = gsp_filter_analysis(G, Wk, s_map);
s_map_out = gsp_vec2mat(s_map_out, Nf);

dd = s_map_out(:,:,1).^2 + s_map_out(:,:,2).^2 + s_map_out(:,:,3).^2;
dd = sqrt(dd);

figure;
subplot(221)
gsp_plot_signal(G,dd(:,2), param_plot);
axis square
title('Curvature estimation scale 1');
subplot(222)
gsp_plot_signal(G,dd(:,3), param_plot);
axis square
title('Curvature estimation scale 2');
subplot(223)
gsp_plot_signal(G,dd(:,4), param_plot);
axis square
title('Curvature estimation scale 3');
subplot(224)
gsp_plot_signal(G,dd(:,5), param_plot);
axis square
title('Curvature estimation scale 4');

%% 
s=sourceTS(:,1);
G = gsp_adj2vec(G);
gr = gsp_grad(G,s);
%%
Xall=sourceTS(:,1:2400);
T=size(Xall,2);
fs=2400;
Gt = gsp_jtv_graph(G,T, fs);
Nf = 6;

K = ones(G.N, T);  % uniform filter
psi_graph = @(x) exp(-x);  % diffusion in space
psi_time = @(t) t.^2 .* exp(-t.^2);  % temporal Mexican hat
K = {@(x, t) 1};
[g,filterType] = gsp_jtv_design_dgw(Gt,K, psi_graph, psi_time); %joint wavelet filter
[h,filterType] = gsp_jtv_filter_array(Gt,g, filterType);

[c] = gsp_jtv_filter_analysis(Gt, g, filterType, Xall);


%% 
coords = gsp_laplacian_eigenmaps(G, 2);
%%
 sigma =  0.0581
 [W_lh, W_rh, V_lh, V_rh] = computeGeodesicWeightMatrix(data, sigma);

W_n=W_lh(1:7000,1:7000);
V_n=V_lh(1:7000,:,:);
G = gsp_graph(W_n, V_n);  % V_lh is N×3 vertex coordinates for left hemisphere
G = gsp_estimate_lmax(G);
G.lap_type = 'normalized';
G = gsp_graph_default_parameters( G )
