%% Alpha burst window detection (GLOBAL window across all MEG channels)
% Assumes you already have:
%   raw100, chans
% Produces:
%   winIdx         -> 1×N logical or index vector for the selected window
%   winStartIdx    -> scalar sample index
%   winEndIdx      -> scalar sample index
%   winStart_s     -> seconds
%   winEnd_s       -> seconds
%   sigsWin        -> nChans×nWinSamples segment for propagation analysis

%% --------------------------

%%
protocolPath="Z:\brainstorm_protocols\TutorialOmega2"
% Surfaces + relative PSD timefreqs
db = loadBrainstorm(protocolPath, ...
    TimefreqPattern=struct('file',"timefreq",'comment',"relative"), ...
    ResultPattern=struct('file',"results_",'comment',""), ...
   LoadSourceMapping=true );
bands.delta=[2 4];
bands.theta=[5 7];
bands.alpha = [8 12];
bands.beta = [15 30];
bands.gamma1=[30 59];
bands.gamma2=[60 90];



%%
sm = db.subjects(1).sourceMapping;
% Resample from 2400 Hz to 600 Hz, return as datastore:
[sds, K, t, fs, chanNames] = readSourceSegment(sm, 0, 300, ...
    AsDatastore=true, Resample=600);
% sfreq is 600, t and F_sensor reflect the new sample count
sm.Reg.Sphere.Vertices ;   % [10244 × 3] — FreeSurfer sphere registration
sm.Atlas;                   % [1×7 struct] — includes 'Structures' for hemi split
sm.surfaceVertices ;        % [10244 × 3] — subject cortex vertices
sm.surfaceFaces   ;         % [20465 × 3] — subject cortex faces

% Also persisted in provenance after writeSourceDatastore:
meta = load(fullfile(outPath, "provenance.mat"));
meta.provenance.Reg.Sphere.Vertices  % available without Brainstorm

%%
analysisRoot ="Z:\brainstorm_protocols_analysis";
outputRoot = fullfile(analysisRoot, "TutorialOmega2")
outPath = writeSourceDatastore(sds, K, sm, outputRoot);

%%
outPath = "Z:\brainstorm_protocols_analysis\TutorialOmega2\sub-0002";
meta = load(fullfile(outPath, "provenance.mat"));
sds2 = signalDatastore(fullfile(outPath, "sensor"), SampleRate=meta.provenance.sfreq);
%% 
[bandStore, t, cwtInfo] = continuousWaveletTransform(sds2, ...
    Bands=bands, FrequencyLimits=[1 60]);
%%
cwtPath = writeCWTDatastore(bandStore, cwtInfo, outPath);
%% Load cwts and get hilbert;
cwtStore = signalDatastore(fullfile(cwtPath, "data"), SampleRate=meta.provenance.sfreq);
cwtMeta = load(fullfile(cwtPath, "provenance.mat"));
% Create lazy Hilbert transform (scales by 1e12, returns amp + phase)
[hTds, hInfo] = hilbertTransform(cwtStore, BandNames=cwtMeta.provenance.bandNames);
[amplitude, phase, t, bInfo] = readHilbertBands(hTds, hInfo);

% Write
hilbertPath = writeHilbertBands(amplitude, phase, bInfo, outPath);

%%
% Surface processing
anat=db.subjects(1).surfaces;
[rH, lH, isConnected, iStruct, iRightScout, iLeftScout] = tess_hemisplit(anat);
[rH, lH] = deal(rH(:), lH(:));  % ensure column

M=bct.Manifold(anat.Vertices, anat.Faces);


%%

fs5pathLeft='C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage5\surf\lh.pial'
[verticesL, facesL] = freesurfer_read_surf(fs5pathLeft);
fs5pathRight='C:\CodingProjects\bioctree\data\mesh\external\freesurfer\fsaverage5\surf\rh.pial'
[verticesR, facesR] = freesurfer_read_surf(fs5pathRight);

MLeft=bct.Manifold(vertices,faces);
% Load fsaverage5 path
fs5root = "data/mesh/external/freesurfer/fsaverage5/surf";

% Single band
alphaFs5 = projectToFsaverage(amplitude.alpha, sm, fs5root, K=K2, Sfreq=resampleHz);
% alphaFs5 is [20484 × T]

