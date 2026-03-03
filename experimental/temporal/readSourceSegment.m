function [F_sensor, K, t, sfreq, chanNames, sampleBounds, sources] = readSourceSegment(sm, tStart, tEnd, opts)
%READSOURCESEGMENT Read raw sensor data and optionally project to source space.
%
%   [F_sensor, K, t, sfreq, chanNames] = readSourceSegment(sm, tStart, tEnd)
%   [sds, K, t, sfreq, chanNames] = readSourceSegment(sm, tStart, tEnd, AsDatastore=true)
%   [F_sensor, K, t, sfreq, chanNames, sampleBounds, sources] = readSourceSegment(sm, tStart, tEnd, ComputeSources=true)
%
%   Reads a time segment of raw continuous MEG data via Brainstorm's in_fread
%   and selects good channels. By default, returns the sensor data and the
%   ImagingKernel so that the caller can compute sources on demand (e.g. in
%   chunks). When ComputeSources=true, also multiplies K * F_sensor and
%   returns the full source-space time series as the seventh output.
%
%   Inputs:
%       sm     - sourceMapping struct from loadBrainstorm (one element)
%                Must contain: sFile, channelMat, GoodChannel, ImagingKernel,
%                              sfreq, ImportOptions
%       tStart - segment start time in seconds (inclusive)
%       tEnd   - segment end time in seconds (inclusive)
%
%   Name-Value Arguments:
%       Resample       - target sampling frequency in Hz (default 0 = no
%                        resampling). When set, the sensor data is resampled
%                        from the native sfreq to the target rate using
%                        MATLAB's resample(). The returned sfreq and t outputs
%                        reflect the new rate. Applied before ComputeSources
%                        and AsDatastore.
%       ComputeSources - logical (default false). When true, computes
%                        sources = K * F_sensor and returns it as the 7th
%                        output. For long segments this may require large
%                        memory (nSources × nSamples × 8 bytes).
%       AsDatastore    - logical (default false). When true, the first output
%                        is a signalDatastore with one member per good channel,
%                        labelled by chanNames. Requires Signal Processing Tbx.
%
%   Outputs:
%       F_sensor     - [nGoodChannels x nSamples] good-channel sensor data
%                      (or signalDatastore when AsDatastore=true)
%       K            - [nSources x nGoodChannels] ImagingKernel (same as
%                      sm.ImagingKernel, returned for convenience)
%       t            - [1 x nSamples] time vector in seconds, referenced to
%                      the full recording (not relative to the segment start)
%       sfreq        - sampling frequency in Hz
%       chanNames    - [nGoodChannels x 1] string array of channel names
%                      corresponding to rows of F_sensor (or datastore members)
%       sampleBounds - [1 x 2] sample indices used for in_fread [first, last]
%       sources      - [nSources x nSamples] source-space time series
%                      (only computed when ComputeSources=true, empty otherwise)
%
%   Example:
%       db = loadBrainstorm(protocolPath, LoadSourceMapping=true);
%       sm = db.subjects(1).sourceMapping;
%
%       % Read sensor data + kernel (default, memory-safe):
%       [F_sensor, K, t, sfreq, chanNames] = readSourceSegment(sm, 100, 250);
%       % t runs from 100 to 250 (absolute recording time)
%       % chanNames identifies each row of F_sensor
%
%       % Return as signalDatastore:
%       [sds, K, t, sfreq, chanNames] = readSourceSegment(sm, 100, 250, AsDatastore=true);
%       % sds.MemberNames contains the channel names
%
%       % Resample from 2400 Hz to 600 Hz and return as datastore:
%       [sds, K, t, sfreq, chanNames] = readSourceSegment(sm, 0, 300, ...
%           AsDatastore=true, Resample=600);
%       % sfreq is now 600, t has fewer samples
%
%       % Read and compute sources in one call (small segments only):
%       [~, ~, t, sfreq, ~, ~, sources] = readSourceSegment(sm, 0, 2, ComputeSources=true);
%
%   Algorithm:
%       1. Convert time bounds to sample indices
%       2. Read raw data: F_raw = in_fread(sFile, channelMat, ...)
%       3. Extract good channels: F_sensor = F_raw(GoodChannel, :)
%       4. (optional) Project to source space: sources = K * F_sensor
%
%   Requires:
%       Brainstorm toolbox on MATLAB path (for in_fread).
%
%   See also: loadBrainstorm, in_fread

    arguments
        sm     (1,1) struct
        tStart (1,1) double {mustBeNonnegative}
        tEnd   (1,1) double {mustBePositive}
        opts.Resample       (1,1) double  {mustBeNonnegative} = 0
        opts.ComputeSources (1,1) logical = false
        opts.AsDatastore    (1,1) logical = false
    end

    % ---- Validate sourceMapping struct ----
    requiredFields = {'sFile','channelMat','GoodChannel','ImagingKernel', ...
                      'sfreq','ImportOptions'};
    missing = setdiff(requiredFields, fieldnames(sm));
    if ~isempty(missing)
        error('readSourceSegment:InvalidInput', ...
            'sourceMapping struct is missing fields: %s', strjoin(missing, ', '));
    end

    % ---- Convert time to sample bounds ----
    sfreq = sm.sfreq;
    t0    = sm.sFile.prop.times(1);  % recording start time

    sampleStart = round((tStart - t0) * sfreq);
    sampleEnd   = round((tEnd   - t0) * sfreq);

    % Clip to valid range
    totalSamples = round(diff(sm.sFile.prop.times) * sfreq);
    sampleStart  = max(sampleStart, 0);
    sampleEnd    = min(sampleEnd, totalSamples);
    sampleBounds = [sampleStart, sampleEnd];

    if sampleEnd <= sampleStart
        error('readSourceSegment:InvalidBounds', ...
            'Segment [%.3f, %.3f] s produces no samples (recording: [%.3f, %.3f] s).', ...
            tStart, tEnd, sm.sFile.prop.times(1), sm.sFile.prop.times(2));
    end

    % ---- Read raw sensor data via Brainstorm ----
    if ~exist('in_fread', 'file')
        error('readSourceSegment:NoBrainstorm', ...
            'in_fread not found. Add Brainstorm toolbox to MATLAB path.');
    end

    F_raw = in_fread(sm.sFile, sm.channelMat, 1, sampleBounds, [], sm.ImportOptions);

    % ---- Extract good channels ----
    F_sensor = F_raw(sm.GoodChannel, :);

    % ---- Return kernel for convenience ----
    K = sm.ImagingKernel;

    % ---- Extract good-channel names ----
    allNames = {sm.channelMat.Channel.Name};
    chanNames = string(allNames(sm.GoodChannel));
    chanNames = chanNames(:);

    % ---- Build absolute time vector ----
    sfreq = sm.sfreq;
    t = t0 + (sampleStart:sampleEnd) / sfreq;

    % ---- Optionally resample ----
    if opts.Resample > 0 && opts.Resample ~= sfreq
        [P, Q] = rat(opts.Resample / sfreq, 1e-6);
        F_sensor = resample(F_sensor', P, Q)';  % resample operates along columns
        t = linspace(t(1), t(end), size(F_sensor, 2));
        sfreq = opts.Resample;
    end

    % ---- Optionally project to source space ----
    if opts.ComputeSources
        sources = K * F_sensor;
    else
        sources = [];
    end

    % ---- Optionally wrap as signalDatastore ----
    if opts.AsDatastore
        nChans = size(F_sensor, 1);
        nSamp  = size(F_sensor, 2);
        C = cell(nChans, 1);
        for ci = 1:nChans
            C{ci} = F_sensor(ci, :)';  % column vector [N x 1]
        end
        sds = signalDatastore(C, 'SampleRate', sfreq);
        sds.MemberNames = chanNames;
        F_sensor = sds;
    end
end
