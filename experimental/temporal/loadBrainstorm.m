function db = loadBrainstorm(protocolPath, opts)
%LOADBRAINSTORM Load surfaces, signals, and study files from a Brainstorm protocol.
%
%   db = loadBrainstorm(protocolPath)
%   db = loadBrainstorm(protocolPath, Name=Value)
%
%   Opens a Brainstorm protocol, reads protocol.mat to discover subjects,
%   anatomy, and studies, then loads files matching user-specified patterns:
%     - Anatomy surfaces (from anat/) matched by filename pattern
%     - Study data files (Timefreq, Data, Result, etc.) matched by filename
%       and/or comment patterns
%
%   Brainstorm database layout:
%       protocolPath/
%           data/protocol.mat      — database index
%           data/<subject>/<study>/ — study files (recordings, PSD, results)
%           anat/<subject>/        — anatomy files (surfaces, MRI)
%
%   Inputs:
%       protocolPath - path to the Brainstorm protocol root folder
%                      e.g. "Z:\brainstorm_protocols\TutorialOmega2"
%
%   Name-Value Arguments:
%     Anatomy:
%       SurfacePattern  - anatomy filename pattern (default "pial_low")
%                         Set to "" to skip surface loading.
%
%     Study data (each is a struct or [] to skip):
%       TimefreqPattern - struct with fields:
%           .file    - filename pattern (e.g. "timefreq")
%           .comment - (optional) comment pattern (e.g. "relative")
%                      Default: struct('file',"timefreq",'comment',"")
%                      Set to [] to skip Timefreq loading.
%       DataPattern     - struct with .file and .comment (default [])
%       ResultPattern   - struct with .file and .comment (default [])
%
%     Source mapping:
%       LoadSourceMapping - logical flag (default false). When true, for each
%                           study that has a Channel file, a Result file with
%                           an ImagingKernel, and a raw Data file, loads:
%                             - ImagingKernel (inverse operator)
%                             - GoodChannel indices and ChannelFlag
%                             - Channel file (sensor metadata, compensation)
%                             - sFile struct for in_fread raw data access
%                             - Pre-configured ImportOptions for in_fread
%                           Requires Brainstorm toolbox on MATLAB path for
%                           subsequent raw data reading via in_fread.
%
%     General:
%       ExcludeSubjects - subject names to skip
%                         (default ["sub-emptyroom","Group_analysis"])
%       Verbose         - print progress (default true)
%
%   Output:
%       db - struct with fields:
%           .protocolPath  - protocol root path
%           .protocolInfo  - ProtocolInfo from protocol.mat
%           .subjects      - [N x 1] struct array with fields:
%               .name       - subject name (e.g. "sub-0002")
%               .fileName   - relative path to brainstormsubject.mat
%               .surfaces   - [K x 1] struct array of loaded surfaces
%                   .comment, .fileName, .surfType, .Vertices, .Faces, ...
%               .timefreq   - [T x 1] struct array of loaded Timefreq files
%                   .comment, .fileName, .studyName, .TF, .Freqs, .Time,
%                   .RowNames, .Measure, .Method, .DataType, .DataFile,
%                   .SurfaceFile, .Options, .fullPath
%               .data       - [D x 1] struct array of loaded Data files
%               .results    - [R x 1] struct array of loaded Result files
%               .sourceMapping - [S x 1] struct array (when LoadSourceMapping=true):
%                   .studyName      - study folder name
%                   .ImagingKernel  - [nSources x nGoodChannels] inverse operator
%                   .GoodChannel    - [1 x nGoodChannels] channel indices
%                   .nComponents    - source components (1=constrained, 3=unconstrained)
%                   .SurfaceFile    - surface file reference from kernel
%                   .channelMat     - full channel file struct (Channel, MegRefCoef, ...)
%                   .ChannelFlag    - [nChannels x 1] from data file (1=good, -1=bad)
%                   .sFile          - sFile struct for use with in_fread
%                   .sfreq          - sampling frequency (Hz)
%                   .nSamples       - total number of samples in recording
%                   .duration       - total duration (seconds)
%                   .ImportOptions  - preconfigured struct for in_fread
%                   .dataFilePath   - full path to raw data .mat file
%
%   Examples:
%       % Load pial_low surfaces + relative PSD timefreq files:
%       db = loadBrainstorm("Z:\brainstorm_protocols\TutorialOmega2", ...
%           TimefreqPattern=struct('file',"timefreq",'comment',"relative"));
%
%       % Surfaces only (no study data):
%       db = loadBrainstorm(protocolPath, TimefreqPattern=[]);
%
%       % Timefreq only (no surfaces):
%       db = loadBrainstorm(protocolPath, SurfacePattern="", ...
%           TimefreqPattern=struct('file',"timefreq",'comment',""));
%
%       % Load all PSD files (any comment):
%       db = loadBrainstorm(protocolPath, ...
%           TimefreqPattern=struct('file',"timefreq_psd",'comment',""));
%
%       % Load source mapping components for all subjects:
%       db = loadBrainstorm(protocolPath, LoadSourceMapping=true);
%       sm = db.subjects(1).sourceMapping;
%       % Read 2 seconds of source-mapped data:
%       bounds = [0, round(2*sm.sfreq)-1];
%       F = in_fread(sm.sFile, sm.channelMat, 1, bounds, [], sm.ImportOptions);
%       sources = sm.ImagingKernel * F(sm.GoodChannel, :);
%
%   See also: loadMEG, readSourceSegment, bct.Manifold

    arguments
        protocolPath    (1,1) string {mustBeFolder}
        opts.SurfacePattern  (1,1) string = "pial_low"
        opts.TimefreqPattern        = []
        opts.DataPattern            = []
        opts.ResultPattern          = []
        opts.LoadSourceMapping (1,1) logical = false
        opts.ExcludeSubjects (1,:) string = ["sub-emptyroom", "Group_analysis"]
        opts.Verbose         (1,1) logical = true
    end

    % ---- Resolve paths ----
    dataPath = fullfile(protocolPath, "data");
    anatPath = fullfile(protocolPath, "anat");

    protocolFile = fullfile(dataPath, "protocol.mat");
    if ~isfile(protocolFile)
        error('loadBrainstorm:NoProtocol', ...
            'protocol.mat not found at: %s', protocolFile);
    end

    % ---- Load protocol index ----
    prot = load(protocolFile);
    allSubjects = prot.ProtocolSubjects.Subject;
    allStudies  = prot.ProtocolStudies.Study;

    if opts.Verbose
        fprintf('loadBrainstorm: protocol at %s\n', protocolPath);
        fprintf('  %d subjects, %d studies in database\n', ...
            numel(allSubjects), numel(allStudies));
    end

    % ---- Determine which data categories to load ----
    loadSurfaces = (opts.SurfacePattern ~= "");
    loadTimefreq = ~isempty(opts.TimefreqPattern);
    loadData     = ~isempty(opts.DataPattern);
    loadResult   = ~isempty(opts.ResultPattern);
    loadStudyData = loadTimefreq || loadData || loadResult || opts.LoadSourceMapping;

    % Normalize pattern structs (ensure .file and .comment fields)
    if loadTimefreq, opts.TimefreqPattern = normalizePattern(opts.TimefreqPattern); end
    if loadData,     opts.DataPattern     = normalizePattern(opts.DataPattern);     end
    if loadResult,   opts.ResultPattern   = normalizePattern(opts.ResultPattern);   end

    % ---- Build subject-to-study lookup ----
    % Map from subject FileName -> list of study indices
    subjStudyMap = containers.Map('KeyType','char','ValueType','any');
    if loadStudyData
        for si = 1:numel(allStudies)
            key = char(allStudies(si).BrainStormSubject);
            if isKey(subjStudyMap, key)
                subjStudyMap(key) = [subjStudyMap(key), si];
            else
                subjStudyMap(key) = si;
            end
        end
    end

    % ---- Iterate subjects ----
    outSubjects = [];
    nSurfLoaded = 0;
    nTfLoaded   = 0;
    nDataLoaded = 0;
    nResLoaded  = 0;
    nSrcLoaded  = 0;

    for si = 1:numel(allSubjects)
        subj = allSubjects(si);
        subjName = string(subj.Name);

        % Skip excluded subjects
        if any(subjName == opts.ExcludeSubjects)
            if opts.Verbose
                fprintf('  [skip] %s (excluded)\n', subjName);
            end
            continue
        end

        subjEntry = struct();
        subjEntry.name     = subjName;
        subjEntry.fileName = string(subj.FileName);
        hasContent = false;

        % ---- Load anatomy surfaces ----
        if loadSurfaces
            loadedSurfaces = loadMatchingSurfaces( ...
                subj, anatPath, opts.SurfacePattern);
            subjEntry.surfaces = loadedSurfaces;
            n = numel(loadedSurfaces);
            nSurfLoaded = nSurfLoaded + n;
            if n > 0
                hasContent = true;
                if opts.Verbose
                    fprintf('  [surf]     %s — %d surface(s)\n', subjName, n);
                end
            end
        else
            subjEntry.surfaces = [];
        end

        % ---- Load study data for this subject ----
        subjEntry.timefreq      = [];
        subjEntry.data          = [];
        subjEntry.results       = [];
        subjEntry.sourceMapping = [];

        if loadStudyData
            subjKey = char(subj.FileName);
            if isKey(subjStudyMap, subjKey)
                studyIdx = subjStudyMap(subjKey);
                for sti = studyIdx
                    st = allStudies(sti);
                    studyName = string(st.Name);

                    % -- Timefreq --
                    if loadTimefreq && ~isempty(st.Timefreq)
                        matched = matchStudyEntries(st.Timefreq, ...
                            opts.TimefreqPattern);
                        for mi = 1:numel(matched)
                            entry = loadTimefreqFile(dataPath, matched(mi), studyName);
                            if ~isempty(entry)
                                subjEntry.timefreq = appendEntry(subjEntry.timefreq, entry);
                                nTfLoaded = nTfLoaded + 1;
                                hasContent = true;
                                if opts.Verbose
                                    fprintf('  [timefreq] %s — "%s" (%s)\n', ...
                                        subjName, entry.comment, studyName);
                                end
                            end
                        end
                    end

                    % -- Data --
                    if loadData && ~isempty(st.Data)
                        matched = matchStudyEntries(st.Data, opts.DataPattern);
                        for mi = 1:numel(matched)
                            entry = loadGenericFile(dataPath, matched(mi), studyName);
                            if ~isempty(entry)
                                subjEntry.data = appendEntry(subjEntry.data, entry);
                                nDataLoaded = nDataLoaded + 1;
                                hasContent = true;
                                if opts.Verbose
                                    fprintf('  [data]     %s — "%s" (%s)\n', ...
                                        subjName, entry.comment, studyName);
                                end
                            end
                        end
                    end

                    % -- Result --
                    if loadResult && ~isempty(st.Result)
                        matched = matchStudyEntries(st.Result, opts.ResultPattern);
                        for mi = 1:numel(matched)
                            entry = loadGenericFile(dataPath, matched(mi), studyName);
                            if ~isempty(entry)
                                subjEntry.results = appendEntry(subjEntry.results, entry);
                                nResLoaded = nResLoaded + 1;
                                hasContent = true;
                                if opts.Verbose
                                    fprintf('  [result]   %s — "%s" (%s)\n', ...
                                        subjName, entry.comment, studyName);
                                end
                            end
                        end
                    end

                    % -- Source Mapping Components --
                    if opts.LoadSourceMapping
                        sm = loadSourceMappingForStudy(dataPath, st, studyName);
                        if ~isempty(sm)
                            subjEntry.sourceMapping = appendEntry( ...
                                subjEntry.sourceMapping, sm);
                            nSrcLoaded = nSrcLoaded + 1;
                            hasContent = true;
                            if opts.Verbose
                                fprintf('  [source]   %s — kernel [%d×%d], sfreq=%g Hz (%s)\n', ...
                                    subjName, size(sm.ImagingKernel,1), ...
                                    size(sm.ImagingKernel,2), sm.sfreq, studyName);
                            end
                        end
                    end
                end
            end
        end

        if hasContent
            outSubjects = appendEntry(outSubjects, subjEntry);
        elseif opts.Verbose
            fprintf('  [skip] %s (no matching files)\n', subjName);
        end
    end

    % ---- Pack output ----
    db.protocolPath = protocolPath;
    db.protocolInfo = prot.ProtocolInfo;
    db.subjects     = outSubjects;

    if opts.Verbose
        fprintf('loadBrainstorm: done — %d subjects ', numel(outSubjects));
        parts = {};
        if loadSurfaces,  parts{end+1} = sprintf('%d surfaces', nSurfLoaded); end
        if loadTimefreq,  parts{end+1} = sprintf('%d timefreq', nTfLoaded);   end
        if loadData,      parts{end+1} = sprintf('%d data', nDataLoaded);     end
        if loadResult,    parts{end+1} = sprintf('%d results', nResLoaded);   end
        if opts.LoadSourceMapping, parts{end+1} = sprintf('%d source mappings', nSrcLoaded); end
        fprintf('(%s)\n', strjoin(parts, ', '));
    end
