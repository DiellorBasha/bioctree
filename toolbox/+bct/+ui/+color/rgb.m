function [rgb, out] = rgb(values, options)
%BCT.UI.COLOR.RGB  Map scalar values to RGB colors
%
%   rgb = bct.ui.color.rgb(values)
%   rgb = bct.ui.color.rgb(values, Name, Value, ...)
%   [rgb, out] = bct.ui.color.rgb(...)
%
% Purpose
%   Primary entry point for converting scalar numeric data to RGB using
%   a named colormap.
%
% Inputs
%   values - numeric array of any shape
%
% Name-Value Arguments (v1)
%   Colormap  (string) - colormap ID (default: "parula")
%   NColors   (positive integer) - number of colors (default: 256)
%   CLim      ([lo hi] or []) - color limits (default: [] = auto from data)
%   NaNColor  (1×3 double) - RGB for non-finite values (default: [0.2 0.2 0.2])
%
% Outputs
%   rgb - [..., 3] double, same shape as values with last dimension = 3
%   out - (optional) struct with fields:
%         ColormapId  - colormap ID used
%         Colormap    - [n×3] colormap matrix
%         NColors     - number of colors
%         CLim        - computed or provided color limits
%         NaNColor    - RGB for NaN values
%         ValidMask   - logical mask of finite values
%
% Behavior
%   1. Parse inputs; merge with defaults from schema()
%   2. Validate options using validate()
%   3. Resolve colormap array via resolve()
%   4. Compute CLim if absent using clim()
%   5. Map finite values to colormap indices
%   6. Non-finite values map to NaNColor
%
% Mapping Algorithm
%   For finite value x:
%     - If CLim(1) == CLim(2): use midpoint color
%     - Else: t = (x - lo)/(hi - lo), clamped to [0,1]
%     - index i = 1 + floor(t*(NColors-1))
%     - rgb = cmap(i,:)
%
% Examples
%   % Basic usage
%   data = randn(100, 100);
%   rgb = bct.ui.color.rgb(data);
%
%   % Custom colormap
%   rgb = bct.ui.color.rgb(data, "Colormap", "redblue");
%
%   % Fixed color limits
%   rgb = bct.ui.color.rgb(data, "CLim", [-2 2]);
%
%   % Get additional output
%   [rgb, out] = bct.ui.color.rgb(data);
%
% See also: bct.ui.color.resolve, bct.ui.color.clim, bct.ui.color.schema

    arguments
        values {mustBeNumeric}
        options.Colormap (1,1) string = "parula"
        options.NColors (1,1) double {mustBePositive, mustBeInteger} = 256
        options.CLim {mustBeNumericOrEmpty} = []
        options.NaNColor (1,3) double = [0.2 0.2 0.2]
    end

    % Build spec from options
    spec = struct(...
        "Colormap", options.Colormap, ...
        "NColors", options.NColors, ...
        "CLim", options.CLim, ...
        "NaNColor", options.NaNColor);

    % Validate spec
    bct.ui.color.validate(spec);

    % Resolve colormap
    cmap = bct.ui.color.resolve(spec.Colormap, spec.NColors);

    % Compute CLim if not provided
    if isempty(spec.CLim)
        CLim = bct.ui.color.clim(values);
    else
        CLim = spec.CLim;
    end

    % Initialize output
    origShape = size(values);
    values = double(values(:));
    n = numel(values);
    
    % Allocate RGB output
    rgbFlat = zeros(n, 3);
    
    % Identify finite values
    finiteMask = isfinite(values);
    
    % Map finite values to colormap indices
    if any(finiteMask)
        finiteVals = values(finiteMask);
        
        % Handle constant CLim
        if CLim(1) == CLim(2)
            % Map to midpoint color
            idx = ceil(spec.NColors / 2);
            rgbFlat(finiteMask, :) = repmat(cmap(idx, :), sum(finiteMask), 1);
        else
            % Normalize to [0, 1]
            t = (finiteVals - CLim(1)) / (CLim(2) - CLim(1));
            t = max(0, min(1, t));  % Clamp
            
            % Map to colormap indices [1, NColors]
            idx = 1 + floor(t * (spec.NColors - 1));
            idx = max(1, min(spec.NColors, idx));  % Safety clamp
            
            % Assign colors
            rgbFlat(finiteMask, :) = cmap(idx, :);
        end
    end
    
    % Map non-finite values to NaNColor
    if any(~finiteMask)
        rgbFlat(~finiteMask, :) = repmat(spec.NaNColor, sum(~finiteMask), 1);
    end
    
    % Reshape to original shape + RGB dimension
    rgb = reshape(rgbFlat, [origShape, 3]);
    
    % Optional output
    if nargout > 1
        out = struct(...
            "ColormapId", spec.Colormap, ...
            "Colormap", cmap, ...
            "NColors", spec.NColors, ...
            "CLim", CLim, ...
            "NaNColor", spec.NaNColor, ...
            "ValidMask", reshape(finiteMask, origShape));
    end
end

function mustBeNumericOrEmpty(x)
    if ~isempty(x)
        validateattributes(x, {'numeric'}, {'size', [1 2]});
    end
end
