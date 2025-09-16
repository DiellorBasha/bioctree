addpath(pwd)
addpath('gspbox/')
addpath('test-data/')
% Ensure GSPBox is initialized
%% Load the graph of the cortical mesh
data = getData();
V = data.anat.Vertices;       % [15002 x 3] flipped to work with Fast Marching
F = data.anat.Faces;             % [29988 x 3]
VertConn=data.anat.VertConn;
nVertices = size(V,2);
nFaces=size(F,2);
sourceTS = data.sourceTS;            % [15002 x 9600]

gsp_start;

%% 

% Create a simple 10x10 grid graph (100 nodes)
% param.radius=1;
param.nb_pts=1000;
param.nb_dim=3; 
G = gsp_sphere(1000);
 %gsp_plot_graph(G)

%% Load the graph of the bunny

G = gsp_bunny();
G = gsp_graph(VertConn, V);
G = gsp_estimate_lmax(G);  % Estimate Laplacian max eigenvalue

N = G.N;             % Number of nodes
T = 1000;             % Number of time points
fs = 1000;           % Sampling frequency (Hz)
t = (0:T-1)/fs;      % Time vector
%G.coords=V(100:200,:);
 %% 
 
G = gsp_compute_fourier_basis(G);
gsp_plot_signal(G,G.U(:,2));


%% 
beta_freq = 4;      % Beta frequency (Hz)

% Create signal matrix (N x T)
X = zeros(G.N, T);

% Simulate signals: sinusoid with node-specific delays and noise
delays=linspace(0.001,1/beta_freq, round(3*N/4));
amplitudes=linspace(1,2, round(3*N/4));
amplitudesT=linspace(1,5,round(T/2));
amplitudesT2=linspace(5,1,round(T/2)); amplitudesT=[amplitudesT, amplitudesT2];

for i = 1:round(3*N/4)
        delay = delays(i);  % 0-10 ms delay
        amplitude = amplitudes(i);
        phase = 2 * pi * beta_freq * (t - delay/fs);
        X(i, :) = (sin(phase) + 0.3*randn(1, T))*amplitude;
        X(i,:)=X(i,:).*amplitudesT;
end

for i = round(3*N/4):N
        % 10% of vertices don't show beta
        X(i, :) = 0.5 * randn(1, T);
end
% for i = 1:N
%         % 10% of vertices don't show beta
%         X(i, :) = 0.5 * randn(1, T);
% end
postcentralDeltas = Atlas(contains({Atlas.Label}, 'postcentral')).Vertices;
beta_freq = 20;      % Beta frequency (Hz)
delays=linspace(0.001,50/beta_freq, numel(postcentralDeltas));

for k =1: numel(postcentralDeltas)
     delay = delays(k);  % 0-10 ms delay
    i=postcentralDeltas(k);    
    amplitude = amplitudes(k);
        phase = 2 * pi * beta_freq * (t - delay/fs);
        X(i, :) = (sin(phase) + 0.3*randn(1, T))*amplitude;

end
X2= [X(round(3*N/4):N, :); X(1:round(3*N/4)-1, :)];
%X=X2;
%% 


figure(1)
clf
for k=1:300
hold on
    plot (t, X(k,:)+k, 'k')
end
%% 
figure(1)
imagesc(X)
%% %% Structure properties
% Heat kernel

clear param_plot
taus = [0.1*G.lmax, 5*G.lmax, 10*G.lmax, 50*G.lmax];
Hk = gsp_design_heat(G, taus);

S = zeros(G.N, 1);
vertex_delta = 83;
S(vertex_delta) = 1;
%% 
tidx=150
S=X(:,tidx);

Sf_vec = gsp_filter_analysis(G, Hk, S);
Sf = gsp_vec2mat(Sf_vec, length(taus));
figure(2)
param_plot.cp = [0.1223, -0.3828, 12.3666];
param_plot.vertex_highlight=vertex_delta;
% param_plot.vertex_size=1;
% param_plot.climits=[min(X(:)),  max(X(:))];
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

figure;
gsp_plot_filter(G,Wk);

param_filter.filter = Wk;
Wkw = gsp_design_warped_translates(G,Nf,param_filter);
 
figure;
gsp_plot_filter(G,Wkw);
%% 

tidx=149
S = zeros(G.N*Nf,Nf);
S(vertex_delta) = 1;
for ii=1:Nf
    for iv=1:G.N
        vertex_delta=iv;
    S(vertex_delta+(ii-1)*G.N,ii) = X(vertex_delta,tidx);
    end
end

Sf = gsp_filter_synthesis(G,Wk,S);

