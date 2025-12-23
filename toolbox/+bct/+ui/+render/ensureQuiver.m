function h = ensureQuiver(ax, X, Y, Z, U, V, W, options)
%BCT.UI.RENDER.ENSUREQUIVER  Create or update quiver3 graphics primitive
%
%   h = bct.ui.render.ensureQuiver(ax, X, Y, Z, U, V, W)
%   h = bct.ui.render.ensureQuiver(ax, X, Y, Z, U, V, W, Name, Value, ...)
%
% Purpose
%   Low-level rendering primitive for vector field visualization.
%   Handles quiver3 object lifecycle and property configuration.
%
% Inputs
%   ax      - UIAxes or axes handle
%   X,Y,Z   - [N×1] double: arrow tail positions
%   U,V,W   - [N×1] double: arrow direction vectors
%
% Name-Value Arguments
%   Handle      - existing quiver3 handle to update (default: [])
%   Color       - [1×3] RGB or color spec (default: [1 1 1])
%   LineWidth   - scalar > 0 (default: 1.5)
%   AutoScale   - 'on' | 'off' (default: 'off')
%   AutoScaleFactor - scalar > 0 (default: 0.9)
%   MaxHeadSize - scalar > 0 (default: 0.5)
%
% Output
%   h - quiver3 handle
%
% Contract
%   - If Handle is valid, updates XData/YData/ZData/UData/VData/WData
%   - If Handle is invalid/empty, creates new quiver3
%   - Always returns valid handle or errors
%
% See also: quiver3, bct.ui.data.sampleVectors

    arguments
        ax
        X (:,1) double
        Y (:,1) double
        Z (:,1) double
        U (:,1) double
        V (:,1) double
        W (:,1) double
        options.Handle = []
        options.Color (1,3) double = [1 1 1]
        options.LineWidth (1,1) double = 1.5
        options.AutoScale (1,1) string = "off"
        options.AutoScaleFactor (1,1) double = 0.9
        options.MaxHeadSize (1,1) double = 0.5
    end
    
    % Validate input sizes
    n = numel(X);
    if numel(Y) ~= n || numel(Z) ~= n || numel(U) ~= n || numel(V) ~= n || numel(W) ~= n
        error('bct:ui:render:SizeMismatch', ...
            'All position and direction vectors must have the same length');
    end
    
    % Check if existing handle is valid
    updateExisting = ~isempty(options.Handle) && isvalid(options.Handle) && isgraphics(options.Handle, 'quiver');
    
    if updateExisting
        % Update existing quiver
        h = options.Handle;
        set(h, ...
            'XData', X, 'YData', Y, 'ZData', Z, ...
            'UData', U, 'VData', V, 'WData', W);
    else
        % Create new quiver3
        h = quiver3(ax, X, Y, Z, U, V, W, 0);  % 0 = disable auto-scaling
    end
    
    % Configure appearance
    set(h, ...
        'Color', options.Color, ...
        'LineWidth', options.LineWidth, ...
        'AutoScale', char(options.AutoScale), ...
        'AutoScaleFactor', options.AutoScaleFactor, ...
        'MaxHeadSize', options.MaxHeadSize);
end
