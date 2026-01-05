function clearCache()
%BCT.RUNTIME.BRUSHES.CLEARCACHE  Clear runtime dictionary cache
%
%   bct.runtime.brushes.clearCache()
%
% Purpose:
%   Clears persistent cache in dictionary function, forcing rebuild
%   on next access. Useful when:
%   - Registry has been modified
%   - Debugging brush definitions
%   - Memory management
%
% Examples:
%   % Clear cache and rebuild
%   bct.runtime.brushes.clearCache();
%   D = bct.runtime.brushes.dictionary();
%
% See also: bct.runtime.brushes.dictionary

    % Clear persistent variables in dictionary function
    clear bct.runtime.brushes.dictionary
    
    fprintf('bct.runtime.brushes: Cache cleared\n');
end