% All bands at once
projAmps = projectToFsaverage(amplitude, sm, fs5root, K=K2);
% projAmps.delta, .theta, .alpha, ... each [20484 × T]

% Precompute W for reuse (saves ~10s per subject)
[~, ~, pInfo] = projectToFsaverage(amplitude.alpha, sm, fs5root, K=K2);
WK = pInfo.W * K2;  % precompute combined operator
betaFs5 = WK * amplitude.beta;
%%
% psdBands.delta, psdBands.theta, ... psdBands.gamma2 — 6 datastores
% Each has 270 members (one per channel), each [nWindows x 1]
% tWindows: window center times in seconds
[psdStore, tWindows, info] = powerSpectrumDensity(sds, ...
    Bands=bands, ...
    WindowDuration=2, ...    % 2-second windows instead of 4
    Overlap=0.5, ...        % 50% overlap (hop = 0.5 s)
    NFFT=8192, ...           % finer frequency resolution
    WindowFcn="hann");       % Hann window instead of Hamming
%%
% Basic — navigate channels with arrow keys or buttons:
plotBandpower(bandStore, tWindows, info);
% Log-scale off, z-scored per band:
plotBandpower(bandStore, tWindows, info, LogScale=false, Normalize=true);
% Only inspect channels 1–10:
plotBandpower(bandStore, tWindows, info, Channels=1:10);

%%
    frameSeconds = 4; 
    ovelapPercent = 0.5; 
    frameSize = round( frameSeconds*fs);
  frameOverlapLength = round(frameSize*ovelapPercent);
     opts = frequencyScalarFeatureOptions;
     opts.WelchPSD = "Energy";
    opts.PeakAmplitude = ["Kurtosis" "PeakValue"];
  sFE = signalFrequencyFeatureExtractor(SampleRate=fs, ...
    PeakAmplitude=true,BandPower=true, WelchPSD=true);
  
  getExtractorParameters(sFE,"WelchPSD")
getScalarizationMethods(sFE,"WelchPSD")
  setExtractorParameters(sFE,"WelchPSD",...
      "FFTLength",frameOverlapLength, ...
      "FrequencyVector", freqbands.alpha, ...
      "OverlapLength", frameOverlapLength, ...
      "Window", frameSize);
    [M,infoFeatures] = extract(sFE,dataOut);
    Features = cell2mat(M);
 p = bandpower(dataOut,info.SampleRate,[8 12])
   plot(t,dataOut*10^12); %rescale

    %%
plotID = 1;
while hasdata(sds)
    [dataOut,info] = read(sds);
    subplot(3,1,plotID)
    stft(dataOut,info.SampleRate)
    plotID = plotID + 1;
end
%%

fssds = 3000;
tsds = 0:1/fs:3-1/fs;
datasds = {chirp(tsds,300,tsds(end),800).*exp(2j*pi*10*cos(2*pi*2*tsds)); ...
        2*chirp(tsds,200,tsds(end),1000,'quadratic',[],'concave'); ...
        vco(sin(2*pi*tsds),[0.1 0.4]*fssds,fssds)};
 datasds(1) = {[datasds{1}; datasds{1}]};
 datasds(2) = {[datasds{2}; datasds{2}]};
 datasds(3) = {[datasds{3}; datasds{3}]};

 sdsdd = signalDatastore(datasds,'SampleRate',fssds);

%%
scoutHemi = cellfun(@(c)c(1), {sSurf.Atlas(iStruct).Scouts.Region}, 'UniformOutput', 0);
    iRightScouts = find(strcmpi(scoutHemi, 'R'));
    iLeftScouts  = find(strcmpi(scoutHemi, 'L'));
    % If both hemispheres are described here: get the indices
    if ~isempty(iRightScouts) && ~isempty(iLeftScouts)
        rH = unique([sSurf.Atlas(iStruct).Scouts(iRightScouts).Vertices]);
        lH = unique([sSurf.Atlas(iStruct).Scouts(iLeftScouts).Vertices]);
        % Make sure these are row vectors
        rH = rH(:)';
        lH = lH(:)';
        return;
    end

    %%
    % Read one channel and plot all bands
