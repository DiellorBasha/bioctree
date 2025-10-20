% Select a subset for speed
vertexSubset = 1:5000;  % Use all vertices if feasible
dataMatrix = S(vertexSubset, 1:5000);
% Original parameters
fs_original = 1200;
fs_target = 300;
downsample_factor = fs_original / fs_target;

% Downsample the data matrix
dataMatrix_downsampled = zeros(size(dataMatrix, 1), ceil(size(dataMatrix, 2) / downsample_factor));

for v = 1:size(dataMatrix, 1)
    dataMatrix_downsampled(v, :) = resample(dataMatrix(v, :), fs_target, fs_original);
end
% Visualize a sample time series
figure;
plot(dataMatrix(1, :));
xlabel('Time (samples)');
ylabel('Amplitude');
title('Sample Vertex Time Series');
%% 
% 2D CWT Parameters
% 2D CWT Parameters (Updated)
scales = 1:16;  % Full range from fast to slow waves
angles = 0:45:315;  % 8 orientations

% Perform 2D CWT
cwtstruct = cwtft2(dataMatrix_downsampled, ...
    'Wavelet', 'morl', ...
    'Scales', scales, ...
    'Angles', angles);

% Inspect the result
% Inspect the structure
disp(cwtstruct);

% Check the size of the coefficients
size(cwtstruct.cfs)
% Flatten the 5D array to 4D
coeffs = reshape(cwtstruct.cfs, [5000, 1250, 16, 8]);
%% 

scaleIdx = 8;   % Mid scale
angleIdx = 1;   % 0 degrees

% Extract a single scale and angle
cfs_slice = abs(coeffs(:, :, scaleIdx, angleIdx));

% Plot
figure;
imagesc(cfs_slice);
xlabel('Time (samples)');
ylabel('Vertices');
title(sprintf('2D CWT Magnitude (Scale %d, Angle %d°)', ...
    cwtstruct.scales(scaleIdx), cwtstruct.angles(angleIdx)));
colormap turbo;

%% 

for v = 1:size(S, 1)
   Sds(v, :) = downsample(S(v, :), 8);
end
% Parameters
fs = 300;  % Sampling frequency
k = 6;     % Morlet parameter
scales = 1:32;  % 32 scales

% Center frequencies (approximate)
frequencies = fs ./ (scales * k);

% Time support (duration of each wavelet)
timeWindows = k ./ frequencies;

% Plot the time support
figure;
plot(scales, timeWindows, 'o-');
xlabel('Scale');
ylabel('Time Window (s)');
title('Time Windows by Scale (Morlet Wavelet)');
grid on;

% Create filter bank
fb = cwtfilterbank('SamplingFrequency', fs, 'VoicesPerOctave', 12, 'FrequencyLimits', [1, fs/2]);

% Get center frequencies
centerFreqs = centerFrequencies(fb);

% Compute time windows
timeWindows_direct = k ./ centerFreqs;

% Plot for comparison
figure;
plot(centerFreqs, timeWindows_direct, 'o-');
xlabel('Frequency (Hz)');
ylabel('Time Window (s)');
title('Direct Time Windows from Wavelet Bank');
grid on;

%% 
% Set number of cycles per window
numCycles = 4;
timeAxis = [];

for scaleIdx = 1:length(scales)
    % Define the time window for this scale
    T_s = timeWindows(scaleIdx);
    t = linspace(0, numCycles * T_s, numCycles * fs * T_s);
    timeAxis = [timeAxis, t];
end

% Plot the hierarchical time axis
figure;
plot(timeAxis, sin(2 * pi * timeAxis));
xlabel('Hierarchical Time');
ylabel('Amplitude');
title('Hierarchical Time Axis from Wavelet Cycles');
grid on;

%% 
% Load or generate test data
fs = 300;  % Sampling frequency
signal = S(1,:);
% Compute CWT
fb = cwtfilterbank('SignalLength', length(signal), 'SamplingFrequency', fs, 'VoicesPerOctave', 12, 'FrequencyLimits', [1, fs/2]);
[cfs, freqs] = cwt(signal, FilterBank=fb);

% Get the power
powerMap = abs(cfs).^2;

%%

% Extract center frequencies
centerFreqs = centerFrequencies(fb);
k = 6;  % Morlet parameter

% Compute time windows for each scale
timeWindows = k ./ centerFreqs;
numCycles = 4;

