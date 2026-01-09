function D = dictionary()
%BCT.RUNTIME.KERNELS.DICTIONARY  Executable kernel evaluator dictionary
%
%   D = bct.runtime.kernels.dictionary()
%
% Purpose
%   Returns a dictionary mapping kernel IDs to executable evaluator functions.
%   This is the runtime dispatch layer for kernel execution.
%
% Output
%   D - MATLAB dictionary
%       keys: kernel Id (string)
%       values: evaluator function_handle @(x,p)->y
%               where x is axis vector, p is parameter struct
%
% Contract
%   - Built from bct.registry.kernels.defs()
%   - Validates registry before building
%   - Uses persistent cache for performance
%   - Cache can be cleared with bct.runtime.kernels.clearCache()
%   - Must error if registry invalid (never silently skip entries)
%
% Usage
%   D = bct.runtime.kernels.dictionary();
%   gaussian = D("Gaussian");
%   axis = linspace(-5, 5, 501).';
%   params = struct('mu', 0, 'sigma', 1);
%   y = gaussian(axis, params);
%
% See also: bct.runtime.kernels.resolve, bct.registry.kernels.defs

    persistent cachedDict
    
    % Return cached dictionary if available
    if ~isempty(cachedDict)
        D = cachedDict;
        return;
    end
    
    % Get and validate registry
    defs = bct.registry.kernels.defs();
    bct.registry.kernels.validate(defs);
    
    % Build dictionary
    D = dictionary();
    
    for i = 1:numel(defs)
        entry = defs(i);
        
        % Ensure Evaluate is present and is function handle
        if ~isfield(entry, 'Evaluate') || ~isa(entry.Evaluate, 'function_handle')
            error('bct:runtime:kernels:MissingEvaluate', ...
                'Kernel %s missing valid Evaluate function', entry.Id);
        end
        
        % Map Id to evaluator
        D(entry.Id) = entry.Evaluate;
    end
    
    % Cache for future calls
    cachedDict = D;
end
