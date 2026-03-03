function [tds, t, cwtInfo] = cwtBandTransform(sds, opts)
%CWTBANDTRANSFORM Lazy CWT band decomposition via signalDatastore transform.
%
%   [tds, t, cwtInfo] = cwtBandTransform(sds, Bands=bands)
%   [tds, t, cwtInfo] = cwtBandTransform(sds, Bands=bands, Name=Value)
%
%   Creates a TransformedDatastore that lazily applies CWT band
%   decomposition to each channel as it is read. Unlike
%   continuousWaveletTransform (which reads all channels upfront), this
%   function returns immediately and processes channels on demand.
%
%   The CWT filterbank is pre-built once from the first channel's length
%   and reused for all subsequent reads. Each read() call returns a
%   [nSamples x nBands] matrix for one channel.
%
%   Inputs:
%       sds - signalDatastore (in-memory or file-based) with one member
%             per channel. Must have a valid SampleRate.
%
%   Name-Value Arguments:
%       Bands           - struct defining frequency bands (REQUIRED).
%                         Each field is a [1x2] [fLow fHigh] Hz vector:
%                           bands.delta = [1  4];
%                           bands.theta = [4  8];
%                           bands.alpha = [8 13];
%                           bands.beta  = [13 30];
%                           bands.gamma = [30 60];
%       FrequencyLimits - [fLow fHigh] Hz for the CWT filterbank
%                         (default: auto from Bands). Restricts scales
%                         computed for efficiency.
%       Wavelet         - wavelet name: "morse" | "amor" | "bump"
%                         (default "morse")
%       VoicesPerOctave - number of voices per octave, 1–48 (default 12)
%       TimeBandwidth   - time-bandwidth product for Morse wavelet
%                         (default 60). Ignored for amor/bump.
%       Verbose         - print filterbank info (default true)
%
%   Outputs:
%       tds     - TransformedDatastore. Each read() returns:
%                   data - [nSamples x nBands] band reconstructions
%                   info - struct with .BandNames, .BandRanges, plus original
%                          info fields (MemberName/SignalVariableNames etc.)
%       t       - [nSamples x 1] time vector in seconds (0-based).
%       cwtInfo - struct with transform parameters:
%                   .bandNames, .bandRanges, .clippedRanges, .bandValid,
%                   .freqVector, .frequencyLimits, .wavelet,
%                   .voicesPerOctave, .nScales, .nSamples, .sfreq
%
%   Usage patterns:
%       % LAZY: process one channel at a time (low memory)
%       [tds, t, info] = cwtBandTransform(sds, Bands=bands);
%       reset(tds);
%       while hasdata(tds)
%           [bMat, chInfo] = read(tds);
%           % bMat is [nSamples x nBands] for this channel
%           % chInfo.BandNames identifies columns
%       end
%
%       % FULL READ: readall concatenates all channels
%       allBands = readall(tds);  % [nSamples*nChans x nBands]
%
%       % CHAINED TRANSFORMS: compose with other operations
%       envFcn = @(data, info) deal(abs(hilbert(data)), info);
%       envTds = transform(tds, envFcn, 'IncludeInfo', true);
%
%   Comparison with continuousWaveletTransform:
%       continuousWaveletTransform — reads ALL channels, returns in-memory
%           signalDatastore. Good when you need all data at once.
%       cwtBandTransform — lazy evaluation via transform(). Processes
%           channels on demand. Better for large datasets and composable
%           pipelines.
%
%   Examples:
%       bands.delta = [2 4]; bands.theta = [5 7]; bands.alpha = [8 12];
%       bands.beta  = [15 30]; bands.gamma = [30 60];
%
%       % From raw MEG (in-memory):
%       [sds, K] = readSourceSegment(sm, 0, 300, AsDatastore=true, Resample=600);
%       [tds, t, info] = cwtBandTransform(sds, Bands=bands, FrequencyLimits=[1 60]);
%
%       % From saved file-based datastore:
%       sds = signalDatastore('Z:\processed\sub-0002\sensor', SampleRate=600);
%       [tds, t, info] = cwtBandTransform(sds, Bands=bands, FrequencyLimits=[1 60]);
%
%       % Read alpha band for first channel:
%       reset(tds);
%       [bMat, chInfo] = read(tds);
%       alphaCol = chInfo.BandNames == "alpha";
%       plot(t, bMat(:, alphaCol));
%
%   See also: continuousWaveletTransform, applyCWTBands, transform,
%             signalDatastore, plotCWT

    arguments
        sds     (1,1)
        opts.Bands                                                   = []
        opts.FrequencyLimits                                         = []
        opts.Wavelet         (1,1) string {mustBeMember(opts.Wavelet, ...
                                   ["morse","amor","bump"])}         = "morse"
        opts.VoicesPerOctave (1,1) double {mustBePositive, ...
                                   mustBeInteger}                    = 12
        opts.TimeBandwidth   (1,1) double {mustBePositive}           = 60
        opts.Verbose         (1,1) logical                           = true
    end

    % ---- Validate ----
    if isempty(opts.Bands) || ~isstruct(opts.Bands)
        error('cwtBandTransform:NoBands', ...
            'Bands argument is required and must be a struct.');
    end

    fs = sds.SampleRate;
    if isempty(fs) || fs <= 0
        error('cwtBandTransform:NoSampleRate', ...
            'Input signalDatastore must have a valid SampleRate property.');
    end

    bands     = opts.Bands;
    bandNames = string(fieldnames(bands));
    nBands    = numel(bandNames);

    % ---- Determine FrequencyLimits ----
    if isempty(opts.FrequencyLimits)
        allLow  = inf;
        allHigh = -inf;
        for bi = 1:nBands
            br = bands.(bandNames(bi));
            allLow  = min(allLow,  br(1));
            allHigh = max(allHigh, br(2));
        end
        freqLimits = [max(allLow, 0.1), min(allHigh, fs/2)];
    else
        freqLimits = opts.FrequencyLimits;
    end

    % ---- Read first channel to get signal length ----
    reset(sds);
    x1 = read(sds);
    if iscell(x1), x1 = x1{1}; end
    x1 = x1(:);
    N  = numel(x1);
    reset(sds);

    % ---- Build filterbank ----
    fbArgs = {'SignalLength', N, ...
              'SamplingFrequency', fs, ...
              'FrequencyLimits', freqLimits, ...
              'VoicesPerOctave', opts.VoicesPerOctave};

    if lower(opts.Wavelet) == "morse"
        fbArgs = [fbArgs, {'TimeBandwidth', opts.TimeBandwidth}];
    end

    fb = cwtfilterbank(fbArgs{:});

    % ---- Get frequency vector ----
    [~, fVec] = wt(fb, x1);
    fVec = fVec(:);
    fMin = min(fVec);
    fMax = max(fVec);

    % ---- Pre-clip band ranges ----
    clippedRanges = cell(nBands, 1);
    bandValid     = false(nBands, 1);

    for bi = 1:nBands
        br = bands.(bandNames(bi));
        clipped = [max(br(1), fMin), min(br(2), fMax)];
        if clipped(1) < clipped(2)
            clippedRanges{bi} = clipped;
            bandValid(bi) = true;
        end
    end

    % ---- Build config struct for the transform function ----
    config = struct();
    config.fb            = fb;
    config.fVec          = fVec;
    config.wavelet       = opts.Wavelet;
    config.nBands        = nBands;
    config.bandNames     = bandNames;
    config.bandRanges    = bands;
    config.clippedRanges = clippedRanges;
    config.bandValid     = bandValid;

    % ---- Create TransformedDatastore ----
    tds = transform(sds, @(dataIn, info) applyCWTBands(dataIn, info, config), ...
        'IncludeInfo', true);

    % ---- Time vector ----
    t = (0:N-1)' / fs;

    % ---- Info struct ----
    cwtInfo = struct();
    cwtInfo.mode             = "cwt_bands_transform";
    cwtInfo.sfreq            = fs;
    cwtInfo.nSamples         = N;
    cwtInfo.nBands           = nBands;
    cwtInfo.nScales          = numel(fVec);
    cwtInfo.bandNames        = bandNames;
    cwtInfo.bandRanges       = bands;
    cwtInfo.clippedRanges    = clippedRanges;
    cwtInfo.bandValid        = bandValid;
    cwtInfo.freqVector       = fVec;
    cwtInfo.frequencyLimits  = freqLimits;
    cwtInfo.wavelet          = opts.Wavelet;
    cwtInfo.voicesPerOctave  = opts.VoicesPerOctave;
    if lower(opts.Wavelet) == "morse"
        cwtInfo.timeBandwidth = opts.TimeBandwidth;
    end

    if opts.Verbose
        chanNames = sdsGetChannelNames(sds);
        nChans = numel(chanNames);
        fprintf('cwtBandTransform: %d channels, %d samples (fs=%.1f Hz)\n', ...
            nChans, N, fs);
        fprintf('  Filterbank: %s wavelet, %d voices/octave, %d scales\n', ...
            opts.Wavelet, opts.VoicesPerOctave, numel(fVec));
        fprintf('  Frequency range: [%.2f–%.2f Hz]\n', fMin, fMax);
        for bi = 1:nBands
            br = bands.(bandNames(bi));
            if bandValid(bi)
                cr = clippedRanges{bi};
                fIdx = (fVec >= cr(1)) & (fVec <= cr(2));
                fprintf('  Band %-8s: [%5.1f–%5.1f Hz] → clipped [%.2f–%.2f Hz], %d scales\n', ...
                    bandNames(bi), br(1), br(2), cr(1), cr(2), sum(fIdx));
            else
                fprintf('  Band %-8s: [%5.1f–%5.1f Hz] → OUTSIDE filterbank range (zeros)\n', ...
                    bandNames(bi), br(1), br(2));
            end
        end
        fprintf('  Mode: lazy TransformedDatastore (channels processed on read)\n');
    end
end