% Build hierarchical time axis
hierarchicalTime = [];
binEdges = [0];
for i = 1:length(timeWindows)
    T_s = timeWindows(i);
    t = linspace(0, numCycles * T_s, numCycles * fs * T_s);
    hierarchicalTime = [hierarchicalTime, t];
    binEdges = [binEdges, binEdges(end) + length(t)];
end

% Plot the hierarchical time axis
figure;
plot(hierarchicalTime, sin(2 * pi * hierarchicalTime));
xlabel('Hierarchical Time');
ylabel('Amplitude');
title('Hierarchical Time Axis from Wavelet Cycles');
grid on;
%% 

% Initialize the binned matrix
binnedPower = zeros(length(freqs), length(binEdges)-1);

% Bin the power map
currentIndex = 1;
for binIdx = 1:length(binEdges)-1
    % Get the range for this bin
    binStart = binEdges(binIdx) + 1;
    binEnd = binEdges(binIdx+1);
    
    % Average power within this bin
    if binEnd <= size(powerMap, 2)
        binnedPower(:, binIdx) = mean(powerMap(:, binStart:binEnd), 2);
    else
        binnedPower(:, binIdx) = mean(powerMap(:, binStart:end), 2);
    end
end

% Create a new time vector
newTimeAxis = 1:size(binnedPower, 2);

% Plot the rescaled power map
figure;
imagesc(newTimeAxis, freqs, binnedPower);
xlabel('Cycle-Based Time');
ylabel('Frequency (Hz)');
title('Rescaled Time-Frequency Representation');
axis xy;
colormap turbo;
colorbar;
%% 

% Set up figure
figure;
imagesc(powerMap);
axis xy;
xlabel('Time (samples)');
ylabel('Frequency (Hz)');
title('Power Map with Recursive Rectangles');
colormap turbo;
hold on;

% Initialize the quadtree
quadtree = [];

% Set the number of cycles per window
numCycles = 4;
timeStart = 0;

% Iterate over scales
for i = 1:length(timeWindows)
    % Define the rectangle dimensions
    T_s = timeWindows(i);
    freqflip=flip(centerFreqs,1);
    f_s = freqflip(i);
    
    % Horizontal extent (time)
    timeEnd = timeStart + numCycles * T_s * fs;
    
    % Extract key parameters
centerFreqs = centerFrequencies(fb);       % Center frequencies
centerPeriods = centerPeriods(fb);         % Center periods
waveletSupports = waveletsupport(fb);      % Time support
bandwidths = powerbw(fb);                  % 3 dB bandwidths
scales_ = scales(fb);                       % Scales
qfactors = qfactor(fb);                    % Quality factors

%% 
% Create a new figure
figure;
imagesc(abs(cwt(signal, FilterBank=fb)).^2);
axis xy;
xlabel('Time (samples)');
ylabel('Frequency (Hz)');
title('Power Map with Recursive Rectangles');
colormap turbo;
hold on;

% Set number of cycles per window
numCycles = 4;
timeStart = 0;
%% 
% Load or generate test data
fs = 2400;  % Sampling frequency
signal = S(1,:);

clear centerPeriods
% Create the filter bank
fb = cwtfilterbank('SignalLength', length(signal), ...
                   'SamplingFrequency', fs, ...
                   'VoicesPerOctave', 16, ...
                   'FrequencyLimits', [1, 300]);

% Create the filter bank
fb2 = cwtfilterbank('SignalLength', length(signal), ...
                   'SamplingPeriod', seconds(1/fs), ...
                   'VoicesPerOctave', 16, ...
                   'PeriodLimits', [seconds(1/fs/2) seconds(1)]);

    % Extract key parameters
centerFreqs = centerFrequencies(fb);       % Center frequencies
centerPeriods = centerPeriods(fb2);         % Center periods
waveletSupports = waveletsupport(fb);      % Time support
bandwidths = powerbw(fb);                  % 3 dB bandwidths
scales_ = scales(fb);                       % Scales
qfactors = qfactor(fb);                    % Quality factors


% Extract the relevant columns
centerFreqs = bandwidths.Frequencies;
lowFreqs = bandwidths.LowFrequencyBorder;
highFreqs = bandwidths.HighFrequencyBorder;
timeSupports = waveletSupports.TimeSupport;

% Remove NaNs (non-analytic wavelets)
validIdx = ~isnan(timeSupports);
centerFreqs = centerFreqs(validIdx);
lowFreqs = lowFreqs(validIdx);
highFreqs = highFreqs(validIdx);
timeSupports = timeSupports(validIdx);
centerPeriods = centerPeriods(validIdx);


for k=1:10
    signal = S(k,:);
