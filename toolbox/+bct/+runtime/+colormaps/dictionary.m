function D = dictionary()
%BCT.RUNTIME.COLORMAPS.DICTIONARY  Executable colormap generator dictionary
%
%   D = bct.runtime.colormaps.dictionary()
%
% Purpose
%   Returns a dictionary mapping colormap IDs to executable generator functions.
%   This is the runtime dispatch layer for colormap generation.
%
% Output
%   D - MATLAB dictionary
%       keys: colormap Id (string)
%       values: generator function_handle @(n)->[n×3 double]
%               where n is number of colors
%
% Contract
%   - Built from bct.registry.colormaps.defs()
%   - Validates registry before building
%   - Uses persistent cache for performance
%   - Cache can be cleared with bct.runtime.colormaps.clearCache()
%   - Provider dispatch:
%     * "matlab" → @(n) feval(id, n)
%     * "bct"    → @(n) bct.ui.color.maps.<id>(n)
%   - Must error if provider unknown or generator missing
%
% Usage
%   D = bct.runtime.colormaps.dictionary();
%   parula_gen = D("parula");
%   C = parula_gen(256);  % Returns 256×3 colormap
%
% See also: bct.runtime.colormaps.resolve, bct.registry.colormaps.defs

    persistent cachedDict
    
    % Return cached dictionary if available
    if ~isempty(cachedDict)
        D = cachedDict;
        return;
    end
    
    % Get and validate registry
    defs = bct.registry.colormaps.defs();
    bct.registry.colormaps.validate(defs);
    
    % Build dictionary
    D = dictionary();
    
    for i = 1:numel(defs)
        entry = defs(i);
        
        switch entry.Provider
            case "matlab"
                % MATLAB built-in colormap
                D(entry.Id) = @(n) feval(char(entry.Id), n);
                
            case "bct"
                % BCT custom colormap
                % Resolve to bct.ui.color.maps.<id>
                try
                    mapFcn = str2func(sprintf('bct.ui.color.maps.%s', entry.Id));
                    D(entry.Id) = mapFcn;
                catch ME
                    error('bct:runtime:colormaps:MissingGenerator', ...
                        'BCT colormap generator not found: bct.ui.color.maps.%s\n%s', ...
                        entry.Id, ME.message);
                end
                
            otherwise
                error('bct:runtime:colormaps:UnknownProvider', ...
                    'Unknown colormap provider "%s" for Id "%s"', ...
                    entry.Provider, entry.Id);
        end
    end
    
    % Cache for future calls
    cachedDict = D;
end
