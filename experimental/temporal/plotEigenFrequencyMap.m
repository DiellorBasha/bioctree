function fig = plotEigenFrequencyMap(psdL, psdR, freqs, eigenvaluesL, eigenvaluesR, opts)
%PLOTEIGENFREQUENCYMAP Plot 2-D eigenmode × frequency power map.
%
%   fig = plotEigenFrequencyMap(psdL, psdR, freqs, eigenvaluesL, eigenvaluesR)
%   fig = plotEigenFrequencyMap(__, Name=Value)
%
%   Displays a heat-map image where the y-axis is eigenmode index (or
%   eigenvalue) and the x-axis is temporal frequency, with color encoding
%   PSD magnitude. This is the joint eigenmode–frequency decomposition.
%
%   Inputs:
%       psdL         - [nModesL × nFreqs] power spectral density, left
%       psdR         - [nModesR × nFreqs] power spectral density, right
%       freqs        - [1 × nFreqs] frequency axis (Hz)
%       eigenvaluesL - [nModesL × 1] eigenvalues, left hemisphere
%       eigenvaluesR - [nModesR × 1] eigenvalues, right hemisphere
%
%   Name-Value Options:
%       YAxis       - 'index' (default) or 'eigenvalue'
%       FreqRange   - [fLow fHigh] Hz display range (default: [1 80])
%       MaxModes    - max modes on y-axis   (default: all)
%       LogColor    - log10 color scale     (default: true)
%       Colormap    - colormap name         (default: "parula")
%       CLim        - [lo hi] or [] for auto (default: [])
%       BandLines   - show canonical band boundaries (default: true)
%       Title       - figure title (default: "Eigenmode–Frequency Map")
%
%   Output:
%       fig - figure handle

arguments
    psdL         (:,:) double
    psdR         (:,:) double
    freqs        (1,:) double
    eigenvaluesL (:,1) double
    eigenvaluesR (:,1) double
    opts.YAxis     (1,1) string {mustBeMember(opts.YAxis, ["index","eigenvalue"])} = "index"
    opts.FreqRange (1,2) double = [1 80]
    opts.MaxModes  (1,1) double {mustBePositive} = Inf
    opts.LogColor  (1,1) logical = true
    opts.Colormap  (1,1) string = "parula"
    opts.CLim      (1,:) double = []
    opts.BandLines (1,1) logical = true
    opts.Title     (1,1) string = "Eigenmode–Frequency Map"
end

fig = figure('Name', opts.Title, 'NumberTitle', 'off');
tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

plotHemiMap(psdL, freqs, eigenvaluesL, "Left hemisphere", opts);
plotHemiMap(psdR, freqs, eigenvaluesR, "Right hemisphere", opts);

applyPlotDefaults(fig);
sgtitle(opts.Title, 'FontWeight', 'bold', 'FontSize', 16);

end

% ---- Helper ----
function plotHemiMap(psd, freqs, eigenvalues, titleStr, opts)
    % Truncate modes
    nModes = min(size(psd, 1), opts.MaxModes);
    psd = psd(1:nModes, :);
    eigenvalues = eigenvalues(1:nModes);

    % Frequency mask
    fMask = freqs >= opts.FreqRange(1) & freqs <= opts.FreqRange(2);
    fPlot = freqs(fMask);
    P = psd(:, fMask);

    % Log color scale
    if opts.LogColor
        P = log10(P + eps);
    end

    % Y-axis
    if opts.YAxis == "eigenvalue"
        yVec = eigenvalues;
        yLabel = "Eigenvalue \lambda";
    else
        yVec = (1:nModes)';
        yLabel = "Mode index";
    end

    nexttile;
    imagesc(fPlot, yVec, P);
    axis xy;
    xlabel("Frequency (Hz)");
    ylabel(yLabel);
    title(titleStr);
    colormap(gca, opts.Colormap);

    if ~isempty(opts.CLim)
        clim(opts.CLim);
    end

    cb = colorbar;
    if opts.LogColor
        cb.Label.String = "log_{10} PSD";
    else
        cb.Label.String = "PSD";
    end

    % Band boundary lines
    if opts.BandLines
        hold on;
        bands = [4 8 12 30 59];
        for b = bands
            if b >= opts.FreqRange(1) && b <= opts.FreqRange(2)
                xline(b, '-', 'Color', 'w', 'LineWidth', 0.8, 'Alpha', 0.7);
            end
        end
        hold off;
    end
end
