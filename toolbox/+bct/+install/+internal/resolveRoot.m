function [depsRoot, source] = resolveRoot(optsRoot)
%RESOLVEROOT Resolve dependency installation root with precedence
%
% Precedence (highest to lowest):
%   1. optsRoot argument (if provided and non-empty)
%   2. Environment variable BCT_DEPS_ROOT
%   3. MATLAB preference bct/depsRoot
%   4. Default: <first userpath>/ThirdParty/bct

% 1. Explicit argument
if nargin > 0 && ~isempty(optsRoot)
    depsRoot = optsRoot;
    source = 'explicit argument';
    return;
end

% 2. Environment variable
envRoot = getenv('BCT_DEPS_ROOT');
if ~isempty(envRoot)
    depsRoot = envRoot;
    source = 'environment variable BCT_DEPS_ROOT';
    return;
end

% 3. Preference
if ispref('bct', 'depsRoot')
    prefRoot = getpref('bct', 'depsRoot');
    if ~isempty(prefRoot)
        depsRoot = prefRoot;
        source = 'MATLAB preference';
        return;
    end
end

% 4. Default userpath location
up = bct.install.internal.normalizeUserpath();
depsRoot = fullfile(up, 'ThirdParty', 'bct');
source = 'default (userpath/ThirdParty/bct)';

end
