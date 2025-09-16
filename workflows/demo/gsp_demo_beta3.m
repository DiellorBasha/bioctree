data=getData(2);
for k =1:10
  blocks(k).data=getData(k);
end
anats=loadanatg();
Atlas=anats(1).bst.Atlas;
 G=anats(1).G;
 fs=200;
 segment=5; 
 N=round(segment*fs);
[X, Gtv] = generate_synthetic_multiband(G, N,fs, Atlas);

fs=2400;
Fch=F(data.result.GoodChannel, :);

freqrange=[1 60];
fs=2400;
noverlap=[];
%% 
[C,T]=size(Fch);
fs = 2400;
winlen=round(1*fs);
%% 
Gtv=gsp_jtv_graph(G, T, fs);
%% 
winlen=round(4*fs);

nff = max(256,2^nextpow2(winlen));
Gtv.jtv.NFFT=nff;

%% 
Xhat=gsp_jft(Gtv,X(:, 1:winlen));
%% 
[f, label] = gsp_jtv_fa(Gtv,0)
%% 

imagesc(fftshift(abs(Xhat),2));
ylabel('lambda')
xlabel('omega')
xlim([0 60])

%%
plot(mean(fftshift(abs(Xhat), 1)))
xlim([0 60])
%% 

for k = 1:C   
xds(k,:)=resample(Fch(k,:), newFs, fs);
end
%% 

