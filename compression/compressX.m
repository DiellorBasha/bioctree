addpath(genpath(pwd));
gsp_start
data=getData(2);
anats=loadanatg();
Atlas=anats(1).bst.Atlas;
 G=anats(1).G;
[X, Gtv] = generate_synthetic_multiband(G, 1000, 200, Atlas);
 F=data.datafile.F(data.result.GoodChannel, :);
%% 
% Wavelet filter setup
wname = 'db4';
maxLevel = 5;

X_wavelet = zeros(size(X));  % compressed time series placeholder
for i = 1:size(X, 1)
    [C, L] = wavedec(X(i, :), maxLevel, wname);
    
    % Thresholding (e.g., hard threshold to remove small coefficients)
    thr = wthrmngr('dw1ddenoLVL','penalhi',C,L);
    C_thresh = wthresh(C, 'h', thr);
    
    % Reconstruct compressed signal
    X_wavelet(i, :) = waverec(C_thresh, L, wname);
end
mra = modwtmra(modwt(Xex,8));
helperMRAPlot(x,mra,t,"wavelet","Wavelet MRA",[2 3 4 9])
%% Synchrosqueezing
fs=2400;
Fex=zscore(F(220,:));

Fex=(downsample(F',24))';
fs=fs/24;
N=size(Fex,1);
T=size(Fex,2);
t=(1:T)/fs;

sstv=zeros(2*fs-1,T,N);
[sst,f, fbparam] = wsst(Fchan,fs);
for k=1:size(F,1)
 Fchan=zscore(Fex(k,:));
  [sst,f] = wsst(Fchan,fs);
  sstv(:,:,k)=sst;
end

%% 
bands = {
    'delta', [1 4];
    'theta', [4 8];
    'alpha', [8 12];
    'beta',  [13 30];
    'gamma', [30 80];
};


N = size(sstv, 3);  % number of channels
T = size(sstv, 2);  % number of time points
nbands = size(bands, 1);
% Preallocate output: cell array of ridge frequency maps per band/channel
bandRidges = cell(nbands, N);

for k = 1:N
    tfm = abs(sstv(:,:,k));  % power spectrogram for this channel

    for b = 1:nbands
        bandName = bands{b,1};
        fRange = bands{b,2};

        % Get indices in frequency axis
        bandIdx = find(f >= fRange(1) & f <= fRange(2));
        tf_band = tfm(bandIdx, :);
        f_band = f(bandIdx);

        % Ridge extraction
        [fridge, iridge] = tfridge(tf_band, f_band, 0, 'NumRidges', 1);

        % % Optional: clean ridge (e.g., jump suppression)
        % jump_thresh = 4;  % bins or Hz
        % for r = 1:size(iridge, 2)
        %     jumps = [false; abs(diff(iridge(:,r))) > jump_thresh];
        %     fridge(jumps, r) = NaN;
        % end

        % Store
        bandRidges{b, k} = fridge;  % or iridge if you want indices
    end
end
%% 
 Fchan=zscore(Fex(k,:));
 
%% 
channel_to_plot = 12;
tfm = abs(sstv(:,:,channel_to_plot));


figure(1)
clf
% hfig=pcolor(t,f,tfm);
cwt(Fex(channel_to_plot,:),fs)
%hfig.LineStyle='none';title(['Ridges for channel ' num2str(channel_to_plot)]);
hold on
colors = lines(nbands);
for b = 1:nbands
    ridge = bandRidges{b, channel_to_plot};
    for r = 1:size(ridge,2)
        valid = ~isnan(ridge(:,r));
        plot(t(valid), ridge(valid,r), 'Color', colors(b,:), 'LineWidth', 1.5);
    end
end
legend(bands(:,1));
%% 

tfm = abs(sstv(:,:,k));  % or use abs.^2 or dB
[fridge, iridge, lridge] = tfridge(tfm, f, 0, 'NumRidges', 3);
% Parameters
jump_thresh = 10;  % max allowed index jump (can be 1–3 for fine ridges)

% Loop through ridges
for r = 1:size(iridge, 2)
    freq_idx = iridge(:, r);               % frequency indices
    freq_diff = abs(diff(freq_idx));       % jump between consecutive bins
    jump_mask = [false; freq_diff < jump_thresh];  % flag jump points

    % Set jumps to NaN in iridge and fridge
    iridge(~jump_mask, r) = NaN;
    fridge(~jump_mask, r) = NaN;
end
% Extract ridge energy values
ridge_vals = tfm(lridge);  % Linear indexing
figure(1)
clf
hfig=pcolor(t,f,tfm);
hfig.LineStyle='none';
shading interp
hold on
plot(t,fridge(:,1), 'k', 'LineWidth',2)
hold off

%% 


for k=1:size(F,1)
[fridge(:,:,k), iridge, lridge] = tfridge(sstv(:,:,k),f, 1, 'NumRidges',6);

end







yticks = linspace(1, length(f), 6);  % 6 evenly spaced ticks
yticklabels = round(linspace(f(end), f(1), 6));  % Flip label order to match
set(gca, 'YTick', yticks, 'YTickLabel', yticklabels);

[fridge, iridge, lridge] = tfridge(chanMean,f, 1, 'NumRidges',3);
median(iridge)

fridge(fridge~=median(f(iridge)),1)=nan;
figure(1)
clf
wsst(Fex,fs);
hold on
plot(t,fridge, 'r', 'LineWidth',2)
hold off

mask=signalMask(fridge(1,:), 'SampleRate', fs);
q = findchangepts(fridge(:,1),"Statistic","rms");
%%

opts = scalarFeatureOptions("timefrequency", ...
    WaveletEntropy=["Mean" "StandardDeviation"], ...
    TfRidges = ["Mean"]);
tfFE = signalTimeFrequencyFeatureExtractor( ...
    SampleRate=fs, ...
    Transform="synchrosqueezedscalogram", ...
    SpectralCrest=true, ...
    SpectralEntropy=true, ...
    InstantaneousFrequency=true, ...
    InstantaneousBandwidth=true, ...
    WaveletEntropy=true, ...,
    TFRidges=true, ...
    ScalarizationMethod=opts);
setExtractorParameters(tfFE,"InstantaneousBandwidth",FrequencyLimits=[8 12])

tfFE = signalTimeFrequencyFeatureExtractor( ...
    SampleRate=fs, ...
    Transform="emd", ...
    InstantaneousEnergy=true,...
    InstantaneousFrequency=true);

[features,info] = extract(tfFE,Fex);
ridges=features(info.TFRidges);

%%
wsst(Fex,fs);
hold on
 plot(t,features(info.InstantaneousBandwidth), 'r')
%% 

[mra,cfs,wfb,info] = emd(Xex);
hht(mra,2400)
%% 
[dh1,h1,cp1,tauq1] = dwtleader(Xex);
[dh2,h2,cp2,tauq2] = dwtleader(Ts2);
figure
hp = plot(h1,dh1,"b-o",h2,dh2,"b-^");
hp(1).MarkerFaceColor = "b";
hp(2).MarkerFaceColor = "r";
grid on
xlabel("h")
ylabel("D(h)")
legend("Ts1","Ts2",Location="NorthEast")
title("Multifractal Spectrum")

%% 

figure(1)
tiledlayout(4,1)
nexttile
plot(t, Xex)
nexttile
plot(t,mra(:,1))
nexttile
plot(t,mra(:,5))
nexttile
plot(t,mra(:,4))