end

% =========================================================================
%  LOCAL HELPERS
% =========================================================================

function pat = normalizePattern(pat)
%NORMALIZEPATTERN Ensure pattern struct has .file and .comment string fields.
    if isstring(pat) || ischar(pat)
        pat = struct('file', string(pat), 'comment', "");
    end
    if ~isfield(pat, 'file'),    pat.file    = ""; end
    if ~isfield(pat, 'comment'), pat.comment = ""; end
    pat.file    = string(pat.file);
    pat.comment = string(pat.comment);
end

function matched = matchStudyEntries(entries, pattern)
%MATCHSTUDYENTRIES Filter Brainstorm study entries by file/comment pattern.
%   entries  - struct array with .FileName and .Comment
%   pattern  - struct with .file and .comment
%   Returns subset of entries matching both patterns (contains, case-insensitive).
    fileNames = {entries.FileName};
    comments  = {entries.Comment};

    keep = true(1, numel(entries));

    if pattern.file ~= ""
        keep = keep & contains(fileNames, pattern.file, 'IgnoreCase', true);
    end
    if pattern.comment ~= ""
        keep = keep & contains(comments, pattern.comment, 'IgnoreCase', true);
    end

    matched = entries(keep);
end

function surfaces = loadMatchingSurfaces(subj, anatPath, surfPattern)
%LOADMATCHINGSURFACES Load anatomy surfaces matching filename pattern.
    surfaces = [];
    if isempty(subj.Surface)
        return
    end

    surfFileNames = {subj.Surface.FileName};
    matchIdx = find(contains(surfFileNames, surfPattern));

    for mi = 1:numel(matchIdx)
        idx = matchIdx(mi);
        relPath  = subj.Surface(idx).FileName;
        fullPath = fullfile(anatPath, relPath);

        if ~isfile(fullPath)
            warning('loadBrainstorm:FileNotFound', ...
                'Surface file not found: %s', fullPath);
            continue
        end

        raw = load(fullPath);

        entry = struct();
        entry.comment  = string(subj.Surface(idx).Comment);
        entry.fileName = string(relPath);
        entry.surfType = string(subj.Surface(idx).SurfaceType);
        entry.Vertices = raw.Vertices;
        entry.Faces    = raw.Faces;
        entry.fullPath = string(fullPath);

        % Optional fields
        if isfield(raw, 'VertNormals'), entry.VertNormals = raw.VertNormals; end
        if isfield(raw, 'Curvature'),   entry.Curvature   = raw.Curvature;   end
        if isfield(raw, 'SulciMap'),    entry.SulciMap    = raw.SulciMap;    end
        if isfield(raw, 'Atlas'),       entry.Atlas       = raw.Atlas;       end
        if isfield(raw, 'VertConn'),    entry.VertConn    = raw.VertConn;    end
        if isfield(raw, 'Color'),       entry.Color       = raw.Color;       end
        if isfield(raw, 'Reg'),         entry.Reg         = raw.Reg;         end
        if isfield(raw, 'History'),     entry.History     = raw.History;     end

        surfaces = appendEntry(surfaces, entry);
    end
