function plotAlphaDetection(result, frameInfo, opts)
%PLOTALPHADETECTION Plot alpha burst detection diagnostics (global pipeline).
%
%   plotAlphaDetection(result, frameInfo)
%   plotAlphaDetection(result, frameInfo, Name=Value)
%
%   Produces a 3-panel diagnostic figure showing:
%     1) Global alpha index (per frame)
%     2) Robust z-score with hysteresis thresholds
%     3) Raw burst mask with selected window markers
%
%   Inputs:
%       result    - struct from detectGlobalAlpha
%       frameInfo - struct from extractAlphaBandpower
%
%   Name-Value Arguments:
%       FigureName - figure title (default "Alpha ROI detection")
%
%   Example:
%       result = detectGlobalAlpha(sigs, fs, nSamples, alphaPow, fi, P);
%       plotAlphaDetection(result, fi);
%
%   See also: detectGlobalAlpha, plotGlobalROIs, plotChannelROIs

    arguments
        result    (1,1) struct
        frameInfo (1,1) struct
        opts.FigureName (1,1) string = "Alpha ROI detection (global)"
    end

    tFrames = result.tFrames;
    P       = result.P;

    figure('Name', opts.FigureName);

    % Panel 1: Global alpha index
    subplot(3,1,1);
    plot(tFrames, result.alphaGlobal);
    grid on;
    xlabel('Time (s)');
    ylabel('median log(\alpha power)');
    title('Global alpha index (per frame)');

    % Panel 2: Robust z-score
    subplot(3,1,2);
    plot(tFrames, result.z);
    hold on; grid on;
    yline(P.thrOn,  '--r', 'thrOn');
    yline(P.thrOff, '--b', 'thrOff');
    xlabel('Time (s)');
    ylabel('robust z');
    title('Robust z-score + hysteresis thresholds');

    % Panel 3: Burst mask + window markers
    subplot(3,1,3);
    stairs(tFrames, double(result.burstMask), 'LineWidth', 1);
    grid on;
    xlabel('Time (s)');
    ylabel('burst mask');
    title('Raw hysteresis mask (pre signalMask cleanup)');

    if ~isempty(result.win.startIdx)
        hold on;
        xline(result.win.start_s, '-g', 'win start', 'LineWidth', 1.5);
        xline(result.win.end_s,   '-g', 'win end',   'LineWidth', 1.5);
    end
end
