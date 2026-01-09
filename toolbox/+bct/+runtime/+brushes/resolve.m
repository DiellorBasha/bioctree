function spec = resolve(id, context)
%BCT.RUNTIME.BRUSHES.RESOLVE  Resolve brush by ID with context
%
%   spec = bct.runtime.brushes.resolve(id)
%   spec = bct.runtime.brushes.resolve(id, context)
%
% Purpose:
%   Resolves brush by ID and optionally applies context-aware defaults
%   and parameter merging.
%
% Inputs:
%   id      - Brush identifier (string)
%   context - (optional) struct with:
%             .manifold - bct.Manifold object
%             .params   - user-provided parameters (merged with defaults)
%
% Output:
%   spec - Complete BrushSpec with optional additional fields:
%          .DefaultParamsResolved - context-aware default parameters
%          .ParamRangesResolved   - context-aware parameter ranges
%
% Examples:
%   % Basic resolution
%   spec = bct.runtime.brushes.resolve('patch_gaussian');
%
%   % With manifold context
%   context = struct('manifold', M);
%   spec = bct.runtime.brushes.resolve('patch_gaussian', context);
%
%   % With user parameters
%   context = struct('manifold', M, 'params', struct('sigma', 10));
%   spec = bct.runtime.brushes.resolve('patch_gaussian', context);
%
% See also: bct.runtime.brushes.dictionary, bct.brush.apply

    arguments
        id (1,1) string
        context struct = struct()
    end
    
    % Get dictionary (filtered by context if manifold provided)
    if isfield(context, 'manifold')
        D = bct.runtime.brushes.dictionary(context);
    else
        D = bct.runtime.brushes.dictionary();
    end
    
    % Lookup brush
    if ~isKey(D, id)
        % Provide helpful error message with available brushes
        availableIds = keys(D);
        if isempty(availableIds)
            errorMsg = sprintf('Brush "%s" not found and no brushes are available.', id);
        else
            errorMsg = sprintf('Brush "%s" not found. Available brushes: %s', ...
                id, strjoin(availableIds, ', '));
        end
        error('bct:runtime:brushes:UnknownBrush', '%s', errorMsg);
    end
    
    spec = D(id);
    
    % Apply context if provided
    if isfield(context, 'manifold')
        M = context.manifold;
        
        % Compute context-aware defaults
        try
            spec.DefaultParamsResolved = spec.DefaultParams(M);
        catch ME
            warning('bct:runtime:brushes:DefaultParamsFailed', ...
                'Failed to compute default parameters for brush "%s": %s', ...
                id, ME.message);
            spec.DefaultParamsResolved = struct();
        end
        
        % Compute context-aware ranges
        try
            spec.ParamRangesResolved = spec.ParamRanges(M);
        catch ME
            warning('bct:runtime:brushes:ParamRangesFailed', ...
                'Failed to compute parameter ranges for brush "%s": %s', ...
                id, ME.message);
            spec.ParamRangesResolved = struct();
        end
        
        % Merge with user parameters if provided
        if isfield(context, 'params')
            spec.DefaultParamsResolved = mergeParams(...
                spec.DefaultParamsResolved, context.params);
        end
    end
end

function merged = mergeParams(defaults, user)
%MERGEPARAMS  Merge user parameters with defaults
%
% User parameters override defaults. Validates that user parameters
% are valid field names.

    merged = defaults;
    
    if isempty(user)
        return;
    end
    
    userFields = fieldnames(user);
    defaultFields = fieldnames(defaults);
    
    for i = 1:length(userFields)
        field = userFields{i};
        
        % Warn about unknown parameters
        if ~ismember(field, defaultFields)
            warning('bct:runtime:brushes:UnknownParameter', ...
                'Parameter "%s" is not a recognized parameter. Ignoring.', field);
            continue;
        end
        
        merged.(field) = user.(field);
    end
end
