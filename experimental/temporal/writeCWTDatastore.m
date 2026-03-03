function cwtPath = writeCWTDatastore(bandStore, cwtInfo, parentPath, opts)
%WRITECWTDATASTORE Write CWT band datastore to disk with provenance.
%
%   cwtPath = writeCWTDatastore(bandStore, cwtInfo, parentPath)
%   cwtPath = writeCWTDatastore(bandStore, cwtInfo, parentPath, Name=Value)
%
%   Saves the output of continuousWaveletTransform to a structured folder
%   under parentPath (the subject folder created by writeSourceDatastore).
%   Inherits provenance from the parent sensor data, and records all CWT
%   parameters so the transform can be exactly reproduced or reloaded.
%
%   Folder layout (created under parentPath):
%       parentPath/
%         cwt/                    — (or custom Subfolder)
%           provenance.mat        — CWT provenance struct (see below)
%           data/                 — writeall output (one .mat per channel)
%             MLC11.mat           — [nSamples x nBands] matrix
%             MLC12.mat
%             ...
%
%   Inputs:
%       bandStore  - signalDatastore from continuousWaveletTransform.
%                    Each member is [nSamples x nBands] for one channel.
%       cwtInfo    - info struct from continuousWaveletTransform. Contains
%                    band names, frequency ranges, wavelet parameters.
%       parentPath - path to the subject folder (output of
%                    writeSourceDatastore), e.g.:
%                    "Z:\brainstorm_protocols_analysis\TutorialOmega2\sub-0002"
%                    Must contain provenance.mat. The parent provenance is
%                    loaded and linked in the CWT provenance.
%
%   Name-Value Arguments:
%       Subfolder  - name of subfolder under parentPath (default "cwt").
%                    Allows multiple CWT runs (e.g. "cwt_1_60", "cwt_1_30").
%       Tag        - optional string tag for disambiguation (default "")
%       Overwrite  - overwrite existing folder (default false)
%       Verbose    - print progress (default true)
%
%   Output:
%       cwtPath - full path to the created CWT folder,
%                 e.g. "Z:\...\sub-0002\cwt"
%
%   CWT Provenance (saved in provenance.mat as struct 'provenance'):
%       .mode               - "cwt_bands"
%       .parentPath         - absolute path to the parent subject folder
%       .parentProvenance   - full parent provenance struct (copied)
%       .subjectName        - inherited from parent
%       .nChannels          - number of channels
%       .channelNames       - [nChannels x 1] string array
%       .sfreq              - sampling frequency
%       .nSamples           - number of time samples per channel
%       .nBands             - number of frequency bands
%       .bandNames          - [nBands x 1] string array (column order)
%       .bandRanges         - struct with each band's [fLow fHigh] (Hz)
%       .clippedRanges      - actual ranges after filterbank clipping
%       .bandValid          - [nBands x 1] logical (bands within range)
%       .wavelet            - wavelet name ("morse", "amor", "bump")
%       .voicesPerOctave    - voices per octave
%       .frequencyLimits    - [fLow fHigh] Hz of filterbank
%       .nScales            - number of CWT scales
%       .timeBandwidth      - Morse wavelet parameter (if applicable)
%       .includeSignalMean  - whether signal mean was added to first band
%       .subfolder          - subfolder name
%       .tag                - user tag
%       .createdOn          - datetime string
%       .matlabVersion      - MATLAB version
%
%   Examples:
%       % --- Save CWT output ---
%       outPath = "Z:\brainstorm_protocols_analysis\TutorialOmega2\sub-0002";
%       meta = load(fullfile(outPath, "provenance.mat"));
%       sds2 = signalDatastore(fullfile(outPath, "sensor"), ...
%           SampleRate=meta.provenance.sfreq);
%
%       bands.delta = [1 4]; bands.theta = [4 8]; bands.alpha = [8 13];
%       bands.beta = [13 30]; bands.gamma = [30 60];
%       [bandStore, t, cwtInfo] = continuousWaveletTransform(sds2, ...
%           Bands=bands, FrequencyLimits=[1 60]);
%
%       cwtPath = writeCWTDatastore(bandStore, cwtInfo, outPath);
%
%       % --- Reload later ---
%       cwtMeta = load(fullfile(outPath, "cwt", "provenance.mat"));
%       bandStore2 = signalDatastore(fullfile(outPath, "cwt", "data"), ...
%           SampleRate=cwtMeta.provenance.sfreq);
%       info2 = cwtMeta.provenance;
%       % Each read(bandStore2) returns [nSamples x nBands]
%       % Column order is info2.bandNames
%
%       % --- Multiple CWT runs with different parameters ---
%       cwtPath1 = writeCWTDatastore(bandStore, cwtInfo, outPath, ...
%           Subfolder="cwt_1_60");
%       cwtPath2 = writeCWTDatastore(bandStore2, cwtInfo2, outPath, ...
%           Subfolder="cwt_4_30");
%
%   See also: continuousWaveletTransform, writeSourceDatastore,
%             cwtBandTransform, signalDatastore/writeall

    arguments
        bandStore  (1,1) signalDatastore
        cwtInfo    (1,1) struct
        parentPath (1,1) string
        opts.Subfolder (1,1) string  = "cwt"
        opts.Tag       (1,1) string  = ""
        opts.Overwrite (1,1) logical = false
        opts.Verbose   (1,1) logical = true
    end

    % ---- Validate parentPath ----
    if ~isfolder(parentPath)
        error('writeCWTDatastore:NoParent', ...
            'Parent path does not exist: %s', parentPath);
    end

    parentProvFile = fullfile(parentPath, "provenance.mat");
    if ~isfile(parentProvFile)
        error('writeCWTDatastore:NoProvenance', ...
            'No provenance.mat found in parent path: %s\nExpected output of writeSourceDatastore.', ...
            parentPath);
    end

    % ---- Load parent provenance ----
    parentMeta = load(parentProvFile);
    parentProv = parentMeta.provenance;

    % ---- Determine subfolder name ----
    subfolderName = opts.Subfolder;
    if opts.Tag ~= ""
        subfolderName = subfolderName + "_" + opts.Tag;
    end

    cwtPath = fullfile(parentPath, subfolderName);
    dataDir = fullfile(cwtPath, "data");

    % ---- Handle existing folder ----
    if isfolder(cwtPath)
        if opts.Overwrite
            if opts.Verbose
                fprintf('writeCWTDatastore: overwriting %s\n', cwtPath);
            end
            rmdir(cwtPath, 's');
        else
            error('writeCWTDatastore:FolderExists', ...
                'CWT folder already exists: %s\nUse Overwrite=true to replace.', cwtPath);
        end
    end

    % ---- Create directories ----
    mkdir(cwtPath);
    mkdir(dataDir);

    % ---- Channel info ----
    chanNames = sdsGetChannelNames(bandStore);
    nChannels = numel(chanNames);
    sfreq     = bandStore.SampleRate;

    % Determine nSamples from first member
    reset(bandStore);
    xSample = read(bandStore);
    if iscell(xSample), xSample = xSample{1}; end
    nSamples = size(xSample, 1);
    nBandsCols = size(xSample, 2);
    reset(bandStore);

    % ---- Write band data ----
    if opts.Verbose
        fprintf('writeCWTDatastore: writing %d channels to %s\n', ...
            nChannels, dataDir);
        fprintf('  Each channel: [%d samples × %d bands]\n', nSamples, nBandsCols);
    end
    writeall(bandStore, dataDir);

    % ---- Build CWT provenance ----
    provenance = struct();
    provenance.mode              = "cwt_bands";
    provenance.parentPath        = string(parentPath);
    provenance.parentProvenance  = parentProv;

    % Inherit subject name from parent
    if isfield(parentProv, 'subjectName')
        provenance.subjectName = parentProv.subjectName;
    else
        provenance.subjectName = "unknown";
    end

    % Channel and signal info
    provenance.nChannels    = nChannels;
    provenance.channelNames = chanNames(:);
    provenance.sfreq        = sfreq;
    provenance.nSamples     = nSamples;
    provenance.duration     = nSamples / sfreq;

    % Band info from cwtInfo
    if isfield(cwtInfo, 'nBands')
        provenance.nBands = cwtInfo.nBands;
    else
        provenance.nBands = nBandsCols;
    end

    fieldsToInherit = { ...
        'bandNames', 'bandRanges', 'clippedRanges', 'bandValid', ...
        'freqVector', 'frequencyLimits', 'nScales', ...
        'wavelet', 'voicesPerOctave', 'timeBandwidth', ...
        'includeSignalMean'};

    for fi = 1:numel(fieldsToInherit)
        fn = fieldsToInherit{fi};
        if isfield(cwtInfo, fn)
            provenance.(fn) = cwtInfo.(fn);
        end
    end

    % Metadata
    provenance.subfolder    = subfolderName;
    provenance.tag          = opts.Tag;
    provenance.createdOn    = string(datetime("now", "Format", "yyyy-MM-dd HH:mm:ss"));
    provenance.matlabVersion = string(version);

    % ---- Save provenance ----
    provFile = fullfile(cwtPath, "provenance.mat");
    save(provFile, 'provenance', '-v7.3');

    % ---- Summary ----
    if opts.Verbose
        fprintf('writeCWTDatastore: complete → %s\n', cwtPath);
        fprintf('  Subject:    %s\n', provenance.subjectName);
        fprintf('  Channels:   %d\n', nChannels);
        fprintf('  Samples:    %d (%.2f s at %.1f Hz)\n', nSamples, nSamples/sfreq, sfreq);
        fprintf('  Bands:      %d [%s]\n', provenance.nBands, ...
            strjoin(provenance.bandNames, ", "));
        fprintf('  Wavelet:    %s, %d voices/octave, %d scales\n', ...
            provenance.wavelet, provenance.voicesPerOctave, provenance.nScales);
        fprintf('  Freq range: [%.1f–%.1f Hz]\n', ...
            provenance.frequencyLimits(1), provenance.frequencyLimits(2));
        fprintf('  Parent:     %s\n', parentPath);
    end
end
