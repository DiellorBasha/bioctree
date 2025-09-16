%GSP_DEMO_WAVELET Introduction to spectral graph wavelet with the GSPBox
% 
%   The wavelets are a special type of filterbank. In this demo, we will
%   show how you can very easily construct a wavelet frame and apply it to
%   a signal. If you want to do find an interactive demo of the wavelet, we
%   encourage you to use the sgwt_demo2 of the sgwt toolbox. It can be
%   downloaded at:
%
%   http://wiki.epfl.ch/sgwt/documents/sgwt_toolbox-1.02.zip
%
%   The sgwt toolbox has the same core as the GSPBox and all his functions
%   have equivalent in the GSPBox ( Except the demos ;-) ).
%
%   In this demo we will show you how to compute the wavelet coefficients
%   of a graph and visualize them. First, let's load a graph :
%
%       G = gsp_bunny();
%
%   This graph is a nearest-neighbor graph of a pointcloud of the Stanford
%   bunny. It will allow us to get interesting visual results using
%   wavelets. 
%
%   At this stage we could compute the full Fourier basis using
%   GSP_COMPUTE_FOURIER_BASIS, but this would take a lot of time, and can
%   be avoided by using Chebychev polynomials approximations. This operation
%   is implemented in most function and is thus completely transparent.
%
%   Simple filtering
%   ----------------
%
%   Before tackling wavelets, we can see the effect of one filter localized
%   on the graph. So we can first design a few heat kernel filters :
%       
%       taus = [1, 10, 25, 50];
%       Hk = gsp_design_heat(G, taus);
%
%   Let's now create a signal as a Kronecker located on one vertex (e.g.
%   the vertex 100) :
%
%       S = zeros(G.N, 1);
%       vertex_delta = 83;
%       S(vertex_delta) = 1;
% 
%       Sf_vec = gsp_filter_analysis(G, Hk, S);
%       Sf = gsp_vec2mat(Sf_vec, length(taus));
%
%   and plot the filtered signal :
%
%       param_plot.cp = [0.1223, -0.3828, 12.3666];
% 
%       figure;
%       subplot(221)
%       gsp_plot_signal(G,Sf(:,1), param_plot);
%       axis square
%       title(sprintf('Heat diffusion tau = %d', taus(1)));
%       subplot(222)
%       gsp_plot_signal(G,Sf(:,2), param_plot);
%       axis square
%       title(sprintf('Heat diffusion tau = %d', taus(2)));
%       subplot(223)
%       gsp_plot_signal(G,Sf(:,3), param_plot);
%       axis square
%       title(sprintf('Heat diffusion tau = %d', taus(3)));
%       subplot(224)
%       gsp_plot_signal(G,Sf(:,4), param_plot);
%       axis square
%       title(sprintf('Heat diffusion tau = %d', taus(4)));
%
%   Figure 1: Heat diffusion at different scales
%
%
%   Visualizing wavelets atoms
%   --------------------------
%   
%   Let's now replace the filtering by the heat kernel by a filter bank of
%   wavelets. We can create a filter bank using one of the design functions
%   such as GSP_DESIGN_MEXICAN_HAT :
%
%         Nf = 6;
%         Wk = gsp_design_mexican_hat(G, Nf);
%
%   We can plot the filter bank spectrum :
%
%         figure;
%         gsp_plot_filter(G,Wk);
%   
%   Figure 2: Wavelets filterbank (Original)
%
%
%   As we can see, the wavelets atoms are stacked on the low frequency part
%   of the spectrum. If we want to get a better coverage of the graph
%   spectrum we can use the function GSP_DESIGN_WARPED_TRANSLATES :
%
%         param_filter.filter = Wk;
%         Wkw = gsp_design_warped_translates(G,Nf,param_filter);
%
%   Now let's plot the new filter bank :
%
%         figure;
%         gsp_plot_filter(G,Wkw);
%   
%   Figure 3: Wavelet filterbank (spectrum adaptated)
%
%
%   We can see that the wavelet atoms are much more spread along the graph
%   spectrum. We can visualize the filtering by one atom as we did with the
%   heat kernel, by placing a Kronecker delta at one specific vertex and
%   filter using the filter bank :
% 
%         S = zeros(G.N*Nf,Nf);
%         S(vertex_delta) = 1;
%         for ii=1:Nf
%             S(vertex_delta+(ii-1)*G.N,ii) = 1;
%         end
% 
%         Sf = gsp_filter_synthesis(G,Wkw,S);
%   
%   We can plot the resulting signal for the different scales :
%
%         figure;
%         subplot(221)
%         gsp_plot_signal(G,Sf(:,1), param_plot);
%         axis square
%         mu = mean(Sf(:,1));
%         sigma = std(Sf(:,1));
%         c_scale = 4;
%         caxis([mu - c_scale*sigma, mu + c_scale*sigma]);
%         title('Wavelet 1');
%
%         subplot(222)
%         gsp_plot_signal(G,Sf(:,2), param_plot);
%         axis square
%         mu = mean(Sf(:,2));
%         sigma = std(Sf(:,2));
%         caxis([mu - c_scale*sigma, mu + c_scale*sigma]);
%         title('Wavelet 2');
%
%         subplot(223)
%         gsp_plot_signal(G,Sf(:,3), param_plot);
%         axis square
%         mu = mean(Sf(:,3));
%         sigma = std(Sf(:,3));
%         caxis([mu - c_scale*sigma, mu + c_scale*sigma]);
%         title('Wavelet 3');
%
%         subplot(224)
%         gsp_plot_signal(G,Sf(:,4), param_plot);
%         axis square
%         mu = mean(Sf(:,4));
%         sigma = std(Sf(:,4));
%         caxis([mu - c_scale*sigma, mu + c_scale*sigma]);
%         title('Wavelet 4');
%
%   Figure 4: A few wavelets atoms
%
%
%   Curvature estimation
%   --------------------
%   
%   As a last and more applied example, let us try to estimate the
%   curvature of the underlying 3D model by only using only spectral
%   filtering on the graph. 
%
%   A simple way to accomplish that is to use the
%   coordinates map [x, y, z] and filter it using the wavelets defined
%   above. We obtain a 3-dimensional signal [hat(x), hat(y), hat(z)]*
%   which describes variation along the 3 coordinates :
%
%         s_map = G.coords;
%         s_map_out = gsp_filter_analysis(G, Wk, s_map);
%         s_map_out = gsp_vec2mat(s_map_out, Nf);
%   
%   Finally we can get the curvature estimation by taking the l_1 or
%   l_2 norm of the filtered signal :
%
%         dd = s_map_out(:,:,1).^2 + s_map_out(:,:,2).^2 + s_map_out(:,:,3).^2;
%         dd = sqrt(dd);
%
%   Let's now plot the result to observe that we indeed have a measure of
%   the curvature :
%
%         figure;
%         subplot(221)
%         gsp_plot_signal(G,dd(:,2), param_plot);
%         axis square
%         title('Curvature estimation scale 1');
%         subplot(222)
%         gsp_plot_signal(G,dd(:,3), param_plot);
%         axis square
%         title('Curvature estimation scale 2');
%         subplot(223)
%         gsp_plot_signal(G,dd(:,4), param_plot);
%         axis square
%         title('Curvature estimation scale 3');
%         subplot(224)
%         gsp_plot_signal(G,dd(:,5), param_plot);
%         axis square
%         title('Curvature estimation scale 4');
%
%   Figure 5: Curvature estimation using wavelet feature
%
%
%
%   Url: https://epfl-lts2.github.io/gspbox-html/doc/demos/gsp_demo_wavelet.html
% Copyright (C) 2013-2016 Nathanael Perraudin, Johan Paratte, David I Shuman.
% This file is part of GSPbox version 0.7.5
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.
% If you use this toolbox please kindly cite
%     N. Perraudin, J. Paratte, D. Shuman, V. Kalofolias, P. Vandergheynst,
%     and D. K. Hammond. GSPBOX: A toolbox for signal processing on graphs.
%     ArXiv e-prints, Aug. 2014.
% http://arxiv.org/abs/1408.5781
% Author: Johan Paratte
% Date : 21 August 2014
%% Initialization
clear;
close all;
%% Load data from brainstorm
MriFileSrc='C:\Users\diell\ownSyncFolder\PAD7_test\anat\sub-MTL0002\subjectimage_T1_reslice.mat'
[sSubject, iSubject] = bst_get('MriFile', MriFileSrc);

