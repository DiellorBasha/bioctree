function [z, alphaSmoothed] = computeRobustZscore(alphaPow, opts)
%COMPUTEROBUSTZSCORE Smooth and robust z-score alpha bandpower.
%
%   [z, alphaSmoothed] = computeRobustZscore(alphaPow)
%   [z, alphaSmoothed] = computeRobustZscore(alphaPow, Name=Value)
%
%   Applies log transform, median/mean smoothing, and robust z-score
%   (using median and MAD) to alpha bandpower. Works on both single-row
%   (global) and multi-row (per-channel) inputs.
%
%   Inputs:
%       alphaPow - [nChans x nFrames] or [1 x nFrames] bandpower matrix
%
%   Name-Value Arguments:
%       SmoothFrames - number of frames for smoothing window (default 5)
%       LogTransform - apply log(x + eps) before smoothing (default true)
%       GlobalMedian - if true, compute median across channels first to
%                      produce a [1 x nFrames] global index (default false)
%
%   Outputs:
%       z              - robust z-score, same size as input (or 1xN if GlobalMedian)
%       alphaSmoothed  - smoothed signal before z-scoring
%
%   The robust z-score is: z = (x - median(x)) / (1.4826 * MAD(x))
%   where MAD is the median absolute deviation, computed along dim 2.
%
%   Example:
%       [z, aS] = computeRobustZscore(alphaPow, SmoothFrames=5);
%       [zG, aSG] = computeRobustZscore(alphaPow, GlobalMedian=true);
%
%   See also: extractAlphaBandpower, detectBurstsHysteresis

    arguments
        alphaPow     (:,:) double
        opts.SmoothFrames (1,1) double {mustBePositive, mustBeInteger} = 5
        opts.LogTransform (1,1) logical = true
        opts.GlobalMedian (1,1) logical = false
    end

    % Log transform
    if opts.LogTransform
        X = log(alphaPow + eps);
    else
        X = alphaPow;
    end

    % Optional: reduce to global index (median across channels)
    if opts.GlobalMedian
        X = median(X, 1);  % [1 x nFrames]
    end

    % Smoothing: movmedian then movmean (along columns = dim 2)
    sf = opts.SmoothFrames;
    alphaSmoothed = movmedian(X, sf, 2);
    alphaSmoothed = movmean(alphaSmoothed, sf, 2);

    % Robust z-score (per row)
    med0 = median(alphaSmoothed, 2);
    madv = mad(alphaSmoothed, 1, 2);
    z    = (alphaSmoothed - med0) ./ (1.4826 * madv + eps);
end