[tfr(k).cfs,freqs]=cwt(signal, FilterBank=fb);
powerMap = abs(tfr(k).cfs).^2;
threshold = 0.05 * max(powerMap(:));  % 20% of max power as edge threshold
tfr(k).edgeMask = powerMap > threshold;
end

cwt(signal, FilterBank=fb);
%% 
k=3
signal = S(k,:);
% Generate a test signal
[cfs,freqs]=cwt(signal, FilterBank=fb);
% Threshold to prune low-energy coefficients
threshold = 0.01 * max(abs(cfs(:)).^2);  % 1% of max power
sparseCoeffs = abs(cfs).^2 > threshold;

% Only keep significant coefficients
cfs(~sparseCoeffs) = 0;

% Reconstruct using only significant coefficients
reconstructed = icwt(cfs);
sparsePowerMap=abs(cfs(:)).^2;
imagesc(1:size(sparsePowerMap,2), centerFreqs, sparsePowerMap);

%% 


% Calculate power map
powerMap = abs(cfs).^2;
zpowerMap=zscore(powerMap);
% Thresholding based on a percentage of maximum power
%threshold = 2;  % 20% of max power as edge threshold
threshold = 0.05 * max(powerMap(:));  % 20% of max power as edge threshold

edgeMask = powerMap > threshold;
% Plot the original signal
figure;
subplot(3,1,1);
plot(signal);
title('Original Signal');
xlabel('Time (samples)');

% Plot the power map
subplot(3,1,2);
imagesc(time, flipud(freqs),flipud(powerMap));
title('Wavelet Power Map');
xlabel('Time (samples)');
ylabel('Frequency (Hz)');
set(gca, 'YDir', 'normal');
colormap jet;
colorbar;

% Plot detected edges
subplot(3,1,3);
imagesc(time, flipud(freqs),flipud(edgeMask));
title('Detected Edges');
xlabel('Time (samples)');
ylabel('Frequency (Hz)');
set(gca, 'YDir', 'normal');
colormap hot;
colorbar;
%% 

% Plot the z-scored power map with contours
figure;
imagesc(powerMap);
hold on;
contour(edgeMask, [0.5 0.5], 'LineColor', 'k', 'LineWidth', 1.5);
hold off;
title('Frequency-Wise Z-Scored Power Map with Contours');
xlabel('Time (samples)');
ylabel('Frequency (Hz)');
set(gca, 'YDir', 'normal');
colormap jet;
colorbar;

%% 
% Apply the edge mask to the original power map
maskedPowerMap = powerMap;
maskedPowerMap(~edgeMask) = 0;

% Plot the masked power map
figure;
imagesc(maskedPowerMap);
title('Masked Power Map (Edges Only)');
xlabel('Time (samples)');
ylabel('Frequency (Hz)');
set(gca, 'YDir', 'normal');
colormap jet;
colorbar;

%% 

% Compute the CWT
powerMap = abs(cwt(signal, FilterBank=fb)).^2;

% Plot the power map
figure;
imagesc(1:size(powerMap,2), centerFreqs, powerMap);
set(gca, 'YScale', 'log');
axis xy;
xlabel('Time (samples)');
ylabel('Frequency (Hz)');
title('Power Map with Center Period Rectangles');
colormap turbo;
hold on;
%% 

% Set number of cycles per window
numCycles = 6;
timeStart = duration(seconds(0));

% Iterate over each scale
for i = 1:4:length(centerFreqs)
    % Horizontal extent (time) using center periods
    P_c = centerPeriods(i);
    T_s = numCycles * P_c * fs;
    
    % Vertical extent (frequency)
    f_low = lowFreqs(i);
    f_high = highFreqs(i);
    
    % Plot the rectangle
    rectangle('Position', [double(seconds(timeStart)), f_low, double(seconds(T_s)), f_high - f_low], ...
              'EdgeColor', 'k', 'LineWidth', 0.5);
    
    % Update the time start for the next rectangle
    timeStart = timeStart + T_s;
end

hold off;
%% 

% Initialize storage for rectangles
rectangles = [];
timeStart = duration(seconds(0));
numCycles = 4;

% Iterate over each scale
for i = 1:length(centerFreqs)
    % Horizontal extent (time) using center periods
    P_c = centerPeriods(i);
    T_s = numCycles * P_c * fs;
    
    % Vertical extent (frequency)
    f_low = lowFreqs(i);
    f_high = highFreqs(i);
    
    % Create a rectangle that spans the entire available time range
    rect = [double(seconds(timeStart)), f_low, double(seconds(T_s)), f_high - f_low];
    rectangles = [rectangles; rect];
    
    % Plot the rectangle
    rectangle('Position', rect, 'EdgeColor', 'k', 'LineWidth', 0.5);
    
    % Update the time start for the next rectangle
    timeStart = timeStart + T_s;