end

function entry = loadTimefreqFile(dataPath, tfEntry, studyName)
%LOADTIMEFREQFILE Load a Brainstorm Timefreq .mat file into a struct.
    relPath  = tfEntry.FileName;
    fullPath = fullfile(dataPath, relPath);

    if ~isfile(fullPath)
        warning('loadBrainstorm:FileNotFound', ...
            'Timefreq file not found: %s', fullPath);
        entry = [];
        return
    end

    raw = load(fullPath);

    entry = struct();
    entry.comment     = string(tfEntry.Comment);
    entry.fileName    = string(relPath);
    entry.studyName   = string(studyName);
    entry.fullPath    = string(fullPath);

    % Core timefreq fields
    entry.TF          = raw.TF;          % [nSources x nTime x nFreqs]
    entry.Freqs       = raw.Freqs;       % frequency info (cell or numeric)
    entry.Time        = raw.Time;        % time vector

    % Metadata
    if isfield(raw, 'RowNames'),    entry.RowNames    = raw.RowNames;    end
    if isfield(raw, 'Measure'),     entry.Measure     = string(raw.Measure);     end
    if isfield(raw, 'Method'),      entry.Method      = string(raw.Method);      end
    if isfield(raw, 'DataType'),    entry.DataType    = string(raw.DataType);    end
    if isfield(raw, 'DataFile'),    entry.DataFile    = string(raw.DataFile);    end
    if isfield(raw, 'SurfaceFile'), entry.SurfaceFile = string(raw.SurfaceFile); end
    if isfield(raw, 'Options'),     entry.Options     = raw.Options;     end
    if isfield(raw, 'Atlas'),       entry.Atlas       = raw.Atlas;       end
    if isfield(raw, 'TimeBands'),   entry.TimeBands   = raw.TimeBands;   end
    if isfield(raw, 'nAvg'),        entry.nAvg        = raw.nAvg;        end
    if isfield(raw, 'Leff'),        entry.Leff        = raw.Leff;        end

    % DataFile and DataType from index entry (if present)
    if isfield(tfEntry, 'DataFile'), entry.indexDataFile = string(tfEntry.DataFile); end
    if isfield(tfEntry, 'DataType'), entry.indexDataType = string(tfEntry.DataType); end
