function plotSensorLine(Z, yIdx, x, varargin)
% plotSensorLine - Visualize wave propagation along a surface line with optional masking
%
% Inputs:
%   Z         - 3D array [Y x X x T], e.g., amplitude over time
%   yIdx      - Row index to extract the line (fixed Y, all X)
%   x         - x-coordinates vector (length must match size(Z,2))
%
% Optional Name-Value Pairs:
%   'MaskIndices'  - Vector of indices into x to keep (others set to NaN)
%   'MaskCoords'   - Vector of x-coordinate values to extract closest matches
%   'FigureName'   - Filename to save the figure (without extension)
%
% Example:
%   plotSensorLine(Z, 60, x, 'MaskCoords', [-5 0 5], 'FigureName', 'masked_plot');

    % Parse inputs
    p = inputParser;
    addParameter(p, 'MaskIndices', []);
    addParameter(p, 'MaskCoords', []);
    addParameter(p, 'FigureName', 'sensor_line_plot');
    parse(p, varargin{:});

    xMaskIdx = p.Results.MaskIndices;
    xMaskCoords = p.Results.MaskCoords;
    figName = p.Results.FigureName;

    % Extract 2D data slice [X x T] at fixed y
    sensorLineFull = squeeze(Z(yIdx, :, :));
    [Nx, T] = size(sensorLineFull);
    tsteps = 1:T;

    % Resolve mask from coordinates
    if ~isempty(xMaskCoords)
        xMaskIdx = knnsearch(x(:), xMaskCoords(:));
    end

    % Build logical mask
    mask = false(1, Nx);
    if ~isempty(xMaskIdx)
        mask(xMaskIdx) = true;
    else
        mask(:) = true;  % keep all if no mask provided
    end

    % Apply mask to get sparse data for imagesc
    sensorLineMasked = sensorLineFull;
    sensorLineMasked(~mask, :) = NaN;

    % Plot
    figure('Color', 'w'); clf;

    % --- Top subplot: imagesc with masked data ---
    subplot(1,2,1);
    imagesc(tsteps, x, sensorLineMasked);  % spatial axis = x
    xlabel('Time (samples)');
    ylabel('Sensor Position (X)');
    title(sprintf('Wave Amplitude at Y = %d (Masked)', yIdx));
    axis square;
    set(gca, 'YDir', 'normal');

    % --- Bottom subplot: stacked plots from masked points only ---
    subplot(1,2,2); hold on;
    maskedIndices = find(mask);
    for k = 1:size(sensorLineFull, 1)
        plot(tsteps, sensorLineFull(k,:) + k, 'k');  % add offset using x(k)
    end
    xlabel('Time (samples)');
    ylabel('Amplitude + X Position');
    title('Time Series from Masked Sensors (Stacked)');
    axis tight square;

    % Save figure
    saveas(gcf, [figName '.png']);
end