reset(bandStore);
[bMat, bMatinfo] = read(bandStore);  
plotCWT(bandStore, t, cwtInfo)
plotCWT(bandStore, t, cwtInfo, Envelope=true, Stacked=true, TimeRange=[2 8])
plotCWTEnvelope(bandStore, t, cwtInfo)
plotCWTEnvelope(bandStore, t, cwtInfo, Layout="subplots", Smooth=0.5, LogScale=true)
plotCWTSpectrogram(bandStore, t, cwtInfo)
plotCWTSpectrogram(bandStore, t, cwtInfo, Smooth=0.5, Colormap="hot")
    
    %% GLOBAL ALPHA BURST WINDOW DETECTION (fast, frame-based)
% Uses signalFrequencyFeatureExtractor (Welch PSD) to get alpha band power per frame.
% Output: ONE selected window (longest alpha event + padding) applied to ALL channels.

%% --------------------------
% 0) Load MEG signals
%% --------------------------
% 0) Load MEG signals
blockPath="Z:\brainstorm_protocols\TutorialOmega\data\sub-0002\sub-0002_ses-01_task-rest_run-01_meg_notch_high_resample\data_block001.mat"
channelPath =  "Z:\brainstorm_protocols\TutorialOmega\data\sub-0002\sub-0002_ses-01_task-rest_run-01_meg_notch_high_resample\channel_ctf_acc1.mat";
studyPath = "Z:\brainstorm_protocols\TutorialOmega\data\sub-0002\sub-0002_ses-01_task-rest_run-01_meg_notch_high_resample\brainstormstudy.mat";

meg=load(blockPath);
chans = load(channelPath);
sStudy=load(studyPath);

%% --------------------------
chanTypes = {chans.Channel.Type};
chanNames = {chans.Channel.Name};
megMask   = strcmp(chanTypes,"MEG");
megNames  = (chanNames(megMask)).';

time = meg.Time;
fs   = round(1/diff(time(1:2)));

sigs = meg.F(megMask,:);             % [nChans x nSamples]
[nChans, nSamples] = size(sigs);

fprintf('fs=%d Hz, nChans=%d, nSamples=%d (%.1f s)\n', fs, nChans, nSamples, nSamples/fs);

%% --------------------------
% 1) Frame policy + alpha band
%% --------------------------
alphaBand = [7.5 12.5];

% Frame length should match your burst timescale.
% 0.25–1.0 s are common; start with 0.5 s.
frameDur_s = 0.50;
hopDur_s   = 0.10;                 % 100 ms hop (overlap)
frameSize  = round(frameDur_s * fs);
hopSize    = round(hopDur_s   * fs);

% Padding to extend the selected window around the burst
pad_s = 0.25;                      % 250 ms each side
pad   = round(pad_s * fs);

%% --------------------------
% 2) Frequency feature extractor: alpha bandpower per frame
%    extract() uses Welch PSD internally for frequency features. :contentReference[oaicite:3]{index=3}
%% --------------------------
freqFE = signalFrequencyFeatureExtractor( ...
    SampleRate   = fs, ...
    FrameSize    = frameSize, ...
    FrameOverlap = frameSize - hopSize, ...
    FeatureFormat= "table", ...
    BandPower    = true);

% Configure Welch PSD parameters if you want (optional):
% setExtractorParameters(freqFE, "WelchPSD", Window=..., OverlapLength=..., FFTLength=...);
% See setExtractorParameters docs. :contentReference[oaicite:4]{index=4}

%% --------------------------
% 3) Compute alpha bandpower per channel per frame, then build a GLOBAL index
%% --------------------------
% We'll compute bandpower feature, then select alpha band from it.
% (BandPower feature returns power in specified frequency bands; in many setups,
% you provide Bands via extractor parameters. If your MATLAB requires explicit
% band specification, set it through setExtractorParameters.)

% Try to set the band(s) explicitly (robust across versions):
try
    setExtractorParameters(freqFE, "BandPower", FrequencyBands=alphaBand);
catch
    % If your version uses a different parameter name, you can inspect:
    % getExtractorParameters(freqFE)
    % and adapt. (This is version-dependent.)
end

% Run extraction channel-by-channel (fast; Welch per frame)
% Features will be returned as a table with one row per frame. :contentReference[oaicite:5]{index=5}
alphaPow_ch = [];   % will become [nChans x nFrames]