end

function entry = loadGenericFile(dataPath, bstEntry, studyName)
%LOADGENERICFILE Load a generic Brainstorm study file (.mat) into a struct.
    relPath  = bstEntry.FileName;
    fullPath = fullfile(dataPath, relPath);

    if ~isfile(fullPath)
        warning('loadBrainstorm:FileNotFound', ...
            'Study file not found: %s', fullPath);
        entry = [];
        return
    end

    raw = load(fullPath);

    entry = struct();
    entry.comment   = string(bstEntry.Comment);
    entry.fileName  = string(relPath);
    entry.studyName = string(studyName);
    entry.fullPath  = string(fullPath);
    entry.raw       = raw;   % preserve all loaded fields
end

function arr = appendEntry(arr, entry)
%APPENDENTRY Append a struct entry to a struct array (handles empty init).
    if isempty(arr)
        arr = entry;
    else
        arr(end+1, 1) = entry;
    end
end

function sm = loadSourceMappingForStudy(dataPath, st, studyName)
%LOADSOURCEMAPPINGFORSTUDY Load source mapping components from a study.
%   Requires the study to have a Channel file, at least one Result file
%   with an ImagingKernel, and at least one raw Data file (F is struct).
%   Returns [] if any required component is missing.

    sm = [];

    % ---- Require Channel, Result, and Data entries ----
    if isempty(st.Channel) || isempty(st.Result) || isempty(st.Data)
        return
    end

    % ---- Load channel file ----
    chanRelPath  = st.Channel.FileName;
    chanFullPath = fullfile(dataPath, chanRelPath);
    if ~isfile(chanFullPath)
        warning('loadBrainstorm:SourceMapping', ...
            'Channel file not found: %s', chanFullPath);
        return
    end
    channelMat = load(chanFullPath);

    % ---- Find first Result with ImagingKernel ----
    kernelMat = [];
    for ri = 1:numel(st.Result)
        resRelPath  = st.Result(ri).FileName;
        resFullPath = fullfile(dataPath, resRelPath);
        if ~isfile(resFullPath), continue; end

        resMat = load(resFullPath);
        if isfield(resMat, 'ImagingKernel') && ~isempty(resMat.ImagingKernel)
            kernelMat = resMat;
            break
        end
    end
    if isempty(kernelMat)
        return
    end

    % ---- Find first raw Data file (F is struct = file descriptor) ----
    dataMat      = [];
    dataFullPath = '';
    for di = 1:numel(st.Data)
        dataRelPath = st.Data(di).FileName;
        dFullPath   = fullfile(dataPath, dataRelPath);
        if ~isfile(dFullPath), continue; end

        dMat = load(dFullPath);
        if isfield(dMat, 'F') && isstruct(dMat.F)
            dataMat      = dMat;
            dataFullPath = dFullPath;
            break
        end
    end
    if isempty(dataMat)
        return
    end

    % ---- Build sFile struct for in_fread ----
    sFile = buildSFileFromData(dataMat, dataFullPath, studyName);

    % ---- Build ImportOptions ----
    ImportOptions = buildImportOptions();

    % ---- Compute derived quantities ----
    sfreq    = sFile.prop.sfreq;
    duration = diff(sFile.prop.times);
    nSamples = round(duration * sfreq) + 1;

    % ---- Package source mapping struct ----
    sm = struct();
    sm.studyName      = string(studyName);
    sm.ImagingKernel  = kernelMat.ImagingKernel;
    sm.GoodChannel    = kernelMat.GoodChannel;
    sm.nComponents    = kernelMat.nComponents;
    sm.SurfaceFile    = string(kernelMat.SurfaceFile);
    sm.channelMat     = channelMat;
    sm.ChannelFlag    = dataMat.ChannelFlag;
    sm.sFile          = sFile;
    sm.sfreq          = sfreq;
    sm.nSamples       = nSamples;
    sm.duration       = duration;
    sm.ImportOptions  = ImportOptions;
    sm.dataFilePath   = string(dataFullPath);

    % ---- Load surface anatomy for projection (Reg, Atlas) ----
    % The SurfaceFile is relative to the anat/ folder in the protocol.
    % Derive anatPath from dataPath: protocol/data/ → protocol/anat/
    anatPath = strrep(dataPath, [filesep 'data'], [filesep 'anat']);
    surfFullPath = fullfile(anatPath, kernelMat.SurfaceFile);
    if isfile(surfFullPath)
        surfRaw = load(surfFullPath);
        if isfield(surfRaw, 'Reg')
            sm.Reg = surfRaw.Reg;
        end
        if isfield(surfRaw, 'Atlas')
            sm.Atlas = surfRaw.Atlas;
        end
        sm.surfaceVertices = surfRaw.Vertices;
        sm.surfaceFaces    = surfRaw.Faces;
        sm.surfaceFullPath = string(surfFullPath);
    else
        warning('loadBrainstorm:SurfaceNotFound', ...
            'Surface file for source mapping not found: %s\nProjection to fsaverage will not be possible.', ...
            surfFullPath);
    end
