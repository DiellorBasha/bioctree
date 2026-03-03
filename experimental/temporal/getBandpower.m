function [bp, bpInfo] = getBandpower(sigs, fs, opts)
%GETBANDPOWER Compute bandpower in specified frequency bands using Welch PSD.
%
%   [bp, bpInfo] = getBandpower(sigs, fs)
%   [bp, bpInfo] = getBandpower(sigs, fs, Name=Value)
%
%   Computes bandpower via MATLAB's bandpower() with the "psd" option in
%   sliding windows. Returns power in user-specified frequency bands
%   (default: delta, alpha, beta) for each channel and window.
%
%   Inputs:
%       sigs - [nChans x nSamples] signal matrix
%       fs   - scalar sampling rate (Hz)
%
%   Name-Value Arguments:
%       Bands        - struct array with fields .name and .range (default:
%                       delta [1 4], alpha [7.5 12.5], beta [13 30])
%       WindowDur_s  - window duration in seconds (default 4)
%       HopDur_s     - hop / stride in seconds (default 1)
%       Verbose      - print progress (default true)
%
%   Outputs:
%       bp     - struct with one field per band name, each [nChans x nWindows]
%       bpInfo - struct with fields:
%           .nWindows   - number of windows
%           .windowSize - window length in samples
%           .hopSize    - hop length in samples
%           .tWindows   - [1 x nWindows] window center times (seconds)
%           .bands      - the band definitions used
%           .fs         - sampling rate
%
%   The bandpower is computed using MATLAB's bandpower(x, fs, freqrange)
%   which internally estimates the PSD via Welch's method ("psd" option).
%
%   Example:
%       data = loadMEG(blockPath, channelPath);
%       [bp, bpInfo] = getBandpower(data.sigs, data.fs);
%       % bp.alpha is [nChans x nWindows]
%
%       % Custom bands and 2-second windows:
%       bands(1) = struct('name','theta','range',[4 8]);
%       bands(2) = struct('name','alpha','range',[8 13]);
%       [bp, bpInfo] = getBandpower(data.sigs, data.fs, Bands=bands, WindowDur_s=2);
%
%   See also: bandpower, extractAlphaBandpower, loadMEG

    arguments
        sigs         (:,:) double
        fs           (1,1) double {mustBePositive}
        opts.Bands          = []
        opts.WindowDur_s (1,1) double {mustBePositive} = 4
        opts.HopDur_s    (1,1) double {mustBePositive} = 1
        opts.Verbose     (1,1) logical = true
    end

    % ---- Default bands ----
    if isempty(opts.Bands)
        bands(1) = struct('name', 'delta', 'range', [1 4]);
        bands(2) = struct('name', 'alpha', 'range', [7.5 12.5]);
        bands(3) = struct('name', 'beta',  'range', [13 30]);
    else
        bands = opts.Bands;
    end

    nBands = numel(bands);

    [nChans, nSamples] = size(sigs);

    % ---- Window parameters ----
    windowSize = round(opts.WindowDur_s * fs);
    hopSize    = round(opts.HopDur_s * fs);

    % Number of complete windows
    nWindows = floor((nSamples - windowSize) / hopSize) + 1;

    if nWindows < 1
        error('getBandpower:ShortSignal', ...
            'Signal too short (%.2f s) for window duration %.2f s.', ...
            nSamples / fs, opts.WindowDur_s);
    end

    % Window start indices (1-based)
    winStarts = (0:nWindows-1) * hopSize + 1;

    % Window center times (seconds)
    tWindows = (winStarts - 1 + windowSize / 2) / fs;

    % ---- Preallocate ----
    bpArrays = zeros(nBands, nChans, nWindows);

    % ---- Compute bandpower per channel per window ----
    for ci = 1:nChans
        for wi = 1:nWindows
            s0 = winStarts(wi);
            s1 = s0 + windowSize - 1;
            seg = sigs(ci, s0:s1);

            for bi = 1:nBands
                bpArrays(bi, ci, wi) = bandpower(seg, fs, bands(bi).range);
            end
        end

        if opts.Verbose && mod(ci, 50) == 0
            fprintf('  getBandpower: %d/%d channels\n', ci, nChans);
        end
    end

    % ---- Pack output ----
    bp = struct();
    for bi = 1:nBands
        bp.(bands(bi).name) = squeeze(bpArrays(bi, :, :));  % [nChans x nWindows]
    end

    bpInfo.nWindows   = nWindows;
    bpInfo.windowSize = windowSize;
    bpInfo.hopSize    = hopSize;
    bpInfo.tWindows   = tWindows;
    bpInfo.bands      = bands;
    bpInfo.fs         = fs;

    if opts.Verbose
        fprintf('  getBandpower: done — %d chans x %d windows x %d bands\n', ...
            nChans, nWindows, nBands);
    end
end
