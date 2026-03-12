function [mat, chanNames, sfreq] = readCWTBand(cwtPath, bandName, opts)
%READCWTBAND Read one CWT band from saved datastore into [nChannels × nSamples].
%
%   [mat, chanNames, sfreq] = readCWTBand(cwtPath, bandName)
%   [mat, chanNames, sfreq] = readCWTBand(cwtPath, bandName, Name=Value)
%
%   Reads the CWT datastore saved by writeCWTDatastore and extracts a
%   single frequency band across all channels, returning a matrix suitable
%   for source mapping (K * mat).
%
%   Each file in the CWT datastore contains [nSamples × nBands] for one
%   channel. This function reads each file, extracts the column
%   corresponding to the requested band, and stacks them as rows.
%
%   Inputs:
%       cwtPath  - path to the CWT folder written by writeCWTDatastore,
%                  e.g. "Z:\...\sub-0004\cwt". Must contain
%                  provenance.mat and data/ subfolder.
%       bandName - name of the band to extract (e.g. "alpha", "beta").
%                  Must match one of the band names in the provenance.
%
%   Name-Value Arguments:
%       DataFolder - subfolder containing .mat files (default "data")
%       Verbose    - print progress (default false)
%
%   Outputs:
%       mat       - [nChannels × nSamples] double matrix for the band
%       chanNames - [nChannels × 1] string array of channel names
%       sfreq     - sampling frequency (Hz)
%
%   Examples:
%       % Read alpha band from CWT output
%       outPath = "Z:\brainstorm_protocols_analysis\TutorialOmega2\sub-0004";
%       [alphaCWT, chans, fs] = readCWTBand(fullfile(outPath, "cwt"), "alpha");
%       % alphaCWT: [270 × 180001]
%
%       % Source-map it
%       K = load(fullfile(outPath, "ImagingKernel.mat")).K;
%       alphaSource = K * alphaCWT;  % [10244 × 180001]
%
%       % Read all bands
%       cwtMeta = load(fullfile(outPath, "cwt", "provenance.mat"));
%       bands = cwtMeta.provenance.bandNames;
%       for bi = 1:numel(bands)
%           cwtBands.(bands(bi)) = readCWTBand(fullfile(outPath, "cwt"), bands(bi));
%       end
%
%   See also: writeCWTDatastore, readBandMatrix, continuousWaveletTransform

    arguments
        cwtPath  (1,1) string
        bandName (1,1) string
        opts.DataFolder (1,1) string  = "data"
        opts.Verbose    (1,1) logical = false
    end

    % ---- Load provenance ----
    provFile = fullfile(cwtPath, "provenance.mat");
    if ~isfile(provFile)
        error('readCWTBand:NoProvenance', ...
            'No provenance.mat found in: %s', cwtPath);
    end
    prov = load(provFile).provenance;
    sfreq = prov.sfreq;

    % ---- Resolve band column index ----
    bandNames = string(prov.bandNames);
    bandIdx = find(strcmpi(bandNames, bandName), 1);
    if isempty(bandIdx)
        error('readCWTBand:BadBand', ...
            'Band "%s" not found. Available bands: %s', ...
            bandName, strjoin(bandNames, ", "));
    end

    % ---- Create datastore ----
    dataDir = fullfile(cwtPath, opts.DataFolder);
    if ~isfolder(dataDir)
        error('readCWTBand:NoData', ...
            'Data folder not found: %s', dataDir);
    end

    sds = signalDatastore(dataDir, SampleRate=sfreq);
    chanNames = sdsGetChannelNames(sds);
    nChannels = numel(chanNames);

    % ---- Read and extract the band column ----
    reset(sds);

    if opts.Verbose
        fprintf('readCWTBand: reading "%s" (column %d/%d) from %d channels\n', ...
            bandName, bandIdx, numel(bandNames), nChannels);
    end

    mat = [];
    ci = 0;
    while hasdata(sds)
        [x, info] = read(sds);
        if iscell(x), x = x{1}; end
        ci = ci + 1;

        % Pre-allocate on first read (now we know nSamples)
        if ci == 1
            nSamples = size(x, 1);
            mat = zeros(nChannels, nSamples);
        end

        mat(ci, :) = x(:, bandIdx)';

        if opts.Verbose && (ci <= 3 || mod(ci, 50) == 0 || ci == nChannels)
            fprintf('  channel %d/%d (%s)\n', ci, nChannels, chanNames(ci));
        end
    end

    reset(sds);

    if opts.Verbose
        fprintf('readCWTBand: complete → [%d × %d]\n', nChannels, nSamples);
    end
end
