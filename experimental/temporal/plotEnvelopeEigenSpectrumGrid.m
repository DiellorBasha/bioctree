function fig = plotEnvelopeEigenSpectrumGrid(avgPowerL, avgPowerR, eigenvaluesL, eigenvaluesR, bandNames, opts)
%PLOTENVELOPEEIGENSPECTRUMGRID Per-band eigenmode power in a grid layout.
%
%   fig = plotEnvelopeEigenSpectrumGrid(avgPowerL, avgPowerR, ...
%             eigenvaluesL, eigenvaluesR, bandNames)
%   fig = plotEnvelopeEigenSpectrumGrid(__, Name=Value)
%
%   Displays one subplot per band, each showing left (blue) and right (red)
%   hemisphere eigenmode power spectra side-by-side.
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
    opts.Scale     (1,1) string {mustBeMember(opts.Scale, ["linear","log","semilogy"])} = "semilogy"
    opts.MaxModes  (1,1) double {mustBePositive} = Inf
    opts.Title     (1,1) string = "Per-Band Envelope Eigenspectrum"
end

nBands = numel(bandNames);

% Truncate modes
nL = min(size(avgPowerL, 1), opts.MaxModes);
nR = min(size(avgPowerR, 1), opts.MaxModes);
avgPowerL = avgPowerL(1:nL, :);
avgPowerR = avgPowerR(1:nR, :);
eigenvaluesL = eigenvaluesL(1:nL);
eigenvaluesR = eigenvaluesR(1:nR);

% X-axis
if opts.XAxis == "eigenvalue"
    xL = eigenvaluesL;  xR = eigenvaluesR;
    xLabel = "Eigenvalue \lambda";
else
    xL = (1:nL)';  xR = (1:nR)';
    xLabel = "Mode index";
end

% Layout: 1 row × nBands columns (or 2 rows if ≥ 6 bands)
if nBands <= 5
    nRows = 1; nCols = nBands;
else
    nRows = 2; nCols = ceil(nBands / 2);
end

fig = figure('Name', opts.Title, 'NumberTitle', 'off');
tiledlayout(nRows, nCols, 'TileSpacing', 'compact', 'Padding', 'compact');

for bi = 1:nBands
    nexttile; hold on;

    plotFn(xL, avgPowerL(:, bi), opts.Scale, [0.2 0.4 0.8], 'LH');
    plotFn(xR, avgPowerR(:, bi), opts.Scale, [0.8 0.3 0.3], 'RH');

    hold off;
    title(bandNames(bi), 'FontWeight', 'bold');
    xlabel(xLabel);
    if bi == 1 || (nBands > 5 && bi == nCols + 1)
        ylabel("Mean power");
    end
    legend('Location', 'northeast', 'FontSize', 14);
    xlim([min(xL(1), xR(1)), max(xL(end), xR(end))]);
end

applyPlotDefaults(gcf);
sgtitle(opts.Title, 'FontWeight', 'bold', 'FontSize', 16);

end

% ---- Helper ----
function plotFn(x, y, scale, col, label)
    switch scale
        case "log"
            loglog(x, y, 'Color', col, 'LineWidth', 1.0, 'DisplayName', label);
        case "semilogy"
            semilogy(x, y, 'Color', col, 'LineWidth', 1.0, 'DisplayName', label);
        otherwise
            plot(x, y, 'Color', col, 'LineWidth', 1.0, 'DisplayName', label);
    end
end
