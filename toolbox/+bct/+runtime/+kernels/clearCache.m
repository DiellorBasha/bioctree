function clearCache()
%BCT.RUNTIME.KERNELS.CLEARCACHE  Clear persistent kernel dictionary cache
%
%   bct.runtime.kernels.clearCache()
%
% Purpose
%   Clears the persistent cache used by bct.runtime.kernels.dictionary().
%   Call this after modifying the registry or when you need to force
%   a rebuild of the runtime dictionary.
%
% Usage
%   % After modifying registry definitions
%   bct.runtime.kernels.clearCache();
%   D = bct.runtime.kernels.dictionary();  % Rebuilds from registry
%
% See also: bct.runtime.kernels.dictionary

    % Clear persistent variables in dictionary function
    clear bct.runtime.kernels.dictionary
end
