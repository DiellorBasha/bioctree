function roiTable = frameToSampleROIs(onFrames, offFrames, hopSize, frameSize, fs, nSamples)
%FRAMETOSAMPLEROIS Convert frame-domain burst runs to sample/time ROIs.
%
%   roiTable = frameToSampleROIs(onFrames, offFrames, hopSize, frameSize, fs, nSamples)
%
%   Converts burst onset/offset frame indices to sample indices and time
%   limits, producing a table suitable for signalMask construction.
%
%   Inputs:
%       onFrames  - [1 x N] frame onset indices
%       offFrames - [1 x N] frame offset indices
%       hopSize   - hop size in samples
%       frameSize - frame size in samples
%       fs        - sampling rate (Hz)
%       nSamples  - total number of samples (for clamping)
%
%   Output:
%       roiTable - table with columns:
%           .roiTime [N x 2] time limits in seconds
%           .roiLab  [N x 1] categorical labels ("alpha")
%           .onSamp  [N x 1] onset sample indices
%           .offSamp [N x 1] offset sample indices
%       Returns empty table if no ROIs.
%
%   Example:
%       [~, on, off] = detectBurstsHysteresis(z, 0.5, 0.5);
%       roiTbl = frameToSampleROIs(on, off, hopSize, frameSize, fs, nSamples);
%
%   See also: detectBurstsHysteresis, buildAlphaMask

    arguments
        onFrames  (1,:) double
        offFrames (1,:) double
        hopSize   (1,1) double {mustBePositive}
        frameSize (1,1) double {mustBePositive}
        fs        (1,1) double {mustBePositive}
        nSamples  (1,1) double {mustBePositive}
    end

    if isempty(onFrames)
        roiTable = table.empty;
        return
    end

    % Frame indices -> sample indices
    onSamp  = (onFrames(:)  - 1) * hopSize + 1;
    offSamp = (offFrames(:) - 1) * hopSize + frameSize;

    % Clamp to valid range
    onSamp  = max(1, onSamp);
    offSamp = min(nSamples, offSamp);

    % Convert to time (seconds)
    roiTime = [(onSamp - 1) / fs, (offSamp - 1) / fs];
    roiLab  = repmat(categorical("alpha"), numel(onSamp), 1);

    roiTable = table(roiTime, roiLab, onSamp, offSamp);
end