for ci = 1:nChans
    x = sigs(ci,:);
    x = x - median(x);  % light robust centering

    feats = extract(freqFE, x);  % table: one row per frame
    % Find the BandPower variable (name can be 'BandPower' or similar)
    vnames = feats.Properties.VariableNames;
    bpName = vnames(contains(vnames,"BandPower", "IgnoreCase", true));
    if isempty(bpName)
        error("Could not find BandPower feature column in extracted table.");
    end

    bp = feats.(bpName{1});  % typically numeric column (nFrames×1 or nFrames×nBands)
    % If multiple bands exist, take the alpha band column:
    if size(bp,2) > 1
        % assume first band is alpha if we set FrequencyBands=alphaBand
        bp = bp(:,1);
    end

    alphaPow_ch(ci,:) = bp(:).';  %#ok<SAGROW>

    if mod(ci,25)==0
        fprintf('Extracted alpha bandpower: %d/%d channels\n', ci, nChans);
    end
end

nFrames = size(alphaPow_ch,2);

% Global alpha index across channels:
% use log-power then robust median across channels for stability
alphaGlobal = median(log(alphaPow_ch + eps), 1);  % 1×nFrames

%% --------------------------
% 4) Smooth + robust z-score on the FRAME series (not sample series)
%% --------------------------
% Smooth in frames (e.g., ~0.5–1 s worth of frames)
smoothFrames = max(3, round(0.5 / hopDur_s));   % ~0.5 s smoothing
alphaS = movmedian(alphaGlobal, smoothFrames);
alphaS = movmean(alphaS, smoothFrames);

med0  = median(alphaS);
madv0 = mad(alphaS,1);
z = (alphaS - med0) / (1.4826*madv0 + eps);

%% --------------------------
%% --------------------------
% 5) Alpha-period detection using signalMask (frames -> ROIs -> samples)
%% ============================================================
%  Alpha ROI detection (GLOBAL) using signalMask built-ins
%  Put this block right after you compute:
%    alphaGlobal, z, nFrames, fs, nSamples, sigs, hopSize, frameSize, tFrames
% ============================================================

%% --------------------------
% USER-TUNABLE PARAMETERS
%% --------------------------
P = struct();

% Hysteresis thresholds on robust z (frame domain)
P.thrOn   = 0.5;      % start ROI when z >= thrOn
P.thrOff  = 0.5;      % end ROI when z <= thrOff

% ROI post-processing (signalMask properties; all in seconds)
P.minLength_s      = 0.30;   % MinLength: discard ROIs shorter than this
P.mergeDistance_s  = 1;   % MergeDistance: merge ROIs separated by gaps <= this
P.leftExtension_s  = 0.50;   % extend each ROI left by this amount (0 = off)
P.rightExtension_s = 0.50;   % extend each ROI right by this amount (0 = off)

% Final selected window padding (applied ONLY to the longest ROI; seconds)
P.finalPad_s = 0.25;

% Optional: if you want to force a minimum total selected window length
P.minSelectedWin_s = 0.00;   % 0 = off, else e.g., 1.0

% --------------------------
% 5) Raw detection in FRAME space (hysteresis)
% --------------------------
isHigh = (z >= P.thrOn);
isLow  = (z <= P.thrOff);

burstF = false(1, nFrames);
state = false;
for k = 1:nFrames
    if ~state
        if isHigh(k), state = true; end
    else
        if isLow(k),  state = false; end
    end
    burstF(k) = state;
