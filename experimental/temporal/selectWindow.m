function win = selectWindow(roiLimits, fs, nSamples, opts)
%SELECTWINDOW Select the longest ROI and return a padded sample window.
%
%   win = selectWindow(roiLimits, fs, nSamples)
%   win = selectWindow(roiLimits, fs, nSamples, Name=Value)
%
%   From a set of cleaned ROI time limits, selects the longest one, applies
%   optional padding, and returns sample indices for the selected window.
%
%   Inputs:
%       roiLimits - [M x 2] ROI time limits in seconds
%       fs        - sampling rate (Hz)
%       nSamples  - total number of samples
%
%   Name-Value Arguments:
%       FinalPad_s       - padding around the selected ROI (default 0.25)
%       MinSelectedWin_s - minimum window length; 0 to disable (default 0)
%       SelectionMode    - "longest" (default) or "strongest" (requires Power)
%       Power            - [M x 1] power per ROI (for "strongest" mode)
%
%   Output:
%       win - struct with fields:
%           .startIdx  - first sample index
%           .endIdx    - last sample index
%           .start_s   - start time in seconds
%           .end_s     - end time in seconds
%           .dur_s     - duration in seconds
%           .roiIdx    - index of the selected ROI in roiLimits
%       Returns empty struct if roiLimits is empty.
%
%   Example:
%       win = selectWindow(roiLimits, fs, nSamples, FinalPad_s=0.25);
%       sigsWin = sigs(:, win.startIdx:win.endIdx);
%
%   See also: buildAlphaMask, frameToSampleROIs

    arguments
        roiLimits  (:,2) double
        fs         (1,1) double {mustBePositive}
        nSamples   (1,1) double {mustBePositive}
        opts.FinalPad_s       (1,1) double {mustBeNonnegative} = 0.25
        opts.MinSelectedWin_s (1,1) double {mustBeNonnegative} = 0.00
        opts.SelectionMode    (1,1) string {mustBeMember(opts.SelectionMode, ...
            ["longest","strongest"])} = "longest"
        opts.Power            (:,1) double = []
    end

    if isempty(roiLimits)
        win = struct('startIdx',[], 'endIdx',[], 'start_s',[], ...
            'end_s',[], 'dur_s',[], 'roiIdx',[]);
        return
    end

    % Select ROI
    roiDur = roiLimits(:,2) - roiLimits(:,1);

    switch opts.SelectionMode
        case "longest"
            [~, imax] = max(roiDur);
        case "strongest"
            if isempty(opts.Power)
                error('selectWindow:NoPower', ...
                    'Power vector required for "strongest" selection mode.');
            end
            [~, imax] = max(opts.Power);
    end

    baseStart_s = roiLimits(imax, 1);
    baseEnd_s   = roiLimits(imax, 2);

    % Apply padding
    winStart_s = max(0, baseStart_s - opts.FinalPad_s);
    winEnd_s   = min((nSamples - 1) / fs, baseEnd_s + opts.FinalPad_s);

    % Enforce minimum window length
    if opts.MinSelectedWin_s > 0
        curLen = winEnd_s - winStart_s;
        if curLen < opts.MinSelectedWin_s
            extra = 0.5 * (opts.MinSelectedWin_s - curLen);
            winStart_s = max(0, winStart_s - extra);
            winEnd_s   = min((nSamples - 1) / fs, winEnd_s + extra);
        end
    end

    % Convert to sample indices
    startIdx = max(1, floor(winStart_s * fs) + 1);
    endIdx   = min(nSamples, ceil(winEnd_s * fs) + 1);

    % Build output
    win.startIdx = startIdx;
    win.endIdx   = endIdx;
    win.start_s  = (startIdx - 1) / fs;
    win.end_s    = (endIdx - 1) / fs;
    win.dur_s    = (endIdx - startIdx + 1) / fs;
    win.roiIdx   = imax;
end
