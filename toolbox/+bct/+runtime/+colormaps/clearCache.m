function clearCache()
%BCT.RUNTIME.COLORMAPS.CLEARCACHE  Clear persistent colormap dictionary cache
%
%   bct.runtime.colormaps.clearCache()
%
% Purpose
%   Clears the persistent cache used by bct.runtime.colormaps.dictionary().
%   Call this after modifying the registry or when you need to force
%   a rebuild of the runtime dictionary.
%
% Usage
%   % After modifying registry definitions
%   bct.runtime.colormaps.clearCache();
%   D = bct.runtime.colormaps.dictionary();  % Rebuilds from registry
%
% See also: bct.runtime.colormaps.dictionary

    % Clear persistent variables in dictionary function
    clear bct.runtime.colormaps.dictionary
end