end
burstF = logical(burstF(:).');  % ensure 1×nFrames logical row

% Helper: logical mask -> [start end] runs (indices)
mask2runs = @(m) deal( ...
    find(diff([false m false])== 1), ...
    find(diff([false m false])==-1)-1 );

[onF, offF] = mask2runs(burstF);

if isempty(onF)
    warning("No alpha periods detected from hysteresis. Lower thresholds or reduce smoothing.");
    alphaMask = signalMask.empty;
    winStartIdx = [];
    winEndIdx   = [];
    sigsWin     = [];
else
    % --------------------------
    % Convert FRAME runs -> SAMPLE runs -> TIME runs (seconds)
    % --------------------------
    onS  = (onF  - 1) * hopSize + 1;
    offS = (offF - 1) * hopSize + frameSize;

    onS  = max(1, onS);
    offS = min(nSamples, offS);

    roiTime = [ (onS(:)-1)/fs, (offS(:)-1)/fs ];      % [N×2] seconds
    roiLab  = repmat(categorical("alpha"), numel(onS), 1);

    % Two-variable source table: limits + labels (required by your MATLAB)
    srcTbl = table(roiTime, roiLab);  % var1 = limits, var2 = labels

    % --------------------------
    % Build signalMask + apply built-in ROI cleanup
    % --------------------------
    alphaMask = signalMask( ...
        srcTbl, ...
        "SampleRate", fs, ...
        "MinLength",      max(1, round(P.minLength_s      * fs)), ...
        "MergeDistance",  max(0, round(P.mergeDistance_s  * fs)), ...
        "LeftExtension",  max(0, round(P.leftExtension_s  * fs)), ...
        "RightExtension", max(0, round(P.rightExtension_s * fs)) );

    % ROIs AFTER merge/prune/extension
    roiOut = roimask(alphaMask);     % table: limits + labels
    roiLimits_t = roiOut{:,1};       % [M×2] seconds
    roiLabels   = roiOut{:,2};

    % Keep alpha only (future-proof if you add categories)
    isAlpha = (roiLabels == categorical("alpha"));
    roiLimits_t = roiLimits_t(isAlpha,:);

    if isempty(roiLimits_t)
        warning("All alpha ROIs removed by MinLength/MergeDistance. Relax P.minLength_s or thresholds.");
        winStartIdx = [];
        winEndIdx   = [];
        sigsWin     = [];
    else
        % --------------------------
        % 6) Select ONE ROI: longest duration, then apply FINAL padding
        % --------------------------
        roiDur = roiLimits_t(:,2) - roiLimits_t(:,1);
        [~,imax] = max(roiDur);

        baseStart_s = roiLimits_t(imax,1);
        baseEnd_s   = roiLimits_t(imax,2);

        % Final padding ONLY for the selected window
        winStart_s = max(0, baseStart_s - P.finalPad_s);
        winEnd_s   = min((nSamples-1)/fs, baseEnd_s + P.finalPad_s);

        % Optional: enforce minimum selected window length
        if P.minSelectedWin_s > 0
            curLen = winEnd_s - winStart_s;
            if curLen < P.minSelectedWin_s
                extra = 0.5*(P.minSelectedWin_s - curLen);
                winStart_s = max(0, winStart_s - extra);
                winEnd_s   = min((nSamples-1)/fs, winEnd_s + extra);
            end
        end

        % Convert to sample indices
        winStartIdx = max(1, floor(winStart_s*fs) + 1);
        winEndIdx   = min(nSamples, ceil(winEnd_s*fs) + 1);

        sigsWin = sigs(:, winStartIdx:winEndIdx);

        fprintf('\nSelected GLOBAL alpha window:\n');
        fprintf('  start = %.3f s (idx %d)\n', (winStartIdx-1)/fs, winStartIdx);
        fprintf('  end   = %.3f s (idx %d)\n', (winEndIdx-1)/fs, winEndIdx);
        fprintf('  dur   = %.3f s\n', (winEndIdx-winStartIdx+1)/fs);

        % --------------------------
        % Optional: Extract ALL ROIs using extractsigroi (if you want them)
        % Note: often expects [nSamples×nSignals]
        % --------------------------
        % sigsRoiAll = extractsigroi(alphaMask, sigs.');   % cell array per ROI (typical)
    end
end

% --------------------------
% 7) Optional plots
% --------------------------
figure('Name','Alpha ROI detection (signalMask built-ins)');
subplot(3,1,1);
plot(tFrames, alphaGlobal); grid on;
xlabel('Time (s)'); ylabel('median log(alphaPow)');
title('Global alpha index (per frame)');

subplot(3,1,2);
plot(tFrames, z); hold on; grid on;
yline(P.thrOn,'--'); yline(P.thrOff,'--');
xlabel('Time (s)'); ylabel('robust z');
title('Robust z-score + hysteresis thresholds');

subplot(3,1,3);
stairs(tFrames, double(burstF), 'LineWidth', 1); grid on;
xlabel('Time (s)'); ylabel('raw frame mask');
title('Raw hysteresis mask (pre signalMask merge/prune)');

if exist('winStartIdx','var') && ~isempty(winStartIdx)
    xline((winStartIdx-1)/fs, '-', 'win start');
    xline((winEndIdx-1)/fs,   '-', 'win end');
end

% Optional ROI visualization on a representative channel:
 figure; plotsigroi(alphaMask, sigs(200,:)); title('Alpha ROIs (post merge/prune)');

 %%

 %% --------------------------