mu=mean(Sf(:));
sigma=std(Sf(:));
c_scale=4;
clim=[mu - c_scale*sigma, mu + c_scale*sigma];

figure(4);

subplot(221)
gsp_plot_signal(G,Sf(:,1), param_plot);
axis square
% mu = mean(Sf(:,1));
% sigma = std(Sf(:,1));
% c_scale = 4;
% caxis([mu - c_scale*sigma, mu + c_scale*sigma]);
caxis(clim);
title('Wavelet 1');

subplot(222)
gsp_plot_signal(G,Sf(:,2), param_plot);
axis square
% mu = mean(Sf(:,2));
% sigma = std(Sf(:,2));
% caxis([mu - c_scale*sigma, mu + c_scale*sigma]);
caxis(clim);
title('Wavelet 2');

subplot(223)
gsp_plot_signal(G,Sf(:,3), param_plot);
axis square
% mu = mean(Sf(:,3));
% sigma = std(Sf(:,3));
% caxis([mu - c_scale*sigma, mu + c_scale*sigma]);
caxis(clim);
title('Wavelet 3');

subplot(224)
gsp_plot_signal(G,Sf(:,4), param_plot);
axis square
% mu = mean(Sf(:,4));
% sigma = std(Sf(:,4));
% caxis([mu - c_scale*sigma, mu + c_scale*sigma]);
caxis(clim);
title('Wavelet 4');

%% Curvature estimation
clear param_plot
param_plot.cp = [0.1223, -0.3828, 12.3666];
param_plot.vertex_size=3;

Nf = 6;

Wk = gsp_design_mexican_hat(G, Nf);

%Wk =  gsp_design_abspline(G, Nf);
% Wk =  gsp_design_meyer(G, Nf);
Wk = gsp_design_simple_tf(G, Nf);

figure;
gsp_plot_filter(G,Wk);

param_filter.filter = Wk;
Wkw = gsp_design_warped_translates(G,Nf,param_filter);
 
figure;
gsp_plot_filter(G,Wkw);

S = zeros(G.N*Nf,Nf);
S(vertex_delta) = 1;
for ii=1:Nf
    S(vertex_delta+(ii-1)*G.N,ii) = 1;
end

Sf = gsp_filter_synthesis(G,Wk,S);

s_map = G.coords;
s_map_out = gsp_filter_analysis(G, Wk, s_map);
s_map_out = gsp_vec2mat(s_map_out, Nf);

dd = s_map_out(:,:,1).^2 + s_map_out(:,:,2).^2 + s_map_out(:,:,3).^2;
dd = sqrt(dd);
%rmfield(param_plot, 'climits')
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
dd=data.anat.Curvature;

gsp_plot_signal(G,dd, param_plot);

%% ============= Create Time-Vertex ==============
Gtv = gsp_jtv_graph(G, T, fs);
%% 
% To find wave velocity, we need to know:
% 
% How far the wavefront travels across the graph per cycle (or per second).
% 
% Let’s say:
% 
% The wavefront travels d nodes per cycle of the 20 Hz oscillation.
% 
% Then: GSPBox internally defines velocity in time steps per spatial unit — the inverse of what we’d normally think of as "velocity".
% 
% So in GSPBox:
% 
% "wave velocity" is not nodes / sec, but rather:
% 𝑣 = Δ𝑡/Δ𝑥 time per unit graph distance​
%  =time per unit graph distance
% 
% Assuming beta wave travels 1 node per second:
% oscillation period T=1/20=0.05sec
% desired speed = v=1 node/0.05 sec = 20 nodes/sec

freq=1; % beta oscillation frequency
dist = [G.N/2, G.N/3, G.N/4,G.N/5]; % nodes per sample step 1/fs
wave_velocity = 1 ./ (freq * dist);  % in seconds per cycle

[g,filtertype] = gsp_jtv_design_wave(Gtv,wave_velocity);

Xf = gsp_jtv_filter_analysis(Gtv, g, filtertype,X);   

%% 
energy_map = abs(Xf(:,140:160)).^2;
vertex_energy = sum(Xf, 2);  % total energy at each node
param_plot.title='Total Energy per Vertex';
param_plot.vertex_size=10;
mu = mean(vertex_energy(:));
sigma = std(vertex_energy(:));
%% 
n_lambda = Gtv.N;                            % Resolution in graph freq
n_omega = Gtv.jtv.T;                             % Resolution in temporal freq

lambda = linspace(0, Gtv.lmax, n_lambda);  % Graph Laplacian eigenvalues
omega = linspace(0, 20, n_omega);        % Temporal frequencies in Hz


%%
Gfilter = zeros(n_omega, n_lambda);  % size: omega × lambda

i =1;  % Index of the filter you want to visualize

