addpath(genpath(pwd))
result=load('results_dSPM-unscaled_MEG_KERNEL_210314_2210.mat');
datafile=load('data_block002.mat');
chanfile=load("channel_ctf_acc1.mat");
chanflag=load("chan_flags_v1.mat");
anat=load('Subject_068_anat\tess_cortex_pial_low.mat');
megInd = find(strcmp({chanfile.Channel.Type}, 'MEG'));
flagInd = find(datafile.ChannelFlag==1);
chans=intersect(megInd, flagInd);
fs=2400;
IK= result.ImagingKernel;
F=datafile.F;
F=F(chans,:);

sourceTS = IK * F;
time = datafile.Time;

for k = 2:2:10
hold on
plot(time,sourceTS(k,:));
end


%% Compute Wavelet Transform
fs = 2400;                      % Sampling frequency (Hz)
frequencies = linspace(1,100,30); % Frequency range
nTimeBlocks = 8;                % Initial time subdivision
nFreqBlocks = 8;                % Initial frequency subdivision
threshold = 0.01;               % Threshold for complexity
vertexID = 1;                   % Vertex to process for demo

signal = sourceTS(vertexID, :);
fb = cwtfilterbank('SignalLength', length(signal), ...
                   'VoicesPerOctave', 12, ...
                   'SamplingFrequency', fs, ...
                   'FrequencyLimits', [1 100]);

[cfs, f] = wt(fb, signal);      % Complex wavelet transform
powerMap = abs(cfs).^2;         % Power at each freq × time
time = (0:length(signal)-1)/fs; % Time vector

%% 
nCycles = 6;  % Number of cycles per wavelet

windowLengths = nCycles ./ f;            % In seconds
sampleWindows = round(windowLengths * fs);  % In samples

adaptiveBlocks = struct;
for fi = 1:length(f)
    sw = sampleWindows(fi);  % Time window size in samples
    step = round(sw/2);      % Use 50% overlap

    tIdx = 1:step:(length(signal) - sw + 1);
    numWindows = length(tIdx);
    
    for ti = 1:numWindows
        tRange = tIdx(ti):(tIdx(ti)+sw-1);
        if max(tRange) > length(time), continue; end

        blockPower = powerMap(fi, tRange);
        value = std(blockPower(:));  % Complexity measure

        adaptiveBlocks(fi, ti).fIndex = fi;
        adaptiveBlocks(fi, ti).tIndex = tRange;
        adaptiveBlocks(fi, ti).value = value;
        adaptiveBlocks(fi, ti).timeRange = [time(min(tRange)), time(max(tRange))];
        adaptiveBlocks(fi, ti).frequency = f(fi);
    end
end
%% 
threshold = 0.01;
keepBlocks = [];

for fi = 1:length(f)
    for ti = 1:size(adaptiveBlocks, 2)
        block = adaptiveBlocks(fi, ti);

        if isfield(block, 'value') && ~isempty(block.value)
            if block.value > threshold
                keepBlocks = [keepBlocks; block];
            end
        end
    end
end

%% 
imagesc(time, f, powerMap); axis xy;
xlabel('Time (s)'); ylabel('Frequency (Hz)');
title('Wavelet Power + Adaptive Subdivision'); colormap turbo; colorbar;
hold on;

for k = 1:length(keepBlocks)
    rect = keepBlocks(k);
    t1 = rect.timeRange(1);
    t2 = rect.timeRange(2);
    f1 = rect.frequency;

    % Estimate frequency window height based on spacing
    if rect.fIndex < length(f)
        f2 = f(rect.fIndex + 1);
    else
        f2 = f(rect.fIndex);
    end

    fMin = min([f1, f2]);
    fMax = max([f1, f2]);
    rectangle('Position', [t1, fMin, t2-t1, fMax-fMin], ...
              'EdgeColor', 'r', 'LineWidth', 1.2);
end
hold off;

