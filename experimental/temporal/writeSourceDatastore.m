function outPath = writeSourceDatastore(sds, K, sm, outputRoot, opts)
%WRITESOURCEDATASTORE Write sensor datastore and kernel to disk with provenance.
%
%   outPath = writeSourceDatastore(sds, K, sm, outputRoot)
%   outPath = writeSourceDatastore(sds, K, sm, outputRoot, Name=Value)
%
%   Writes the sensor signalDatastore (from readSourceSegment with
%   AsDatastore=true) and the imaging kernel K to a structured folder
%   on disk, along with a provenance metadata file that records subject
%   information, channel names, protocol paths, and segment parameters.
%
%   Folder layout (created under outputRoot):
%       outputRoot/
%         <SubjectName>/
%           provenance.mat        — metadata struct (see below)
%           ImagingKernel.mat     — K matrix
%           sensor/               — writeall output (one .mat per channel)
%             MLC11.mat
%             MLC12.mat
%             ...
%
%   Inputs:
%       sds        - signalDatastore from readSourceSegment (AsDatastore=true).
%                    Must have MemberNames set to channel names.
%       K          - [nSources x nGoodChannels] ImagingKernel from
%                    readSourceSegment.
%       sm         - sourceMapping struct from loadBrainstorm (one element).
%                    Used to extract provenance metadata. If [] or omitted,
%                    only basic metadata is saved.
%       outputRoot - root folder where subject subfolder will be created.
%                    e.g. "Z:\omega\processed" or "C:\data\out"
%
%   Name-Value Arguments:
%       SubjectName   - subject folder name (default: auto from sm.studyName
%                       or "unknown_subject")
%       SegmentStart  - segment start time in seconds (default [])
%       SegmentEnd    - segment end time in seconds (default [])
%       Resample      - resampled frequency in Hz (default 0 = not resampled)
%       Tag           - optional string tag appended to folder name for
%                       disambiguation (default "")
%       Overwrite     - overwrite existing folder (default false)
%       SaveKernel    - save ImagingKernel to disk (default true). Set false
%                       to skip (e.g. if kernel is very large and you only
%                       want the sensor data).
%       ExtraFields   - struct of additional fields to include in provenance
%                       (default struct())
%       Verbose       - print progress (default true)
%
%   Output:
%       outPath - full path to the created subject folder.
%
%   Provenance metadata (saved in provenance.mat as struct 'provenance'):
%       .subjectName      - subject identifier
%       .protocolPath     - Brainstorm protocol root
%       .studyName        - study folder name
%       .dataFilePath     - path to the raw data file in protocol
%       .surfaceFile      - surface file used for source model
%       .nChannels        - number of good channels
%       .channelNames     - [nChannels x 1] string array
%       .nSources         - number of cortical sources (rows of K)
%       .nComponents      - source components (1 or 3)
%       .sfreq            - sampling frequency of saved data
%       .sfreqOriginal    - original (native) sampling frequency
%       .resampledTo      - resampled target, 0 if not resampled
%       .segmentStart     - segment start time (s), [] if full
%       .segmentEnd       - segment end time (s), [] if full
%       .nSamples         - number of time samples saved
%       .durationOriginal - total recording duration (s)
%       .createdOn        - datetime string of when this was written
%       .matlabVersion    - MATLAB version string
%       .tag              - user-supplied tag
%       .extra            - any extra fields from ExtraFields
%
%   Examples:
%       db = loadBrainstorm(protocolPath, LoadSourceMapping=true);
%       sm = db.subjects(1).sourceMapping;
%       [sds, K, t, fs] = readSourceSegment(sm, 0, 300, ...
%           AsDatastore=true, Resample=600);
%
%       % Write to disk:
%       outPath = writeSourceDatastore(sds, K, sm, "Z:\omega\processed", ...
%           SegmentStart=0, SegmentEnd=300, Resample=600);
%
%       % Reload later:
%       meta = load(fullfile(outPath, "provenance.mat"));
%       sds2 = signalDatastore(fullfile(outPath, "sensor"), ...
%           SampleRate=meta.provenance.sfreq);
%       K2 = load(fullfile(outPath, "ImagingKernel.mat")).K;
%
%   See also: readSourceSegment, loadBrainstorm, signalDatastore/writeall

    arguments
        sds        (1,1) signalDatastore
        K          double
        sm                                                           = []
        outputRoot (1,1) string                                      = ""
        opts.SubjectName  (1,1) string                               = ""
        opts.SegmentStart                                            = []
        opts.SegmentEnd                                              = []
        opts.Resample     (1,1) double {mustBeNonnegative}           = 0
        opts.Tag          (1,1) string                               = ""
        opts.Overwrite    (1,1) logical                              = false
        opts.SaveKernel   (1,1) logical                              = true
        opts.ExtraFields  (1,1) struct                               = struct()
        opts.Verbose      (1,1) logical                              = true
    end

    % ---- Validate outputRoot ----
    if outputRoot == ""
        error('writeSourceDatastore:NoOutput', ...
            'outputRoot must be specified.');
    end

    % ---- Determine subject name ----
    subjectName = opts.SubjectName;
    if subjectName == "" && ~isempty(sm)
        % Strategy 1: regex for sub-XXXX pattern in studyName
        if isfield(sm, 'studyName')
            tok = regexp(sm.studyName, '(sub-[0-9A-Za-z]+)', 'tokens', 'once');
            if ~isempty(tok)
                subjectName = string(tok{1});
            end
        end
        % Strategy 2: extract from dataFilePath (protocolPath/data/<subject>/...)
        if subjectName == "" && isfield(sm, 'dataFilePath')
            parts = split(string(sm.dataFilePath), filesep);
            dataIdx = find(lower(parts) == "data", 1, 'last');
            if ~isempty(dataIdx) && dataIdx < numel(parts)
                subjectName = parts(dataIdx + 1);
            end
        end
        % Strategy 3: slash-separated studyName (e.g. "@raw/sub-0002/...")
        if subjectName == "" && isfield(sm, 'studyName')
            parts = split(sm.studyName, '/');
            for pi = 1:numel(parts)
                p = parts{pi};
                if ~isempty(p) && ~startsWith(p, '@')
                    subjectName = string(p);
                    break;
                end
            end
        end
    end
    if subjectName == ""
        subjectName = "unknown_subject";
    end

    % ---- Build folder name ----
    folderName = subjectName;
    if opts.Tag ~= ""
        folderName = folderName + "_" + opts.Tag;
    end

    outPath = fullfile(outputRoot, folderName);
    sensorDir = fullfile(outPath, "sensor");

    % ---- Handle existing folder ----
    if isfolder(outPath)
        if opts.Overwrite
            if opts.Verbose
                fprintf('writeSourceDatastore: overwriting %s\n', outPath);
            end
            rmdir(outPath, 's');
        else
            error('writeSourceDatastore:FolderExists', ...
                'Output folder already exists: %s\nUse Overwrite=true to replace.', outPath);
        end
    end

    % ---- Create directories ----
    if ~isfolder(outPath)
        mkdir(outPath);
    end
    if ~isfolder(sensorDir)
        mkdir(sensorDir);
    end

    % ---- Write sensor datastore ----
    if opts.Verbose
        fprintf('writeSourceDatastore: writing %d channels to %s\n', ...
            numel(sdsGetChannelNames(sds)), sensorDir);
    end
    writeall(sds, sensorDir);

    % ---- Write ImagingKernel ----
    if opts.SaveKernel && ~isempty(K)
        kernelFile = fullfile(outPath, "ImagingKernel.mat");
        if opts.Verbose
            fprintf('writeSourceDatastore: saving ImagingKernel [%d x %d] → %s\n', ...
                size(K, 1), size(K, 2), kernelFile);
        end
        save(kernelFile, 'K', '-v7.3');
    end

    % ---- Gather channel info from datastore ----
    chanNames = sdsGetChannelNames(sds);
    nChannels = numel(chanNames);
    sfreq     = sds.SampleRate;

    % Determine nSamples from first member
    reset(sds);
    xSample = read(sds);
    if iscell(xSample), xSample = xSample{1}; end
    nSamples = numel(xSample);  % numel works for both row and column vectors
    reset(sds);

    % ---- Build provenance struct ----
    provenance = struct();
    provenance.subjectName   = subjectName;
    provenance.nChannels     = nChannels;
    provenance.channelNames  = chanNames(:);
    provenance.sfreq         = sfreq;
    provenance.nSamples      = nSamples;
    provenance.segmentStart  = opts.SegmentStart;
    provenance.segmentEnd    = opts.SegmentEnd;
    provenance.resampledTo   = opts.Resample;
    provenance.tag           = opts.Tag;

    % Kernel dimensions
    if ~isempty(K)
        provenance.nSources    = size(K, 1);
        provenance.kernelSize  = size(K);
        provenance.kernelSaved = opts.SaveKernel;
    else
        provenance.nSources    = 0;
        provenance.kernelSize  = [0 0];
        provenance.kernelSaved = false;
    end

    % ---- Extract from sourceMapping if available ----
    if ~isempty(sm) && isstruct(sm)
        if isfield(sm, 'sfreq')
            provenance.sfreqOriginal = sm.sfreq;
        end
        if isfield(sm, 'duration')
            provenance.durationOriginal = sm.duration;
        end
        if isfield(sm, 'nSamples')
            provenance.nSamplesOriginal = sm.nSamples;
        end
        if isfield(sm, 'nComponents')
            provenance.nComponents = sm.nComponents;
        end
        if isfield(sm, 'studyName')
            provenance.studyName = sm.studyName;
        end
        if isfield(sm, 'SurfaceFile')
            provenance.surfaceFile = sm.SurfaceFile;
        end
        if isfield(sm, 'dataFilePath')
            provenance.dataFilePath = sm.dataFilePath;
        end

        % Protocol path: walk up from dataFilePath to find protocol root
        % The dataFilePath is typically: protocolPath/data/subj/study/file.mat
        if isfield(sm, 'dataFilePath')
            provenance.protocolPath = extractProtocolPath(sm.dataFilePath);
        end

        % GoodChannel indices
        if isfield(sm, 'GoodChannel')
            provenance.goodChannelIdx = sm.GoodChannel(:);
        end

        % Channel details from channelMat
        if isfield(sm, 'channelMat') && isfield(sm.channelMat, 'Channel')
            allChanNames = {sm.channelMat.Channel.Name};
            allChanTypes = {sm.channelMat.Channel.Type};
            if isfield(sm, 'GoodChannel')
                gc = sm.GoodChannel;
                provenance.channelTypes = string(allChanTypes(gc))';
            end
            provenance.nChannelsTotal = numel(allChanNames);
        end

        % Surface anatomy for projection to fsaverage
        if isfield(sm, 'Reg')
            provenance.Reg = sm.Reg;
        end
        if isfield(sm, 'Atlas')
            provenance.Atlas = sm.Atlas;
        end
        if isfield(sm, 'surfaceVertices')
            provenance.surfaceVertices = sm.surfaceVertices;
            provenance.surfaceFaces    = sm.surfaceFaces;
        end
        if isfield(sm, 'surfaceFullPath')
            provenance.surfaceFullPath = sm.surfaceFullPath;
        end
    end

    % ---- Timestamps and env ----
    provenance.createdOn     = string(datetime("now", "Format", "yyyy-MM-dd HH:mm:ss"));
    provenance.matlabVersion = string(version);
    provenance.extra         = opts.ExtraFields;

    % ---- Save provenance ----
    provenanceFile = fullfile(outPath, "provenance.mat");
    save(provenanceFile, 'provenance', '-v7.3');

    if opts.Verbose
        fprintf('writeSourceDatastore: complete → %s\n', outPath);
        fprintf('  Subject:    %s\n', subjectName);
        fprintf('  Channels:   %d\n', nChannels);
        fprintf('  Samples:    %d (%.2f s at %.1f Hz)\n', nSamples, nSamples/sfreq, sfreq);
        if ~isempty(K)
            fprintf('  Kernel:     [%d × %d]%s\n', size(K,1), size(K,2), ...
                ternary(opts.SaveKernel, " (saved)", " (not saved)"));
        end
        if ~isempty(opts.SegmentStart)
            fprintf('  Segment:    [%.1f – %.1f s]\n', opts.SegmentStart, opts.SegmentEnd);
        end
        if opts.Resample > 0
            fprintf('  Resampled:  %.1f Hz\n', opts.Resample);
        end
        if isfield(provenance, 'protocolPath')
            fprintf('  Protocol:   %s\n', provenance.protocolPath);
        end
    end
end

% =========================================================================
%  HELPERS
% =========================================================================

function pp = extractProtocolPath(dataFilePath)
%EXTRACTPROTOCOLPATH Walk up from a Brainstorm data file to find protocol root.
%   The data file is at: protocolPath/data/<subject>/<study>/file.mat
%   We look for the /data/ segment in the path.
    pp = "";
    parts = split(string(dataFilePath), filesep);
    % Find the 'data' directory component
    for i = numel(parts):-1:1
        if lower(parts(i)) == "data"
            if i > 1
                pp = strjoin(parts(1:i-1), filesep);
            end
            return;
        end
    end
    % Fallback: go up 4 levels from the file
    pp = fileparts(fileparts(fileparts(fileparts(dataFilePath))));
end

function v = ternary(cond, a, b)
    if cond, v = a; else, v = b; end
end
