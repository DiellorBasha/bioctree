function [msk, roiLimits] = buildAlphaMask(roiTable, fs, opts)
%BUILDALPHAMASK Build a signalMask from ROI table with cleanup parameters.
%
%   [msk, roiLimits] = buildAlphaMask(roiTable, fs)
%   [msk, roiLimits] = buildAlphaMask(roiTable, fs, Name=Value)
%
%   Creates a MATLAB signalMask object from a table of ROI time limits,
%   applying built-in cleanup (MinLength, MergeDistance, extensions).
%
%   Inputs:
%       roiTable - table with columns roiTime [Nx2] and roiLab [Nx1]
%                  (as produced by frameToSampleROIs)
%       fs       - sampling rate (Hz)
%
%   Name-Value Arguments:
%       MinLength_s      - minimum ROI duration (default 0.30)
%       MergeDistance_s   - merge gap threshold (default 1.00)
%       LeftExtension_s  - left extension (default 0.50)
%       RightExtension_s - right extension (default 0.50)
%       Label            - category to keep (default "alpha")
%
%   Outputs:
%       msk       - signalMask object (after cleanup)
%       roiLimits - [M x 2] cleaned ROI time limits (seconds)
%                   Empty if all ROIs pruned.
%
%   Example:
%       roiTbl = frameToSampleROIs(on, off, hopSize, frameSize, fs, nSamples);
%       [msk, lims] = buildAlphaMask(roiTbl, fs, MinLength_s=0.3);
%
%   See also: signalMask, frameToSampleROIs, selectWindow

    arguments
        roiTable          table
        fs                (1,1) double {mustBePositive}
        opts.MinLength_s      (1,1) double {mustBeNonnegative} = 0.30
        opts.MergeDistance_s   (1,1) double {mustBeNonnegative} = 1.00
        opts.LeftExtension_s  (1,1) double {mustBeNonnegative} = 0.50
        opts.RightExtension_s (1,1) double {mustBeNonnegative} = 0.50
        opts.Label            (1,1) string = "alpha"
    end

    if isempty(roiTable)
        msk = signalMask.empty;
        roiLimits = [];
        return
    end

    % Source table for signalMask: two columns (limits, labels)
    srcTbl = table(roiTable.roiTime, roiTable.roiLab);

    msk = signalMask( ...
        srcTbl, ...
        "SampleRate",     fs, ...
        "MinLength",      max(1, round(opts.MinLength_s      * fs)), ...
        "MergeDistance",   max(0, round(opts.MergeDistance_s   * fs)), ...
        "LeftExtension",  max(0, round(opts.LeftExtension_s  * fs)), ...
        "RightExtension", max(0, round(opts.RightExtension_s * fs)));

    % Extract cleaned ROIs
    roiOut    = roimask(msk);
    roiLimits = roiOut{:, 1};
    roiLabels = roiOut{:, 2};

    % Filter by label
    keep = (roiLabels == categorical(opts.Label));
    roiLimits = roiLimits(keep, :);
end