% Per-channel ROI detection + Global ROI merge PARAMETERS
%% --------------------------
P = struct();

% Per-channel z-score thresholds (computed per channel after smoothing)
P.thrOn   = 1.5;
P.thrOff  = 1.5;

% Smoothing (in frames)
P.smooth_s = 0.5;  % seconds worth of frames for smoothing

% Per-channel ROI cleanup (signalMask)
P.minLength_s      = 0.20;
P.mergeDistance_s  = 0.10;
P.leftExtension_s  = 0.00;
P.rightExtension_s = 0.00;

% Merge channels into global ROI:
P.minChanFrac   = 0.15;   % e.g., 0.15 => require 15% of channels active
% (Alternative: use an absolute number instead)
P.minChanCount  = [];     % e.g., 30; if non-empty, overrides minChanFrac

% Global ROI cleanup (signalMask)
P.globalMinLength_s     = 0.20;
P.globalMergeDistance_s = 0.15;
P.globalLeftExt_s       = 0.00;
P.globalRightExt_s      = 0.00;

% Final selected window padding (seconds)
P.finalPad_s = 0.25;

% --------------------------
% 4) Per-channel smoothing + robust z-score (frame domain)
% --------------------------
smoothFrames = max(3, round(P.smooth_s / hopDur_s));

alphaLog = log(alphaPow_ch + eps);                      % [nChans x nFrames]
alphaS_ch = movmedian(alphaLog, smoothFrames, 2);
alphaS_ch = movmean(alphaS_ch, smoothFrames, 2);

med_ch  = median(alphaS_ch, 2);                         % [nChans x 1]
mad_ch  = mad(alphaS_ch, 1, 2);                         % [nChans x 1]
z_ch    = (alphaS_ch - med_ch) ./ (1.4826*mad_ch + eps);% [nChans x nFrames]

% --------------------------
% 5) Per-channel ROIs (signalMask) -> Global ROI table
%--------------------------

mask2runs = @(m) deal( ...
    find(diff([false m false])== 1), ...
    find(diff([false m false])==-1)-1 );

% Frame time axis (seconds). Each frame start sample = (k-1)*hopSize+1
tFrames = ((0:nFrames-1)*hopSize + 1) / fs;   % 1 x nFrames (frame "start times")

% We will build a binary activity matrix after ROI cleanup:
% active_ch(ci,k) = 1 if channel ci is in an alpha ROI at frame k (after merge/prune)
active_ch = false(nChans, nFrames);

% Optional: store ROIs per channel (time limits)
roiPerChan = cell(nChans,1);

for ci = 1:nChans
    zc = z_ch(ci,:);

    % Hysteresis in frame space
    isHigh = (zc >= P.thrOn);
    isLow  = (zc <= P.thrOff);

    m = false(1,nFrames);
    state = false;
    for k = 1:nFrames
        if ~state
            if isHigh(k), state = true; end
        else
            if isLow(k),  state = false; end
        end
        m(k) = state;
    end
    m = logical(m);

    % Convert frame mask -> frame runs -> sample runs -> time runs (seconds)
    [onF, offF] = mask2runs(m);
    if isempty(onF)
        continue;
    end

    onS  = (onF  - 1) * hopSize + 1;
    offS = (offF - 1) * hopSize + frameSize;

    onS  = max(1, onS);
    offS = min(nSamples, offS);

    roiTime = [ (onS(:)-1)/fs, (offS(:)-1)/fs ];      % seconds
    roiLab  = repmat(categorical("alpha"), numel(onS), 1);
    srcTbl  = table(roiTime, roiLab);

    % Per-channel cleanup with signalMask built-ins
    msk = signalMask( ...
        srcTbl, ...
        "SampleRate", fs, ...
        "MinLength",      max(1, round(P.minLength_s * fs)), ...
        "MergeDistance",  max(0, round(P.mergeDistance_s * fs)), ...
        "LeftExtension",  max(0, round(P.leftExtension_s * fs)), ...
        "RightExtension", max(0, round(P.rightExtension_s * fs)) );

    roiOut = roimask(msk);
    roiLimits_t = roiOut{:,1};   % [M x 2] seconds

    roiPerChan{ci} = roiLimits_t;

    % Rasterize cleaned ROIs back to frame grid (active_ch)
    for r = 1:size(roiLimits_t,1)
        a = roiLimits_t(r,1);
        b = roiLimits_t(r,2);
        % mark frames whose start time lies in [a,b]
        active_ch(ci,:) = active_ch(ci,:) | (tFrames >= a & tFrames <= b);
    end
