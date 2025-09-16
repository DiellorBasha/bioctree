%GSP_DEMO_WAVELET Introduction to spectral graph wavelet with the GSPBox
% 


%% Initialization
clear;
close all;

%% Load the graph of the bunny
G = gsp_bunny();
%anat=load('/export02/export01/data/brainstorm_db/PAD7JG/anat/Subject_068/tess_cortex_pial_low.mat');
anat=load('tess_cortex_pial_low.mat');
data=load('data.mat');
V=anat.Vertices;
VertConn=anat.VertConn;
Atlas=anat.Atlas(3).Scouts;
AtlasLabels={Atlas.Label};
calcarineDeltas = Atlas(strcmp({Atlas.Label}, 'pericalcarine L')).Vertices;
frontalDeltas = Atlas(strcmp({Atlas.Label}, 'frontalpole L')).Vertices;
postcentralDeltas = Atlas(strcmp({Atlas.Label}, 'postcentral L')).Vertices;
cmfDeltas = Atlas(strcmp({Atlas.Label}, 'caudalmiddlefrontal L')).Vertices;

cd('/export02/export01/data/dbasha/code/gspbox-0.7.5/gspbox');
gsp_start

G=gsp_graph(VertConn,V);
G = gsp_estimate_lmax(G);
%%
F=data.raw.F;
chanFlag=data.results.GoodChannel;
F=F(chanFlag,:);
X=data.results.ImagingKernel * F;

fs=200;
T=size(X,2);
%% Heat kernel
taus = [0.1*G.lmax, 1*G.lmax, 10*G.lmax, 100*G.lmax];
Hk = gsp_design_heat(G, taus);

S = zeros(G.N, 1);

vertex_delta = calcarineDeltas(1);
vertex_delta = postcentralDeltas(round(end/2));
vertex_delta = frontalDeltas(end);
vertex_delta = cmfDeltas(end);
vertex_delta = postcentralDeltas(round(end/2));

S(vertex_delta) = 1;

Sf_vec = gsp_filter_analysis(G, Hk, S);
Sf = gsp_vec2mat(Sf_vec, length(taus));

param_plot.cp = [0.1223, -0.3828, 12.3666];
param_plot.vertex_size=5;
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
Nf = round(G.lmax*2);
Nf=6;
Wk = gsp_design_mexican_hat(G, Nf);

figure;
gsp_plot_filter(G,Wk);

param_filter.filter = Wk;
Wkw = gsp_design_warped_translates(G,Nf,param_filter);
 
figure;
gsp_plot_filter(G,Wkw);


%% 
vertex_delta = calcarineDeltas(1);
vertex_delta = postcentralDeltas(round(end/2));

vertex_delta = cmfDeltas(end);

vertex_delta = frontalDeltas(end);
vertex_delta = postcentralDeltas(round(end/2));
S = zeros(G.N*Nf,Nf);
S(vertex_delta) = 1;
for ii=1:Nf
    S(vertex_delta+(ii-1)*G.N,ii) = 1;
end

      param_plot.cp = [0.1223, -0.3828, 12.3666];
% 
Sf = gsp_filter_synthesis(G,Wk,S);
figure;
subplot(221)
gsp_plot_signal(G,Sf(:,1), param_plot);
axis square
mu = mean(Sf(:,1));
sigma = std(Sf(:,1));
c_scale = 4;
caxis([mu - c_scale*sigma, mu + c_scale*sigma]);

title('Wavelet 1');
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
gsp_plot_signal(G,Sf(:,end), param_plot);
axis square
mu = mean(Sf(:,end));
sigma = std(Sf(:,end));
caxis([mu - c_scale*sigma, mu + c_scale*sigma]);
title('Wavelet 4');
colormap hot
%% Curvature estimation
param_plot.vertex_size=3;
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
gsp_plot_signal(G,dd(:,10), param_plot);
axis square
title('Curvature estimation scale 3');
subplot(224)
gsp_plot_signal(G,dd(:,end), param_plot);
axis square
title('Curvature estimation scale 4');

colormap hot

    %% ======== CREATE TIME-VERTEX
    fs=200;
    T=size(X,2);
    Gtv = gsp_jtv_graph(G, T, fs); 
  
    Nf = 6;
    psi_graph = gsp_design_mexican_hat(Gtv, Nf);


    omega = Gtv.jtv.omega;
    Nf=32;
    fmin=1;
    fmax=fs/2;
    
    center_frequencies = logspace(log10(fmin),log10(fmax), Nf);
    Q=10;
    sigma=center_frequencies/Q;
    psi_time=cell(Nf,1);
    for j=1:length(center_frequencies)
    psi_time{j}= @(f) exp(-0.5 * ((omega - center_frequencies(j))/sigma(j)).^2);
    end
 
%% 

fb = cwtfilterbank ('Wavelet','amor',...
    'SignalLength', T, ...
    'VoicesPerOctave', 12, ...
    'SamplingFrequency', fs, ...
    'FrequencyLimits', [1 50]);
