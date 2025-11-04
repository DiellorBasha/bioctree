function TT = read_bs_tt(fn)
% READ_BS_TT Load a Brainstorm data_block*.mat into a timetable.
%  - Variables: ch001, ch002, ...
%  - Row times from sample rate inferred via Time
%  - Data stored as single to be GPU-friendly

S = load(fn, 'F', 'Time', 'ChannelFlag');
if ~isfield(S,'F') || ~isfield(S,'Time')
    error('read_bs_tt:MissingVars','File %s is missing F or Time', fn);
end

Fs = 1/median(diff(S.Time));                 % sampling rate (Hz)
X  = single(S.F.');                          % [T x Ch]  (transpose!)
TT = array2timetable(X, 'SampleRate', Fs);   % regular sampling ⇒ use SampleRate

% Name variables ch001..chN
TT.Properties.VariableNames = compose('ch%03d', 1:size(X,2));

% Optional metadata you may want later:
TT.Properties.UserData.File         = fn;
TT.Properties.UserData.Fs           = Fs;
if isfield(S,'ChannelFlag'), TT.Properties.UserData.ChannelFlag = S.ChannelFlag; end
end
