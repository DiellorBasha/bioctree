function [bandStore, t, cwtInfo] = continuousWaveletTransform(sds, opts)
%CONTINUOUSWAVELETTRANSFORM  CWT-based band decomposition per channel.
%
%   Computes the continuous wavelet transform for each channel in a
%   signalDatastore, then reconstructs time-domain signals within specified
%   frequency bands using the inverse CWT (icwt).
%
%   [bandStore, t, cwtInfo] = continuousWaveletTransform(sds, Bands=bands)
%
%   Inputs:
%       sds - signalDatastore with one member per channel (e.g. from
%             readSourceSegment with AsDatastore=true). Must have a valid
%             SampleRate property.
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
%                         (default: auto from Bands). Restricts the scales
%                         computed, saving memory and time when only low
%                         frequencies are of interest (e.g. [1 60]).
%       Wavelet         - wavelet name: "morse" | "amor" | "bump"
%                         (default "morse")
%       VoicesPerOctave - number of voices per octave, 1–48 (default 12)
%       TimeBandwidth   - time-bandwidth product for Morse wavelet
%                         (default 60). Ignored for amor/bump.
%       IncludeSignalMean - if true, the first band in the output receives
%                         the signal mean added back. Otherwise all bands
%                         have SignalMean=0. (default false)
%       Verbose         - print progress (default true)
%
%   Outputs:
%       bandStore - signalDatastore with nChannels members. Each member is
%                   a [nSamples x nBands] matrix where column j is the
%                   time-domain reconstruction of band j via icwt.
%                   Column order matches cwtInfo.bandNames.
%                   SampleRate = input SampleRate.
%                   MemberNames = channel names from input.
%       t         - [nSamples x 1] time vector in seconds (0-based).
%                   Add segment tStart for absolute time.
%       cwtInfo   - struct with transform parameters and band definitions.
%                   Fields include: bandNames, bandRanges, freqVector,
%                   wavelet, voicesPerOctave, frequencyLimits, nScales,
%                   nChannels, nSamples, sfreq.
%
%   Notes:
%       - The CWT filterbank is built once and reused for all channels
%         (requires equal-length signals).
%       - Band frequency ranges are automatically clipped to the actual
%         frequency range of the filterbank. Bands entirely outside the
%         range produce zero columns.
%       - icwt reconstructions are NOT additive: the sum of band
%         reconstructions will not perfectly recover the original signal.
%         This is inherent to the CWT's redundant representation.
%       - For frequency-limited analysis (e.g. 1–60 Hz), set
%         FrequencyLimits to avoid computing coefficients for irrelevant
%         high-frequency scales.
%
%   Examples:
%       % Define bands and compute CWT band decomposition:
%       bands.delta = [1 4]; bands.theta = [4 8]; bands.alpha = [8 13];
%       bands.beta = [13 30]; bands.gamma = [30 60];
%       [bandStore, t, info] = continuousWaveletTransform(sds, Bands=bands);
%
%       % Read alpha band for first channel:
%       reset(bandStore);
%       bMat = read(bandStore);          % [nSamples x nBands]
%       alphaCol = info.bandNames == "alpha";
%       plot(t, bMat(:, alphaCol));
%       title('Alpha-band reconstruction (channel 1)');
%
%       % Full pipeline from raw MEG:
%       sm = loadBrainstorm('Z:\proto', LoadSourceMapping=true);
%       [sds, K] = readSourceSegment(sm, 0, 60, AsDatastore=true, Resample=600);
%       [bandStore, t, info] = continuousWaveletTransform(sds, Bands=bands);
%
%   See also: cwtfilterbank, cwt, icwt, powerSpectrumDensity, readSourceSegment

    arguments
        sds     (1,1) signalDatastore
        opts.Bands                                                   = []
        opts.FrequencyLimits                                         = []
        opts.Wavelet         (1,1) string {mustBeMember(opts.Wavelet, ...
                                   ["morse","amor","bump"])}         = "morse"
        opts.VoicesPerOctave (1,1) double {mustBePositive, ...
                                   mustBeInteger}                    = 12
        opts.TimeBandwidth   (1,1) double {mustBePositive}           = 60
        opts.IncludeSignalMean (1,1) logical                         = false
        opts.Verbose         (1,1) logical                           = true
    end

    % ---- Validate inputs ----
    if isempty(opts.Bands) || ~isstruct(opts.Bands)
        error('continuousWaveletTransform:NoBands', ...
            'Bands argument is required and must be a struct.');
    end

    fs = sds.SampleRate;
    if isempty(fs) || fs <= 0
        error('continuousWaveletTransform:NoSampleRate', ...
            'Input signalDatastore must have a valid SampleRate property.');
    end

    bands     = opts.Bands;
    bandNames = string(fieldnames(bands));
    nBands    = numel(bandNames);

    chanNames = sdsGetChannelNames(sds);
    nChans    = numel(chanNames);

    % ---- Determine FrequencyLimits ----
    if isempty(opts.FrequencyLimits)
        % Derive from band definitions: cover all bands
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

    % ---- Build filterbank (reused for all channels) ----
    fbArgs = {'SignalLength', N, ...
              'SamplingFrequency', fs, ...
              'FrequencyLimits', freqLimits, ...
              'VoicesPerOctave', opts.VoicesPerOctave};

    if lower(opts.Wavelet) == "morse"
        fbArgs = [fbArgs, {'TimeBandwidth', opts.TimeBandwidth}];
    end

    fb = cwtfilterbank(fbArgs{:});

    % Determine actual frequencies
    [~, fVec] = wt(fb, x1);
    fVec  = fVec(:);
    fMin  = min(fVec);
    fMax  = max(fVec);

    if opts.Verbose
        fprintf('continuousWaveletTransform: %d channels, %d samples (fs=%.1f Hz)\n', ...
            nChans, N, fs);
        fprintf('  Filterbank: %s wavelet, %d voices/octave, %d scales\n', ...
            opts.Wavelet, opts.VoicesPerOctave, numel(fVec));
        fprintf('  Frequency range: [%.2f–%.2f Hz]\n', fMin, fMax);
    end

    % ---- Pre-compute clipped band ranges ----
    clippedRanges = cell(nBands, 1);
    bandValid     = false(nBands, 1);

    for bi = 1:nBands
        br = bands.(bandNames(bi));
        clipped = [max(br(1), fMin), min(br(2), fMax)];
        if clipped(1) < clipped(2)
            clippedRanges{bi} = clipped;
            bandValid(bi) = true;
        else
            clippedRanges{bi} = [];
        end
    end

    if opts.Verbose
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
    end

    % ---- Process each channel ----
    chanCells = cell(nChans, 1);
    waveletName = opts.Wavelet;

    reset(sds);
    for ci = 1:nChans
        x = read(sds);
        if iscell(x), x = x{1}; end
        x = x(:);

        xMean = mean(x);

        % Compute CWT
        [cfs, ~] = wt(fb, x);

        % Reconstruct each band
        bMat = zeros(N, nBands);
        for bi = 1:nBands
            if ~bandValid(bi)
                continue;
            end

            % Determine SignalMean for this band
            if opts.IncludeSignalMean && bi == 1
                sigMean = xMean;
            else
                sigMean = 0;
            end

            xBand = icwt(cfs, waveletName, fVec, clippedRanges{bi}, ...
                'SignalMean', sigMean);
            bMat(:, bi) = xBand(:);
        end

        chanCells{ci} = bMat;

        if opts.Verbose && (ci <= 3 || ci == nChans || mod(ci, 50) == 0)
            fprintf('  Channel %d/%d (%s) done\n', ci, nChans, chanNames(ci));
        end
    end
    reset(sds);

    % ---- Build output signalDatastore (always in-memory) ----
    bandStore = signalDatastore(chanCells, 'SampleRate', fs);
    bandStore.MemberNames = chanNames(:);

    % ---- Time vector ----
    t = (0:N-1)' / fs;

    % ---- Info struct ----
    cwtInfo = struct();
    cwtInfo.mode             = "cwt_bands";
    cwtInfo.sfreq            = fs;
    cwtInfo.nSamples         = N;
    cwtInfo.nChannels        = nChans;
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
    cwtInfo.includeSignalMean = opts.IncludeSignalMean;

    if opts.Verbose
        fprintf('continuousWaveletTransform: complete. Output: %d channels × [%d × %d] (samples × bands)\n', ...
            nChans, N, nBands);
    end
end