allFiles = {sSubject.Surface.FileName};
% Find indices for each surface type
idxPial  = find(~cellfun('isempty', regexp(allFiles, 'cortex_pial_low\.mat$', 'once')), 1);
 pialFile = allFiles{idxPial};
 sPial  = in_tess_bst(pialFile);

%% Load the graph of the bunny
data=getData(5);
G = gsp_bunny();
V=data.anat.Vertices;
VertConn=data.anat.VertConn;
Atlas=data.anat.Atlas(3).Scouts;
AtlasLabels={Atlas.Label};
calcarineDeltas = Atlas(strcmp({Atlas.Label}, 'pericalcarine L')).Vertices;
frontalDeltas = Atlas(strcmp({Atlas.Label}, 'frontalpole L')).Vertices;
postcentralDeltas = Atlas(strcmp({Atlas.Label}, 'postcentral L')).Vertices;
cmfDeltas = Atlas(strcmp({Atlas.Label}, 'caudalmiddlefrontal L')).Vertices;
SulciMap=data.anat.SulciMap;
CurvatureLocal=data.anat.Curvature;
G=gsp_graph(VertConn,V);

G = gsp_estimate_lmax(G);
%% Heat kernel
taus = [0.1*G.lmax, 1*G.lmax, 10*G.lmax, 100*G.lmax];
Hk = gsp_design_heat(G, taus);
S = zeros(G.N, 1);
vertex_delta = calcarineDeltas(1);
vertex_delta = postcentralDeltas(round(end/2));
vertex_delta = frontalDeltas(end);
vertex_delta = cmfDeltas(end);
vertex_delta = postcentralDeltas(round(end/2));
gyri=find(~SulciMap);
sulci=find(~SulciMap);
postcentralGyri= postcentralDeltas(ismember(postcentralDeltas, gyri));
vertex_delta = postcentralGyri(round(end/2));

