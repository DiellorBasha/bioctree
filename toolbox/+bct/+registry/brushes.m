function varargout = brushes(action, varargin)
%BCT.REGISTRY.BRUSHES  Unified interface to brush registry
%
%   USAGE PATTERNS
%   --------------
%
%   1. Get all brush definitions:
%      defs = bct.registry.brushes();
%      defs = bct.registry.brushes('all');
%
%   2. Get specific brush:
%      spec = bct.registry.brushes('get', brushId);
%
%   3. Validate a brush spec:
%      [ok, msg] = bct.registry.brushes('validate', brushSpec);
%
%   4. List available brushes:
%      ids = bct.registry.brushes('list');
%      [ids, categories] = bct.registry.brushes('list');
%
%   5. Get schema:
%      schema = bct.registry.brushes('schema');
%
% OUTPUTS
% -------
%   defs   : struct array of brush definitions
%   spec   : single brush specification struct
%   ok     : logical validation result
%   msg    : char array with validation message
%   ids    : string array of brush identifiers
%   schema : struct with RequiredFields and AllowedValues
%
% See also: bct.registry.brushes.defs, bct.registry.brushes.validate,
%           bct.runtime.brushes.dictionary

    if nargin == 0
        action = 'all';
    end

    switch lower(action)
        case {'all', 'defs'}
            % Get all brush definitions
            varargout{1} = bct.registry.brushes.defs();

        case 'get'
            % Get specific brush by ID
            if nargin < 2
                error('bct:registry:brushes:MissingArgument', ...
                    'Brush ID required for ''get'' action');
            end
            brushId = varargin{1};
            defs = bct.registry.brushes.defs();
            idx = find(strcmp({defs.Id}, brushId), 1);
            if isempty(idx)
                error('bct:registry:brushes:UnknownBrush', ...
                    'Unknown brush ID: %s', brushId);
            end
            varargout{1} = defs(idx);

        case 'validate'
            % Validate a brush spec
            if nargin < 2
                error('bct:registry:brushes:MissingArgument', ...
                    'Brush spec required for ''validate'' action');
            end
            brushSpec = varargin{1};
            try
                bct.registry.brushes.validate(brushSpec);
                varargout{1} = true;
                if nargout > 1
                    varargout{2} = 'Valid';
                end
            catch ME
                varargout{1} = false;
                if nargout > 1
                    varargout{2} = ME.message;
                else
                    rethrow(ME);
                end
            end

        case 'list'
            % List available brushes
            defs = bct.registry.brushes.defs();
            varargout{1} = string({defs.Id})';
            if nargout > 1
                varargout{2} = string({defs.Category})';
            end

        case 'schema'
            % Get validation schema
            varargout{1} = bct.registry.brushes.schema();

        otherwise
            error('bct:registry:brushes:UnknownAction', ...
                'Unknown action: %s. Valid: all, get, validate, list, schema', action);
    end

end