for o = 1:n_omega
    for l = 1:n_lambda
        Gfilter(o, l) = g{i}(lambda(l), omega(o));  % Evaluate g(λ, ω)
    end
end

figure;
imagesc(lambda, omega, Gfilter);
xlabel('\lambda (Graph freq)');
ylabel('\omega (Temporal freq in Hz)');
title(sprintf('Joint Filter g_{%d}(λ, ω)', i));
colorbar;
axis xy;


%% 

figure(5)
clf
subplot(221)
gsp_plot_signal(Gtv, vertex_energy(:,:,1), param_plot);
axis square
caxis([mu - c_scale*sigma, mu + c_scale*sigma]);
title(sprintf('Signal response energy to wave velocity %d nodes/second', 1/wave_velocity(1)));

subplot(222)
gsp_plot_signal(Gtv, vertex_energy(:,:,2), param_plot);
axis square
caxis([mu - c_scale*sigma, mu + c_scale*sigma]);
title(sprintf('Signal response energy to wave velocity %d nodes/second', 1/wave_velocity(2)));

subplot(223)
gsp_plot_signal(Gtv, vertex_energy(:,:,3), param_plot);
axis square
caxis([mu - c_scale*sigma, mu + c_scale*sigma]);
title(sprintf('Signal response energy to wave velocity %d nodes/second', 1/wave_velocity(3)));

subplot(224)
gsp_plot_signal(Gtv, vertex_energy(:,:,4), param_plot);
axis square
caxis([mu - c_scale*sigma, mu + c_scale*sigma]);
title(sprintf('Signal response energy to wave velocity %d nodes/second', 1/wave_velocity(4)));

%% 

[max_energy, idx] = max(energy_map(:));
[i_max, t_max] = ind2sub(size(energy_map), idx);
fprintf('Max activity at vertex %d and time %d ms\n', i_max, t_max);
% plot(X(i_max,:))

clear param_plot
param_plot.cp = [0.1223, -0.3828, 12.3666];

%% 

freq=20; % beta oscillation frequency
dist = [2.5, 10, 20, 100]; % 10 nodes per cycle
wave_velocity = 1 ./ (freq * dist);  % in seconds per node

[g,filtertype] = gsp_jtv_design_wave(Gtv,wave_velocity);

Xf = gsp_jtv_filter_analysis(Gtv, g, filtertype,X);   

%% 
f = gsp_jtv_fa(Gtv);
taxis = gsp_jtv_ta(Gtv);
plot(taxis,f)
%% 
% K = 4;
% 
% % Graph filters (spatial)
% taus = [0.01, 0.05, 0.1, 0.5];
% psi_graph = gsp_design_heat(Gtv, taus);

% Graph filter using Mexican hat wavelet
Nf = 6;  % number of spatial scales
psi_graph = gsp_design_mexican_hat(Gtv, Nf);  % returns cell array of filters over λ

% Temporal filter using Morlet wavelet
omega = Gtv.jtv.omega;  % temporal frequencies (1 x T)

center_frequencies = [5, 10, 15, 20, 25];  % Hz
sigma = 5;

psi_time = cell(length(center_frequencies),1);
for j = 1:length(center_frequencies)
    psi_time{j} = exp(-0.5 * ((omega - center_frequencies(j))/sigma).^2);
end
%% Check Morlet wavelets
% In frequency domain (expected by GSP)
figure;
hold on;
for j = 1:length(psi_time)
    plot(omega, psi_time{j}, 'DisplayName', sprintf('f₀ = %d Hz', center_frequencies(j)));
end
xlabel('\omega (Hz)');
ylabel('\psi_{time}(\omega)');
title('Temporal Wavelets (Gaussian in Frequency)');
legend show;
grid on;

% In time domain
psi_freq = psi_time{i};  % pick one Morlet-style wavelet
% Construct full spectrum assuming conjugate symmetry
psi_full = [psi_freq, fliplr(psi_freq(2:end-1))];  % 1×(2*T-2)
psi_full = psi_full / max(psi_full);               % normalize

% Inverse FFT to get time-domain wavelet
psi_time_domain = ifft(ifftshift(psi_full), 'symmetric');  % real-valued
dt = 1 / fs;                             % time resolution
n_time = length(psi_time_domain);
tpsi = (-n_time/2 : n_time/2 - 1) * dt;     % centered time axis
figure;
plot(tpsi, psi_time_domain);
xlabel('Time (s)');
ylabel('\psi(t)');
title(sprintf('Time-Domain Morlet Wavelet (f₀ = %d Hz)', center_frequencies(j)));
grid on;

%% 