end

% ---- Merge channels to a GLOBAL frame mask ----
chanCount = sum(active_ch, 1);  % 1 x nFrames

if ~isempty(P.minChanCount)
    minC = P.minChanCount;
else
    minC = max(1, ceil(P.minChanFrac * nChans));
end

globalF = (chanCount >= minC);

% Convert global frame mask -> time ROIs
[gonF, goffF] = mask2runs(globalF);

if isempty(gonF)
    warning("No global alpha events after channel-merge. Lower minChanFrac/minChanCount or thresholds.");
    alphaMaskGlobal = signalMask.empty;
    winStartIdx = [];
    winEndIdx = [];
    sigsWin = [];
else
    gonS  = (gonF  - 1) * hopSize + 1;
    goffS = (goffF - 1) * hopSize + frameSize;

    gonS  = max(1, gonS);
    goffS = min(nSamples, goffS);

    globalTime = [ (gonS(:)-1)/fs, (goffS(:)-1)/fs ];
    globalLab  = repmat(categorical("alphaGlobal"), size(globalTime,1), 1);
    globalSrc  = table(globalTime, globalLab);

    % Clean GLOBAL ROIs with signalMask too (often helpful)
    alphaMaskGlobal = signalMask( ...
        globalSrc, ...
        "SampleRate", fs, ...
        "MinLength",      max(1, round(P.globalMinLength_s * fs)), ...
        "MergeDistance",  max(0, round(P.globalMergeDistance_s * fs)), ...
        "LeftExtension",  max(0, round(P.globalLeftExt_s * fs)), ...
        "RightExtension", max(0, round(P.globalRightExt_s * fs)) );

    globalOut = roimask(alphaMaskGlobal);
    globalLimits_t = globalOut{:,1};  % seconds (post-clean)

    % ---- Select longest GLOBAL ROI + final pad ----
    dur = globalLimits_t(:,2) - globalLimits_t(:,1);
    [~,imax] = max(dur);

    baseStart_s = globalLimits_t(imax,1);
    baseEnd_s   = globalLimits_t(imax,2);

    winStart_s = max(0, baseStart_s - P.finalPad_s);
    winEnd_s   = min((nSamples-1)/fs, baseEnd_s + P.finalPad_s);

    winStartIdx = max(1, floor(winStart_s*fs) + 1);
    winEndIdx   = min(nSamples, ceil(winEnd_s*fs) + 1);

    sigsWin = sigs(:, winStartIdx:winEndIdx);

    fprintf('\nSelected GLOBAL alpha window (channel-merged):\n');
    fprintf('  start = %.3f s (idx %d)\n', (winStartIdx-1)/fs, winStartIdx);
    fprintf('  end   = %.3f s (idx %d)\n', (winEndIdx-1)/fs, winEndIdx);
    fprintf('  dur   = %.3f s\n', (winEndIdx-winStartIdx+1)/fs);
end
%

alphaGlobal_samp = zeros(1, nSamples);
for k = 1:nFrames
    s0 = (k-1)*hopSize + 1;
    s1 = min(nSamples, s0 + frameSize - 1);
    alphaGlobal_samp(s0:s1) = alphaGlobal(k);
end

figure('Name','Global alpha ROIs over alphaGlobal');
plotsigroi(alphaMaskGlobal, alphaGlobal_samp);
title('Global alpha ROIs over alphaGlobal (frame-hold to sample-rate)');
%
% ---- choose channels to inspect ----
exampleChans = [1 50 100 150 200 250];   % change as you like

for ii = 1:numel(exampleChans)
    ci = exampleChans(ii);
    if ci < 1 || ci > nChans, continue; end

    x = sigs(ci,:);  % vector

    figure('Name', sprintf('Global alpha ROIs over channel %d (%s)', ...
        ci, megNames{ci}));
    plotsigroi(alphaMaskGlobal, x);
    title(sprintf('Global alpha ROIs over MEG channel %d (%s)', ci, megNames{ci}));
end

%%
% Often expects [nSamples x nSignals]
