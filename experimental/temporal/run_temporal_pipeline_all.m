%% run_temporal_pipeline_all.m
%  Full per-subject temporal analysis pipeline for a Brainstorm protocol.
%
%  For each subject:
%    1. Read raw MEG sensor data (resampled to 600 Hz)
%    2. Write sensor datastore + kernel to disk
%    3. CWT band decomposition
%    4. Hilbert amplitude & phase extraction
%    5. Write per-band matrices to disk
%
%  Results are stored under analysisRoot/<protocolName>/<subjectName>/
%  and can be reloaded independently for source mapping.

%% ===== CONFIGURATION =====
protocolPath = "Z:\brainstorm_protocols\TutorialOmega2";
analysisRoot = "Z:\brainstorm_protocols_analysis";

% Segment & resampling
segmentStart = 0;       % seconds
segmentEnd   = 300;     % seconds (5 min)
resampleHz   = 600;     % downsample from 2400 Hz

% Frequency bands
bands.delta  = [2   4];
bands.theta  = [5   7];
bands.alpha  = [8  12];
bands.beta   = [15 30];
bands.gamma1 = [30 59];
freqLimits = [1 60];   % CWT filterbank range (covers gamma2 upper edge)

% Hilbert scaling (A·m → fT-scale)
scaleFactor = 1e12;

% Overwrite existing results
overwrite = false;

%% ===== LOAD BRAINSTORM DATABASE =====
fprintf('\n========================================\n');
fprintf('Loading Brainstorm protocol: %s\n', protocolPath);
fprintf('========================================\n');

db = loadBrainstorm(protocolPath, ...
    TimefreqPattern = struct('file', "timefreq", 'comment', "relative"), ...
    ResultPattern   = struct('file', "results_", 'comment', ""), ...
    LoadSourceMapping = true);

nSubjects = numel(db.subjects);
fprintf('Found %d subjects\n\n', nSubjects);

% Protocol name for output folder
[~, protocolName] = fileparts(protocolPath);
outputRoot = fullfile(analysisRoot, protocolName);

%% ===== PROCESS EACH SUBJECT =====
results = struct('subject', {}, 'outPath', {}, 'cwtPath', {}, ...
    'hilbertPath', {}, 'status', {}, 'error', {}, 'elapsed', {});

