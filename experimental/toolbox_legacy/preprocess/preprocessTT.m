function [TTout, targetFs] = preprocessTT(TTin, varName)
%PREPROCESSTT  Resample->Detrend->Denoise a 1-channel timetable.
% Usage:
%   TTout = preprocessTT(TTin)                 % auto-detect channel var
%   TTout = preprocessTT(TTin, "MLC12")        % explicitly pick a variable
%
% Input:
%   TTin   : timetable with row times (duration or datetime) and a signal var
%   varName: (optional) string/char, variable name to use
%
% Output:
%   TTout  : timetable at 256 Hz with SAME variable name as input

    % --- pick the channel variable name ---
    vn = string(TTin.Properties.VariableNames);
    if nargin >= 2 && ~isempty(varName)
        var = string(varName);
        assert(any(vn == var), "Variable '%s' not found in TTin.", var);
    else
        % prefer a single numeric vector; otherwise take the first numeric var
        isNum = ismember(varfun(@class, TTin, "OutputFormat","cell"), ...
                         {'double','single'});
        if sum(isNum) >= 1
            var = vn(find(isNum,1,'first'));
        else
            error('No numeric variable found in TTin.');
        end
    end

    % --- time handling ---
    t0 = TTin.Time(1);
    tx = TTin.Time;
    if isduration(tx)
        tx = seconds(tx);                      % duration -> numeric seconds
    elseif isdatetime(tx)
        tx = seconds(tx - t0);                 % datetime -> seconds from start
    else
        error('Row times must be duration or datetime.');
    end

    % --- signal vector as column ---
    x = TTin.(var)(:);

    % --- handle NaNs (simple forward/back fill) ---
    if any(isnan(x))
        x = fillmissing(x,'linear','EndValues','nearest');
    end

    % --- original Fs estimate ---
    Fs0 = 1/median(diff(tx));

    % --- target Fs with proper anti-aliasing (polyphase resample) ---
    targetFs = 256;
    [p,q] = rat(targetFs/Fs0, 1e-12);
    y = resample(x, p, q);                     % anti-aliased

    % --- rebuild time vector at exactly targetFs, preserving start time ---
    n   = numel(y);
    Time = t0 + seconds((0:n-1).'/targetFs);

    % --- detrend & denoise ---
    y = double(detrend(y, 'linear'));
    y = wdenoise(y, 2, ...
        'Wavelet','sym8', ...
        'DenoisingMethod','Bayes', ...
        'ThresholdRule','Soft', ...
        'NoiseEstimate','LevelDependent');
y=zscore(y);
    % --- return timetable, keep the SAME variable name ---
    TTout = timetable(Time, single(y), 'VariableNames', cellstr(var));
end