winlen=round(4*newFs);
[pxx, f]=pwelch(xds',winlen,noverlap,[],newFs, 'onesided');
plot(f,pxx)
xlim([0 60]);
%% 

X = data.IK * Fch;

%% Get left hemisphere
fs=200
[Idx, Gz, bl] = gsp_components(G);
LG =Gz{1};
LG = gsp_estimate_lmax(LG);
LX=X(Idx==1,:);
LT=size(LX,2);
LGtv=gsp_jtv_graph(LG, LT, fs);
param.cp=[0,0.5,0]
param.cp=[0,0.5,0.5]
gsp_plot_jtv_signal(LGtv,LX, param)
%% 
s=hilbert(LX);
sphase=angle(s);
samp=abs(s);
 LG = gsp_adj2vec(LG);
 LD = gsp_grad_mat(LG);
lgr = gsp_grad(LG,sphase);
lamp =gsp_grad(LG, samp);
%% Detect beta burst
% in time
fb = cwtfilterbank('Wavelet', 'amor', ...
                     'SignalLength', LT,...
                   'VoicesPerOctave', 12, ...
                   'SamplingFrequency', fs, ...
                   'FrequencyLimits', [8 12]);

LXW=zeros(size(LX));LXWP=zeros(size(LX));
LXWM=zeros(size(LX));
for k = 1:size(LX, 1)
cfs=cwt(LX(k,:), 'FilterBank', fb);
phases = angle(cfs);
phase=mean(phases,1);
amps = abs(cfs);
amp = mean(amps, 1);
LXWP(k,:) = phase;
LXWM(k,:) = amp;
end
meanamp=mean(LXWM,1);
threshold = mean(meanamp)+1*std(meanamp);

sparseLXWM=LXWM(:,meanamp>threshold);

alphasig=mean(abs(cfs), 1); 
%% 
S=LX;
Nf=6;
Wk = gsp_design_mexican_hat(LG, Nf);
%sf = gsp_vec2mat(gsp_filter_analysis(LG,Wk,sparseLXWM),Nf);

Sf_vec = gsp_filter_analysis(LG, Wk, S);
Sf = gsp_vec2mat(Sf_vec, length(Wk));
f2 = gsp_filter_synthesis(LG,Wk,Sf);
%% 
sf2=sf;
sf1=mean(squeeze(sf(:,2,:)),2);
threshold = mean(sf1(:))+3*std(sf1(:));
sparseSf=zeros(size(sf));
sparseSf(sf>threshold)=sf(sf>threshold);
sf=sparseSf;

mu = mean(sf(:));
sigma = std(sf(:));
c_scale = 4;

subplot(221)
gsp_plot_signal(LG,mean(squeeze(sf(:,1,:)),2));
axis square
caxis([mu - c_scale*sigma, mu + c_scale*sigma]);

subplot(222)
gsp_plot_signal(LG,mean(squeeze(sf(:,2,:)),2));
axis square
caxis([mu - c_scale*sigma, mu + c_scale*sigma]);

subplot(223)
gsp_plot_signal(LG,mean(squeeze(sf(:,4,:)),2));
axis square
caxis([mu - c_scale*sigma, mu + c_scale*sigma]);

subplot(224)
gsp_plot_signal(LG,mean(squeeze(sf(:,6,:)),2));
axis square
caxis([mu - c_scale*sigma, mu + c_scale*sigma]);


%% 
param.cp=[0, 0.5, 0.5];
gsp_plot_jtv_signal(LG,sf1, param)

%% 
% Parameters
center_freqs = [8, 10, 12, 14];  % Hz
sigma = 0.1;                     % Width of Gaussian in seconds
G = gsp_estimate_lmax(G);
% Design GRAPH wavelets (e.g., Mexican Hat)
Nf_graph = round(G.lmax);     % graph wavelet resolution
Gtv=gsp_estimate_lmax(Gtv);
psi_graph = gsp_design_mexican_hat(Gtv, Nf_graph);  % filterbank along graph

% Design TIME wavelets (Morlet-like in frequency domain)
omega = Gtv.jtv.omega;        % frequency vector in Hz
psi_time = cell(1, length(center_freqs));
for j = 1:length(center_freqs)
    psi_time{j} =  exp(-0.5 * ((omega - center_freqs(j)) / sigma).^2);
end


% Combine into joint filterbank
[K, filterType] = gsp_jtv_design_dgw(Gtv, Nf_graph, psi_graph, psi_time);
K=K(1:56);


%% % Define time vector
% Plot frequency responses
figure;
for j = 1:length(psi_time)
    plot(Gtv.jtv.omega, psi_time{j}, 'DisplayName', ...
         ['Center: ' num2str(center_freqs(j)) ' Hz']);
    hold on;
end
xlabel('Frequency (Hz)'), ylabel('Amplitude')
title('psi\_time Frequency Responses')
legend, grid on


%% 
omega = Gtv.jtv.omega;  % Frequency vector from the time-vertex graph
figure;
for j = 1:length(psi_time)
    psi_eval = psi_time{j}(omega);  % Evaluate function handle
    plot(omega, psi_eval, 'DisplayName', ...
        ['Center: ' num2str(center_freqs(j)) ' Hz']);
    hold on;
end
xlabel('Frequency (Hz)'), ylabel('Amplitude')
title('psi\_time Frequency Responses')
legend, grid on

%% 
% Inverse FFT to get time-domain wavelets
psi_time_td = cell(size(psi_time));
N = length(Gtv.jtv.omega);  % typically T

fs = 1000;                      % Sampling frequency in Hz
duration = 1;                   % Total duration in seconds
t = linspace(-duration/2, duration/2, fs*duration);  % Centered time axis



% Generate and plot
figure;
for j = 1:length(center_freqs)
    f0 = center_freqs(j);
    morlet = exp(1i*2*pi*f0*t) .* exp(-t.^2/(2*sigma^2));
    
    subplot(length(center_freqs),2,2*j-1)
    plot(t, real(morlet), 'b'); hold on;
    plot(t, imag(morlet), 'r--');
    title(['Real (blue) / Imag (red) of Morlet f_0 = ' num2str(f0) ' Hz'])
    xlabel('Time (s)'), ylabel('Amplitude'), grid on
    
    subplot(length(center_freqs),2,2*j)
    plot(t, abs(morlet), 'k');
    title(['Envelope of Morlet f_0 = ' num2str(f0) ' Hz'])
    xlabel('Time (s)'), ylabel('Amplitude'), grid on
end


%% 

% Evaluate filters into usable form
[h, filterType] = gsp_jtv_filter_array(Gtv, K, filterType);
%% 

% Apply joint wavelet transform

Xvec = X(:);            % vectorize for joint analysis
Y = gsp_jtv_filter_analysis(Gtv, h, Xvec);

% Reshape output: Y is [N*T x numFilters]
Y_reshaped = reshape(Y, [N, T, length(h)]);

% Optional: Plot the energy over time and space for a filter
filter_index = 2;
imagesc(Y_reshaped(:, :, filter_index));  % spatial x time
xlabel('Time (samples)'), ylabel('Vertex index')
title(['Joint Wavelet Coefficients for filter ' num2str(filter_index)])
colorbar

fs = 200
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

%% Extract wavelet information
freqs = fb.centerFrequencies;            % [68 x 1] center freqs
freqResponses = fb.freqz;                % [68 x T] complex frequency responses
freqResponses = freqResponses(:, 2:end); % Remove DC component (1st column)

%% Get omega from GSP joint time-vertex graph
omega = Gtv.jtv.omega;   % [1 x T] angular frequency in rad/s (can be pos + neg)

%% Convert frequency axis used in freqResponses to match omega
% freqResponses is over [0, fs/2], so define matching freq_axis in Hz
freq_axis = linspace(0, fs/2, size(freqResponses, 2));    % [1 x T/2-1] in Hz
omega_support = 2 * pi * freq_axis;       

%% Pad responses symmetrically to match full omega (neg + pos)
n_wavelets = size(freqResponses, 1);
n_omega = length(omega);
psi_time = cell(n_wavelets, 1);
% Find indices of non-negative omega values
pos_idx = find(omega >= 0);

for j = 1:n_wavelets
    % Create zero-padded response
    psi_full = zeros(1, n_omega);

    % Fill positive side (zero and up)
    response = abs(freqResponses(j, :));  % Use magnitude (optional: keep complex)
    n_pos_vals = min(length(pos_idx), length(response));
    psi_full(pos_idx(1:n_pos_vals)) = response(1:n_pos_vals);

    % Store in psi_time
    psi_time{j} = psi_full;
end


%% 
%% Assume you have a graph G already created

% Define log-spaced wavelet scales
Nf = round(G.lmax);
Nf=6
% 4. Call the function with:
psi_graph = gsp_design_mexican_hat(G, Nf);

figure;
gsp_plot_filter(G,psi_graph);
param_filter.filter = psi_graph;
Wkw = gsp_design_warped_translates(G,Nf,param_filter);

figure;
gsp_plot_filter(G,Wkw);

