function [D, meta] = dictionary(context)
%BCT.RUNTIME.BRUSHES.DICTIONARY  Fast brush lookup dictionary
%
%   D = bct.runtime.brushes.dictionary()
%   D = bct.runtime.brushes.dictionary(context)
%   [D, meta] = bct.runtime.brushes.dictionary(context)
%
% Purpose:
%   Provides fast brush lookup via dictionary (ID → BrushSpec).
%   Optionally filters brushes based on manifold capabilities.
%
% Inputs:
%   context - (optional) struct with:
%             .manifold          - bct.Manifold object
%             .checkDependencies - logical (default: true)
%             .forceRefresh      - logical (default: false)
%
% Outputs:
%   D    - dictionary mapping BrushId (string) → BrushSpec (struct)
%   meta - struct with statistics:
%          .numBrushes - number of brushes in dictionary
%          .cacheTime  - when dictionary was cached
%          .filtered   - whether dependency filtering was applied
%
% Caching:
%   Dictionary is cached persistently for performance.
%   Call bct.runtime.brushes.clearCache() to force rebuild.
%
% Examples:
%   % Get dictionary of all brushes
%   D = bct.runtime.brushes.dictionary();
%
%   % Get dictionary filtered by manifold capabilities
%   context = struct('manifold', M);
%   D = bct.runtime.brushes.dictionary(context);
%
%   % Force refresh
%   context = struct('forceRefresh', true);
%   D = bct.runtime.brushes.dictionary(context);
%
% See also: bct.registry.brushes, bct.runtime.brushes.resolve

    persistent cachedDict
    persistent cacheTime
    
    % Check if cache needs refresh
    needsRefresh = isempty(cachedDict) || ...
                   (nargin == 1 && isfield(context, 'forceRefresh') && context.forceRefresh);
    
    if needsRefresh || nargin == 0
        % Build from registry
        defs = bct.registry.brushes();
        
        % Build dictionary
        cachedDict = dictionary();
        for i = 1:length(defs)
            cachedDict(defs(i).Id) = defs(i);
        end
        cacheTime = datetime('now');
    end
    
    % Apply filtering if context with manifold provided
    if nargin == 1 && isfield(context, 'manifold')
        D = filterByDependencies(cachedDict, context);
        wasFiltered = true;
    else
        D = cachedDict;
        wasFiltered = false;
    end
    
    % Build metadata if requested
    if nargout > 1
        meta = struct(...
            'numBrushes', length(D), ...
            'cacheTime',  cacheTime, ...
            'filtered',   wasFiltered ...
        );
    end
end

function filtered = filterByDependencies(D, context)
%FILTERBYDEPENDENCIES  Filter brushes based on manifold capabilities
%
% Inputs:
%   D       - dictionary of all brushes
%   context - struct with .manifold and optional .checkDependencies
%
% Output:
%   filtered - dictionary with only brushes whose dependencies are satisfied

    % Check if filtering is disabled
    if isfield(context, 'checkDependencies') && ~context.checkDependencies
        filtered = D;
        return;
    end
    
    % Create new filtered dictionary
    filtered = dictionary();
    
    % Check each brush
    ids = keys(D);
    for i = 1:length(ids)
        spec = D(ids(i));
        
        if isDependencySatisfied(spec, context.manifold)
            filtered(ids(i)) = spec;
        end
    end
end

function satisfied = isDependencySatisfied(spec, manifold)
%ISDEPENDENCYSATISFIED  Check if brush requirements are met by manifold
%
% Inputs:
%   spec     - BrushSpec struct
%   manifold - bct.Manifold object
%
% Output:
%   satisfied - true if all requirements met

    satisfied = true;
    
    % No requirements means always satisfied
    if ~isfield(spec, 'Requires') || isempty(spec.Requires)
        return;
    end
    
    % Check each requirement
    for i = 1:length(spec.Requires)
        req = spec.Requires(i);
        
        switch req
            case "Graph"
                try
                    manifold.Graph();
                catch
                    satisfied = false;
                    return;
                end
                
            case "DEC"
                try
                    manifold.DEC();
                catch
                    satisfied = false;
                    return;
                end
                
            case "Eigenpairs"
                % Eigenpairs are computed through manifold.eigenmodes()
                try
                    % Check if eigenmodes can be computed
                    % (we don't actually compute them here, just verify capability)
                    if manifold.numVertices() < 1
                        satisfied = false;
                        return;
                    end
                catch
                    satisfied = false;
                    return;
                end
                
            otherwise
                % Unknown requirement - assume not satisfied
                warning('bct:runtime:brushes:UnknownRequirement', ...
                    'Unknown requirement "%s" for brush "%s"', req, spec.Id);
                satisfied = false;
                return;
        end
    end
end