freqs=fb.centerFrequencies;
wvlets=fb.wavelets;
wvsupport=fb.waveletsupport;
freqResponses=fb.freqz;
freqResponses=freqResponses(:,2:end);
omega=Gtv.jtv.omega;
freq_axis=linspace(0,fs/2,size(freqResponses,2));
omega_support=2*pi*freq_axis;

n_wavelets=size(freqResponses,1);
n_omega=length(omega);
psi_time=cell(n_wavelets,1);
pos_idx=find(omega>=0);
for j = 1:n_wavelets
    psi_full=zeros(1,n_omega);
    response=abs(freqResponses(j,:));
    n_pos_vals=min(length(pos_idx), length(response));
    psi_full(pos_idx(1:n_pos_vals)) = response(1:n_pos_vals);
    psi_time{j}=psi_full;

end

%% 
 Xe=X(:,end-2000:end);
    T=size(Xe,2);
    %% 
%% 
    %======== Design kernel

    s= 0.5; % scale = propagation speed required
    beta=0.05; % damping
        s_max=2/Gtv.lmax; Nspeeds=6;
        s_vals = logspace(log10(0.01*s_max), log10(s_max), Nspeeds);
        s_vals = linspace(0.01 * s_max, s_max, Nspeeds);

    K=cell(length(s_vals), 1); 
    for i = 1:length(s_vals)
    s=s_vals(i);
    K{i} = @(x,t) (t>=0) .* exp(-beta * t) .* cos (t .*acos(1 - s * x/2));
    end
   
    s=s_vals(1);
    K=cell(length(s), 1); 
    K{1} = @(x,t) (t>=0) .* exp(-beta * t) .* cos (t .*acos(1 - s * x/2));
    alphas=psi_time(centerFreqs>8 & centerFreqs<12);
    betas=psi_time(centerFreqs>14 & centerFreqs<25);

    alphas=psi_time(center_frequencies>8 & center_frequencies<12);
clear g
    K = {@(lambda, omega) 1};
    [g, filterType] = gsp_jtv_design_dgw (Gtv, K, psi_graph, alphas); 
%% 

    % Design the dynamic graph wavelet filters
    
       g=g(1:18)
  param.fftshift=0
  gsp_plot_jtv_filter(Gtv,g,filterType,param)
   %% 
   g=g(1:36)
   %% 
    Xs=X(:,1:2000);
    T=size(Xs,2);
    Gtv = gsp_jtv_graph(G, T, fs); 
    %%

   
     [g, filterType] = gsp_jtv_design_dgw (Gtv, K, psi_graph, betas); 
      Xbeta = gsp_jtv_filter_analysis(Gtv, g, filterType, Xe);

    %% Gtv 
X1=zeros(Gtv.N,Gtv.jtv.T,length(g));
    X1 = gsp_jtv_filter_analysis(Gtv, g(1:6), filterType, X);

    %%
    energy_per_filter = squeeze(sum(sum(abs(Xf).^2, 1), 2));  % 1×5
    figure
    bar(energy_per_filter);
    xlabel('Filter index (scale or wave speed)');
    ylabel('Total energy');
    title('Energy captured by each dynamic wavelet');
    %%

    climmax=max(abs(Xbeta(:)));
    climmin = min(abs(Xbeta(:)));
   %% 
    Sf = gsp_vec2mat(Xbeta, length(betas));
%% 

k=3
paramplot.vertex_size=5;
% paramplot.cp=[0,0.5,0]
% paramplot.clim = [climmin climmax];
paramplot.colorbar=1;
gsp_plot_jtv_signal(Gtv, abs(Xef(:,:,k)), paramplot)

%%

    k = 5;  % choose filter index
    figure
    imagesc(abs(Xf(:,:,k)));  % size: 2503 × 1000
        xlabel('Time');
        ylabel('Vertex');
        title(sprintf('Wavelet coefficients for filter %d', k));
        colormap turbo;
        colorbar;
%% 

figure(7)
clf abs(Xf(:,:,k))
Xfsig= abs(Xf(:,1:1000, 5));
gsp_plot_jtv_signal(Gtv,abs(Xef(:,1:1000, 5)), param_plot)
axis square
%% Estimating speed for kernels
% speed2 is 1/lambda per t^2
% t is in samples, so time=t/fs

% s must be smaller or equal to 2/lambda in order to keep the argument of
% arccos in valid bounds
% maximum speed is thefore smax=2/Gtv.lmax;


% 2. Temporal Resolution Limit
% You must have enough samples per oscillation to capture the wave.
% 
% rule of thumb
s_max=2/Gtv.lmax; Nspeeds=6;
s_vals = logspace(log10(0.01*s_max), log10(s_max), Nspeeds);
s_vals = linspace(0.01 * s_max, s_max, Nspeeds);

%%

omega_max=pi*fs;
omega=linspace(0, omega_max, 1000)
freq_Hz=omega/(2*pi)