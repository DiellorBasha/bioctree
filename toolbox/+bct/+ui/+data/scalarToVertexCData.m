function cdata = scalarToVertexCData(scalarData, vertices, options)
%BCT.UI.DATA.SCALARTOVERTEXCDATA  Convert scalar data to vertex CData RGB
%
%   cdata = bct.ui.data.scalarToVertexCData(scalarData, vertices)
%   cdata = bct.ui.data.scalarToVertexCData(scalarData, vertices, Name, Value, ...)
%
% Purpose
%   Data adapter layer that converts scalar signals to vertex RGB data.
%   Handles various input shapes and delegates colormap resolution to bct.ui.color.
%
% Inputs
%   scalarData - [N×1], [1×N], or scalar: per-vertex scalar values
%   vertices   - [N×3] double: mesh vertices (for size validation)
%
% Name-Value Arguments
%   Colormap     - string or [M×3], colormap specification (default: "parula")
%   CLim         - [min max], color limits (default: auto from data range)
%   NaNColor     - [1×3] RGB for NaN values (default: [0.5 0.5 0.5])
%   InfColor     - [1×3] RGB for Inf values (default: [1 0 0])
%   Normalize    - logical, auto-normalize to [0,1] (default: false)
%
% Output
%   cdata - [N×3] double, RGB values in [0,1] for each vertex
%
% Contract
%   Per BCTUIMANIFOLD_CONTRACT.md:
%   - Scalar → RGB conversion ALWAYS delegates to bct.ui.color
%   - Must handle shape mismatches gracefully with clear errors
%   - NaN/Inf handling with hardcoded fallback colors
%
% See also: bct.ui.color.resolve

    arguments
        scalarData (:,:) double
        vertices (:,3) double
        options.Colormap = "parula"
        options.CLim (1,2) double = []
        options.NaNColor (1,3) double = [0.5 0.5 0.5]
        options.InfColor (1,3) double = [1 0 0]
        options.Normalize (1,1) logical = false
    end
    
    nVerts = size(vertices, 1);
    
    % Handle scalar broadcast
    if isscalar(scalarData)
        scalarData = repmat(scalarData, nVerts, 1);
    end
    
    % Validate and reshape to column
    scalarData = scalarData(:);
    
    if numel(scalarData) ~= nVerts
        error('bct:ui:data:SizeMismatch', ...
            'scalarData has %d elements but mesh has %d vertices', ...
            numel(scalarData), nVerts);
    end
    
    % Handle NaN and Inf
    nanMask = isnan(scalarData);
    infMask = isinf(scalarData);
    validMask = ~nanMask & ~infMask;
    
    % Normalize if requested
    if options.Normalize && any(validMask)
        validData = scalarData(validMask);
        minVal = min(validData);
        maxVal = max(validData);
        if maxVal > minVal
            scalarData(validMask) = (validData - minVal) / (maxVal - minVal);
        end
    end
    
    % Determine color limits
    if isempty(options.CLim)
        if any(validMask)
            validData = scalarData(validMask);
            options.CLim = [min(validData), max(validData)];
        else
            options.CLim = [0 1];
        end
    end
    
    % Resolve colormap via bct.ui.color
    try
        cmapFunc = bct.ui.color.resolve(options.Colormap);
        cmap = cmapFunc(256);
    catch ME
        warning('bct:ui:data:ColormapFallback', ...
            'Failed to resolve colormap "%s": %s. Using parula.', ...
            string(options.Colormap), ME.message);
        cmap = parula(256);
    end
    
    % Map scalar to colormap indices
    clim = options.CLim;
    if clim(2) <= clim(1)
        clim(2) = clim(1) + 1;
    end
    
    % Normalize to [0, 1]
    normalized = (scalarData - clim(1)) / (clim(2) - clim(1));
    normalized = max(0, min(1, normalized));
    
    % Map to colormap indices [1, 256]
    indices = round(normalized * (size(cmap, 1) - 1)) + 1;
    
    % Get RGB from colormap
    cdata = cmap(indices, :);
    
    % Apply NaN/Inf colors
    if any(nanMask)
        cdata(nanMask, :) = repmat(options.NaNColor, sum(nanMask), 1);
    end
    if any(infMask)
        cdata(infMask, :) = repmat(options.InfColor, sum(infMask), 1);
    end
end
