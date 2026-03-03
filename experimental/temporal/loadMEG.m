function data = loadMEG(blockPath, channelPath, opts)
%LOADMEG Load MEG signals from Brainstorm data files.
%
%   data = loadMEG(blockPath, channelPath)
%   data = loadMEG(blockPath, channelPath, StudyPath=studyPath)
%
%   Loads a Brainstorm MEG data block and channel file, extracts MEG-type
%   channels, and returns a struct with the signal matrix, time vector,
%   sampling rate, and channel metadata.
%
%   Inputs:
%       blockPath   - Path to the data block .mat file (contains F, Time)
%       channelPath - Path to the channel .mat file (contains Channel struct)
%
%   Name-Value Arguments:
%       StudyPath   - (optional) Path to brainstormstudy.mat
%       ChannelType - (default "MEG") Channel type to extract
%
%   Output:
%       data - struct with fields:
%           .sigs      [nChans x nSamples] MEG signal matrix
%           .time      [1 x nSamples] time vector (seconds)
%           .fs        scalar sampling rate (Hz)
%           .chanNames {nChans x 1} cell array of channel names
%           .chanMask  [1 x nAllChans] logical mask for selected channels
%           .nChans    number of selected channels
%           .nSamples  number of time samples
%           .study     (optional) loaded study struct if StudyPath given
%
%   Example:
%       blockPath   = "Z:\...\data_block001.mat";
%       channelPath = "Z:\...\channel_ctf_acc1.mat";
%       data = loadMEG(blockPath, channelPath);
%
%   See also: signalFrequencyFeatureExtractor, extractAlphaBandpower

    arguments
        blockPath   (1,1) string {mustBeFile}
        channelPath (1,1) string {mustBeFile}
        opts.StudyPath   (1,1) string = ""
        opts.ChannelType (1,1) string = "MEG"
    end

    % Load raw data
    meg   = load(blockPath);
    chans = load(channelPath);

    % Extract channel type mask
    chanTypes = {chans.Channel.Type};
    chanNames = {chans.Channel.Name};
    chanMask  = strcmp(chanTypes, opts.ChannelType);

    if ~any(chanMask)
        error('loadMEG:NoChannels', ...
            'No channels of type "%s" found in channel file.', opts.ChannelType);
    end

    megNames = chanNames(chanMask).';

    % Time and sampling rate
    time = meg.Time;
    fs   = round(1 / diff(time(1:2)));

    % Extract signal matrix
    sigs = meg.F(chanMask, :);
    [nChans, nSamples] = size(sigs);

    % Build output struct
    data.sigs      = sigs;
    data.time      = time;
    data.fs        = fs;
    data.chanNames = megNames;
    data.chanMask  = chanMask;
    data.nChans    = nChans;
    data.nSamples  = nSamples;

    % Optional study
    if opts.StudyPath ~= ""
        data.study = load(opts.StudyPath);
    end

    fprintf('loadMEG: fs=%d Hz, nChans=%d, nSamples=%d (%.1f s)\n', ...
        fs, nChans, nSamples, nSamples/fs);
end
