function [segDs, winTbl] = makeWindowedDatastore(bandsPath, sfreq, nSamples, opts)
%MAKEWINDOWEDDATASTORE Create a time-windowed datastore over a bands matfile.
%
%   [segDs, winTbl] = makeWindowedDatastore(bandsPath, sfreq, nSamples)
%   [segDs, winTbl] = makeWindowedDatastore(..., Name=Value)
%
%   Builds a TransformedDatastore that lazily loads time windows from a
%   v7.3 .mat file containing a 3-D array X [nChannels × nSamples × nBands]
%   via matfile partial I/O.
%
%   Each read(segDs) returns a struct with:
%       .window        - 1-based window index
%       .tStartSec     - window start time (seconds)
%       .tStopSec      - window stop time (seconds)
%       .durationSec   - window duration (seconds)
%       .sampleStart   - 1-based start sample index
%       .sampleStop    - 1-based stop sample index
%       .nSamples      - number of samples in window
%       .sfreq         - sampling frequency (Hz)
%       .X             - [nChannels × nSamplesWin × nBands] data chunk
%
%   Inputs:
%       bandsPath - path to v7.3 .mat file containing variable X
%                   with shape [nChannels × nSamples × nBands]
%       sfreq     - sampling frequency in Hz
%       nSamples  - total number of time samples in X
%
%   Name-Value Arguments:
%       WindowSec   - window length in seconds (default 20)
%       OverlapSec  - overlap between consecutive windows in seconds
%                     (default 0, i.e. non-overlapping). Must be < WindowSec.
%       HopSec      - hop size in seconds (default: WindowSec - OverlapSec).
%                     If both OverlapSec and HopSec are specified, HopSec
%                     takes precedence.
%       VariableName - name of the variable in the .mat file (default "X")
%
%   Outputs:
%       segDs  - TransformedDatastore. Use reset(segDs); w = read(segDs);
%       winTbl - table of window metadata with columns:
%                window, sampleStart, sampleStop, nSamples,
%                tStartSec, tStopSec, durationSec
%
%   Examples:
%       % Non-overlapping 20 s windows:
%       [segDs, tbl] = makeWindowedDatastore(bandsPath, 600, 180001);
%       reset(segDs); w1 = read(segDs);
%
%       % 50% overlapping 10 s windows:
%       [segDs, tbl] = makeWindowedDatastore(bandsPath, 600, 180001, ...
%           WindowSec=10, OverlapSec=5);
%
%       % Custom hop size (2 s hop, 20 s window):
%       [segDs, tbl] = makeWindowedDatastore(bandsPath, 600, 180001, ...
%           WindowSec=20, HopSec=2);
%
%       % Iterate all windows:
%       reset(segDs);
%       while hasdata(segDs)
%           w = read(segDs);
%           fprintf('Window %d: %.1f–%.1f s  [%s]\n', ...
%               w.window, w.tStartSec, w.tStopSec, ...
%               strjoin(string(size(w.X)), '×'));
%       end
%
%   See also: matfile, arrayDatastore, transform

    arguments
        bandsPath  (1,1) string
        sfreq      (1,1) double {mustBePositive}
        nSamples   (1,1) double {mustBePositive, mustBeInteger}
        opts.WindowSec    (1,1) double {mustBePositive}          = 20
        opts.OverlapSec   (1,1) double {mustBeNonnegative}       = 0
        opts.HopSec       (1,1) double                           = NaN
        opts.VariableName (1,1) string                           = "X"
    end

    % ---- Validate inputs ----
    if ~isfile(bandsPath)
        error('makeWindowedDatastore:FileNotFound', ...
            'Bands file not found: %s', bandsPath);
    end

    winSamp = round(sfreq * opts.WindowSec);
    if winSamp > nSamples
        error('makeWindowedDatastore:WindowTooLong', ...
            'Window (%d samples) exceeds signal length (%d samples).', ...
            winSamp, nSamples);
    end

    % ---- Determine hop size ----
    if ~isnan(opts.HopSec) && opts.HopSec > 0
        hopSamp = round(sfreq * opts.HopSec);
    else
        hopSamp = round(sfreq * (opts.WindowSec - opts.OverlapSec));
    end

    if hopSamp < 1
        error('makeWindowedDatastore:BadHop', ...
            'Hop size must be ≥ 1 sample. Check OverlapSec < WindowSec.');
    end

    % ---- Build window table ----
    sampleStart  = (1:hopSamp:(nSamples - winSamp + 1))';
    sampleStop   = sampleStart + winSamp - 1;
    nWindows     = numel(sampleStart);
    window       = (1:nWindows)';
    samplesPerWin = repmat(winSamp, nWindows, 1);
    tStartSec    = (sampleStart - 1) / sfreq;
    tStopSec     = (sampleStop  - 1) / sfreq;
    durationSec  = repmat(opts.WindowSec, nWindows, 1);

    winTbl = table(window, sampleStart, sampleStop, samplesPerWin, ...
                   tStartSec, tStopSec, durationSec);

    % ---- Build datastore ----
    metaDs = arrayDatastore(winTbl, ...
        "IterationDimension", 1, ...
        "OutputType", "cell");

    m = matfile(bandsPath);
    varName = opts.VariableName;

    segDs = transform(metaDs, @(c) makeStruct(c{1}, m, sfreq, varName));
end


% =========================================================================
%  HELPER
% =========================================================================

function s = makeStruct(row, m, sfreq, varName)
%MAKESTRUCT Build a self-describing struct for one time window.
%   Handles both 2-D [nChannels × nSamples] and
%   3-D [nChannels × nSamples × nBands] data transparently.
    vn = char(varName);
    sz = size(m, vn);
    if numel(sz) >= 3
        chunk = m.(vn)(:, row.sampleStart:row.sampleStop, :);
    else
        chunk = m.(vn)(:, row.sampleStart:row.sampleStop);
    end
    s = struct( ...
        "window",      row.window, ...
        "tStartSec",   row.tStartSec, ...
        "tStopSec",    row.tStopSec, ...
        "durationSec", row.durationSec, ...
        "sampleStart", row.sampleStart, ...
        "sampleStop",  row.sampleStop, ...
        "nSamples",    row.samplesPerWin, ...
        "sfreq",       sfreq, ...
        "X",           chunk );
end
