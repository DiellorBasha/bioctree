function D = colormap()
%BCT.RUNTIME.COLORMAP  Executable colormap generator dictionary
%
%   D = bct.runtime.colormap()
%
% Purpose
%   Provides executable mapping: colormapId → @(n) -> [n×3 double]
%   This is the runtime dispatch layer built from bct.registry.colormaps().
%
% Outputs
%   D - MATLAB dictionary with:
%       keys: string (colormap IDs)
%       values: function_handle with signature @(n) -> [n×3 double]
%
% Construction Policy
%   For each entry in bct.registry.colormaps():
%     - Provider="matlab": D(id) = @(n) feval(id, n)
%     - Provider="bct": D(id) = @(n) bct.ui.color.maps.<id>(n)
%
% Caching
%   Dictionary is cached internally (persistent) for performance.
%   Clear functions to rebuild.
%
% See also: bct.registry.colormaps, bct.ui.color.resolve

    persistent cachedDict
    
    % Return cached dictionary if available
    if ~isempty(cachedDict)
        D = cachedDict;
        return;
    end
    
    % Build dictionary from registry
    defs = bct.registry.colormaps();
    
    % Initialize dictionary
    D = dictionary();
    
    for k = 1:numel(defs)
        id = string(defs(k).Id);
        provider = string(defs(k).Provider);
        
        switch provider
            case "matlab"
                % MATLAB built-in: call by name via feval
                D(id) = @(n) feval(id, n);
                
            case "bct"
                % BCT custom: call bct.ui.color.maps.<id>
                % Construct function handle dynamically
                funcName = sprintf('bct.ui.color.maps.%s', id);
                try
                    funcHandle = str2func(funcName);
                    D(id) = funcHandle;
                catch ME
                    warning('bct:runtime:colormap:MissingGenerator', ...
                        'Colormap "%s" registered but generator not found: %s\n  Error: %s', ...
                        id, funcName, ME.message);
                    % Skip this colormap
                    continue;
                end
                
            otherwise
                warning('bct:runtime:colormap:UnknownProvider', ...
                    'Unknown provider "%s" for colormap "%s"', provider, id);
        end
    end
    
    % Cache for future calls
    cachedDict = D;
end
