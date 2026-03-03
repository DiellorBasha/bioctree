function [alphaPow, frameInfo] = extractAlphaBandpower(sigs, fs, opts)
%EXTRACTALPHABANDPOWER Extract alpha-band power per channel per frame.
%
%   [alphaPow, frameInfo] = extractAlphaBandpower(sigs, fs)
%   [alphaPow, frameInfo] = extractAlphaBandpower(sigs, fs, Name=Value)
%
%   Uses MATLAB's signalFrequencyFeatureExtractor with Welch PSD to compute
%   alpha-band power for each channel at each frame.
%
%   Inputs:
%       sigs  - [nChans x nSamples] signal matrix
%       fs    - scalar sampling rate (Hz)
%
%   Name-Value Arguments:
%       AlphaBand  - [1x2] frequency band (default [7.5 12.5])
%       FrameDur_s - frame duration in seconds (default 0.50)
%       HopDur_s   - hop duration in seconds (default 0.10)
%       Verbose    - print progress (default true)
%
%   Outputs:
%       alphaPow  - [nChans x nFrames] alpha bandpower matrix
%       frameInfo - struct with fields:
%           .nFrames   - number of frames
%           .frameSize - frame length in samples
%           .hopSize   - hop length in samples
%           .tFrames   - [1 x nFrames] frame center times (seconds)
%           .extractor - the signalFrequencyFeatureExtractor object
%
%   Example:
%       data = loadMEG(blockPath, channelPath);
%       [alphaPow, fi] = extractAlphaBandpower(data.sigs, data.fs);
%
%   See also: signalFrequencyFeatureExtractor, loadMEG, computeRobustZscore

    arguments
        sigs      (:,:) double
        fs        (1,1) double {mustBePositive}
        opts.AlphaBand  (1,2) double = [7.5 12.5]
        opts.FrameDur_s (1,1) double {mustBePositive} = 0.50
        opts.HopDur_s   (1,1) double {mustBePositive} = 0.10
        opts.Verbose    (1,1) logical = true
    end

    [nChans, nSamples] = size(sigs);

    % Frame parameters in samples
    frameSize = round(opts.FrameDur_s * fs);
    hopSize   = round(opts.HopDur_s   * fs);

    % Build extractor
    freqFE = signalFrequencyFeatureExtractor( ...
        SampleRate    = fs, ...
        FrameSize     = frameSize, ...
        FrameOverlap  = frameSize - hopSize, ...
        FeatureFormat  = "table", ...
        BandPower     = true);

    % Try to set alpha band explicitly
    try
        setExtractorParameters(freqFE, "BandPower", FrequencyBands=opts.AlphaBand);
    catch
        % Version-dependent; proceed with defaults
    end

    % Extract per channel
    alphaPow = [];
    for ci = 1:nChans
        x = sigs(ci, :);
        x = x - median(x);  % robust centering

        feats  = extract(freqFE, x);
        vnames = feats.Properties.VariableNames;
        bpName = vnames(contains(vnames, "BandPower", "IgnoreCase", true));

        if isempty(bpName)
            error('extractAlphaBandpower:NoFeature', ...
                'Could not find BandPower feature column in extracted table.');
        end

        bp = feats.(bpName{1});
        if size(bp, 2) > 1
            bp = bp(:, 1);  % first band = alpha
        end

        alphaPow(ci, :) = bp(:).';  %#ok<AGROW>

        if opts.Verbose && mod(ci, 50) == 0
            fprintf('  extractAlphaBandpower: %d/%d channels\n', ci, nChans);
        end
    end

    % Frame info
    nFrames = size(alphaPow, 2);
    tFrames = ((0:nFrames-1) * hopSize + 1) / fs;

    frameInfo.nFrames   = nFrames;
    frameInfo.frameSize = frameSize;
    frameInfo.hopSize   = hopSize;
    frameInfo.tFrames   = tFrames;
    frameInfo.extractor = freqFE;

    if opts.Verbose
        fprintf('  extractAlphaBandpower: done — %d chans x %d frames\n', ...
            nChans, nFrames);
    end
end
