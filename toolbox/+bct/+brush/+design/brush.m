function w = brush(category, brushType, manifold, params, varargin)
%BCT.BRUSH.DESIGN.BRUSH  Design a brush using the brush registry
%
%   w = bct.brush.design.brush(category, brushType, manifold, params)
%   w = bct.brush.design.brush(category, brushType, manifold, params, time)
%
%   Inputs:
%     category   : 'patch', 'trajectory', or 'time'
%     brushType  : brush type name (e.g., 'spectral', 'gaussian', 'heat', 'geodesic')
%     manifold   : bct.Manifold object
%     params     : struct of brush-specific parameters
%     time       : bct.Time object (required for 'time' category)
%
%   Output:
%     w          : brush weights
%                  [N×1] for patch/trajectory
%                  [N×T] for time category
%
%   Description:
%     This function provides a unified interface to all brush types using
%     the brush registry. It validates inputs, retrieves the appropriate
%     brush function, and applies it with the given parameters.
%
%   Examples:
%     % Patch - Spectral gaussian
%     params.source = 100;
%     params.kernel = 'gaussian';
%     params.sigma = 15;
%     w = bct.brush.design.brush('patch', 'spectral', B.Manifold, params);
%
%     % Trajectory - Gaussian
%     params.source = 100;
%     params.target = 500;
%     params.sigma = 10;
%     w = bct.brush.design.brush('trajectory', 'gaussian', B.Manifold, params);
%
%     % Time - Heat diffusion
%     params.source = 100;
%     params.target = 500;
%     params.tau_range = [0.02, 0.4];
%     params.tau_profile = 'exponential';
%     w = bct.brush.design.brush('time', 'heat', B.Manifold, params, B.Time);
%
%     % Time - Moving spectral patch
%     [path, ~] = B.Manifold.Graph.shortestPath(100, 500);
%     params.source = @(t, T) path(min(round(t/T*length(path)), length(path)));
%     params.kernel = 'heat';
%     params.tau = 0.15;
%     w = bct.brush.design.brush('time', 'spectral', B.Manifold, params, B.Time);
%
%   See also: bct.brush.registry, bct.brush.patch, bct.brush.trajectory, bct.brush.time

    arguments
        category (1,:) char
        brushType (1,:) char
        manifold (1,1) bct.Manifold
        params struct
    end
    
    % Parse optional time argument
    if nargin > 4
        time = varargin{1};
        if ~isempty(time) && ~isa(time, 'bct.Time')
            error('bct:brush:design:InvalidTime', ...
                'Fifth argument must be a bct.Time object');
        end
    else
        time = [];
    end

    % Validate category
    category_lower = lower(category);
    valid_categories = {'patch', 'trajectory', 'time'};
    if ~ismember(category_lower, valid_categories)
        error('bct:brush:design:InvalidCategory', ...
            'Category must be one of: %s', strjoin(valid_categories, ', '));
    end
    
    % Check time requirement
    if strcmp(category_lower, 'time') && isempty(time)
        error('bct:brush:design:MissingTime', ...
            'Time domain required for time category brushes. ' + ...
            'Usage: bct.brush.design.brush(''time'', type, manifold, params, time)');
    end

    % Get registry
    R = bct.brush.registry();
    
    % Build registry key: category_brushType
    brushType_lower = lower(brushType);
    registry_key = [category_lower '_' brushType_lower];
    
    % Check if brush exists in registry
    if ~isfield(R, registry_key)
        % Try to find similar brushes for helpful error message
        available_brushes = fieldnames(R);
        category_brushes = available_brushes(startsWith(available_brushes, category_lower));
        
        if isempty(category_brushes)
            error('bct:brush:design:UnknownBrush', ...
                'Brush ''%s'' not found in category ''%s''.\nNo brushes registered for this category.', ...
                brushType, category_lower);
        else
            % Extract just the type names
            brush_types = cellfun(@(x) strrep(x, [category_lower '_'], ''), ...
                category_brushes, 'UniformOutput', false);
            error('bct:brush:design:UnknownBrush', ...
                'Brush ''%s'' not found in category ''%s''.\nAvailable %s brushes: %s', ...
                brushType, category_lower, category_lower, strjoin(brush_types, ', '));
        end
    end
    
    % Get brush entry from registry
    brush_entry = R.(registry_key);
    
    % Validate that entry has required fields
    if ~isfield(brush_entry, 'Algorithm')
        error('bct:brush:design:InvalidRegistry', ...
            'Brush registry entry ''%s'' is missing Algorithm field', registry_key);
    end
    
    % Get the brush function handle
    brush_fn = brush_entry.Algorithm;
    
    % Validate that it's a function handle
    if ~isa(brush_fn, 'function_handle')
        error('bct:brush:design:InvalidAlgorithm', ...
            'Brush Algorithm for ''%s'' is not a function handle', registry_key);
    end
    
    % Call the brush function with appropriate arguments
    try
        switch category_lower
            case {'patch', 'trajectory'}
                % Patch and trajectory brushes: fn(manifold, params)
                w = brush_fn(manifold, params);
                
            case 'time'
                % Time brushes: fn(manifold, time, params)
                w = brush_fn(manifold, time, params);
        end
    catch ME
        % Provide more context in error message
        error('bct:brush:design:BrushError', ...
            'Error calling brush ''%s'' in category ''%s'':\n%s', ...
            brushType, category_lower, ME.message);
    end
    
    % Validate output
    if ~isnumeric(w) || ~isvector(w) && ~ismatrix(w)
        error('bct:brush:design:InvalidOutput', ...
            'Brush ''%s'' returned invalid output (expected numeric vector or matrix)', ...
            registry_key);
    end
    
    % Validate dimensions
    N = manifold.N;
    if size(w, 1) ~= N
        error('bct:brush:design:DimensionMismatch', ...
            'Brush output first dimension (%d) does not match Manifold.N (%d)', ...
            size(w, 1), N);
    end
    
    % For time category, validate time dimension
    if strcmp(category_lower, 'time')
        T = time.N;
        if size(w, 2) ~= T
            error('bct:brush:design:TimeDimensionMismatch', ...
                'Brush output second dimension (%d) does not match Time.N (%d)', ...
                size(w, 2), T);
        end
    end

end