S(vertex_delta) = 1;
Sf_vec = gsp_filter_analysis(G, Hk, S);
Sf = gsp_vec2mat(Sf_vec, length(taus));

%% 

param_plot.cp = [0, 0.5, 0];
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
Wk=Wkw;
%% 
param_plot.cp = [0.1223, -0.3828, 12.3666];
vertex_delta = calcarineDeltas(1);
vertex_delta = postcentralDeltas(round(end/2));
vertex_delta = frontalDeltas(end);
vertex_delta = cmfDeltas(1);
gyri=find(~SulciMap);
sulci=find(~SulciMap);
cmfGyri= cmfDeltas(ismember(cmfDeltas, gyri));
vertex_delta = cmfGyri(round(end/2));
pcGyri= postcentralDeltas(ismember(postcentralDeltas, gyri));
pcSulci= postcentralDeltas(ismember(postcentralDeltas, sulci));

vertex_delta = pcSulci(round(end/2));
vertex_delta = pcGyri(1);
S = zeros(G.N*Nf,Nf);
S(vertex_delta) = 1;
for ii=1:Nf
    S(vertex_delta+(ii-1)*G.N,ii) = 1;
end
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
s_map = G.coords;
s_map_out = gsp_filter_analysis(G, Wk, s_map);
s_map_out = gsp_vec2mat(s_map_out, Nf);
dd = s_map_out(:,:,1).^2 + s_map_out(:,:,2).^2 + s_map_out(:,:,3).^2;
dd = sqrt(dd);
figure;
subplot(221)
gsp_plot_signal(G,dd(:,1), param_plot);
axis square
title('Curvature estimation scale 1');
subplot(222)
gsp_plot_signal(G,dd(:,2), param_plot);
axis square
title('Curvature estimation scale 2');
subplot(223)
gsp_plot_signal(G,dd(:,3), param_plot);
axis square
title('Curvature estimation scale 3');
subplot(224)
gsp_plot_signal(G,dd(:,4), param_plot);
axis square
title('Curvature estimation scale 4');
colormap hot
    %% ======== CREATE TIME-VERTEX
    % for ii=1:9
    % data(ii).data=getData(ii);
    % end
    % 
    % for k = 1:9 
    % Xin=data(k).data.sourceTS;
    % Xds=(downsample(Xin',8))';
    % X = [X Xds];
    % end
    data2=getData(7);
%% 
dsFactor=
X=(downsample(data2.sourceTS', 12))';
fs=data2.fs/12;  
T=size(X,2);

%% 

fb = cwtfilterbank('Wavelet', 'amor', ...
                     'SignalLength', T,...
                   'VoicesPerOctave', 12, ...
                   'SamplingFrequency', fs, ...
                   'FrequencyLimits', [1 50]);
freqs=fb.centerFrequencies;
wvlets=fb.wavelets;
wvsupport=fb.waveletsupport;
freqResponses=fb.freqz;
freqResponses=freqResponses(:,2:end);
scaleSpectrum(fb,X(1,:));
timeSpectrum(fb,X(1,:));
%% 

figure 
subplot(221)
cwt(X(calcarineDeltas(124),:), 'FilterBank', fb)
subplot(222)
cwt(X(cmfDeltas(124),:), 'FilterBank', fb)
subplot(223)
cwt(X(frontalDeltas(12),:), 'FilterBank', fb)
subplot(224)
cwt(X(postcentralDeltas(138),:), 'FilterBank', fb)
%% 

 Gtv = gsp_jtv_graph(G, T, fs); 
%% 

    Nf = round(G.lmax)-1;
    Nf=4;
    psi_graph = gsp_design_mexican_hat(Gtv, Nf);
    omega = Gtv.jtv.omega;
%% 

Nf = 10;
fmin = 1;
fmax = fs/2;
centerFreqs = logspace(log10(fmin), log10(fmax), Nf);
Q = 10;
sigma = centerFreqs / Q;

psi_time = cell(1, numel(centerFreqs));
for j = 1:numel(centerFreqs)
    psi_time{j} = @(f) exp(-0.5 * ((f - centerFreqs(j))/sigma(j)).^2);
end
psi_time=psi_time.';
%% 

% Parameters
            % Sampling rate (Hz)
lowcut = 8;           % Lower cutoff (Hz)
highcut = 13;         % Upper cutoff (Hz)
order = 4;            % Filter order

% Design bandpass Butterworth filter
[b, a] = butter(order, [lowcut highcut]/(fs/2), 'bandpass');

% Apply to each vertex (along time dimension)
X_alpha = filtfilt(b, a, X')';  % Transpose to filter along rows, then transpose back

%% 

    Nspeeds=2;
    beta=0.05; % damping
        s_max=2/Gtv.lmax; 
        s_vals = logspace(log10(0.001*s_max), log10(s_max), Nspeeds);
    K=cell(length(s_vals), 1); 
    for i = 1:length(s_vals)
    s=s_vals(i);
    K{i} = @(x,t) (t>=0) .* exp(-beta * t) .* cos (t .*acos(1 - s * x/2));
    end

psi_alpha=psi_time(centerFreqs>7 & centerFreqs<13);

    % Design the dynamic graph wavelet filters
     [g, filterType] = gsp_jtv_design_dgw (Gtv, K, psi_graph, psi_alpha); 
   %% 
   
    g=g(1:16);


filparam.domain='joint-spectral'
filparam.show_sum=0;
filparam.fftshift = 1;  % Don't center at 0 Hz
gsp_plot_jtv_filter(Gtv, g, filterType,filparam)
    %% 

    Xf = gsp_jtv_filter_analysis(Gtv, g(4), filterType, X);
    %%
    energy_per_filter = squeeze(sum(sum(abs(Xf).^2, 1), 2));  % 1×5
    figure(2)
    bar(energy_per_filter);
    xlabel('Filter index (scale or wave speed)');
    ylabel('Total energy');
    title('Energy captured by each dynamic wavelet');
%% 
    k =7;  % choose filter index
    figure
    imagesc(abs(Xf(:,:,k)));  % size: 2503 × 1000
        xlabel('Time');
        ylabel('Vertex');
        title(sprintf('Wavelet coefficients for filter %d', k));
        colormap turbo;
        colorbar;

      climmax=  max(abs(Xf(:)));
      climmin = min(abs(Xf(:)));
%% 
k=1
% paramjtvplot.cp = [0, 0.5,0];
parajvtplot.vertex_size=4;
parajvtplot.clim = [climmin climmax];
parajvtplot.colorbar=1;
gsp_plot_jtv_signal(Gtv,abs(Xf(:,:,k)), parajvtplot)
%% 

k=12
sigxf=abs(Xf(:,:,10:12));
sigxf=mean(sigxf, 3);
paramjtvplot.cp = [0.1223, -0.3828, 12.3666];
gsp_plot_jtv_signal(Gtv,sigxf, paramjtvplot)

%% 
filparam.domain='joint-spectral'
filparam.show_sum=0;
gsp_plot_jtv_filter(Gtv, g, filterType,filparam)

%% 

t = (0:T-1)/fs;  % time from 0 to 1 second

figure;
hold on;
for j = 1:length(center_frequencies)
    plot(t, psi_time{j}(t), 'DisplayName', sprintf('f₀ = %d Hz', center_frequencies(j)));
end
xlabel('Time (s)');
ylabel('\psi_{time}(t)');
title('Temporal Wavelets (Morlet-like)');
legend;
grid on;

%% 

lb = -4; ub = 4; n = 1000;
[psi_vals, t_vals] = morlet(lb, ub, n);

psi_time_func = @(t) interp1(t_vals, psi_vals, t, 'linear', 0);
psi_time = {psi_time_func};  % wrapped in cell array


%%

% Xf: [time_wavelet, graph_wavelet, kernel]
Xf_abs = abs(Xf);  % magnitude
Xf_phase = angle(Xf);  % phase