function cwtBandsPath = writeCWTBands(cwtPath, parentPath, opts)
%WRITECWTBANDS Write per-band CWT signed data to disk for fast retrieval.
%
%   cwtBandsPath = writeCWTBands(cwtPath, parentPath)
%   cwtBandsPath = writeCWTBands(cwtPath, parentPath, Name=Value)
%
%   Reads the CWT datastore written by writeCWTDatastore (where each
%   channel file is [nSamples × nBands]) and rewrites it as per-band
%   folders of per-channel [nSamples × 1] .mat files — the same layout
%   used by writeHilbertBands. This allows instant retrieval of any
%   band as a signalDatastore without re-reading all bands.
%
%   Folder layout (created under parentPath):
%       parentPath/
%         cwt_bands/                  — (or custom Subfolder)
%           provenance.mat            — CWT-bands provenance struct
%           delta/                    — one folder per band
%             MLC11.mat               — [nSamples × 1] signed CWT
%             MLC12.mat
%             ...
%           theta/
%           alpha/
%           beta/
%           gamma/
%
%   Inputs:
%       cwtPath    - path to the CWT folder written by writeCWTDatastore,
%                    e.g. "Z:\...\sub-0004\cwt". Must contain
%                    provenance.mat and data/ subfolder.
%       parentPath - subject folder (output of writeSourceDatastore), e.g.
%                    "Z:\...\sub-0004". Must contain provenance.mat.
%
%   Name-Value Arguments:
%       Subfolder  - name of subfolder under parentPath (default "cwt_bands")
%       Bands      - string array of band names to write (default: all)
%       DataFolder - subfolder in cwtPath containing .mat files (default "data")
%       Tag        - optional string tag for disambiguation (default "")
%       Overwrite  - overwrite existing folder (default false)
%       Verbose    - print progress (default true)
%
%   Output:
%       cwtBandsPath - full path to the created CWT bands folder.
%
%   Reload pattern:
%       % Read provenance
%       meta = load(fullfile(cwtBandsPath, "provenance.mat")).provenance;
%       sfreq = meta.sfreq;
%       bandNames = meta.bandNames;
%
%       % Load alpha band (all channels) as [nChannels × nSamples]
%       sds_alpha = signalDatastore( ...
%           fullfile(cwtBandsPath, "alpha"), SampleRate=sfreq);
%       [alphaCWT, chanNames, fs] = readBandMatrix(sds_alpha);
%
%       % Source-map (signed → correct for downstream Hilbert)
%       alphaSource = WK * alphaCWT;  % [20484 × nSamples]
%
%       % Load all bands into struct
%       for bi = 1:numel(bandNames)
%           sds = signalDatastore( ...
%               fullfile(cwtBandsPath, bandNames(bi)), SampleRate=sfreq);
%           cwtBands.(bandNames(bi)) = readBandMatrix(sds);
%       end
%
%   See also: writeCWTDatastore, readCWTBand, readBandMatrix,
%             writeHilbertBands, buildSpectralProjection

    arguments
        cwtPath    (1,1) string
        parentPath (1,1) string
        opts.Subfolder  (1,1) string  = "cwt_bands"
        opts.Bands      (:,1) string  = string.empty
        opts.DataFolder (1,1) string  = "data"
        opts.Tag        (1,1) string  = ""
        opts.Overwrite  (1,1) logical = false
        opts.Verbose    (1,1) logical = true
    end

    % ---- Validate inputs ----
    if ~isfolder(cwtPath)
        error('writeCWTBands:NoCWT', 'CWT path not found: %s', cwtPath);
    end

    cwtProvFile = fullfile(cwtPath, "provenance.mat");
    if ~isfile(cwtProvFile)
        error('writeCWTBands:NoProvenance', ...
            'No provenance.mat in CWT path: %s', cwtPath);
    end

    if ~isfolder(parentPath)
        error('writeCWTBands:NoParent', ...
            'Parent path not found: %s', parentPath);
    end

    parentProvFile = fullfile(parentPath, "provenance.mat");
    if ~isfile(parentProvFile)
        error('writeCWTBands:NoParentProv', ...
            'No provenance.mat in parent path: %s', parentPath);
    end

    % ---- Load provenances ----
    cwtProv    = load(cwtProvFile).provenance;
    parentProv = load(parentProvFile).provenance;

    sfreq      = cwtProv.sfreq;
    allBands   = string(cwtProv.bandNames(:));
    chanNames  = string(cwtProv.channelNames(:));
    nChannels  = cwtProv.nChannels;

    % ---- Resolve which bands to write ----
    if isempty(opts.Bands)
        bandsToWrite = allBands;
    else
        % Validate requested bands
        for bi = 1:numel(opts.Bands)
            if ~any(strcmpi(allBands, opts.Bands(bi)))
                error('writeCWTBands:BadBand', ...
                    'Band "%s" not found. Available: %s', ...
                    opts.Bands(bi), strjoin(allBands, ", "));
            end
        end
        bandsToWrite = opts.Bands;
    end
    nBands = numel(bandsToWrite);

    % ---- Determine output path ----
    subfolderName = opts.Subfolder;
    if opts.Tag ~= ""
        subfolderName = subfolderName + "_" + opts.Tag;
    end
    cwtBandsPath = fullfile(parentPath, subfolderName);

    % ---- Handle existing folder ----
    if isfolder(cwtBandsPath)
        if opts.Overwrite
            if opts.Verbose
                fprintf('writeCWTBands: overwriting %s\n', cwtBandsPath);
            end
            rmdir(cwtBandsPath, 's');
        else
            error('writeCWTBands:FolderExists', ...
                'Output folder already exists: %s\nUse Overwrite=true to replace.', ...
                cwtBandsPath);
        end
    end

    mkdir(cwtBandsPath);

    % ---- Create datastore for the raw CWT data ----
    dataDir = fullfile(cwtPath, opts.DataFolder);
    if ~isfolder(dataDir)
        error('writeCWTBands:NoData', 'Data folder not found: %s', dataDir);
    end

    sds = signalDatastore(dataDir, SampleRate=sfreq);

    % ---- Build band-column mapping ----
    bandColIdx = zeros(nBands, 1);
    for bi = 1:nBands
        idx = find(strcmpi(allBands, bandsToWrite(bi)), 1);
        bandColIdx(bi) = idx;
    end

    % ---- Read all channels, extract bands, write per-band files ----
    %  Strategy: read each channel file once, split into band columns,
    %  accumulate in memory per band, then write all at once per band.
    %  This is I/O-efficient (one pass through the datastore).

    if opts.Verbose
        fprintf('writeCWTBands: reading %d channels × %d bands from %s\n', ...
            nChannels, nBands, dataDir);
    end

    % Pre-read first channel to get nSamples
    reset(sds);
    [x0, ~] = read(sds);
    if iscell(x0), x0 = x0{1}; end
    nSamples = size(x0, 1);
    reset(sds);

    % Pre-allocate per-band matrices [nChannels × nSamples]
    bandData = struct();
    for bi = 1:nBands
        bandData.(bandsToWrite(bi)) = zeros(nChannels, nSamples);
    end

    % Read all channels
    ci = 0;
    while hasdata(sds)
        [x, ~] = read(sds);
        if iscell(x), x = x{1}; end
        ci = ci + 1;

        for bi = 1:nBands
            bandData.(bandsToWrite(bi))(ci, :) = x(:, bandColIdx(bi))';
        end

        if opts.Verbose && (ci <= 3 || mod(ci, 50) == 0 || ci == nChannels)
            fprintf('  read channel %d/%d (%s)\n', ci, nChannels, chanNames(ci));
        end
    end
    reset(sds);

    % ---- Write per-band folders ----
    if opts.Verbose
        fprintf('writeCWTBands: writing %d bands × %d channels\n', nBands, nChannels);
    end

    for bi = 1:nBands
        bn = bandsToWrite(bi);
        bandDir = fullfile(cwtBandsPath, bn);
        mkdir(bandDir);

        mat = bandData.(bn);  % [nChannels × nSamples]

        % Build per-channel cell array of column vectors
        cells = cell(nChannels, 1);
        for ci = 1:nChannels
            cells{ci} = mat(ci, :)';  % [nSamples × 1]
        end

        tmpSds = signalDatastore(cells, 'SampleRate', sfreq);
        tmpSds.MemberNames = chanNames;
        writeall(tmpSds, bandDir);

        if opts.Verbose
            fprintf('  %-8s: [%d × %d] → %s\n', bn, nChannels, nSamples, bandDir);
        end
    end

    % ---- Build provenance ----
    provenance = struct();
    provenance.mode             = "cwt_bands_split";
    provenance.parentPath       = string(parentPath);
    provenance.parentProvenance = parentProv;
    provenance.cwtProvenance    = cwtProv;
    provenance.cwtPath          = string(cwtPath);

    % Inherit subject name
    if isfield(parentProv, 'subjectName')
        provenance.subjectName = parentProv.subjectName;
    elseif isfield(cwtProv, 'subjectName')
        provenance.subjectName = cwtProv.subjectName;
    else
        provenance.subjectName = "unknown";
    end

    % Band & channel info
    provenance.nChannels    = nChannels;
    provenance.channelNames = chanNames;
    provenance.sfreq        = sfreq;
    provenance.nSamples     = nSamples;
    provenance.duration     = nSamples / sfreq;
    provenance.nBands       = nBands;
    provenance.bandNames    = bandsToWrite;

    % Inherit CWT parameters
    fieldsToInherit = {'bandRanges', 'clippedRanges', 'bandValid', ...
        'frequencyLimits', 'wavelet', 'voicesPerOctave', 'nScales', ...
        'timeBandwidth', 'scaleFactor'};
    for fi = 1:numel(fieldsToInherit)
        fn = fieldsToInherit{fi};
        if isfield(cwtProv, fn)
            provenance.(fn) = cwtProv.(fn);
        end
    end

    % Metadata
    provenance.subfolder     = subfolderName;
    provenance.tag           = opts.Tag;
    provenance.createdOn     = string(datetime("now", "Format", "yyyy-MM-dd HH:mm:ss"));
    provenance.matlabVersion = string(version);

    % ---- Save provenance ----
    provFile = fullfile(cwtBandsPath, "provenance.mat");
    save(provFile, 'provenance', '-v7.3');

    % ---- Summary ----
    if opts.Verbose
        nFiles = nBands * nChannels;
        totalGB = nFiles * nSamples * 8 / 1e9;

        fprintf('writeCWTBands: complete → %s\n', cwtBandsPath);
        fprintf('  Subject:     %s\n', provenance.subjectName);
        fprintf('  Channels:    %d\n', nChannels);
        fprintf('  Samples:     %d (%.2f s at %.1f Hz)\n', ...
            nSamples, nSamples/sfreq, sfreq);
        fprintf('  Bands:       %d [%s]\n', nBands, strjoin(bandsToWrite, ", "));
        fprintf('  Files:       %d (.mat per channel per band)\n', nFiles);
        fprintf('  Est. size:   %.2f GB\n', totalGB);
    end
end