for si = 4:5
    subj = db.subjects(si);
    subjName = subj.name;

    fprintf('\n========================================\n');
    fprintf('Subject %d/%d: %s\n', si, nSubjects, subjName);
    fprintf('========================================\n');

    res = struct('subject', subjName, 'outPath', "", 'cwtPath', "", ...
        'hilbertPath', "", 'status', "pending", 'error', "", 'elapsed', 0);
    tSubjStart = tic;

    try
        % ---- Check for source mapping ----
        if ~isfield(subj, 'sourceMapping') || isempty(subj.sourceMapping)
            warning('run_pipeline:NoSourceMapping', ...
                'Subject %s has no sourceMapping — skipping.', subjName);
            res.status = "skipped_no_source_mapping";
            results(end+1) = res; %#ok<SAGROW>
            continue;
        end
        sm = subj.sourceMapping;

        % ---- Step 1: Read raw sensor data ----
        outPath = fullfile(outputRoot, subjName);

        if isfolder(outPath) && ~overwrite
            fprintf('  [skip] Sensor data exists: %s\n', outPath);
        else
            fprintf('  [1/5] Reading sensor data (%.0f–%.0f s, resample %d Hz)...\n', ...
                segmentStart, segmentEnd, resampleHz);
            [sds, K, ~, ~, ~] = readSourceSegment(sm, segmentStart, segmentEnd, ...
                AsDatastore=true, Resample=resampleHz);

            fprintf('  [2/5] Writing sensor datastore...\n');
            outPath = writeSourceDatastore(sds, K, sm, outputRoot, ...
                SegmentStart=segmentStart, SegmentEnd=segmentEnd, ...
                Resample=resampleHz, Overwrite=overwrite);
        end
        res.outPath = outPath;

        % ---- Step 2: CWT band decomposition ----
        cwtPath = fullfile(outPath, "cwt");

        if isfolder(cwtPath) && ~overwrite
            fprintf('  [skip] CWT data exists: %s\n', cwtPath);
        else
            fprintf('  [3/5] CWT band decomposition...\n');
            meta = load(fullfile(outPath, "provenance.mat"));
            sds2 = signalDatastore(fullfile(outPath, "sensor"), ...
                SampleRate=meta.provenance.sfreq);

            [bandStore, ~, cwtInfo] = continuousWaveletTransform(sds2, ...
                Bands=bands, FrequencyLimits=freqLimits);

            cwtPath = writeCWTDatastore(bandStore, cwtInfo, outPath, ...
                Overwrite=overwrite);

            clear bandStore sds2;  % free memory
        end
        res.cwtPath = cwtPath;

        % ---- Step 3: Hilbert amplitude & phase ----
        hilbertPath = fullfile(outPath, "hilbert");

        if isfolder(hilbertPath) && ~overwrite
            fprintf('  [skip] Hilbert data exists: %s\n', hilbertPath);
        else
            fprintf('  [4/5] Hilbert transform...\n');
            meta = load(fullfile(outPath, "provenance.mat"));
            cwtMeta = load(fullfile(cwtPath, "provenance.mat"));
            cwtStore = signalDatastore(fullfile(cwtPath, "data"), ...
                SampleRate=meta.provenance.sfreq);

            [hTds, hInfo] = hilbertTransform(cwtStore, ...
                BandNames=cwtMeta.provenance.bandNames, ...
                ScaleFactor=scaleFactor);

            [amplitude, phase, ~, bInfo] = readHilbertBands(hTds, hInfo);

            fprintf('  [5/5] Writing Hilbert bands...\n');
            hilbertPath = writeHilbertBands(amplitude, phase, bInfo, outPath, ...
                ScaleFactor=scaleFactor, Overwrite=false);

            clear amplitude phase hTds cwtStore;  % free memory
        end
        res.hilbertPath = hilbertPath;

        res.status = "complete";
        res.elapsed = toc(tSubjStart);
        fprintf('  Done (%.1f s)\n', res.elapsed);

    catch ME
        res.status = "error";
        res.error = string(ME.message);
        res.elapsed = toc(tSubjStart);
        fprintf('  ERROR: %s\n', ME.message);
        fprintf('  %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
    end

    results(end+1) = res; %#ok<SAGROW>
end

%% ===== SUMMARY =====
fprintf('\n========================================\n');
fprintf('PIPELINE SUMMARY\n');
fprintf('========================================\n');

nComplete = sum([results.status] == "complete");
nSkipped  = sum(startsWith([results.status], "skip"));
nErrors   = sum([results.status] == "error");

fprintf('  Total:     %d subjects\n', numel(results));
fprintf('  Complete:  %d\n', nComplete);
fprintf('  Skipped:   %d\n', nSkipped);
fprintf('  Errors:    %d\n', nErrors);

if nComplete > 0
    elapsed = [results([results.status] == "complete").elapsed];
    fprintf('  Time:      %.1f s total (%.1f s avg per subject)\n', ...
        sum(elapsed), mean(elapsed));
end

if nErrors > 0
    fprintf('\n  Failed subjects:\n');
    errIdx = find([results.status] == "error");
    for ei = 1:numel(errIdx)
        r = results(errIdx(ei));
        fprintf('    %s: %s\n', r.subject, r.error);
    end
end

fprintf('\nOutput root: %s\n', outputRoot);
fprintf('========================================\n');

%% ===== PATCH: WRITE PER-BAND CWT FILES =====
%  Splits the existing CWT datastore (channel files with [nSamples × nBands])
%  into per-band folders of per-channel [nSamples × 1] files for fast reload.
%  Run this once to update subjects that were processed before writeCWTBands existed.

fprintf('\n========================================\n');
fprintf('PATCHING: Write per-band CWT files\n');
fprintf('========================================\n');

patchOverwrite = false;  % set true to re-write existing cwt_bands

for si = 2:nSubjects
    subj = db.subjects(si);
    subjName = subj.name;
    subjectOut = fullfile(outputRoot, subjName);

    cwtPath      = fullfile(subjectOut, "cwt");
    cwtBandsPath = fullfile(subjectOut, "cwt_bands");

    % Skip if subject folder or CWT doesn't exist
    if ~isfolder(subjectOut)
        fprintf('  [skip] %s — no output folder\n', subjName);
        continue;
    end
    if ~isfolder(cwtPath) || ~isfile(fullfile(cwtPath, "provenance.mat"))
        fprintf('  [skip] %s — no CWT data\n', subjName);
        continue;
    end

    % Skip if already patched
    if isfolder(cwtBandsPath) && ~patchOverwrite
        fprintf('  [skip] %s — cwt_bands already exists\n', subjName);
        continue;
    end

    fprintf('  [patch] %s ...\n', subjName);
    try
        tPatch = tic;
        writeCWTBands(cwtPath, subjectOut, Overwrite=patchOverwrite);
        fprintf('  [done] %s (%.1f s)\n', subjName, toc(tPatch));
    catch ME
        fprintf('  [ERROR] %s: %s\n', subjName, ME.message);
    end
end

fprintf('========================================\n');
fprintf('CWT band patch complete.\n');
fprintf('========================================\n');

%% ===== PATCH: UPDATE PROVENANCE WITH SURFACE & REG.SPHERE =====
%  Adds Reg.Sphere, surfaceVertices, surfaceFaces, surfaceFullPath, and
%  SurfaceFile to each subject's provenance.mat from the Brainstorm
%  anatomy surface referenced by the imaging kernel.
%
%  SAFETY: Only inserts/updates the specific surface-related fields.
%  All other provenance fields are left untouched.

fprintf('\n========================================\n');
fprintf('PATCHING: Update provenance with Reg.Sphere\n');
fprintf('========================================\n');

for si = 2:nSubjects
    subj = db.subjects(si);
    subjName = subj.name;
    subjectOut = fullfile(outputRoot, subjName);
    provenanceFile = fullfile(subjectOut, "provenance.mat");

    % Skip if subject output doesn't exist
    if ~isfile(provenanceFile)
        fprintf('  [skip] %s — no provenance.mat\n', subjName);
        continue;
    end

    % Skip if no sourceMapping from Brainstorm
    if ~isfield(subj, 'sourceMapping') || isempty(subj.sourceMapping)
        fprintf('  [skip] %s — no sourceMapping in db\n', subjName);
        continue;
    end
    sm = subj.sourceMapping;

    % Check that Reg.Sphere exists in the sourceMapping
    if ~isfield(sm, 'Reg') || ~isfield(sm.Reg, 'Sphere') || ...
       ~isfield(sm.Reg.Sphere, 'Vertices') || isempty(sm.Reg.Sphere.Vertices)
        fprintf('  [skip] %s — sourceMapping has no Reg.Sphere\n', subjName);
        continue;
    end

    % Load existing provenance — keep everything
    tmp = load(provenanceFile, 'provenance');
    provenance = tmp.provenance;

    % Check if already patched (Reg.Sphere present and same size)
    if isfield(provenance, 'Reg') && isfield(provenance.Reg, 'Sphere') && ...
       isfield(provenance.Reg.Sphere, 'Vertices') && ...
       ~isempty(provenance.Reg.Sphere.Vertices)
        fprintf('  [skip] %s — Reg.Sphere already present (%d vertices)\n', ...
            subjName, size(provenance.Reg.Sphere.Vertices, 1));
        continue;
    end

    % ---- Inject surface fields (add/update only these) ----
    provenance.Reg = sm.Reg;

    if isfield(sm, 'surfaceVertices') && ~isempty(sm.surfaceVertices)
        provenance.surfaceVertices = sm.surfaceVertices;
    end
    if isfield(sm, 'surfaceFaces') && ~isempty(sm.surfaceFaces)
        provenance.surfaceFaces = sm.surfaceFaces;
    end
    if isfield(sm, 'surfaceFullPath') && ~isempty(sm.surfaceFullPath)
        provenance.surfaceFullPath = string(sm.surfaceFullPath);
    end
    if isfield(sm, 'SurfaceFile') && ~isempty(sm.SurfaceFile)
        provenance.surfaceFile = string(sm.SurfaceFile);
    end

    % ---- Save back (preserves all other fields) ----
    save(provenanceFile, 'provenance', '-v7.3');

    fprintf('  [patched] %s — Reg.Sphere (%d vertices), surface: %s\n', ...
        subjName, size(sm.Reg.Sphere.Vertices, 1), sm.SurfaceFile);
end

fprintf('========================================\n');
fprintf('Reg.Sphere provenance patch complete.\n');
fprintf('========================================\n');
