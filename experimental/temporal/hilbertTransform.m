function [tds, hilbertInfo] = hilbertTransform(sds, opts)
%HILBERTTRANSFORM Lazy Hilbert amplitude & phase via datastore transform.
%
%   [tds, hilbertInfo] = hilbertTransform(sds)
%   [tds, hilbertInfo] = hilbertTransform(sds, Name=Value)
%
%   Creates a TransformedDatastore that lazily computes the analytic signal
%   (Hilbert transform) for each channel as it is read, extracting the
%   instantaneous amplitude envelope and phase.
%
%   Designed to chain after CWT band output: input is a signalDatastore
%   where each member is [nSamples x nBands], and output is
%   [nSamples x 2*nBands] with amplitude columns followed by phase columns.
%
%   Inputs:
%       sds - signalDatastore (in-memory or file-based). Each member can be:
%             - [nSamples x nBands] from CWT band decomposition
%             - [nSamples x 1] single-channel signal
%             Must have a valid SampleRate.
%
%   Name-Value Arguments:
%       ScaleFactor - multiplicative scale applied before Hilbert transform
%                     (default 1e12). For MEG source data in A·m, this
%                     converts to fT-scale for numerical stability.
%                     Set to 1 if data is already in desired units.
%       BandNames   - string array of band names matching columns of each
%                     member (default []). If provided, output info will
%                     use these names (e.g. ["delta","theta","alpha",...]).
%                     If empty, names are auto-generated ("band1","band2",...).
%       Verbose     - print summary (default true)
%
%   Outputs:
%       tds         - TransformedDatastore. Each read() returns:
%                       data - [nSamples x 2*nBands] matrix
%                              Columns 1:nBands       = amplitude (abs of analytic signal)
%                              Columns (nBands+1):end  = phase (angle, in radians)
%                       info - struct with:
%                              .BandNames     — band names
%                              .AmplitudeCols — indices 1:nBands
%                              .PhaseCols     — indices (nBands+1):(2*nBands)
%                              .ColumnNames   — ["amp_delta",...,"phase_delta",...]
%                              .ScaleFactor   — scaling applied
%
%       hilbertInfo - summary struct:
%                       .mode, .sfreq, .nSamples, .nBands, .nOutputColumns,
%                       .bandNames, .amplitudeCols, .phaseCols,
%                       .columnNames, .scaleFactor
%
%   Usage:
%       % --- From saved CWT output ---
%       cwtMeta = load(fullfile(outPath, "cwt", "provenance.mat"));
%       cwtStore = signalDatastore(fullfile(outPath, "cwt", "data"), ...
%           SampleRate=cwtMeta.provenance.sfreq);
%
%       [hTds, hInfo] = hilbertTransform(cwtStore, ...
%           BandNames=cwtMeta.provenance.bandNames);
%
%       % Read amplitude & phase for first channel:
%       reset(hTds);
%       [hMat, chInfo] = read(hTds);
%       amp   = hMat(:, chInfo.AmplitudeCols);   % [N x nBands]
%       phase = hMat(:, chInfo.PhaseCols);        % [N x nBands]
%
%       % --- Compose with CWT transform (fully lazy pipeline) ---
%       [cwtTds, t, cwtInfo] = cwtBandTransform(sds, Bands=bands);
%       [hTds, hInfo] = hilbertTransform(cwtTds, ...
%           BandNames=cwtInfo.bandNames);
%       % hTds is a double-transformed datastore: raw → CWT → Hilbert
%
%       % --- Read all at once ---
%       allData = readall(hTds);  % cell array, each [N x 2*nBands]
%
%   Notes:
%       - MATLAB's hilbert() operates column-wise, so all bands are
%         processed in one call per channel (efficient).
%       - The ScaleFactor is applied BEFORE the Hilbert transform.
%         Original data is not modified (lazy evaluation).
%       - Phase is in radians (-pi to pi). Use unwrap() downstream
%         if continuous phase is needed.
%       - Amplitude is the envelope of the analytic signal, equivalent
%         to the magnitude of the complex Hilbert output.
%
%   See also: applyHilbert, hilbert, cwtBandTransform, continuousWaveletTransform,
%             writeCWTDatastore

    arguments
        sds     (1,1)
        opts.ScaleFactor (1,1) double  = 1e12
        opts.BandNames                 = []
        opts.Verbose     (1,1) logical = true
    end

    fs = sds.SampleRate;
    if isempty(fs) || fs <= 0
        error('hilbertTransform:NoSampleRate', ...
            'Input signalDatastore must have a valid SampleRate property.');
    end

    % ---- Peek at first member to determine dimensions ----
    reset(sds);
    x1 = read(sds);
    if iscell(x1), x1 = x1{1}; end
    nSamples = size(x1, 1);
    nBands   = size(x1, 2);
    reset(sds);

    % ---- Band names ----
    if ~isempty(opts.BandNames)
        bandNames = string(opts.BandNames(:));
        if numel(bandNames) ~= nBands
            error('hilbertTransform:BandNamesMismatch', ...
                'BandNames has %d elements but data has %d columns.', ...
                numel(bandNames), nBands);
        end
    else
        bandNames = "band" + (1:nBands)';
    end

    % ---- Build config struct for the transform function ----
    config = struct();
    config.scaleFactor = opts.ScaleFactor;
    config.bandNames   = bandNames;

    % ---- Create TransformedDatastore ----
    tds = transform(sds, @(dataIn, info) applyHilbert(dataIn, info, config), ...
        'IncludeInfo', true);

    % ---- Build column name arrays ----
    ampNames   = "amp_"   + bandNames;
    phaseNames = "phase_" + bandNames;
    columnNames = [ampNames; phaseNames];

    % ---- Info struct ----
    hilbertInfo = struct();
    hilbertInfo.mode           = "hilbert_transform";
    hilbertInfo.sfreq          = fs;
    hilbertInfo.nSamples       = nSamples;
    hilbertInfo.nBands         = nBands;
    hilbertInfo.nOutputColumns = 2 * nBands;
    hilbertInfo.bandNames      = bandNames;
    hilbertInfo.amplitudeCols  = 1:nBands;
    hilbertInfo.phaseCols      = (nBands+1):(2*nBands);
    hilbertInfo.columnNames    = columnNames;
    hilbertInfo.scaleFactor    = opts.ScaleFactor;

    if opts.Verbose
        chanNames = sdsGetChannelNames(sds);
        nChans = numel(chanNames);
        fprintf('hilbertTransform: %d channels, %d samples (fs=%.1f Hz)\n', ...
            nChans, nSamples, fs);
        fprintf('  Input:  [%d × %d] per channel (%d bands)\n', ...
            nSamples, nBands, nBands);
        fprintf('  Output: [%d × %d] per channel (amplitude + phase)\n', ...
            nSamples, 2*nBands);
        fprintf('  Scale factor: %.0e\n', opts.ScaleFactor);
        fprintf('  Bands: %s\n', strjoin(bandNames, ", "));
        fprintf('  Columns: %s\n', strjoin(columnNames, ", "));
        fprintf('  Mode: lazy TransformedDatastore (channels processed on read)\n');
    end
end
