function [burstMask, onIdx, offIdx] = detectBurstsHysteresis(z, thrOn, thrOff)
%DETECTBURSTSHYSTERESIS Detect burst periods using hysteresis thresholding.
%
%   [burstMask, onIdx, offIdx] = detectBurstsHysteresis(z, thrOn, thrOff)
%
%   Applies hysteresis-based detection to a z-scored time series. A burst
%   begins when z >= thrOn and ends when z <= thrOff. Works on single-row
%   or multi-row inputs (each row processed independently).
%
%   Inputs:
%       z      - [nRows x nFrames] z-scored signal(s)
%       thrOn  - scalar onset threshold (z >= thrOn starts a burst)
%       thrOff - scalar offset threshold (z <= thrOff ends a burst)
%
%   Outputs:
%       burstMask - [nRows x nFrames] logical mask of burst periods
%       onIdx     - {nRows x 1} cell array of burst onset indices
%       offIdx    - {nRows x 1} cell array of burst offset indices
%
%   Example:
%       [mask, on, off] = detectBurstsHysteresis(z, 0.5, 0.5);
%
%   See also: computeRobustZscore, frameToSampleROIs

    arguments
        z      (:,:) double
        thrOn  (1,1) double
        thrOff (1,1) double
    end

    [nRows, nFrames] = size(z);
    burstMask = false(nRows, nFrames);
    onIdx  = cell(nRows, 1);
    offIdx = cell(nRows, 1);

    for ri = 1:nRows
        zr = z(ri, :);
        m  = false(1, nFrames);
        state = false;

        for k = 1:nFrames
            if ~state
                if zr(k) >= thrOn, state = true; end
            else
                if zr(k) <= thrOff, state = false; end
            end
            m(k) = state;
        end

        burstMask(ri, :) = m;

        % Extract runs
        d = diff([false, m, false]);
        onIdx{ri}  = find(d ==  1);
        offIdx{ri} = find(d == -1) - 1;
    end

    % If single row, unwrap from cell
    if nRows == 1
        onIdx  = onIdx{1};
        offIdx = offIdx{1};
    end
end
