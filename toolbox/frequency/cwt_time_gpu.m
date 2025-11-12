
bstdb="C:\CodingProjects\bioctree\test-data\omega-tutorial\" ;
sub="0002";
dblock = "001";
filePath = fullfile(bstdb, sprintf('sub-%s', sub), 'sensor', sprintf('data_block%s.mat', dblock));
data=load(filePath);
time=data.Time;
fs=round(1/diff(time(1:2)));
sigs=data.F;
[nChans, nSamples]=size(data.F);

fb = cwtfilterbank(SignalLength=nSamples,SamplingFrequency=fs, FrequencyLimits=[0 60], ...
    VoicesPerOctave=12);
%% 

ch=100;
freqz(fb)
x=data.F(ch,:);
figure (1)
subplot(211)
plot(time, x);
xlabel('Time (s)');
ylabel('Signal Amplitude');
title(sprintf('Channel %d Signal', ch));
%%

tfFE = signalTimeFrequencyFeatureExtractor(...
    SampleRate=fs, ...
    InstantaneousBandwidth=true, ...
    InstantaneousEnergy=true, ...
    InstantaneousFrequency=true, ...
    TimeSpectrum=true, ScaleSpectrum=true);

features = extract(tfFE,x);
subplot(211)
plot(time, x)
subplot(212)
featuresRows = reshape(features,[],2);
stackedplot(featuresRows,"*",...
    DisplayLabels=["Spectral Kurtosis" "Instantaneous Frequency"])
grid on
%% 

% Choose a framed transform
transform = "spectrogram";   % or "scalogram", "synchrosqueezedspectrogram", ...

% Framing params are allowed here
FrameSize          = round(0.25*fs);
FrameOverlapLength = round(0.90*FrameSize);

opts = timeFrequencyScalarFeatureOptions;
opts.InstantaneousFrequency = "Mean";
opts.InstantaneousBandwidth = "Mean";
opts.InstantaneousEnergy    = "Energy";
opts.SpectralKurtosis       = "Mean";
opts.ScaleSpectrum = "Mean";
opts.TFRidges = "Mean";
opts.TimeSpectrum = "Mean";
tfFE = signalTimeFrequencyFeatureExtractor( ...
    SampleRate = fs, ...
    Transform  = transform, ...
    FrameSize  = FrameSize, ...
    FrameOverlapLength = FrameOverlapLength, ...
    InstantaneousFrequency = true, ...
    InstantaneousBandwidth = true, ...
    SpectralKurtosis       = true, ...
    ScaleSpectrum = true, ...
    TimeSpectrum= true, ...
    TFRidges= true, ...
    ScalarizationMethod    = opts, ...
    FeatureFormat          = "table");

featuresTbl = extract(tfFE, x(:));  % has Time = frame centers
             % now has scalar columns
% Assume: featuresTbl has FrameStartTime, FrameEndTime, and scalar columns like ...Mean
% fs = your sampling rate (Hz)

% 1) Compute frame-center timestamps (seconds)
tCenters = (featuresTbl.FrameStartTime + featuresTbl.FrameEndTime) ./ (2*fs);  % 1×N in seconds
featuresTbl.Time = seconds(tCenters(:));  % add a Time column as duration

% 2) Keep only scalar (per-frame) features for plotting
allNames  = string(featuresTbl.Properties.VariableNames);
isScalar  = endsWith(allNames, "Mean");                  % e.g., SpectralKurtosisMean, InstantaneousFrequencyMean, ...
keepNames = ["Time", allNames(isScalar)];                % include Time
featuresTblPlot = featuresTbl(:, cellstr(keepNames));

% 3) Convert to timetable using Time as row times
TT = table2timetable(featuresTblPlot, 'RowTimes', 'Time');

% Choose which variables to plot
vars = ["ScaleSpectrum", "TimeSpectrum", "TFRidges"];
vars = vars(ismember(vars, string(TT.Properties.VariableNames)));

t = seconds(TT.Time);
n = numel(vars) + 1;

figure(2); clf
tiledlayout(n,1,'TileSpacing','compact','Padding','compact')

% Top: raw
ax(1) = nexttile;
plot((0:numel(x)-1)/fs, x, 'LineWidth',1); grid on
xlabel('Time (s)'); ylabel('Signal'); title(sprintf('Channel %d', ch))

% Stacked feature axes
for k = 1:numel(vars)
    ax(k+1) = nexttile;
    plot(t, TT.(vars(k)), 'LineWidth',1); grid on
    ylabel(strrep(vars(k),'_',' '));
end
xlabel('Time (s)');

% Link all x-axes (zoom/pan sync)
linkaxes(ax,'x');
