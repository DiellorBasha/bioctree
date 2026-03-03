function P = defaultParams(opts)
%DEFAULTPARAMS Return default parameter struct for the temporal analysis pipeline.
%
%   P = defaultParams()
%   P = defaultParams(Preset="global")
%   P = defaultParams(Preset="perchannel")
%
%   Returns a struct P containing all tunable parameters for alpha burst
%   detection, organized into sections: band definition, framing, feature
%   extraction, smoothing, detection thresholds, ROI cleanup, and window
%   selection.
%
%   Name-Value Arguments:
%       Preset - "global" (default) or "perchannel"
%                "global"     : single-pass median-across-channels detection
%                "perchannel" : per-channel detection with channel-merge
%
%   Output:
%       P - struct with all pipeline parameters
%
%   Example:
%       P = defaultParams();
%       P.thrOn = 1.0;  % override threshold
%
%   See also: extractAlphaBandpower, detectGlobalAlpha, detectPerChannelAlpha

    arguments
        opts.Preset (1,1) string {mustBeMember(opts.Preset, ...
            ["global","perchannel"])} = "global"
    end

    % ---- Band definition ----
    P.alphaBand = [7.5 12.5];          % Hz

    % ---- Framing ----
    P.frameDur_s = 0.50;               % frame length (seconds)
    P.hopDur_s   = 0.10;               % hop / stride (seconds)

    % ---- Smoothing ----
    P.smooth_s = 0.50;                 % smoothing window (seconds of frames)

    % ---- Detection thresholds (robust z-score) ----
    switch opts.Preset
        case "global"
            P.thrOn  = 0.5;
            P.thrOff = 0.5;
        case "perchannel"
            P.thrOn  = 1.5;
            P.thrOff = 1.5;
    end

    % ---- Per-channel ROI cleanup (signalMask) ----
    P.minLength_s      = 0.30;
    P.mergeDistance_s   = 1.00;
    P.leftExtension_s  = 0.50;
    P.rightExtension_s = 0.50;

    % ---- Per-channel merge parameters (perchannel preset only) ----
    if opts.Preset == "perchannel"
        P.minLength_s      = 0.20;
        P.mergeDistance_s   = 0.10;
        P.leftExtension_s  = 0.00;
        P.rightExtension_s = 0.00;

        P.minChanFrac  = 0.15;        % fraction of channels that must be active
        P.minChanCount = [];           % if non-empty, overrides minChanFrac

        % Global ROI cleanup (after channel merge)
        P.globalMinLength_s     = 0.20;
        P.globalMergeDistance_s = 0.15;
        P.globalLeftExt_s       = 0.00;
        P.globalRightExt_s      = 0.00;
    end

    % ---- Final window selection ----
    P.finalPad_s       = 0.25;        % padding around selected ROI (seconds)
    P.minSelectedWin_s = 0.00;        % minimum total window length (0 = off)
end
