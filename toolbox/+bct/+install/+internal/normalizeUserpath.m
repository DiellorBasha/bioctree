function up = normalizeUserpath()
%NORMALIZEUSERPATH Get first userpath entry
%
% Returns the first entry from MATLAB's userpath.

upRaw = userpath;

% userpath returns colon/semicolon-separated list
if ispc
    sep = ';';
else
    sep = ':';
end

% Split and get first entry
parts = strsplit(upRaw, sep);
parts = parts(~cellfun(@isempty, parts));

if isempty(parts)
    % Fallback to Documents/MATLAB
    if ispc
        up = fullfile(getenv('USERPROFILE'), 'Documents', 'MATLAB');
    else
        up = fullfile(getenv('HOME'), 'Documents', 'MATLAB');
    end
else
    up = parts{1};
end

end