% 3. Match number of joint atoms
Klen = min(length(psi_graph), length(psi_time));
psi_graph = psi_graph(1:Klen);
psi_time = psi_time(1:Klen);

% 4. FIXED: Define joint kernel functions (all flat)
K = repmat({@(x,t) 1}, Klen, 1);  % ✅ this is what the function expects

s = 0.5;   % scale = propagation speed squared
beta = 0.1;  % damping

K = {@(x,t) (t >= 0) .* exp(-beta * t) .* cos(t .* acos(1 - s * x / 2))};
s_vals = [0.1, 0.2, 0.3, 0.4, 0.5];
beta = 0.1;
K = cell(length(s_vals),1);
for i = 1:length(s_vals)
    s = s_vals(i);
    K{i} = @(x,t) (t >= 0) .* exp(-beta * t) .* cos(t .* acos(1 - s * x / 2));
end


% Design the dynamic graph wavelet filters
[g, filterType] = gsp_jtv_design_dgw(Gtv, K);

Xf = gsp_jtv_filter_analysis(Gtv, g, filtertype,X);   
%% 

for k = 1:size(Xf,3);  % choose filter index
nexttile
imagesc(abs(Xf(:,:,k)));  % size: 2503 × 1000
xlabel('Time');
ylabel('Vertex');
title(sprintf('Wavelet coefficients for filter %d', k));
colormap turbo;
colorbar;
end
%% 
t_idx = 503;
k = 5;

vertex_activation = abs(Xf(:,t_idx,k));
scatter(1:2503, vertex_activation, '.');
xlabel('Vertex index');
ylabel('|Xf(v,t,k)|');
title(sprintf('Activation at t=%d, filter %d', t_idx, k));

%% 

k = 4;
[max_vals, max_vertex_idx] = max(abs(Xf(:,:,k)), [], 1);  % over rows

plot(1:1000, max_vertex_idx);
xlabel('Time');
ylabel('Vertex with max response');
title(sprintf('Wavefront trajectory (filter %d)', k));


%% 

% Assuming G.coords is 2503×2 or 3
gsp_plot_signal(Gtv, Xf(:,t_idx,k));
title('Spatial activation at time slice');
%% 
mean_energy_time = squeeze(mean(abs(Xf).^2, 1));  % size: 1000 × 5

plot(mean_energy_time);
xlabel('Time');
ylabel('Mean energy');
legend('Filter 1', 'Filter 2', 'Filter 3', 'Filter 4', 'Filter 5');
title('Mean temporal energy per filter');
%% 
k = 5;  % filter index (wave velocity)
num_bins = 5;
bin_edges = round(linspace(1, 1000, num_bins+1));  % e.g., 0–200ms, 200–400ms, etc.
activation_by_bin = zeros(G.N, num_bins);

for b = 1:num_bins
    t_idx = bin_edges(b):bin_edges(b+1)-1;
    activation_by_bin(:, b) = mean(abs(Xf(:,t_idx,k)), 2);  % average across time bin
end

[~, max_bin_idx] = max(activation_by_bin, [], 2);  % bin where each vertex is most active
max_vals = max(activation_by_bin, [], 2);  % actual activation value

% Set low values to NaN for cleaner visualization
threshold = max(max_vals) * 0.1;
max_bin_idx(max_vals < threshold) = NaN;

colors = parula(num_bins);  % or 'hot', 'jet', etc.

% Create a color vector where each vertex has a color corresponding to its max_bin_idx
vertex_colors = zeros(G.N, 3);
for b = 1:num_bins
    idx = (max_bin_idx == b);
    vertex_colors(idx, :) = repmat(colors(b,:), sum(idx), 1);
end

% Set zero vectors to white
vertex_colors(sum(vertex_colors,2)==0,:) = 1;

% Plot using custom color mapping
gsp_plot_signal(G, max_vals, struct('vertex_color', vertex_colors));
title(sprintf('Wavefront propagation for filter %d', k));
colorbar off;
%% 
s_vals = [0.1, 0.2, 0.3, 0.4, 0.5];  % wave speeds squared
beta = 0.05;  % light damping over 1 second
K = cell(length(s_vals),1);
for i = 1:length(s_vals)
    s = s_vals(i);
    K{i} = @(x,t) (t >= 0) .* exp(-beta * t) .* cos(t .* acos(1 - s * x / 2));
end


psi_graph = gsp_design_mexican_hat(Gtv, length(s_vals));
psi_time = repmat({@(t) 1}, length(s_vals), 1);  % no temporal wavelet
[g, filtertype] = gsp_jtv_design_dgw(Gtv, K, psi_graph, psi_time);
Xf = gsp_jtv_filter_analysis(Gtv, g, filtertype, X);  % X = [2503 x 1000]
