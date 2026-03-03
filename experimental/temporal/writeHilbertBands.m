function hilbertPath = writeHilbertBands(amplitude, phase, bandInfo, parentPath, opts)
%WRITEHILBERTBANDS Write per-band Hilbert amplitude & phase to disk.
%
%   hilbertPath = writeHilbertBands(amplitude, phase, bandInfo, parentPath)
%   hilbertPath = writeHilbertBands(..., Name=Value)
%
%   Saves the output of readHilbertBands to a structured folder under
%   parentPath (the subject folder from writeSourceDatastore). Each band
%   is saved as a folder of per-channel .mat files via writeall, so it
%   can be reloaded directly as a signalDatastore for source mapping.
%
%   Folder layout (created under parentPath):
%       parentPath/
%         hilbert/                       — (or custom Subfolder)
%           provenance.mat               — Hilbert provenance struct
%           amplitude/
%             delta/                     — one folder per band
%               MLC11.mat               — [nSamples x 1] column vector
%               MLC12.mat
%               ...
%             theta/
%             alpha/
%             beta/
%             gamma/
%           phase/
%             delta/
%             theta/
%             ...
%
%   Inputs:
%       amplitude  - struct from readHilbertBands. Each field is a band
%                    name mapping to [nChannels x nSamples] matrix.
%       phase      - struct with same layout, containing instantaneous
%                    phase in radians.
%       bandInfo   - info struct from readHilbertBands. Must contain:
%                    .bandNames, .channelNames, .nChannels, .nSamples,
%                    .nBands, .sfreq
%       parentPath - subject folder (output of writeSourceDatastore), e.g.
%                    "Z:\brainstorm_protocols_analysis\TutorialOmega2\sub-0002"
%                    Must contain provenance.mat.
%
%   Name-Value Arguments:
%       Subfolder   - name of subfolder under parentPath (default "hilbert")
%       ScaleFactor - the scaling applied during hilbertTransform
%                     (default 1e12). Recorded in provenance.
%       Tag         - optional string tag for disambiguation (default "")
%       Overwrite   - overwrite existing folder (default false)
%       SavePhase   - save phase data too (default true). Set false to
%                     skip phase and save only amplitude (halves disk use).
%       Verbose     - print progress (default true)
%
%   Output:
%       hilbertPath - full path to the created Hilbert folder.
%
%   Reload pattern — single band as signalDatastore:
%       hMeta = load(fullfile(hilbertPath, "provenance.mat"));
%       sfreq = hMeta.provenance.sfreq;
%       bandNames = hMeta.provenance.bandNames;
%
%       % Load alpha amplitude (all channels):
%       sds_alpha = signalDatastore( ...
%           fullfile(hilbertPath, "amplitude", "alpha"), SampleRate=sfreq);
%
%       % Source mapping:
%       K = load(fullfile(outPath, "ImagingKernel.mat")).K;
%       alphaSource = K * readBandMatrix(sds_alpha);  % [nSources x nSamples]
%
%   Reload pattern — load band matrix directly:
%       sds_alpha = signalDatastore( ...
%           fullfile(hilbertPath, "amplitude", "alpha"), SampleRate=sfreq);
%       mat = readBandMatrix(sds_alpha);   % [nChannels x nSamples]
%
%   Reload pattern — iterate over bands:
%       for bi = 1:numel(bandNames)
%           sds_b = signalDatastore( ...
%               fullfile(hilbertPath, "amplitude", bandNames(bi)), ...
%               SampleRate=sfreq);
%           mat_b = readBandMatrix(sds_b);  % [nChannels x nSamples]
%           sourceB = K * mat_b;
%       end
%
%   See also: readHilbertBands, hilbertTransform, readBandMatrix,
%             writeCWTDatastore, writeSourceDatastore

    arguments
        amplitude  (1,1) struct
        phase      (1,1) struct
        bandInfo   (1,1) struct
        parentPath (1,1) string
        opts.Subfolder   (1,1) string  = "hilbert"
        opts.ScaleFactor (1,1) double  = 1e12
        opts.Tag         (1,1) string  = ""
        opts.Overwrite   (1,1) logical = false
        opts.SavePhase   (1,1) logical = true
        opts.Verbose     (1,1) logical = true
    end

    % ---- Validate parentPath ----
    if ~isfolder(parentPath)
        error('writeHilbertBands:NoParent', ...
            'Parent path does not exist: %s', parentPath);
    end

    parentProvFile = fullfile(parentPath, "provenance.mat");
    if ~isfile(parentProvFile)
        error('writeHilbertBands:NoProvenance', ...
            'No provenance.mat found in parent path: %s\nExpected output of writeSourceDatastore.', ...
            parentPath);
    end

    % ---- Load parent provenance ----
    parentMeta = load(parentProvFile);
    parentProv = parentMeta.provenance;

    % ---- Also try to load CWT provenance if available ----
    cwtProv = [];
    cwtProvFile = fullfile(parentPath, "cwt", "provenance.mat");
    if isfile(cwtProvFile)
        cwtMeta = load(cwtProvFile);
        cwtProv = cwtMeta.provenance;
    end

    % ---- Extract bandInfo fields ----
    bandNames  = string(bandInfo.bandNames(:));
    chanNames  = string(bandInfo.channelNames(:));
    nChannels  = bandInfo.nChannels;
    nSamples   = bandInfo.nSamples;
    nBands     = bandInfo.nBands;
    sfreq      = bandInfo.sfreq;

    % ---- Determine subfolder name ----
    subfolderName = opts.Subfolder;
    if opts.Tag ~= ""
        subfolderName = subfolderName + "_" + opts.Tag;
    end

    hilbertPath = fullfile(parentPath, subfolderName);
    ampDir      = fullfile(hilbertPath, "amplitude");
    phsDir      = fullfile(hilbertPath, "phase");

    % ---- Handle existing folder ----
    if isfolder(hilbertPath)
        if opts.Overwrite
            if opts.Verbose
                fprintf('writeHilbertBands: overwriting %s\n', hilbertPath);
            end
            rmdir(hilbertPath, 's');
        else
            error('writeHilbertBands:FolderExists', ...
                'Hilbert folder already exists: %s\nUse Overwrite=true to replace.', ...
                hilbertPath);
        end
    end

    % ---- Create directories ----
    mkdir(hilbertPath);
    mkdir(ampDir);
    if opts.SavePhase
        mkdir(phsDir);
    end

    % ---- Write amplitude bands ----
    if opts.Verbose
        fprintf('writeHilbertBands: writing amplitude (%d bands × %d channels)\n', ...
            nBands, nChannels);
    end

    for bi = 1:nBands
        bn = bandNames(bi);
        bandDir = fullfile(ampDir, bn);
        mkdir(bandDir);

        mat = amplitude.(bn);  % [nChannels x nSamples]

        % Build per-channel cell array of column vectors
        cells = cell(nChannels, 1);
        for ci = 1:nChannels
            cells{ci} = mat(ci, :)';  % [nSamples x 1]
        end

        tmpSds = signalDatastore(cells, 'SampleRate', sfreq);
        tmpSds.MemberNames = chanNames;
        writeall(tmpSds, bandDir);

        if opts.Verbose
            fprintf('  amplitude/%-8s: [%d × %d] → %s\n', ...
                bn, nChannels, nSamples, bandDir);
        end
    end

    % ---- Write phase bands ----
    if opts.SavePhase
        if opts.Verbose
            fprintf('writeHilbertBands: writing phase (%d bands × %d channels)\n', ...
                nBands, nChannels);
        end

        for bi = 1:nBands
            bn = bandNames(bi);
            bandDir = fullfile(phsDir, bn);
            mkdir(bandDir);

            mat = phase.(bn);  % [nChannels x nSamples]

            cells = cell(nChannels, 1);
            for ci = 1:nChannels
                cells{ci} = mat(ci, :)';  % [nSamples x 1]
            end

            tmpSds = signalDatastore(cells, 'SampleRate', sfreq);
            tmpSds.MemberNames = chanNames;
            writeall(tmpSds, bandDir);

            if opts.Verbose
                fprintf('  phase/%-8s:     [%d × %d] → %s\n', ...
                    bn, nChannels, nSamples, bandDir);
            end
        end
    end

    % ---- Build provenance ----
    provenance = struct();
    provenance.mode             = "hilbert_bands";
    provenance.parentPath       = string(parentPath);
    provenance.parentProvenance = parentProv;

    if ~isempty(cwtProv)
        provenance.cwtProvenance = cwtProv;
    end

    % Inherit subject name
    if isfield(parentProv, 'subjectName')
        provenance.subjectName = parentProv.subjectName;
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
    provenance.bandNames    = bandNames;
    provenance.scaleFactor  = opts.ScaleFactor;
    provenance.savedPhase   = opts.SavePhase;

    % Inherit CWT band ranges if available
    if ~isempty(cwtProv)
        fieldsToInherit = {'bandRanges', 'clippedRanges', 'bandValid', ...
            'frequencyLimits', 'wavelet', 'voicesPerOctave', 'nScales', ...
            'timeBandwidth'};
        for fi = 1:numel(fieldsToInherit)
            fn = fieldsToInherit{fi};
            if isfield(cwtProv, fn)
                provenance.(fn) = cwtProv.(fn);
            end
        end
    end

    % Metadata
    provenance.subfolder     = subfolderName;
    provenance.tag           = opts.Tag;
    provenance.createdOn     = string(datetime("now", "Format", "yyyy-MM-dd HH:mm:ss"));
    provenance.matlabVersion = string(version);

    % ---- Save provenance ----
    provFile = fullfile(hilbertPath, "provenance.mat");
    save(provFile, 'provenance', '-v7.3');

    % ---- Summary ----
    if opts.Verbose
        nFiles = nBands * nChannels;
        if opts.SavePhase
            nFiles = nFiles * 2;
        end
        totalGB = nFiles * nSamples * 8 / 1e9;  % double precision

        fprintf('writeHilbertBands: complete → %s\n', hilbertPath);
        fprintf('  Subject:     %s\n', provenance.subjectName);
        fprintf('  Channels:    %d\n', nChannels);
        fprintf('  Samples:     %d (%.2f s at %.1f Hz)\n', ...
            nSamples, nSamples/sfreq, sfreq);
        fprintf('  Bands:       %d [%s]\n', nBands, strjoin(bandNames, ", "));
        fprintf('  Scale:       %.0e\n', opts.ScaleFactor);
        fprintf('  Files:       %d (.mat per channel per band%s)\n', ...
            nFiles, ternary(opts.SavePhase, " × amp+phase", " amp only"));
        fprintf('  Est. size:   %.2f GB\n', totalGB);
        fprintf('  Phase saved: %s\n', ternary(opts.SavePhase, "yes", "no"));
        fprintf('  Parent:      %s\n', parentPath);
    end
end

% =========================================================================
%  HELPERS
% =========================================================================

function v = ternary(cond, a, b)
    if cond, v = a; else, v = b; end
end
