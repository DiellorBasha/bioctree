function [out1, out2, psdInfo] = powerSpectrumDensity(sds, opts)
%POWERSPECTRUMDENSITY Compute PSD per channel, optionally band-stratified.
%
%   MODE 1 — Broadband PSD (no Bands argument):
%     [psdStore, f, psdInfo] = powerSpectrumDensity(sds)
%     Returns one signalDatastore with a full PSD vector per channel.
%
%   MODE 2 — Band-stratified windowed PSD:
%     [psdBands, tWindows, psdInfo] = powerSpectrumDensity(sds, Bands=bands)
%     Returns a struct of signalDatastores (one per band), where each
%     member is the time-resolved mean PSD in that band per channel.
%
%   Inputs:
%       sds - signalDatastore with one member per channel (e.g. from
%             readSourceSegment with AsDatastore=true). Must have a valid
%             SampleRate property.
%
%   Name-Value Arguments:
%       WindowDuration - window duration in seconds (default 4)
%       Overlap        - fractional overlap between windows, 0–1 (default 0.5)
%       NFFT           - FFT length (default 0 = next power of 2 ≥ window)
%       FreqRange      - [fLow fHigh] in Hz to trim output (default [] = full)
%                        (broadband mode only)
%       WindowFcn      - window function name (default "hamming")
%       Bands          - struct defining frequency bands (default [] = broadband).
%                        Each field is a [1x2] [fLow fHigh] Hz vector, e.g.:
%                          bands.delta  = [2 4];
%                          bands.theta  = [5 7];
%                          bands.alpha  = [8 12];
%                          bands.beta   = [15 30];
%                          bands.gamma1 = [30 59];
%                          bands.gamma2 = [60 90];
%       Verbose        - print progress (default true)
%
%   Outputs (broadband mode, Bands=[]):
%       psdStore - signalDatastore, one member per channel, each [nFreqs x 1]
%       f        - [nFreqs x 1] frequency vector (Hz)
%       psdInfo  - struct with parameters
%
%   Outputs (band mode, Bands=struct):
%       bandStore - signalDatastore with nChannels members. Each member is
%                   a [nWindows x nBands] matrix where column j is the
%                   time-resolved bandpower for band j. Column order matches
%                   psdInfo.bandNames. SampleRate = effective window rate.
%                   MemberNames = channel names from input.
%       tWindows  - [1 x nWindows] window center times in seconds (relative
%                   to signal start; add segment tStart for absolute time)
%       psdInfo   - struct with parameters and band definitions. Use
%                   psdInfo.bandNames to identify columns of the band matrix.
%
%   Examples:
%       % Broadband PSD:
%       [psdStore, f, info] = powerSpectrumDensity(sds);
%
%       % Band-stratified windowed PSD:
%       bands.delta = [2 4]; bands.theta = [5 7]; bands.alpha = [8 12];
%       bands.beta  = [15 30]; bands.gamma1 = [30 59]; bands.gamma2 = [60 90];
%       [bandStore, tWindows, info] = powerSpectrumDensity(sds, Bands=bands);
%       % Each member is [nWindows x 6] — columns are delta,theta,...,gamma2
%       % info.bandNames lists the column names
%
%       % Read one channel and extract alpha column:
%       reset(bandStore);
%       bp = read(bandStore);        % [nWindows x nBands]
%       alphaCol = strcmp(info.bandNames, "alpha");
%       plot(tWindows, bp(:, alphaCol));
%
%       % Resample + band PSD in one pipeline:
%       [sds, K] = readSourceSegment(sm, 0, 300, AsDatastore=true, Resample=600);
%       [bandStore, tWindows] = powerSpectrumDensity(sds, Bands=bands);
%
%   See also: pwelch, spectrogram, signalDatastore, readSourceSegment

    arguments
        sds     (1,1) signalDatastore
        opts.WindowDuration (1,1) double {mustBePositive}  = 4
        opts.Overlap        (1,1) double {mustBeInRange(opts.Overlap,0,1)} = 0.5
        opts.NFFT           (1,1) double {mustBeNonnegative} = 0
        opts.FreqRange                                       = []
        opts.WindowFcn      (1,1) string                     = "hamming"
        opts.Bands                                           = []
        opts.Verbose        (1,1) logical                    = true
    end

    % ---- Get sample rate from datastore ----
    fs = sds.SampleRate;
    if isempty(fs) || fs <= 0
        error('powerSpectrumDensity:NoSampleRate', ...
            'Input signalDatastore must have a valid SampleRate property.');
    end

    % ---- Common Welch / spectrogram parameters ----
    windowSamples  = round(opts.WindowDuration * fs);
    overlapSamples = round(windowSamples * opts.Overlap);

    if opts.NFFT > 0
        nfft = opts.NFFT;
    else
        nfft = 2^nextpow2(windowSamples);
    end

    winVec    = window(opts.WindowFcn, windowSamples);
    chanNames = sdsGetChannelNames(sds);
    nChans    = numel(chanNames);

    % ---- Dispatch to broadband or band-stratified mode ----
    if isempty(opts.Bands)
        [out1, out2, psdInfo] = broadbandPSD(sds, fs, winVec, ...
            overlapSamples, nfft, chanNames, nChans, windowSamples, ...
            opts);
    else
        [out1, out2, psdInfo] = bandStratifiedPSD(sds, fs, winVec, ...
            overlapSamples, nfft, chanNames, nChans, windowSamples, ...
            opts);
    end
end

