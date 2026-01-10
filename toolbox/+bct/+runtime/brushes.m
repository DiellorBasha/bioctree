function varargout = brushes(action, varargin)
%BCT.RUNTIME.BRUSHES  Unified runtime interface for brush operations
%
%   USAGE PATTERNS
%   --------------
%
%   1. Get runtime dictionary (filtered by manifold capabilities):
%      dict = bct.runtime.brushes('dictionary', manifold);
%
%   2. Resolve brush with context:
%      spec = bct.runtime.brushes('resolve', brushId, context);
%      where context = struct('manifold', M, 'params', userParams);
%
%   3. Clear cache:
%      bct.runtime.brushes('clear');
%
%   4. Get available brushes for manifold:
%      ids = bct.runtime.brushes('list', manifold);
%
% OUTPUTS
% -------
%   dict : struct array of available brushes (filtered by dependencies)
%   spec : resolved brush specification with context-specific defaults
%   ids  : string array of available brush IDs
%
% Notes:
%   - dictionary() uses persistent caching for performance
%   - resolve() merges user params with context-aware defaults
%   - Filtering respects manifold capabilities (Graph, FEM, DEC, Eigenpairs)
%
% See also: bct.runtime.brushes.dictionary, bct.runtime.brushes.resolve,
%           bct.runtime.brushes.clearCache

    if nargin == 0
        error('bct:runtime:brushes:MissingAction', ...
            'Action required. Valid: dictionary, resolve, clear, list');
    end

    switch lower(action)
        case {'dictionary', 'dict'}
            % Get filtered dictionary
            if nargin < 2
                error('bct:runtime:brushes:MissingArgument', ...
                    'Manifold required for ''dictionary'' action');
            end
            manifold = varargin{1};
            varargout{1} = bct.runtime.brushes.dictionary(manifold);

        case 'resolve'
            % Resolve brush with context
            if nargin < 3
                error('bct:runtime:brushes:MissingArgument', ...
                    'Brush ID and context required for ''resolve'' action');
            end
            brushId = varargin{1};
            context = varargin{2};
            varargout{1} = bct.runtime.brushes.resolve(brushId, context);

        case {'clear', 'clearcache'}
            % Clear cache
            bct.runtime.brushes.clearCache();
            if nargout > 0
                varargout{1} = true;
            end

        case 'list'
            % List available brushes for manifold
            if nargin < 2
                error('bct:runtime:brushes:MissingArgument', ...
                    'Manifold required for ''list'' action');
            end
            manifold = varargin{1};
            dict = bct.runtime.brushes.dictionary(manifold);
            
            % Extract IDs from dictionary
            brushIds = keys(dict);
            varargout{1} = string(brushIds);

        otherwise
            error('bct:runtime:brushes:UnknownAction', ...
                'Unknown action: %s. Valid: dictionary, resolve, clear, list', action);
    end

end