end

function sFile = buildSFileFromData(dataMat, ~, ~)
%BUILDSFILEFROMDATA Extract the sFile struct from a loaded raw data .mat.
%   For raw continuous recordings in Brainstorm, the data file's F field
%   IS the complete sFile struct (contains filename, format, header, prop,
%   events, epochs, channelflag, etc.) ready for use with in_fread.
%
%   For non-raw data files where F is a numeric matrix, constructs a
%   minimal sFile from available metadata.

    if isfield(dataMat, 'F') && isstruct(dataMat.F)
        % F is already a complete sFile struct for raw continuous recordings
        sFile = dataMat.F;
    else
        error('loadBrainstorm:NotRawData', ...
            'Data file does not contain a raw file descriptor (F is not a struct).');
    end
end

function opts = buildImportOptions()
%BUILDIMPORTOPTIONS Build default ImportOptions struct for in_fread.
%   Enables CTF compensation and SSP projectors, disables baseline removal.
%   If Brainstorm's db_template is available, uses it as the base; otherwise
%   constructs the struct manually with the essential fields.

    try
        opts = db_template('ImportOptions');
    catch
        opts = struct();
    end

    opts.UseCtfComp       = 1;
    opts.UseSsp           = 1;
    opts.RemoveBaseline   = 'no';
    opts.DisplayMessages  = 0;
    opts.ImportMode       = 'Time';
    opts.Resample         = 0;
    opts.IgnoreShortEpochs = 1;
    opts.EventsMode       = 'ignore';
end