% =========================================================================
%  BROADBAND PSD (original mode)
% =========================================================================
function [psdStore, f, psdInfo] = broadbandPSD(sds, fs, winVec, ...
        overlapSamples, nfft, chanNames, nChans, windowSamples, opts)

    reset(sds);
    psdCell = cell(nChans, 1);
    f = [];

    for ci = 1:nChans
        x = read(sds);
        if iscell(x), x = x{1}; end
        x = x(:);

        [pxx, fChan] = pwelch(x, winVec, overlapSamples, nfft, fs);

        if isempty(f), f = fChan(:); end
        psdCell{ci} = pxx(:)';
    end
    reset(sds);

    % ---- Apply frequency range trim ----
    freqRange = [f(1), f(end)];
    if ~isempty(opts.FreqRange)
        fLow  = opts.FreqRange(1);
        fHigh = opts.FreqRange(2);
        fIdx  = (f >= fLow) & (f <= fHigh);
        f = f(fIdx);
        for ci = 1:nChans
            psdCell{ci} = psdCell{ci}(fIdx');
        end
        freqRange = [fLow, fHigh];
    end

    nFreqs = numel(f);
    df = f(2) - f(1);

    C = cell(nChans, 1);
    for ci = 1:nChans
        C{ci} = psdCell{ci}(:);
    end

    psdStore = signalDatastore(C, 'SampleRate', df);
    psdStore.MemberNames = chanNames(:);

    psdInfo = struct();
    psdInfo.mode           = "broadband";
    psdInfo.sfreq          = fs;
    psdInfo.windowSamples  = windowSamples;
    psdInfo.overlapSamples = overlapSamples;
    psdInfo.nfft           = nfft;
    psdInfo.df             = df;
    psdInfo.freqRange      = freqRange;
    psdInfo.nChannels      = nChans;
    psdInfo.nFreqs         = nFreqs;
    psdInfo.windowFcn      = opts.WindowFcn;

    if opts.Verbose
        fprintf('powerSpectrumDensity [broadband]: %d channels, %d freq bins (%.2f–%.2f Hz, df=%.4f Hz)\n', ...
            nChans, nFreqs, f(1), f(end), df);
        fprintf('  Welch: %d-sample window (%s), %d overlap, %d-pt FFT\n', ...
            windowSamples, opts.WindowFcn, overlapSamples, nfft);
    end
end

% =========================================================================
%  BAND-STRATIFIED WINDOWED PSD
% =========================================================================
function [bandStore, tWindows, psdInfo] = bandStratifiedPSD(sds, fs, winVec, ...
        overlapSamples, nfft, chanNames, nChans, windowSamples, opts)

    bands     = opts.Bands;
    bandNames = string(fieldnames(bands));
    nBands    = numel(bandNames);

    hopSamples = windowSamples - overlapSamples;
    hopSeconds = hopSamples / fs;
    windowRate = 1 / hopSeconds;  % effective sample rate of output

    % ---- Pre-allocate: one cell per channel, each will be [nWindows x nBands] ----
    chanCells = cell(nChans, 1);

    reset(sds);
    tWindows = [];
    F = [];  % frequency vector from spectrogram

    for ci = 1:nChans
        x = read(sds);
        if iscell(x), x = x{1}; end
        x = x(:);

        % Compute spectrogram with PSD normalization
        [~, fSpec, tSpec, P] = spectrogram(x, winVec, overlapSamples, nfft, fs, 'psd');
        % P: [nFreqs x nWindows] one-sided PSD per window

        if isempty(F)
            F = fSpec(:);
            tWindows = tSpec(:)';
        end

        nWin = size(P, 2);
        bpMat = zeros(nWin, nBands);  % [nWindows x nBands]

        % Compute band power for each band using bandpower(pxx,f,freqRange,"psd")
        for bi = 1:nBands
            bRange = bands.(bandNames(bi));
            for wi = 1:nWin
                bpMat(wi, bi) = bandpower(P(:, wi), F, bRange, 'psd');
            end
        end

        chanCells{ci} = bpMat;  % [nWindows x nBands]
    end
    reset(sds);

    % ---- Build single signalDatastore: one member per channel ----
    bandStore = signalDatastore(chanCells, 'SampleRate', windowRate);
    bandStore.MemberNames = chanNames(:);

    % ---- Info struct ----
    df = F(2) - F(1);
    nWindows = numel(tWindows);

    psdInfo = struct();
    psdInfo.mode           = "bands";
    psdInfo.sfreq          = fs;
    psdInfo.windowSamples  = windowSamples;
    psdInfo.overlapSamples = overlapSamples;
    psdInfo.hopSeconds     = hopSeconds;
    psdInfo.windowRate     = windowRate;
    psdInfo.nfft           = nfft;
    psdInfo.df             = df;
    psdInfo.nChannels      = nChans;
    psdInfo.nWindows       = nWindows;
    psdInfo.windowFcn      = opts.WindowFcn;
    psdInfo.bandNames      = bandNames;
    psdInfo.bandRanges     = bands;

    if opts.Verbose
        fprintf('powerSpectrumDensity [bands]: %d channels, %d windows (hop=%.2f s, rate=%.4f Hz)\n', ...
            nChans, nWindows, hopSeconds, windowRate);
        fprintf('  Spectrogram: %d-sample window (%s), %d overlap, %d-pt FFT\n', ...
            windowSamples, opts.WindowFcn, overlapSamples, nfft);
        for bi = 1:nBands
            bRange = bands.(bandNames(bi));
            bIdx = (F >= bRange(1)) & (F <= bRange(2));
            fprintf('  Band %-8s: [%5.1f–%5.1f Hz] → %d bins\n', ...
                bandNames(bi), bRange(1), bRange(2), sum(bIdx));
        end
    end
end
