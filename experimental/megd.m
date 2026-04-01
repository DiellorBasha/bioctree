block(1).data=load("Z:\PADJG_GSP\data\sub-MTL0010\PADMTL0010PREMG00_spontaneous_20180712_01_notch_high\data_block001.mat");
block(2).data=load("Z:\PADJG_GSP\data\sub-MTL0010\PADMTL0010PREMG00_spontaneous_20180712_01_notch_high\data_block002.mat");
block(3).data=load("Z:\PADJG_GSP\data\sub-MTL0010\PADMTL0010PREMG00_spontaneous_20180712_01_notch_high\data_block002.mat");
block(4).data=load("Z:\PADJG_GSP\data\sub-MTL0010\PADMTL0010PREMG00_spontaneous_20180712_01_notch_high\data_block002.mat");
block(5).data=load("Z:\PADJG_GSP\data\sub-MTL0010\PADMTL0010PREMG00_spontaneous_20180712_01_notch_high\data_block002.mat");

block(1).data
recs=[block(1).data.F ,block(2).data.F,block(3).data.F,block(4).data.F,block(5).data.F ];
for k = 1:size(recs,1)
recsds(k,:)=zscore(downsample(recs(k,:), 4), 0, 2);
end
%%
figure(1)
cla
clf
for k=105:225
    hold on
plot(tVec, recsds(k,:)+2*k, 'w')
hold off
end

%%
zscrec=zscore(recs,0,2);
cla
clf
for k=85:105
    hold on
plot(zscore(recs (k,:)+2*k), 'w')
hold off
end

%%

block(67).data=load("Z:\PADJG_GSP\data\sub-MTL0005\PADMTL0005NAPMG00_spontaneous_20170714_01_notch_high\data_block067.mat");
block(68).data=load("Z:\PADJG_GSP\data\sub-MTL0005\PADMTL0005NAPMG00_spontaneous_20170714_01_notch_high\data_block068.mat");
block(69).data=load("Z:\PADJG_GSP\data\sub-MTL0005\PADMTL0005NAPMG00_spontaneous_20170714_01_notch_high\data_block069.mat");
recs=[block(67).data.F ,block(68).data.F,block(69).data.F ];

%% 

zscrec=zscore(recs,0,2);
cla
for k=200:250
    hold on
plot(zscrec(k,:)+2*k, 'k')
hold off
end


%%

om = load("C:\Users\diell\OneDrive - McGill University\Workspace\Library\Datasets\temp-preliminary-omega\preliminary_omega_sub0002.mat")

tVec=om.raw100.Time;
fs = round(1./diff(tVec(1:2)));
recs=om.raw100.F;
dsFactor=4;
for k = 1:size(recs,1)
recsds(k,:)=zscore(downsample(recs(k,:), 4), 0, 2);
end
tVec=downsample(tVec, 4);
N=numel(tVec);
fs=round(fs/4);
%%
% figure(1)
cla
clf

startChan=105;
endChan = 225;

for k=startChan:endChan
    hold on
ypos = k-startChan;
thisSig = recsds(k,:);
plot(tVec, thisSig+2*ypos, 'w')
hold off
end
xlabel ('Time(s)')
ylabel ('Channel (zscore)');
ylim([-10 , 2*ypos + 10 ])
%% 

% figure(1)
cla
clf

startChan=220;
endChan = 221;

for k=startChan:endChan
hold on
ypos = 3*(k-startChan);
thisSig = recsds(k,:);
plot(tVec, thisSig+ypos, 'w')
hold off
end
xlabel ('Time(s)')
ylabel ('Channel (zscore)');
ylim([-10 , ypos + 10 ])
xlim([30, 40])

  %% Select a signal
freqLimits = [0, 60];
k=startChan
x1 = recsds(k,:);
        
        opts.VoicesPerOctave=12;

    % ---- Build filterbank ----
    fbArgs = {'SignalLength', N, ...
              'SamplingFrequency', fs, ...
              'FrequencyLimits', freqLimits, ...
              'VoicesPerOctave', opts.VoicesPerOctave};
    fb = cwtfilterbank(fbArgs{:});

figure (2)
[wt,f] = cwt(x1,FilterBank=fb);
freqRange=[min(f), max(f)];
xrec=icwt(wt, [], f,freqRange);
figure(1)
plot (tVec, xrec, 'w')
xlim([30, 45])

%% "bandpass 

tavg=timeSpectrum(fb,x1,'SpectrumType','density', ...
    'Normalization','pdf');

ax=plot(f,tavg, 'LineWidth', 2)
a=gca;a.TickDir="out"; a.TickLength=[0.01, 0.05];
a.Box="off";
a.FontSize=14;


%%

timeRange=[30 40]
bands = [0   1   2;   % sub-delta
         1   4   4;   % delta
         5   8   4;   % theta
         8  11   4;   % alpha
        20  30   6];  % beta — higher order for steeper skirts

fig = plot_fourier_superposition(x1, fs, timeRange, bands, ...
    'chanIdx',    220, ...
    'bandLabels', {'Sub-delta','Delta','Theta','Alpha','Beta'}, ...
    'exportPath', 'C:\Users\diell\workspace\library\datasets\illustrations\fourier_superposition2.png', ...
    'exportDPI',  200, ...
    'figTitle',   'A signal is a sum of sinusoids');