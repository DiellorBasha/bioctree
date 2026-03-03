%% run_temporal_pipeline.m
% Main script demonstrating the modular temporal analysis pipeline.
%
% This script replicates the functionality of prelimomega.m using the
% modular functions in experimental/temporal/.
%
% Workflow:
%   1. Load MEG data               -> loadMEG
%   2. Extract alpha bandpower      -> extractAlphaBandpower
%   3a. Global detection pipeline   -> detectGlobalAlpha
%   3b. Per-channel detection       -> detectPerChannelAlpha
%   4. Visualize results            -> plotAlphaDetection, plotGlobalROIs, etc.
%
% The output (result.sigsWin, result.win) provides the selected time window
% ready for subsequent spectral analysis with bct eigenmodes.

%% ---- Add temporal functions to path ----
addpath(fullfile(fileparts(mfilename('fullpath'))));

%% ---- 0) Configure data paths ----
blockPath   = "Z:\brainstorm_protocols\TutorialOmega\data\sub-0002\sub-0002_ses-01_task-rest_run-01_meg_notch_high_resample\data_block001.mat";
channelPath = "Z:\brainstorm_protocols\TutorialOmega\data\sub-0002\sub-0002_ses-01_task-rest_run-01_meg_notch_high_resample\channel_ctf_acc1.mat";
studyPath   = "Z:\brainstorm_protocols\TutorialOmega\data\sub-0002\sub-0002_ses-01_task-rest_run-01_meg_notch_high_resample\brainstormstudy.mat";

%% ---- 1) Load MEG data ----
data = loadMEG(blockPath, channelPath, StudyPath=studyPath);

%% ---- 2) Extract alpha bandpower ----
[alphaPow, frameInfo] = extractAlphaBandpower(data.sigs, data.fs);

%% ========================================================
%  APPROACH A: Global alpha detection
%  (single median-across-channels index → hysteresis → window)
%% ========================================================

P_global = defaultParams(Preset="global");

% Override defaults if desired:
% P_global.thrOn  = 0.8;
% P_global.thrOff = 0.3;

resultGlobal = detectGlobalAlpha( ...
    data.sigs, data.fs, data.nSamples, alphaPow, frameInfo, P_global);

% ---- Diagnostic plots ----
plotAlphaDetection(resultGlobal, frameInfo);

if ~isempty(resultGlobal.alphaMask)
    plotGlobalROIs(resultGlobal.alphaMask, data.sigs, data.fs, frameInfo, ...
        AlphaGlobal    = resultGlobal.alphaGlobal, ...
        ChannelIndices = [1 50 100 150 200 250], ...
        ChannelNames   = data.chanNames);
end

%% ========================================================
%  APPROACH B: Per-channel alpha detection with global merge
%  (per-channel z-score → per-channel ROIs → channel-count merge → window)
%% ========================================================

P_perch = defaultParams(Preset="perchannel");

% Override defaults if desired:
% P_perch.minChanFrac = 0.20;
% P_perch.thrOn = 2.0;

resultPerCh = detectPerChannelAlpha( ...
    data.sigs, data.fs, data.nSamples, alphaPow, frameInfo, P_perch);

% ---- Diagnostic plots ----
plotPerChannelSummary(resultPerCh, frameInfo);

if ~isempty(resultPerCh.alphaMaskGlobal) && ~isempty(resultPerCh.roiLimits)
    plotGlobalROIs(resultPerCh.alphaMaskGlobal, data.sigs, data.fs, frameInfo, ...
        ChannelIndices = [1 50 100 150 200 250], ...
        ChannelNames   = data.chanNames);
end

%% ---- Summary ----
fprintf('\n=== Pipeline Summary ===\n');
if ~isempty(resultGlobal.win.startIdx)
    fprintf('Global approach:     %.3f – %.3f s  (%.3f s)\n', ...
        resultGlobal.win.start_s, resultGlobal.win.end_s, resultGlobal.win.dur_s);
end
if ~isempty(resultPerCh.win.startIdx)
    fprintf('Per-channel approach: %.3f – %.3f s  (%.3f s)\n', ...
        resultPerCh.win.start_s, resultPerCh.win.end_s, resultPerCh.win.dur_s);
end

%% ---- Ready for spectral analysis ----
% Use resultGlobal.sigsWin or resultPerCh.sigsWin as input to bct
% spectral analysis (eigenmode projection on the cortical manifold).
%
% Example next step:
%   M = bct.data.load('Id', 'fsaverage_rh_pial');
%   [lambda, U] = M.eigenmodes(100);
%   % Map sigsWin channels to manifold vertices, then project onto eigenmodes
