function fig = plotEnvelopeEigenSpectrumAllBands(avgPowerL, avgPowerR, eigenvaluesL, eigenvaluesR, bandNames, opts)
%PLOTENVELOPEEIGENSPECTRUMALLBANDS Overlay per-band eigenmode power spectra.
%
%   fig = plotEnvelopeEigenSpectrumAllBands(avgPowerL, avgPowerR, ...
%             eigenvaluesL, eigenvaluesR, bandNames)
%   fig = plotEnvelopeEigenSpectrumAllBands(__, Name=Value)
%
%   Displays the time-averaged eigenmode power (mean c_k^2) for each
%   frequency band as overlaid curves, one panel per hemisphere.
%
%   Inputs:
%       avgPowerL    - [nModesL × nBands] time-averaged eigenmode power, left
%       avgPowerR    - [nModesR × nBands] time-averaged eigenmode power, right
%       eigenvaluesL - [nModesL × 1] eigenvalues, left hemisphere
%       eigenvaluesR - [nModesR × 1] eigenvalues, right hemisphere
%       bandNames    - [1 × nBands] string array of band labels
%
%   Name-Value Options:
%       XAxis     - 'index' (default) or 'eigenvalue'
%       Scale     - 'linear' (default), 'log', or 'semilogy'
%       MaxModes  - max modes to display (default: all)
%       Normalize - normalize each band's curve to max=1 (default: false)
%       Title     - figure title
%
%   Output:
%       fig - figure handle

arguments
    avgPowerL    (:,:) double
    avgPowerR    (:,:) double
    eigenvaluesL (:,1) double
    eigenvaluesR (:,1) double
    bandNames    (1,:) string
    opts.XAxis     (1,1) string {mustBeMember(opts.XAxis, ["index","eigenvalue"])} = "index"
    opts.Scale     (1,1) string {mustBeMember(opts.Scale, ["linear","log","semilogy"])} = "linear"
    opts.MaxModes  (1,1) double {mustBePositive} = Inf
    opts.Normalize (1,1) logical = false
    opts.Title     (1,1) string = "Envelope Eigenspectrum — All Bands"
end

nBands = numel(bandNames);

fig = figure('Name', opts.Title, 'NumberTitle', 'off');
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

plotHemi(avgPowerL, eigenvaluesL, bandNames, nBands, "Left hemisphere", opts);
plotHemi(avgPowerR, eigenvaluesR, bandNames, nBands, "Right hemisphere", opts);

applyPlotDefaults(gcf);
sgtitle(opts.Title, 'FontWeight', 'bold', 'FontSize', 16);

end

% ---- Helper ----
function plotHemi(avgPower, eigenvalues, bandNames, nBands, titleStr, opts)
    nModes = min(size(avgPower, 1), opts.MaxModes);
    avgPower = avgPower(1:nModes, :);
    eigenvalues = eigenvalues(1:nModes);

    if opts.XAxis == "eigenvalue"
        x = eigenvalues;
        xLabel = "Eigenvalue \lambda";
    else
        x = (1:nModes)';
        xLabel = "Mode index";
    end

    nexttile; hold on;
    cmap = lines(nBands);

    for bi = 1:nBands
        y = avgPower(:, bi);
        if opts.Normalize && max(y) > 0
            y = y / max(y);
        end
        switch opts.Scale
            case "log",     loglog(x, y, 'Color', cmap(bi,:), 'LineWidth', 1.2);
            case "semilogy",semilogy(x, y, 'Color', cmap(bi,:), 'LineWidth', 1.2);
            otherwise,      plot(x, y, 'Color', cmap(bi,:), 'LineWidth', 1.2);
        end
    end

    hold off;
    xlabel(xLabel);
    ylabel(yLabelStr(opts.Normalize));
    title(titleStr);
    legend(bandNames, 'Location', 'northeast', 'FontSize', 14);
    xlim([x(1) x(end)]);
end

function s = yLabelStr(normalized)
    if normalized
        s = "Normalized power";
    else
        s = "Mean power  \langle c_k^2 \rangle";
    end
end
