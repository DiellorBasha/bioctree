function [figs, mask] = plotJointKernels(jointKernel, spatialWeights, eigenvalues, freqs, scaleLabels, opts)
%PLOTJOINTKERNELS  Visualize joint spectral-temporal filter kernels
%
%   plotJointKernels(jointKernel, spatialWeights, eigenvalues, freqs, scaleLabels)
%   plotJointKernels(__, Name=Value)
%   figs = plotJointKernels(__)
%
%   Produces two figures:
%     (1) Tiled heatmaps — one per scale showing K_s(λ, f) on the
%         (eigenmode rank, frequency) plane.
%     (2) Marginal projections — three-panel figure with:
%         (a) spatial kernels h(λ) per scale,
%         (b) temporal kernel ψ(f),
%         (c) composite sum Σ_s K_s(λ, f).
%
%   Inputs
%   ------
%   jointKernel    : [nModes × nFreqs × nScales]
%       Joint filter kernel array for one hemisphere.
%   spatialWeights : [nModes × nScales]
%       Spatial kernel weights h(λ) per scale.
%   eigenvalues    : [nModes × 1]
%       Eigenvalues corresponding to the mode axis.
%   freqs          : [1 × nFreqs] or [nFreqs × 1]
%       Temporal frequency axis in Hz.
%   scaleLabels    : [1 × nScales] string
%       Labels for each spatial scale (e.g. ["lowpass", "scale 1", ...]).
%
%   Name-Value Options
%   ------------------
%   TemporalWeights  : [1 × nFreqs] double (default = [])
%       Explicit temporal kernel ψ(f).  If empty, inferred from
%       jointKernel(:,:,end) ./ spatialWeights(:,end) at the peak mode.
%   TemporalLabel    : string (default = "Temporal kernel")
%       Label for the temporal kernel subplot title.
%   Colormap         : (default = parula(256))
%       Colormap for heatmaps.
%   YAxis            : "rank" | "eigenvalue"  (default = "rank")
%       Y-axis type: eigenmode rank index or eigenvalue magnitude.
%   LogEigenvalue    : logical (default = false)
%       Log-scale eigenvalue axis (only when YAxis="eigenvalue").
%   Title            : string (default = "")
%       Super-title prefix.  If empty, uses a default label.
%   MaxCols          : double (default = 3)
%       Maximum columns in the tiled heatmap layout.
%   Transpose        : logical (default = false)
%       If true, plot eigenmodes on x-axis and frequency on y-axis
%       (default is frequency on x, eigenmodes on y).
%   Style            : "color" | "mask"  (default = "color")
%       "color" — standard colormap heatmaps.
%       "mask"  — grayscale [0,1] normalized for use as transparency overlay.
%
%   Output
%   ------
%   figs : [1 × 2] figure handles  [heatmapFig, marginalsFig]
%   mask : struct — normalized [0,1] composite kernel for transparency overlay
%          .alpha  — [m × n] double, composite kernel normalized to [0,1]
%          .x, .y  — axis vectors matching the plot orientation
%          .xLabel, .yLabel — axis label strings
%
%   See also eigenmodeJointFilter, plotJointFilterResults,
%            plotEigenmodeSpectrogram

    arguments
        jointKernel    (:,:,:) double
        spatialWeights (:,:)   double
        eigenvalues    (:,1)   double
        freqs          (1,:)   double
        scaleLabels    (1,:)   string
        opts.TemporalWeights  (1,:) double  = []
        opts.TemporalLabel    (1,1) string  = "Temporal kernel"
        opts.Colormap                       = parula(256)
        opts.YAxis            (1,1) string {mustBeMember(opts.YAxis, ...
                                    ["rank","eigenvalue"])} = "rank"
        opts.LogEigenvalue    (1,1) logical = false
        opts.Title            (1,1) string  = ""
        opts.MaxCols          (1,1) double {mustBePositive, mustBeInteger} = 3
        opts.Transpose        (1,1) logical = false
        opts.Style            (1,1) string {mustBeMember(opts.Style, ...
                                    ["color","mask"])} = "color"
    end

    [nModes, nFreqs, nScales] = size(jointKernel);
    freqs = freqs(:)';

    % --- Recover temporal kernel if not supplied ---
    if isempty(opts.TemporalWeights)
        % Pick mode with largest peak across all scales to infer ψ(f)
        [~, peakMode] = max(max(spatialWeights, [], 2));
        hPeak = spatialWeights(peakMode, end);
        if hPeak > 0
            opts.TemporalWeights = jointKernel(peakMode, :, end) / hPeak;
        else
            opts.TemporalWeights = ones(1, nFreqs);
        end
    end
    temporalWeights = opts.TemporalWeights;

    % --- Y-axis ---
    switch opts.YAxis
        case "rank"
            yVals  = 1:nModes;
            yLabel = 'Eigenmode rank';
        case "eigenvalue"
            yVals  = eigenvalues(:)';
            yLabel = '\lambda  (eigenvalue)';
    end

    % --- Title prefix ---
    if opts.Title == ""
        titlePrefix = "Joint Kernels";
    else
        titlePrefix = opts.Title;
    end

    % --- Orientation setup (transpose swaps eigenmode ↔ frequency axes) ---
    if opts.Transpose
        heatX = yVals;        heatY = freqs;
        xLabelStr = yLabel;   yLabelStr = 'Frequency (Hz)';
    else
        heatX = freqs;        heatY = yVals;
        xLabelStr = 'Frequency (Hz)';  yLabelStr = yLabel;
    end

    % --- Style setup (mask → grayscale [0,1]) ---
    if opts.Style == "mask"
        cmap    = gray(256);
        Kglobal = max(jointKernel(:));
        if Kglobal == 0, Kglobal = 1; end
    else
        cmap    = opts.Colormap;
        Kglobal = [];  %#ok<NASGU>
    end

    % ================================================================
    %  Figure 1: Tiled heatmaps — one per scale
    % ================================================================
    nCols = min(nScales, opts.MaxCols);
    nRows = ceil(nScales / nCols);

    fig1 = figure('Name', sprintf('%s  K(\\lambda, f)', titlePrefix), ...
        'NumberTitle', 'off', 'Position', [80 80 380*nCols 320*nRows]);
    tiledlayout(nRows, nCols, 'TileSpacing', 'compact', 'Padding', 'compact');

    for si = 1:nScales
        nexttile;
        K2D = jointKernel(:, :, si);
        plotData = K2D;
        if opts.Style == "mask", plotData = plotData / Kglobal; end
        if opts.Transpose,       plotData = plotData'; end

        if opts.YAxis == "eigenvalue" && opts.LogEigenvalue
            pcolor(heatX, heatY, plotData);
            shading flat;
            if opts.Transpose, set(gca, 'XScale', 'log');
            else,              set(gca, 'YScale', 'log'); end
        else
            imagesc(heatX, heatY, plotData);
            axis xy;
        end

        colormap(gca, cmap);
        if opts.Style == "mask"
            clim([0 1]);
        else
            kMax = max(plotData(:));
            if kMax > 0, clim([0 kMax]); end
        end

        title(scaleLabels(si));

        if mod(si, nCols) == 1 || nCols == 1
            ylabel(yLabelStr);
        else
            yticklabels([]);
        end
        if si > nScales - nCols
            xlabel(xLabelStr);
        else
            xticklabels([]);
        end
    end

    applyPlotDefaults(fig1);
    sgtitle(sprintf('%s   K(\\lambda, f) = h(\\lambda) \\cdot \\psi(f)', ...
        titlePrefix), 'FontSize', 16, 'FontWeight', 'bold');

    % ================================================================
    %  Figure 2: Marginal projections + composite
    % ================================================================
    fig2 = figure('Name', sprintf('%s — Marginals', titlePrefix), ...
        'NumberTitle', 'off', 'Position', [100 100 900 350]);
    tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

    % (a) Spatial marginals h(λ) per scale
    nexttile;
    co = lines(nScales);
    hold on;
    for si = 1:nScales
        plot(eigenvalues, spatialWeights(:, si), 'Color', co(si,:), ...
            'LineWidth', 1.5, 'DisplayName', scaleLabels(si));
    end
    hold off;
    xlabel('\lambda  (eigenvalue)');
    ylabel('h(\lambda)');
    title('Spatial kernels');
    legend('Location', 'best', 'FontSize', 14);

    % (b) Temporal marginal ψ(f)
    nexttile;
    plot(freqs, temporalWeights, 'k', 'LineWidth', 2);
    xlabel('Frequency (Hz)');
    ylabel('\psi(f)');
    title(opts.TemporalLabel);

    % (c) Composite: sum across scales
    nexttile;
    Ksum = sum(jointKernel, 3);
    plotSum = Ksum;
    if opts.Style == "mask", plotSum = plotSum / Kglobal; end
    if opts.Transpose,       plotSum = plotSum'; end

    if opts.YAxis == "eigenvalue" && opts.LogEigenvalue
        pcolor(heatX, heatY, plotSum);
        shading flat;
        if opts.Transpose, set(gca, 'XScale', 'log');
        else,              set(gca, 'YScale', 'log'); end
    else
        imagesc(heatX, heatY, plotSum);
        axis xy;
    end

    colormap(gca, cmap);
    if opts.Style == "mask", clim([0 1]); end
    colorbar;
    xlabel(xLabelStr);
    ylabel(yLabelStr);
    title('\Sigma_s K_s(\lambda, f)   (all scales)');

    applyPlotDefaults(fig2);
    sgtitle(sprintf('%s — Marginals & Composite', titlePrefix), ...
        'FontSize', 16, 'FontWeight', 'bold');

    drawnow;

    % --- Output ---
    figs = [fig1, fig2];

    % --- Mask output (composite kernel normalized to [0,1]) ---
    Kcomp = sum(jointKernel, 3);
    Kmax  = max(Kcomp(:));
    if Kmax == 0, Kmax = 1; end
    maskAlpha = Kcomp / Kmax;
    if opts.Transpose, maskAlpha = maskAlpha'; end
    mask = struct('alpha', maskAlpha, ...
                  'x', heatX, 'y', heatY, ...
                  'xLabel', xLabelStr, 'yLabel', yLabelStr);
end