end

%% 

% Initialize hierarchical levels
levels = cell(4, 1);
levels{1} = rectangles;

% Subdivide each level
for lvl = 2:4
    parentRects = levels{lvl - 1};
    childRects = [];
    
    for j = 1:size(parentRects, 1)
        % Get parent rectangle
        parent = parentRects(j, :);
        timeStart = parent(1);
        timeWidth = parent(3);
        freqStart = parent(2);
        freqWidth = parent(4);
        
        % Subdivide into 4 quadrants if aspect ratio is reasonable
        if timeWidth > 1 && freqWidth > 0.1
            t_half = timeWidth / 2;
            f_half = freqWidth / 2;
            
            % Create 4 child rectangles
            childRects = [childRects;
                          timeStart, freqStart, t_half, f_half;
                          timeStart + t_half, freqStart, t_half, f_half;
                          timeStart, freqStart + f_half, t_half, f_half;
                          timeStart + t_half, freqStart + f_half, t_half, f_half];
        end
    end
    
    % Store the child rectangles
    levels{lvl} = childRects;
    
    % Plot the child rectangles
    for k = 1:size(childRects, 1)
        rect = childRects(k, :);
        rectangle('Position', rect, 'EdgeColor', 'r', 'LineWidth', 0.5);
    end
end

hold off;

%% 


% Extract the widest and tallest rectangle properties
[~, idx_tallest] = max(highFreqs - lowFreqs);
[~, idx_widest] = max(centerPeriods);

% Use the height of the tallest and width of the widest
tallest_height = highFreqs(idx_tallest) - lowFreqs(idx_tallest);
widest_width = centerPeriods(idx_widest) * fs * 4;
widest_width=double(seconds(widest_width));
% Determine the overall time and frequency ranges
[cfs,freq]=cwt(signal, FilterBank=fb);
total_time = size(cfs,2);
total_freq =size(cfs,1);

% Calculate the number of tiles needed
num_tiles_x = ceil(total_time / widest_width);
num_tiles_y = ceil(total_freq / tallest_height);
%% 

% Create the figure
% Create a new figure
figure;
imagesc(abs(cwt(signal, FilterBank=fb)).^2);
axis xy;
xlabel('Time (samples)');
ylabel('Frequency (Hz)');
title('Power Map with Recursive Rectangles');
colormap turbo;
hold on;


% Generate the base tiles
rectangles = [];
time_start = 0;
freq_start = min(lowFreqs);

for i = 1:num_tiles_x
    for j = 1:num_tiles_y
        % Define the base rectangle
        rect = [time_start, freq_start, widest_width, tallest_height];
        rectangles = [rectangles; rect];
        
        % Plot the rectangle
        rectangle('Position', rect, 'EdgeColor', 'k', 'LineWidth', 0.5);
        
        % Update the frequency start
        freq_start = freq_start + tallest_height;
    end
    
    % Reset frequency and update time
    freq_start = min(lowFreqs);
    time_start = time_start + widest_width;
end
%% 

% Initialize hierarchical levels
levels = cell(4, 1);
levels{1} = rectangles;

% Subdivide each level
for lvl = 2:4
    parentRects = levels{lvl - 1};
    childRects = [];
    
    for j = 1:size(parentRects, 1)
        % Get parent rectangle
        parent = parentRects(j, :);
        time_start = parent(1);
        time_width = parent(3);
        freq_start = parent(2);
        freq_height = parent(4);
        
        % Subdivide into 4 quadrants
        t_half = time_width / 2;
        f_half = freq_height / 2;
        
        % Create 4 child rectangles
        childRects = [childRects;
                      time_start, freq_start, t_half, f_half;
                      time_start + t_half, freq_start, t_half, f_half;
                      time_start, freq_start + f_half, t_half, f_half;
                      time_start + t_half, freq_start + f_half, t_half, f_half];
    end
    
    % Store the child rectangles
    levels{lvl} = childRects;
    
    % Plot the child rectangles
    for k = 1:size(childRects, 1)
        rect = childRects(k, :);
        rectangle('Position', rect, 'EdgeColor', 'r', 'LineWidth', 0.5);
    end
end

hold off;
%% 

